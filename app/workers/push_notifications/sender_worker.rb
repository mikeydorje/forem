module PushNotifications
  class SenderWorker
    include Sidekiq::Job

    sidekiq_options queue: :low_priority

    def perform(notification_id)
      notification = Notification.find_by(id: notification_id)
      return unless notification

      user = notification.user
      return unless user

      # Find devices for this user
      # We only care about Android for now as per requirements
      devices = Device.where(user: user, platform: 'Android')
      return if devices.empty?

      title = "New Notification"
      body = generate_body(notification)
      
      # We need a payload to open the right screen.
      # For now, just open the notifications screen.
      data = {
        url: "/notifications",
        notification_id: notification.id.to_s
      }

      devices.each do |device|
        # Call our new service
        # We assume Push::FcmV1Client is available
        Push::FcmV1Client.send(
          token: device.token,
          title: title,
          body: body,
          data: data,
          dry_run: ENV['PUSH_TEST_DRY_RUN'] == 'true'
        )
      end
    end

    private

    def generate_body(notification)
      notifiable = notification.notifiable
      return "You have a new notification" unless notifiable

      case notification.notifiable_type
      when 'Article'
        "New article: #{notifiable.title}"
      when 'Comment'
        "New comment from #{notifiable.user.name}"
      when 'Follow'
        # Follow model usually has follower_id
        follower = User.find_by(id: notifiable.follower_id)
        "New follower: #{follower&.name || 'Someone'}"
      when 'Mention'
        "You were mentioned"
      else
        "You have a new notification"
      end
    rescue => e
      Rails.logger.error("Error generating notification body: #{e.message}")
      "You have a new notification"
    end
  end
end
