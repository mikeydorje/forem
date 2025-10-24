#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../config/environment"

puts "=" * 80
puts "🔔 PUSH NOTIFICATION TEST SETUP SCRIPT"
puts "=" * 80
puts ""

# Step 1: Check environment and dependencies
puts "Step 1: Checking environment..."
puts "-" * 80

required_gems = ['rpush', 'redis', 'sidekiq']
missing_gems = []

required_gems.each do |gem_name|
  begin
    Gem::Specification.find_by_name(gem_name)
    puts "✅ #{gem_name} gem installed"
  rescue Gem::MissingSpecError
    puts "❌ #{gem_name} gem not installed"
    missing_gems << gem_name
  end
end

if missing_gems.any?
  puts ""
  puts "⚠️  Missing gems: #{missing_gems.join(', ')}"
  puts "Run: bundle install"
  exit 1
end

# Check Redis connection
begin
  redis = Redis.new(url: ENV.fetch("REDIS_RPUSH_URL") { ENV.fetch("REDIS_URL", "redis://localhost:6379") })
  redis.ping
  puts "✅ Redis connection successful"
rescue => e
  puts "❌ Redis connection failed: #{e.message}"
  puts "   Make sure Redis is running: redis-server"
  exit 1
end

puts ""

# Step 2: Check Rpush tables
puts "Step 2: Checking database..."
puts "-" * 80

required_tables = ['rpush_apps', 'rpush_notifications', 'rpush_feedback', 'devices', 'consumer_apps']
missing_tables = []

required_tables.each do |table|
  if ActiveRecord::Base.connection.table_exists?(table)
    puts "✅ Table '#{table}' exists"
  else
    puts "❌ Table '#{table}' missing"
    missing_tables << table
  end
end

if missing_tables.any?
  puts ""
  puts "⚠️  Missing tables: #{missing_tables.join(', ')}"
  puts "Run: rails db:migrate"
  exit 1
end

puts ""

# Step 3: Check/Create Consumer Apps
puts "Step 3: Setting up Consumer Apps..."
puts "-" * 80

platforms = {
  'android' => { bundle: ConsumerApp::FOREM_ANDROID_BUNDLE, platform: 'Android', env_var: 'RPUSH_FCM_KEY' },
  'ios' => { bundle: ConsumerApp::FOREM_IOS_BUNDLE, platform: 'iOS', env_var: 'RPUSH_IOS_PEM' }
}

platforms.each do |key, config|
  consumer_app = ConsumerApp.find_or_create_by(
    app_bundle: config[:bundle],
    platform: key
  ) do |app|
    app.active = true
  end
  
  operational = consumer_app.operational?
  puts "#{operational ? '✅' : '⚠️ '} #{config[:platform]} Consumer App (ID: #{consumer_app.id})"
  puts "   Bundle: #{config[:bundle]}"
  puts "   Active: #{consumer_app.active}"
  puts "   Operational: #{operational}"
  
  unless operational
    puts "   ❌ Missing: #{config[:env_var]} environment variable"
    puts "      You need valid credentials to send #{config[:platform]} push notifications"
  end
  
  # Try to create/update Rpush app
  begin
    rpush_app = ConsumerApps::RpushAppQuery.call(
      app_bundle: config[:bundle],
      platform: key
    )
    
    if rpush_app
      puts "   ✅ Rpush #{config[:platform]} app configured"
    else
      puts "   ⚠️  Rpush #{config[:platform]} app not configured (needs credentials)"
    end
  rescue => e
    puts "   ❌ Error configuring Rpush app: #{e.message}"
  end
end

puts ""

# Step 4: Check for test users
puts "Step 4: Checking for test users..."
puts "-" * 80

test_emails = [
  'test@example.com',
  'testuser@example.com',
  'admin@forem.local'
]

found_users = []
test_emails.each do |email|
  user = User.find_by(email: email)
  if user
    found_users << user
    device_count = Device.where(user: user).count
    puts "✅ Found user: #{user.name} (#{user.email})"
    puts "   Devices registered: #{device_count}"
  end
end

if found_users.empty?
  puts "⚠️  No test users found"
  puts ""
  puts "Creating a test user..."
  
  begin
    test_user = User.create!(
      email: 'test-push@example.com',
      username: "testuser#{SecureRandom.hex(4)}",
      name: 'Test Push User',
      password: 'password123',
      password_confirmation: 'password123',
      confirmed_at: Time.current
    )
    puts "✅ Created test user: #{test_user.email}"
    puts "   Username: #{test_user.username}"
    puts "   Password: password123"
    found_users << test_user
  rescue => e
    puts "❌ Failed to create test user: #{e.message}"
  end
end

puts ""

# Step 5: Summary and Next Steps
puts "Step 5: Summary and Next Steps"
puts "=" * 80
puts ""

# Check what's working
ios_operational = ConsumerApp.find_by(platform: 'ios')&.operational? || false
android_operational = ConsumerApp.find_by(platform: 'android')&.operational? || false

if ios_operational || android_operational
  puts "✅ Push notification system is partially configured!"
  puts ""
  puts "Operational platforms:"
  puts "   iOS: #{ios_operational ? '✅' : '❌'}"
  puts "   Android: #{android_operational ? '✅' : '❌'}"
else
  puts "⚠️  Push notification system needs credentials!"
  puts ""
  puts "To enable push notifications, you need to set:"
  puts "   - RPUSH_FCM_KEY for Android (Firebase Cloud Messaging server key)"
  puts "   - RPUSH_IOS_PEM for iOS (APNS certificate in PEM format)"
  puts ""
  puts "For LOCAL TESTING with Android:"
  puts "   1. Create a Firebase project"
  puts "   2. Get your FCM server key from Firebase Console"
  puts "   3. Add to your .env file: RPUSH_FCM_KEY='your-server-key'"
  puts "   4. Restart the Rails server"
end

puts ""
puts "📱 TO REGISTER A DEVICE:"
puts "-" * 80
puts "1. Make sure the React Native app is running"
puts "2. Log in with a test user (e.g., #{found_users.first&.email || 'test@example.com'})"
puts "3. Grant notification permissions when prompted"
puts "4. The app will automatically register the device token via:"
puts "   POST /users/devices"
puts ""
puts "OR manually create a device in Rails console:"
puts "   user = User.find_by(email: '#{found_users.first&.email || 'test@example.com'}')"
puts "   consumer_app = ConsumerApp.find_by(app_bundle: 'com.forem.android', platform: 'Android')"
puts "   Device.create!(user: user, consumer_app: consumer_app, platform: 'Android', token: 'YOUR_FCM_TOKEN_HERE')"
puts ""

puts "🧪 TO SEND A TEST NOTIFICATION:"
puts "-" * 80
puts "1. Check system status:"
puts "   rake push_notifications:status"
puts ""
puts "2. Send test notification to a user:"
puts "   rake push_notifications:test[#{found_users.first&.email || 'test@example.com'}]"
puts ""
puts "3. Manually deliver pending notifications (if needed):"
puts "   rake push_notifications:deliver"
puts ""

puts "🔧 TROUBLESHOOTING:"
puts "-" * 80
puts "- Make sure Sidekiq is running: bundle exec sidekiq"
puts "- Check Rails logs: tail -f log/development.log"
puts "- Check Sidekiq logs for worker execution"
puts "- Verify Redis is running: redis-cli ping"
puts "- Use rake push_notifications:status to check configuration"
puts ""

puts "=" * 80
puts "Setup check complete! 🎉"
puts "=" * 80
