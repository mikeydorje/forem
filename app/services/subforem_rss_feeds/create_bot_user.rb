module SubforemRssFeeds
  class CreateBotUser
    def self.call(rss_feed)
      new(rss_feed).call
    end

    def initialize(rss_feed)
      @rss_feed = rss_feed
    end

    def call
      return @rss_feed.bot_user if @rss_feed.bot_user.present?

      username = generate_unique_username
      return nil if username.blank?

      password = SecureRandom.hex(32)
      bot_user = User.create!(
        name: generate_name,
        username: username,
        email: generate_email(username),
        password: password,
        password_confirmation: password,
        confirmed_at: Time.current,
        profile_image: default_profile_image
      )

      @rss_feed.update!(bot_user: bot_user)
      bot_user
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("SubforemRssFeeds::CreateBotUser failed: #{e.message}")
      nil
    end

    private

    def generate_unique_username
      base_username = @rss_feed.bot_username
      return nil if base_username.blank?

      username = base_username
      counter = 1

      while User.exists?(username: username)
        username = "#{base_username}#{counter}"
        counter += 1
        break if counter > 100 # Safety limit
      end

      username
    end

    def generate_name
      uri = URI.parse(@rss_feed.feed_url)
      domain = uri.host.to_s.gsub(/^www\./, "")
      "RSS Bot (#{domain})"
    rescue URI::InvalidURIError
      "RSS Feed Bot"
    end

    def generate_email(username)
      "#{username}+rssbot@#{Settings::General.app_domain}"
    end

    def default_profile_image
      # Use a default bot avatar or placeholder
      "https://via.placeholder.com/150?text=RSS"
    end
  end
end
