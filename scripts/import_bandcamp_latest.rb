require "net/http"
require "nokogiri"

# Usage:
#   bin/rails runner scripts/import_bandcamp_latest.rb

BANDCAMP_FEED = "https://daily.bandcamp.com/feed"

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

def content_html_for(item)
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
    .map { |t| t.delete(" ") }
    .map { |t| t.gsub(/[^[:alnum:]]/i, "") }
    .map { |t| t.downcase[0, 20] }
    .reject(&:empty?)
    .uniq
    .first(Article::MAX_TAG_LIST_SIZE)
end

def strip_tracking(url)
  return "" if url.to_s.empty?
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
  enclosure = item.at_xpath("enclosure[@type][@url]")
  if enclosure && enclosure["type"].to_s.start_with?("image/")
    return enclosure["url"].to_s
  end
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
  if og
    width = page.at_xpath("//meta[@property='og:image:width']/@content")&.text.to_i
    height = page.at_xpath("//meta[@property='og:image:height']/@content")&.text.to_i
    og = absolutize(url, og)
    return og if width.zero? || height.zero? || (width >= 600 && height >= 315)
  end
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
  return body_html if body_html.to_s.include?(host)
  suffix = "\n\nRead the full article on [#{host}](#{url})."
  body_html.to_s.strip + suffix
end

def import_bandcamp_latest(limit: 5)
  xml = fetch_xml(BANDCAMP_FEED)
  items = xml.xpath("//item").to_a
  user = User.first
  raise "No users in DB" unless user

  imported = 0
  items.each do |item|
    break if imported >= limit

    title = item.at_xpath("title")&.text&.strip
    link = item.at_xpath("link")&.text&.strip
    link = strip_tracking(link)
    next if link.blank?

    if Article.where(user_id: user.id, feed_source_url: link).exists?
      puts "Skipped (duplicate): #{title}"
      next
    end

    content_html = content_html_for(item)

    image = extract_image_from_item(item)
    image ||= extract_image_from_html(content_html)
    image ||= extract_og_image_from_page(link)

    tags = sanitize_tags(categories_for(item))
    content_without_imgs = remove_images_from_html(content_html)
    body_markdown = ensure_read_more(content_without_imgs, link)

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

    imported += 1
    puts "bandcamp => #{article.id}: #{article.title}"
    puts "http://localhost:4000#{article.path}"
    puts ""
  end

  puts "Imported #{imported} new Bandcamp post(s)."
end

limit = (ENV["LIMIT"] || "5").to_i
limit = 1 if limit <= 0
import_bandcamp_latest(limit: limit)
