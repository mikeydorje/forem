namespace :push_notifications do
  desc "Send a test push notification to a specific user"
  task :test, [:user_email] => :environment do |_t, args|
    user_email = args[:user_email] || ENV["TEST_USER_EMAIL"]
    
    if user_email.blank?
      puts "❌ Error: Please provide a user email"
      puts "Usage: rake push_notifications:test[user@example.com]"
      puts "   or: TEST_USER_EMAIL=user@example.com rake push_notifications:test"
      exit 1
    end

    user = User.find_by(email: user_email)
    
    unless user
      puts "❌ Error: User with email '#{user_email}' not found"
      puts "Available users:"
      User.limit(10).pluck(:email, :name).each do |email, name|
        puts "  - #{email} (#{name})"
      end
      exit 1
    end

    devices = Device.where(user: user)
    
    if devices.empty?
      puts "❌ Error: No devices registered for user '#{user.name}' (#{user.email})"
      puts ""
      puts "To register a device, you need to:"
      puts "1. Log in to the mobile app with this user"
      puts "2. Grant notification permissions"
      puts "3. The app will automatically register the device token"
      puts ""
      puts "You can also manually create a device:"
      puts "  user = User.find_by(email: '#{user.email}')"
      puts "  consumer_app = ConsumerApp.find_by(app_bundle: 'com.forem.android', platform: 'Android')"
      puts "  Device.create!(user: user, consumer_app: consumer_app, platform: 'Android', token: 'YOUR_FCM_TOKEN')"
      exit 1
    end

    puts "📱 Found #{devices.count} device(s) for #{user.name} (#{user.email}):"
    devices.each do |device|
      puts "  - Device ##{device.id}: #{device.platform} (#{device.consumer_app.app_bundle})"
      puts "    Token: #{device.token[0..40]}..."
      puts "    Consumer App Operational: #{device.consumer_app.operational? ? '✅ Yes' : '❌ No'}"
      
      unless device.consumer_app.operational?
        puts "    ⚠️  Missing credentials for #{device.platform}:"
        if device.ios?
          puts "       Set RPUSH_IOS_PEM environment variable"
        elsif device.android?
          puts "       Set RPUSH_FCM_KEY environment variable"
        end
      end
    end
    puts ""

    # Check if any consumer apps are operational
    operational_devices = devices.select { |d| d.consumer_app.operational? }
    
    if operational_devices.empty?
      puts "❌ Error: None of the devices have operational consumer apps"
      puts "Please configure the required credentials (see above)"
      exit 1
    end

    # Send the test notification
    title = "Test Notification"
    body = "This is a test push notification sent at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}"
    payload = {
      type: "test",
      timestamp: Time.current.to_i,
      message: "Test notification from Rails console"
    }

    puts "🔔 Sending test push notification..."
    puts "   Title: #{title}"
    puts "   Body: #{body}"
    puts "   Payload: #{payload}"
    puts ""

    begin
      PushNotifications::Send.call(
        user_ids: [user.id],
        title: title,
        body: body,
        payload: payload
      )
      
      puts "✅ Test notification created successfully!"
      puts ""
      puts "📊 Checking Rpush notification queue..."
      
      # Check what notifications are pending
      pending_count = Rpush::Notification.where(delivered: false, failed: false).count
      puts "   Pending notifications: #{pending_count}"
      
      if pending_count > 0
        puts ""
        puts "🔄 To deliver pending notifications, you need to:"
        puts "   1. Make sure Sidekiq is running: bundle exec sidekiq"
        puts "   2. Wait 30 seconds for PushNotifications::DeliverWorker to run"
        puts "   3. Or manually trigger delivery:"
        puts "      rake push_notifications:deliver"
      end
      
    rescue => e
      puts "❌ Error sending notification: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      exit 1
    end
  end

  desc "Manually deliver all pending push notifications (bypasses Sidekiq delay)"
  task :deliver => :environment do
    pending = Rpush::Notification.where(delivered: false, failed: false)
    puts "📊 Found #{pending.count} pending notification(s)"
    
    if pending.count > 0
      puts "🔄 Delivering notifications..."
      Rpush.push
      Rpush.apns_feedback
      puts "✅ Delivery process completed!"
      puts ""
      puts "Check the logs above for delivery results"
    else
      puts "✨ No pending notifications to deliver"
    end
  end

  desc "Check push notification system status"
  task :status => :environment do
    puts "📊 Push Notification System Status"
    puts "=" * 60
    puts ""
    
    # Check Rpush configuration
    puts "🔧 Rpush Configuration:"
    puts "   Client: #{Rpush.config.client}"
    puts "   Redis URL: #{Rpush.config.redis_options[:url]}"
    puts "   Push Poll: #{Rpush.config.push_poll} seconds"
    puts "   Batch Size: #{Rpush.config.batch_size}"
    puts ""
    
    # Check registered apps
    puts "📱 Registered Consumer Apps:"
    ConsumerApp.all.each do |app|
      puts "   #{app.platform.upcase}: #{app.app_bundle}"
      puts "      Active: #{app.active ? '✅' : '❌'}"
      puts "      Operational: #{app.operational? ? '✅' : '❌'}"
      puts "      Devices: #{app.devices.count}"
      puts "      Credentials Set: #{app.auth_credentials.present? ? '✅' : '❌'}"
    end
    puts ""
    
    # Check Rpush apps
    puts "🚀 Rpush Apps:"
    ios_apps = Rpush::Apns2::App.all
    android_apps = Rpush::Gcm::App.all
    
    if ios_apps.any?
      ios_apps.each do |app|
        puts "   iOS: #{app.name}"
        puts "      Bundle ID: #{app.bundle_id}"
        puts "      Environment: #{app.environment}"
      end
    else
      puts "   No iOS apps registered"
    end
    
    if android_apps.any?
      android_apps.each do |app|
        puts "   Android: #{app.name}"
        puts "      Auth Key Set: #{app.auth_key.present? ? '✅' : '❌'}"
      end
    else
      puts "   No Android apps registered"
    end
    puts ""
    
    # Check notifications
    total_notifications = Rpush::Notification.count rescue 0
    pending_notifications = Rpush::Notification.where(delivered: false, failed: false).count rescue 0
    delivered_notifications = Rpush::Notification.where(delivered: true).count rescue 0
    failed_notifications = Rpush::Notification.where(failed: true).count rescue 0
    
    puts "📧 Notification Stats:"
    puts "   Total: #{total_notifications}"
    puts "   Pending: #{pending_notifications}"
    puts "   Delivered: #{delivered_notifications}"
    puts "   Failed: #{failed_notifications}"
    puts ""
    
    # Check recent notifications
    if total_notifications > 0
      recent = Rpush::Notification.order(created_at: :desc).limit(5)
      puts "📋 Recent Notifications:"
      recent.each do |notif|
        status = notif.delivered? ? "✅ Delivered" : (notif.failed? ? "❌ Failed" : "⏳ Pending")
        puts "   #{status} - Created: #{notif.created_at}"
        if notif.failed?
          puts "      Error: #{notif.error_description} (Code: #{notif.error_code})"
        end
      end
    end
    puts ""
    
    # Environment variables check
    puts "🔑 Environment Variables:"
    puts "   RPUSH_IOS_PEM: #{ENV['RPUSH_IOS_PEM'].present? ? '✅ Set' : '❌ Not set'}"
    puts "   RPUSH_FCM_KEY: #{ENV['RPUSH_FCM_KEY'].present? ? '✅ Set' : '❌ Not set'}"
    puts "   REDIS_RPUSH_URL: #{ENV['REDIS_RPUSH_URL'].present? ? '✅ Set' : '⚠️  Using REDIS_URL'}"
    puts ""
  end

  desc "Setup test consumer app and device"
  task :setup_test => :environment do
    puts "🔧 Setting up test push notification environment..."
    puts ""
    
    # Prompt for platform
    print "Which platform? (ios/android): "
    platform_input = STDIN.gets.chomp.downcase
    
    unless ['ios', 'android'].include?(platform_input)
      puts "❌ Invalid platform. Must be 'ios' or 'android'"
      exit 1
    end
    
    platform = platform_input == 'ios' ? 'iOS' : 'Android'
    app_bundle = platform_input == 'ios' ? ConsumerApp::FOREM_IOS_BUNDLE : ConsumerApp::FOREM_ANDROID_BUNDLE
    
    puts "📱 Platform: #{platform}"
    puts "📦 App Bundle: #{app_bundle}"
    puts ""
    
    # Check or create consumer app
    consumer_app = ConsumerApp.find_or_create_by(
      app_bundle: app_bundle,
      platform: platform_input
    ) do |app|
      app.active = true
    end
    
    puts "✅ Consumer App #{consumer_app.persisted? ? 'found' : 'created'}: ##{consumer_app.id}"
    puts "   Operational: #{consumer_app.operational? ? '✅ Yes' : '❌ No'}"
    
    unless consumer_app.operational?
      puts ""
      puts "⚠️  Consumer app is not operational!"
      puts "   You need to set the appropriate environment variable:"
      if platform_input == 'ios'
        puts "   RPUSH_IOS_PEM - Your APNS certificate in PEM format"
      else
        puts "   RPUSH_FCM_KEY - Your Firebase Cloud Messaging server key"
      end
      puts ""
    end
    
    # Prompt for user email
    print "Enter test user email (or press Enter to create new user): "
    user_email = STDIN.gets.chomp
    
    if user_email.blank?
      # Create test user
      user_email = "test-push-#{SecureRandom.hex(4)}@example.com"
      user = User.create!(
        email: user_email,
        username: "testuser#{SecureRandom.hex(4)}",
        name: "Test User",
        password: "password123",
        password_confirmation: "password123",
        confirmed_at: Time.current
      )
      puts "✅ Created test user: #{user.email}"
    else
      user = User.find_by(email: user_email)
      unless user
        puts "❌ User not found: #{user_email}"
        exit 1
      end
      puts "✅ Found user: #{user.name} (#{user.email})"
    end
    
    puts ""
    print "Enter device token (from your mobile app logs): "
    device_token = STDIN.gets.chomp
    
    if device_token.blank?
      puts "❌ Device token cannot be blank"
      puts ""
      puts "To get a device token:"
      puts "1. Run your mobile app"
      puts "2. Look for FCM token in the logs (Android) or APNS token (iOS)"
      puts "3. Copy the token and run this task again"
      exit 1
    end
    
    # Create or find device
    device = Device.find_or_create_by(
      user: user,
      consumer_app: consumer_app,
      platform: platform
    ) do |d|
      d.token = device_token
    end
    
    # Update token if device already existed
    if device.token != device_token
      device.update(token: device_token)
    end
    
    puts "✅ Device registered: ##{device.id}"
    puts "   Token: #{device.token[0..40]}..."
    puts ""
    puts "🎉 Setup complete!"
    puts ""
    puts "To send a test notification:"
    puts "   rake push_notifications:test[#{user.email}]"
  end
end
