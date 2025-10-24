#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick Push Notification Test from Rails Console
# Usage: rails runner quick_push_test.rb user@example.com

require_relative "config/environment"

def send_test_notification(user_email)
  puts "🔔 Quick Push Notification Test"
  puts "=" * 60
  puts ""
  
  # Find user
  user = User.find_by(email: user_email)
  unless user
    puts "❌ User not found: #{user_email}"
    puts ""
    puts "Available users:"
    User.limit(10).pluck(:email, :name).each { |e, n| puts "  - #{e} (#{n})" }
    return false
  end
  
  puts "✅ Found user: #{user.name} (#{user.email})"
  
  # Check devices
  devices = Device.where(user: user)
  if devices.empty?
    puts "❌ No devices registered for this user"
    puts ""
    puts "Register a device first:"
    puts "  rake push_notifications:setup_test"
    return false
  end
  
  puts "📱 Found #{devices.count} device(s):"
  devices.each do |d|
    operational = d.consumer_app.operational?
    puts "  #{operational ? '✅' : '❌'} #{d.platform} - #{d.consumer_app.app_bundle}"
  end
  
  operational_devices = devices.select { |d| d.consumer_app.operational? }
  if operational_devices.empty?
    puts ""
    puts "❌ No operational devices (missing credentials)"
    return false
  end
  
  puts ""
  puts "🚀 Sending test notification..."
  
  # Send notification
  begin
    PushNotifications::Send.call(
      user_ids: [user.id],
      title: "Test Notification",
      body: "Quick test sent at #{Time.current.strftime('%H:%M:%S')}",
      payload: {
        type: "quick_test",
        timestamp: Time.current.to_i
      }
    )
    
    puts "✅ Notification queued successfully!"
    puts ""
    
    # Check queue
    pending = Rpush::Notification.where(delivered: false, failed: false).count
    puts "📊 Pending notifications: #{pending}"
    puts ""
    puts "⏰ Notification will be delivered in ~30 seconds"
    puts "   Or run: rake push_notifications:deliver"
    puts ""
    
    return true
  rescue => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(3)
    return false
  end
end

# Main execution
if ARGV.empty?
  puts "Usage: rails runner quick_push_test.rb user@example.com"
  exit 1
end

user_email = ARGV[0]
success = send_test_notification(user_email)
exit(success ? 0 : 1)
