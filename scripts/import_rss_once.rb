require "net/http"
require "nokogiri"

# Usage:
#   bin/rails runner scripts/import_rss_once.rb

def http_get(uri)
  uri = URI(uri) unless uri.is_a?(URI)
  limit = 5
  current = uri
  loop do
    http = Net::HTTP.new(current.host, current.port)
    http.use_ssl = current.scheme == "https"
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?
    req = Net::HTTP::Get.new(current.request_uri)
    req["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119 Safari/537.36"
    res = http.request(req)

    case res
    when Net::HTTPRedirection
      raise "Too many redirects" if (limit -= 1) < 0
      location = URI(res["location"])
      current = location.relative? ? URI.join(current, location) : location
    else
      return [res, current]
    end
  end
end

def fetch_xml(url)
  res, _ = http_get(url)
  Nokogiri::XML(res.body) { |c| c.recover }
end

def fetch_html(url)
  res, _ = http_get(url)
  Nokogiri::HTML(res.body)
end

def first_item(doc)
  (doc.xpath("//item").to_a + doc.xpath("//entry").to_a).first
end

def text_of(node, xpath)
  node.at_xpath(xpath)&.text&.strip
end

def content_html_for(item)
  # Prefer content:encoded, then content, then description/summary
  text = item.at_xpath("*[local-name()='encoded']")&.text
  text ||= item.at_xpath("content|*[local-name()='content']")&.text
  text ||= item.at_xpath("summary")&.text
  text ||= item.at_xpath("description")&.text
  text.to_s
end

def categories_for(item)
  item.xpath("category").map { |c| c.text.to_s.strip }.reject(&:empty?)
end

def sanitize_tags(cats)
  cats
    .map { |t| t.to_s.strip }
    .map { |t| t.delete(" ") } # remove spaces entirely
    .map { |t| t.gsub(/[^[:alnum:]]/i, "") } # keep only alphanumeric
    .map { |t| t.downcase[0, 20] }
    .reject(&:empty?)
    .uniq
    .first(Article::MAX_TAG_LIST_SIZE)
end

def strip_tracking(url)
  return "" if url.to_s.empty?
  # Remove common tracking query params and known source= patterns
  uri = URI(url)
  if uri.query
    params = URI.decode_www_form(uri.query).reject { |k, _| k =~ /^(utm_|ref|source)$/i }
    uri.query = params.any? ? URI.encode_www_form(params) : nil
  end
  uri.to_s.split("?source=").first
end

def host_from(url)
  return nil if url.to_s.empty?
  u = URI(url)
  (u.host || "").sub(/^www\./, "")
rescue
  nil
end

def extract_image_from_item(item)
  # Try enclosure with image type
  enclosure = item.at_xpath("enclosure[@type][@url]")
  if enclosure && enclosure["type"].to_s.start_with?("image/")
    return enclosure["url"].to_s
  end

  # Try media:content with image
  media = item.at_xpath("*[local-name()='content'][@url][@type]")
  if media && media["type"].to_s.start_with?("image/")
    return media["url"].to_s
  end

  nil
end

def extract_image_from_html(html)
  doc = Nokogiri::HTML(html)
  img = doc.at_css("img[src]")
  img&.[]("src")
end

def absolutize(base_url, src)
  return src if src.to_s =~ /\Ahttps?:\/\//i
  URI.join(base_url, src).to_s
rescue
  src
end

def extract_og_image_from_page(url)
  page = fetch_html(url)
  og = page.at_xpath("//meta[@property='og:image']/@content")&.text ||
       page.at_xpath("//meta[@property='og:image:secure_url']/@content")&.text ||
       page.at_xpath("//meta[@name='twitter:image']/@content")&.text
  # Optional: prefer large images when width meta available
  if og
    width = page.at_xpath("//meta[@property='og:image:width']/@content")&.text.to_i
    height = page.at_xpath("//meta[@property='og:image:height']/@content")&.text.to_i
    og = absolutize(url, og)
    return og if width.zero? || height.zero? || (width >= 600 && height >= 315)
  end
  # Fallback: choose first large-looking img in page if metas absent/insufficient
  candidates = page.css("img[src]").map { |n| absolutize(url, n["src"]) }.uniq
  sized = candidates.select { |s| s =~ /([\-_])(\d{3,4})x(\d{3,4})([\._-]|$)/i }
  pick = sized.find { |s| s[/([\-_])(\d{3,4})x(\d{3,4})/i] && $2.to_i >= 600 && $3.to_i >= 315 } || sized.first || candidates.first
  pick
rescue
  nil
end

def remove_images_from_html(html)
  frag = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
  frag.css("picture").each(&:remove)
  frag.css("figure").each { |fig| fig.remove if fig.at_css("img") }
  frag.css("img").each(&:remove)
  frag.to_html
end

def ensure_read_more(body_html, url)
  return body_html if url.to_s.empty?
  host = host_from(url)
  return body_html if host.nil?

  # If body already includes a link to the source host, skip adding
  if body_html.to_s.include?(host)
    return body_html
  end

  suffix = "\n\nRead the full article on [#{host}](#{url})."
  body_html.to_s.strip + suffix
end

def create_from_feed(feed_url, label: nil)
  xml = fetch_xml(feed_url)
  item = first_item(xml)
  raise "No items in feed: #{feed_url}" unless item

  title = text_of(item, "title")
  link = text_of(item, "link") || text_of(item, "*[local-name()='link']/@href")
  link = strip_tracking(link)
  content_html = content_html_for(item)

  # Image selection strategy: RSS image -> first IMG in content -> og:image
  image = extract_image_from_item(item)
  image ||= extract_image_from_html(content_html)
  image ||= extract_og_image_from_page(link) if link.present?

  # Tags from categories, normalized and limited to 4
  tags = sanitize_tags(categories_for(item))

  # Remove inline images to avoid duplication with cover image
  content_without_imgs = remove_images_from_html(content_html)
  # Append a minimal read-more if not already present
  body_markdown = ensure_read_more(content_without_imgs, link)

  user = User.first
  raise "No users in DB" unless user

  # Avoid duplicates for this user
  if Article.where(user_id: user.id, feed_source_url: link).exists?
    puts "Skipped (duplicate): #{title}"
    return
  end

  article = Article.create!(
    title: title,
    body_markdown: body_markdown,
    user_id: user.id,
    published: true,
    published_from_feed: true,
    feed_source_url: link,
    main_image: image,
    tag_list: tags
  )

  puts "#{label || host_from(feed_url)} => #{article.id}: #{article.title}"
  puts "http://localhost:4000#{article.path}"
  puts ""
end

# Sources: latest one from each
create_from_feed("https://daily.bandcamp.com/feed", label: "bandcamp")
create_from_feed("https://www.ableton.com/en/blog/feeds/latest/", label: "ableton")
