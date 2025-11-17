namespace :rss do
  desc "Import a few demo RSS posts into production"
  task import: :environment do
    require "net/http"
    require "nokogiri"
    require "feedjira"

    feeds = [
      { url: "https://daily.bandcamp.com/feed", limit: 1 },
      { url: "https://www.ableton.com/en/blog/feeds/latest/", limit: 1 },
      { url: "https://stereogum.com/category/music/feed", limit: 1 }
    ]

    def http_get_body(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl?
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = "ForemRSSDemo/1.0"
      res = http.request(req)
      res.body
    end

    def first_img_src(html)
      doc = Nokogiri::HTML(html.to_s)
      doc.at_css("img[src]")&.[]("src")
    end

    def sanitize_tags(cats)
      Array(cats)
        .map { |t| t.to_s.strip }
        .map { |t| t.delete(" ") }
        .map { |t| t.gsub(/[^[:alnum:]]/i, "") }
        .map { |t| t.downcase[0, 20] }
        .reject(&:empty?)
        .uniq
        .first(Article::MAX_TAG_LIST_SIZE)
    end

    user = User.first
    raise "No users in DB" unless user

    feeds.each do |cfg|
      url = cfg[:url]
      limit = cfg[:limit] || 1
      puts "\n=== Importing from #{url} ==="

      xml = http_get_body(url)
      feed = Feedjira.parse(xml)
      entries = Array(feed&.entries).first(limit)
      if entries.empty?
        puts "No entries found"
        next
      end

      entries.each do |e|
        link = e.url.to_s.strip
        next if link.empty?
        if Article.where(user_id: user.id, feed_source_url: link).exists?
          puts "Skip duplicate: #{e.title}"
          next
        end

        title = e.title.to_s.strip.presence || "Untitled"
        content_html = e.respond_to?(:content) ? e.content.to_s : ""
        summary_html = e.summary.to_s
        body_html = content_html.presence || summary_html.presence || ""
        img = first_img_src(content_html) || first_img_src(summary_html)
        tags = sanitize_tags(e.respond_to?(:categories) ? e.categories : [])

        read_more = "\n\nRead the full article on [source](#{link})."
        body_md = body_html.to_s.strip + read_more

        article = Article.create!(
          title: title,
          body_markdown: body_md,
          user_id: user.id,
          published: true,
          published_from_feed: true,
          feed_source_url: link,
          main_image: img,
          tag_list: tags
        )
        app_protocol = ENV.fetch("APP_PROTOCOL", "https")
        app_domain = ENV.fetch("APP_DOMAIN") { ENV["HEROKU_APP_NAME"].to_s + ".herokuapp.com" }
        puts "Imported => #{article.id}: #{article.title}"
        puts "#{app_protocol}://#{app_domain}#{article.path}"
      end

      puts "Done."
    end

    puts "\n✓ RSS import completed."
  end
end
