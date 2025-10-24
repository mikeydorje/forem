# Push Notifications Testing Guide

This guide will help you test push notifications between your Rails backend (Forem) and React Native mobile app.

## 🎯 Overview

The push notification system uses:
- **Backend (Rails)**: Rpush gem with Redis for queuing notifications
- **Android**: Firebase Cloud Messaging (FCM)
- **iOS**: Apple Push Notification service (APNs)
- **Queue**: Sidekiq for background job processing

## 📋 Prerequisites

### 1. Redis
```bash
# Check if Redis is running
redis-cli ping
# Should respond with: PONG

# If not running, start Redis:
redis-server
```

### 2. Sidekiq
Sidekiq processes the background jobs that deliver notifications.

```bash
# In forem directory, run:
bundle exec sidekiq
```

### 3. Database Migrations
Ensure all Rpush tables exist:

```bash
cd forem
rails db:migrate
```

## 🔑 Configuration

### For Android (FCM)

1. **Get your Firebase Server Key:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project (or create one)
   - Go to Project Settings → Cloud Messaging
   - Copy the "Server Key"

2. **Set environment variable:**
   ```bash
   # Add to forem/.env file:
   RPUSH_FCM_KEY="your-firebase-server-key-here"
   ```

3. **Restart Rails server** to load new environment variables

### For iOS (APNs)

1. **Get your APNS certificate:**
   - Generate in Apple Developer Portal
   - Export as `.p12` file
   - Convert to PEM format:
     ```bash
     openssl pkcs12 -in cert.p12 -out cert.pem -nodes -clcerts
     ```

2. **Set environment variable:**
   ```bash
   # Add to forem/.env file:
   RPUSH_IOS_PEM="-----BEGIN CERTIFICATE-----
   ... your certificate content ...
   -----END CERTIFICATE-----
   -----BEGIN PRIVATE KEY-----
   ... your private key content ...
   -----END PRIVATE KEY-----"
   ```
   
   Note: Replace actual newlines with `\n` if needed

3. **Restart Rails server**

## 🚀 Quick Start

### Step 1: Run Setup Script

```bash
cd forem
ruby setup_push_notifications.rb
```

This script will:
- ✅ Check all dependencies
- ✅ Verify database tables
- ✅ Create Consumer Apps
- ✅ Create a test user (if needed)
- ✅ Show you what's missing

### Step 2: Check System Status

```bash
rake push_notifications:status
```

This shows:
- Rpush configuration
- Registered Consumer Apps
- Environment variables status
- Recent notifications

### Step 3: Register a Device

You have two options:

#### Option A: Use the Mobile App (Recommended)
1. Start your React Native app
2. Log in with a test user
3. Grant notification permissions
4. The app will automatically register via: `POST /users/devices`

#### Option B: Manual Registration (for testing)
```bash
# Start Rails console
rails console

# Create a device manually:
user = User.find_by(email: 'test@example.com')
consumer_app = ConsumerApp.find_by(app_bundle: 'com.forem.android', platform: 'Android')
Device.create!(
  user: user,
  consumer_app: consumer_app,
  platform: 'Android',
  token: 'YOUR_FCM_TOKEN_FROM_MOBILE_APP'
)
```

**To get FCM token from your mobile app:**
- Look in the app logs for "FCM Token" or "Device Token"
- Or use Firebase messaging `.getToken()` method

### Step 4: Send a Test Notification

```bash
# Send to a specific user:
rake push_notifications:test[test@example.com]

# Or set environment variable:
TEST_USER_EMAIL=test@example.com rake push_notifications:test
```

The task will:
1. ✅ Find the user
2. ✅ Find registered devices
3. ✅ Create notification in Rpush queue
4. ✅ Schedule delivery via Sidekiq (30 seconds delay)

### Step 5: Verify Delivery

**Option A: Wait for automatic delivery**
- Sidekiq will automatically process the notification after 30 seconds
- Watch Sidekiq logs: `tail -f log/sidekiq.log`

**Option B: Trigger immediate delivery**
```bash
rake push_notifications:deliver
```

## 🛠️ Available Rake Tasks

### `rake push_notifications:test[user_email]`
Sends a test push notification to a specific user.

```bash
rake push_notifications:test[test@example.com]
```

### `rake push_notifications:status`
Shows complete system status including:
- Rpush configuration
- Consumer Apps
- Notification statistics
- Environment variables

```bash
rake push_notifications:status
```

### `rake push_notifications:deliver`
Manually delivers all pending notifications (bypasses Sidekiq delay).

```bash
rake push_notifications:deliver
```

### `rake push_notifications:setup_test`
Interactive setup to create Consumer App and Device.

```bash
rake push_notifications:setup_test
```

## 🧪 Testing Scenarios

### Scenario 1: Test Basic Notification
```bash
# 1. Register a device (via mobile app or console)
# 2. Send test notification
rake push_notifications:test[test@example.com]

# 3. Check status
rake push_notifications:status

# 4. Force delivery (optional)
rake push_notifications:deliver
```

### Scenario 2: Test from Rails Console
```ruby
# Open Rails console
rails console

# Find a user with registered devices
user = User.find_by(email: 'test@example.com')
user.devices # Should show at least one device

# Send notification directly
PushNotifications::Send.call(
  user_ids: [user.id],
  title: "Test Notification",
  body: "This is a test from Rails console",
  payload: { type: "test", timestamp: Time.current.to_i }
)

# Check pending notifications
Rpush::Notification.where(delivered: false, failed: false).count

# Manually trigger delivery
Rpush.push
Rpush.apns_feedback
```

### Scenario 3: Test Multiple Devices
```ruby
# Send to multiple users
user_ids = User.where(email: ['user1@example.com', 'user2@example.com']).pluck(:id)

PushNotifications::Send.call(
  user_ids: user_ids,
  title: "Bulk Test",
  body: "Testing multiple devices",
  payload: { type: "bulk_test" }
)
```

## 🔍 Troubleshooting

### No notifications received?

1. **Check device registration:**
   ```bash
   rails console
   user = User.find_by(email: 'your@email.com')
   user.devices.each do |d|
     puts "Device ##{d.id}: #{d.platform}, operational: #{d.consumer_app.operational?}"
   end
   ```

2. **Check Consumer App is operational:**
   ```bash
   rake push_notifications:status
   ```
   
   Look for "Operational: ✅" next to your platform

3. **Check credentials are set:**
   ```bash
   # Android
   echo $RPUSH_FCM_KEY
   
   # iOS  
   echo $RPUSH_IOS_PEM
   ```

4. **Check Rpush queue:**
   ```ruby
   # Rails console
   pending = Rpush::Notification.where(delivered: false, failed: false)
   puts "Pending: #{pending.count}"
   
   failed = Rpush::Notification.where(failed: true).last
   if failed
     puts "Error: #{failed.error_description}"
     puts "Code: #{failed.error_code}"
   end
   ```

5. **Check Sidekiq is running:**
   ```bash
   ps aux | grep sidekiq
   ```

6. **Check Rails logs:**
   ```bash
   tail -f log/development.log | grep "🔔"
   ```

### Invalid/Expired Token?

If you get "BadDeviceToken" error:
```ruby
# Delete the invalid device
Device.where(token: 'invalid_token').destroy_all

# Re-register from mobile app
```

### Redis Connection Issues?

```bash
# Check Redis is running
redis-cli ping

# Check connection URL
echo $REDIS_URL
echo $REDIS_RPUSH_URL

# Test connection
redis-cli -u redis://localhost:6379 ping
```

### Notification Created but Not Delivered?

```bash
# Check if Sidekiq is processing jobs
bundle exec sidekiq

# Check Sidekiq queue
rails console
Sidekiq::Queue.all.each { |q| puts "#{q.name}: #{q.size}" }

# Manually trigger delivery
rake push_notifications:deliver
```

## 📱 Mobile App Integration

The mobile app should:

1. **Request notification permissions**
2. **Get the FCM/APNS token**
3. **Register device with backend:**
   ```javascript
   POST /users/devices
   {
     "token": "device_token_from_fcm_or_apns",
     "platform": "Android", // or "iOS"
     "app_bundle": "com.forem.android" // or "com.forem.app" for iOS
   }
   ```

4. **Handle incoming notifications**

## 🔐 Security Notes

- **Never commit** FCM keys or APNS certificates to Git
- Use environment variables (`.env` file)
- Add `.env` to `.gitignore`
- In production, use secure secret management

## 📊 Monitoring

### Check notification stats:
```ruby
# Rails console
total = Rpush::Notification.count
delivered = Rpush::Notification.where(delivered: true).count
failed = Rpush::Notification.where(failed: true).count
pending = Rpush::Notification.where(delivered: false, failed: false).count

puts "Total: #{total}"
puts "Delivered: #{delivered} (#{(delivered.to_f/total*100).round(1)}%)"
puts "Failed: #{failed}"
puts "Pending: #{pending}"
```

### Check recent failures:
```ruby
Rpush::Notification.where(failed: true).order(failed_at: :desc).limit(10).each do |n|
  puts "#{n.failed_at}: #{n.error_description} (#{n.error_code})"
end
```

## 🎉 Success Checklist

- [ ] Redis is running
- [ ] Sidekiq is running
- [ ] Rails server is running
- [ ] Environment variables are set (RPUSH_FCM_KEY or RPUSH_IOS_PEM)
- [ ] Consumer App exists and is operational
- [ ] Test user exists
- [ ] Device is registered with valid token
- [ ] `rake push_notifications:status` shows everything ✅
- [ ] Test notification sent successfully
- [ ] Notification received on mobile device

## 📚 Additional Resources

- [Rpush Documentation](https://github.com/rpush/rpush)
- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [Apple Push Notifications](https://developer.apple.com/documentation/usernotifications)
- [Sidekiq](https://github.com/mperham/sidekiq)

## 💡 Tips

1. **Start simple**: Test with Android first (easier to set up than iOS)
2. **Check logs**: The 🔔 emoji marks all notification-related log messages
3. **Use rake tasks**: They provide helpful feedback and error messages
4. **Test locally first**: Make sure everything works before deploying
5. **Monitor Redis**: Use `redis-cli monitor` to see real-time activity

---

**Still having issues?** Run the setup script again:
```bash
ruby setup_push_notifications.rb
```

It will show you exactly what's missing! 🔍
