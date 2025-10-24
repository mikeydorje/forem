class Device < ApplicationRecord
  belongs_to :consumer_app
  belongs_to :user

  IOS = "iOS".freeze
  ANDROID = "Android".freeze

  enum platform: { android: ANDROID, ios: IOS }

  validates :platform, inclusion: { in: platforms.keys }
  validates :token, presence: true
  validates :token, uniqueness: { scope: %i[user_id platform consumer_app_id] }

  def create_notification(title, body, payload)
    Rails.logger.info "🔔 Device#create_notification called for device #{id} (#{platform}) with title: '#{title}', body: '#{body}', payload: #{payload}"
    
    # Use new Firebase FCM V1 API approach instead of Rpush
    begin
      result = PushNotificationService.send_notification(
        device_token: token,
        title: title,
        body: body.to_s.truncate(512),
        data: payload.stringify_keys
      )
      
      Rails.logger.info "🔔 Device#create_notification result: #{result.inspect}"
      result
    rescue => e
      Rails.logger.error "❌ Device#create_notification ERROR: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      false
    end
  end

end
