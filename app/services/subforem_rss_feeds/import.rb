module SubforemRssFeeds
  class Import
    def self.call(rss_feed)
      new(rss_feed).call
    end

    def initialize(rss_feed)
      @rss_feed = rss_feed
      @subforem = rss_feed.subforem
    end

    def call
      # Ensure we have a bot user
      @bot_user = @rss_feed.bot_user || SubforemRssFeeds::CreateBotUser.call(@rss_feed)
      
      unless @bot_user
        @rss_feed.mark_fetched!(error: "Failed to create bot user")
        return 0
      end

      # Fetch and parse feed
      feed_data = fetch_feed(@rss_feed.feed_url)
      return 0 unless feed_data

      items = parse_feed(feed_data)
      return 0 if items.empty?

      # Import articles
      articles_created = 0
      
      items.first(10).each do |item| # Limit to 10 newest items per fetch
        next if article_already_imported?(item)

        begin
          create_article_from_item(item)
          articles_created += 1
        rescue StandardError => e
          Rails.logger.error("SubforemRssFeeds::Import article creation error: #{e.message}")
          next
        end
      end

      # Update feed status
      @rss_feed.mark_fetched!(error: nil)
      @rss_feed.increment_articles_count!(articles_created) if articles_created > 0

      articles_created
    rescue StandardError => e
      @rss_feed.mark_fetched!(error: e.message)
      Rails.logger.error("SubforemRssFeeds::Import error: #{e.message}")
      0
    end

    private

    def fetch_feed(feed_url)
      uri = URI.parse(feed_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl # TODO: Fix for production
      http.read_timeout = 10
      http.open_timeout = 10

      # Follow redirects
      response = http.request_get(uri.path.presence || "/")
      redirect_limit = 5

      while response.is_a?(Net::HTTPRedirection) && redirect_limit > 0
        location = URI(response["location"])
        uri = location.relative? ? URI.join(uri, location) : location
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if http.use_ssl
        http.read_timeout = 10
        http.open_timeout = 10
        response = http.request_get(uri.path.presence || "/")
        redirect_limit -= 1
      end

      return nil unless response.is_a?(Net::HTTPSuccess)

      response.body
    rescue StandardError => e
      Rails.logger.error("SubforemRssFeeds::Import fetch error: #{e.message}")
      nil
    end

    def parse_feed(feed_data)
      require "nokogiri"
      
      doc = Nokogiri::XML(feed_data) { |config| config.recover }
      doc.xpath("//item").to_a
    rescue StandardError => e
      Rails.logger.error("SubforemRssFeeds::Import parse error: #{e.message}")
      []
    end

    def article_already_imported?(item)
      link = item.at_xpath("link")&.text&.strip
      return true if link.blank?

      feed_source_url = link.split("?source=").first
      Article.exists?(feed_source_url: feed_source_url, user_id: @bot_user.id)
    end

    def create_article_from_item(item)
      title = item.at_xpath("title")&.text&.strip
      link = item.at_xpath("link")&.text&.strip
      description = item.at_xpath("description")&.text
      content_encoded = item.at_xpath("*[local-name()='encoded']")&.text

      content = content_encoded || description || ""
      feed_source_url = link.split("?source=").first

      Article.create!(
        user_id: @bot_user.id,
        subforem_id: @subforem.id,
        title: title,
        body_markdown: "**Source:** #{link}\n\n#{content}",
        feed_source_url: feed_source_url,
        published_from_feed: true,
        published: true,
        show_comments: true,
        organization_id: nil
      )
    end
  end
end
