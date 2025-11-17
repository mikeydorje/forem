require "net/http"
require "nokogiri"

# Universal RSS feed importer
# Usage:
#   bin/rails runner scripts/import_rss_feeds.rb

FEEDS = [
  { url: "https://daily.bandcamp.com/feed", limit: 1 },
  { url: "https://www.ableton.com/en/blog/feeds/latest/", limit: 1 },
  { url: "https://stereogum.com/category/music/feed", limit: 1 }
]

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

def feed_items(doc)
  (doc.xpath("//item").to_a + doc.xpath("//entry").to_a)
end

def content_html_for(item)
  # Prefer full content fields first, then description, then summary
  text = item.at_xpath("*[local-name()='encoded']")&.text
  text ||= item.at_xpath("content|*[local-name()='content']")&.text
  text ||= item.at_xpath("description")&.text
  text ||= item.at_xpath("summary")&.text
  text.to_s
end

def description_for(item)
  item.at_xpath("description")&.text.to_s
end

def summary_for(item)
  item.at_xpath("summary")&.text.to_s
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

def absolutize(base_url, src)
  return src if src.to_s =~ /\Ahttps?:\/\//i
  URI.join(base_url, src).to_s
rescue
  src
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
  # Fallback: choose first large-looking img in page if metas absent/insufficient
  candidates = page.css("img[src]").map { |n| absolutize(url, n["src"]) }.uniq
  sized = candidates.select { |s| s =~ /([\-_])(\d{3,4})x(\d{3,4})([\._-]|$)/i }
  pick = sized.find { |s| s[/([\-_])(\d{3,4})x(\d{3,4})/i] && $2.to_i >= 600 && $3.to_i >= 315 } || sized.first || candidates.first
  pick
rescue
  nil
end

def extract_paragraphs_from_page(url, max_paragraphs: 3)
  page = fetch_html(url)
  nodes = page.xpath(
    "//article//p | //div[contains(@class,'entry-content')]//p | //div[contains(@class,'post__content')]//p | //div[contains(@class,'content')]//p"
  )
  cleaned = []
  nodes.each do |p|
    html = p.inner_html.to_s.strip
    text = p.text.to_s.strip
    next if html.empty? || text.empty?
    next if text =~ /appeared first on/i
    next if text =~ /^the post\b/i
    next if text =~ /continue reading/i
    cleaned << "<p>#{html}</p>"
    break if cleaned.length >= max_paragraphs
  end
  cleaned.join("\n")
rescue
  ""
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

def bold_short_snippets(body_html)
  # If snippet is very short (< 150 chars of text), bold the main content
  # but leave "Read full story" link unbold
  frag = Nokogiri::HTML::DocumentFragment.parse(body_html.to_s)
  
  # Find paragraphs that don't contain "Read full" links
  main_paras = []
  read_more_paras = []
  
  frag.children.each do |node|
    if node.text? && node.text.strip.empty?
      next
    elsif node.text =~ /Read full (story|article)/i || node.inner_html.to_s =~ /Read full (story|article)/i
      read_more_paras << node
    else
      main_paras << node
    end
  end
  
  # Calculate text length of main content only
  main_text = main_paras.map(&:text).join.strip
  return body_html if main_text.length >= 150
  return body_html if main_paras.empty?
  
  # Bold the main paragraphs, leave read-more as-is
  result = main_paras.map { |n| "<strong>#{n.to_html}</strong>" }.join("\n")
  result += "\n" + read_more_paras.map(&:to_html).join("\n") unless read_more_paras.empty?
  result
end

def strip_inline_formatting(html)
  frag = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
  # Unwrap emphasis/italics/bold tags but keep their inner text
  frag.css('em, i, strong, b').each { |n| n.replace(n.children) }
  # Also clean up any escaped HTML entities in link text (e.g., &lt;em&gt;)
  frag.css('a').each do |link|
    link.inner_html = CGI.unescapeHTML(link.inner_html)
      .gsub(/<\/?(?:em|i|strong|b)>/i, '')
  end
  frag.to_html
end

def import_from_feed(feed_url:, limit: 1, user:)
  xml = fetch_xml(feed_url)
  items = feed_items(xml)
  raise "No items in feed: #{feed_url}" if items.empty?

  imported = 0
  items.each do |item|
    break if imported >= limit

    title = item.at_xpath("title")&.text&.strip
    link = item.at_xpath("link")&.text&.strip || item.at_xpath("*[local-name()='link']/@href")&.text
    link = strip_tracking(link)
    next if link.blank?

    if Article.where(user_id: user.id, feed_source_url: link).exists?
      puts "Skipped (duplicate): #{title}"
      next
    end

    content_html = content_html_for(item)
    orig_description = description_for(item)
    orig_summary = summary_for(item)

    # Image selection cascade: RSS -> content -> og/twitter -> fallback page scan
    image = extract_image_from_item(item)
    image ||= extract_image_from_html(content_html)
    image ||= extract_og_image_from_page(link)

    # Tags from categories, normalized and limited to 4
    tags = sanitize_tags(categories_for(item))

    # Remove inline images from body to avoid duplication with cover
    content_without_imgs = remove_images_from_html(content_html)
    # If stripping images left us with nothing, fall back to plain text from original HTML
    if content_without_imgs.strip.empty? && content_html.present?
      plain = Nokogiri::HTML(content_html).at('body')&.inner_html.to_s
      content_without_imgs = plain.strip.presence || Nokogiri::HTML(content_html).text.strip
    end
    # If still too minimal, prefer description, then summary
    text_len = Nokogiri::HTML.fragment(content_without_imgs).text.strip.length
    if text_len < 60
      if orig_description.present?
        desc_no_imgs = remove_images_from_html(orig_description)
        content_without_imgs = desc_no_imgs if Nokogiri::HTML.fragment(desc_no_imgs).text.strip.length >= text_len
        text_len = Nokogiri::HTML.fragment(content_without_imgs).text.strip.length
      end
    end
    if text_len < 60 && orig_summary.present?
      sum_no_imgs = remove_images_from_html(orig_summary)
      if Nokogiri::HTML.fragment(sum_no_imgs).text.strip.length > text_len
        content_without_imgs = sum_no_imgs
        text_len = Nokogiri::HTML.fragment(content_without_imgs).text.strip.length
      end
    end
    # As a last resort, scrape first paragraphs from the article page
    if text_len < 60 && link.present?
      page_paras = extract_paragraphs_from_page(link)
      if page_paras.present?
        content_without_imgs = page_paras
      end
    end
    # Strip inline formatting like <em>/<i> in link text and elsewhere
    content_without_imgs = strip_inline_formatting(content_without_imgs)
    # Bold short snippets (leaving read-more unbold)
    content_without_imgs = bold_short_snippets(content_without_imgs)
    # Append read-more if not already present
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
    feed_label = host_from(feed_url) || "feed"
    puts "#{feed_label} => #{article.id}: #{article.title}"
    puts "http://localhost:4000#{article.path}"
    puts ""
  end

  puts "Imported #{imported} new post(s) from #{host_from(feed_url) || feed_url}."
end

# Main execution
user = User.first
raise "No users in DB" unless user

FEEDS.each do |feed_config|
  puts "\n=== Processing #{feed_config[:url]} ==="
  import_from_feed(
    feed_url: feed_config[:url],
    limit: feed_config[:limit] || 1,
    user: user
  )
end

puts "\n✓ All feeds processed."
