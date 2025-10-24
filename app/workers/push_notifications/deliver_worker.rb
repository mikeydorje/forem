module PushNotifications
  class DeliverWorker
    include Sidekiq::Job

    sidekiq_options queue: :medium_priority,
                    retry: 10,
                    lock: :until_expired,
                    lock_ttl: 30,
                    on_conflict: :log

    def perform
      Rails.logger.info "🔔 PushNotifications::DeliverWorker starting - checking for pending notifications"
      
      # Get all notifications (without complex where queries that cause Modis issues)
      all_notifications = Rpush::Notification.all
      pending_notifications = all_notifications.select { |n| !n.delivered && !n.failed }
      pending_count = pending_notifications.count
      Rails.logger.info "🔔 Found #{pending_count} pending notifications to deliver"
      
      if pending_count > 0
        # Deliver all pending Push Notifications
        Rails.logger.info "🔔 Calling Rpush.push to deliver notifications"
        Rpush.push
        
        # Count after delivery
        all_notifications_after = Rpush::Notification.all
        remaining_notifications = all_notifications_after.select { |n| !n.delivered && !n.failed }
        remaining_count = remaining_notifications.count
        delivered_count = pending_count - remaining_count
        Rails.logger.info "🔔 Delivered #{delivered_count} notifications, #{remaining_count} remaining"
      else
        Rails.logger.info "🔔 No pending notifications to deliver"
      end
      
      # Callback for feedback (see `config/initializers/rpush.rb`)
      Rails.logger.info "🔔 Calling Rpush.apns_feedback for iOS feedback"
      Rpush.apns_feedback
      
      Rails.logger.info "🔔 PushNotifications::DeliverWorker completed"
    end
  end
end
