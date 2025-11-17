module SubforemRssFeeds
  class ImportWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority, retry: 3

    def perform(rss_feed_id)
      rss_feed = SubforemRssFeed.find(rss_feed_id)
      
      return unless rss_feed.enabled?

      SubforemRssFeeds::Import.call(rss_feed)
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("SubforemRssFeeds::ImportWorker: RSS feed #{rss_feed_id} not found")
    end
    
    # Class method to import all enabled feeds
    def self.import_all
      SubforemRssFeed.needs_fetch.find_each do |rss_feed|
        perform_async(rss_feed.id)
      end
    end
  end
end
