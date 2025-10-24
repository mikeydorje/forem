class PushNotificationService
  def self.send_notification(device_token:, title:, body:, data: {})
    Rails.logger.info "✅ PushNotificationService.send_notification START - token: #{device_token[0..20]}..."
    
    require 'net/http'
    require 'json'
    require 'googleauth'

    Rails.logger.info "✅ Required gems loaded successfully"
    
    # Get Firebase access token
    json_key_path = Rails.root.join('firebase-service-account.json')
    Rails.logger.info "✅ Firebase JSON path: #{json_key_path}"
    scope = 'https://www.googleapis.com/auth/firebase.messaging'
    
    begin
      Rails.logger.info "✅ About to open file..."
      file_io = File.open(json_key_path)
      Rails.logger.info "✅ File opened successfully"
      
      Rails.logger.info "✅ About to create authorizer..."
      authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: file_io,
        scope: scope
      )
      Rails.logger.info "✅ Authorizer created successfully"
      
      Rails.logger.info "✅ Fetching access token..."
      authorizer.fetch_access_token!
      access_token = authorizer.access_token
      Rails.logger.info "✅ Access token obtained: #{access_token[0..20]}..."
    rescue => e
      Rails.logger.error "❌ FIREBASE AUTH FAILED: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      return false
    end

    # Send to FCM
    project_id = 'forem-5d94b'
    url = URI("https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send")
    
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(url)
    request['Authorization'] = "Bearer #{access_token}"
    request['Content-Type'] = 'application/json'
    
    payload = {
      message: {
        token: device_token,
        notification: {
          title: title,
          body: body
        },
        android: {
          priority: 'high'
        },
        data: data.stringify_keys
      }
    }
    
    request.body = payload.to_json
    response = http.request(request)
    
    if response.code == '200'
      Rails.logger.info "✅ Push notification sent successfully to #{device_token}"
      true
    else
      Rails.logger.error "❌ Failed to send push notification: #{response.body}"
      false
    end
  rescue => e
    Rails.logger.error "❌ Push notification error: #{e.message}"
    false
  end

  # Send to all devices for a user
  def self.notify_user(user:, title:, body:, data: {})
    user.devices.find_each do |device|
      send_notification(
        device_token: device.token,
        title: title,
        body: body,
        data: data
      )
    end
  end
end
