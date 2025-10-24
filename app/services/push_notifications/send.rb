module PushNotifications
  class Send
    def self.call(user_ids:, title:, body:, payload:)
      new(user_ids: user_ids, title: title, body: body, payload: payload).call
    end

    def initialize(user_ids:, title:, body:, payload:)
      @user_ids = user_ids
      @title = title
      @body = body
      @payload = payload
    end

    def call
      Rails.logger.info "🔔 PushNotifications::Send called with user_ids: #{@user_ids}, title: '#{@title}', body: '#{@body}', payload: #{@payload}"
      
      relation = Device.where(user_id: @user_ids)
      Rails.logger.info "🔔 Found #{relation.count} devices for user_ids #{@user_ids}: #{relation.pluck(:id, :platform, :token).map { |id, platform, token| "Device #{id} (#{platform}): #{token[0..20]}..." }}"

      relation.find_each do |device|
        Rails.logger.info "🔔 Creating notification for device #{device.id} (#{device.platform}) token: #{device.token[0..20]}..."
        result = device.create_notification(@title, @body, @payload)
        Rails.logger.info "🔔 Notification creation result for device #{device.id}: #{result.inspect}"
      end

      # Note: Using Firebase FCM V1 API directly now, no need for Rpush delivery worker
      Rails.logger.info "🔔 Sent #{relation.count} push notifications via Firebase FCM"
    end
  end
end
