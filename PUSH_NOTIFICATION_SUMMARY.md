# 🔔 Push Notification Test Suite - Summary

## What Was Created

This test suite provides everything you need to test push notifications between your Rails/Forem backend and React Native mobile app.

### 📁 Files Created

1. **`lib/tasks/push_notifications.rake`** - Comprehensive rake tasks
   - `push_notifications:test` - Send test notification to a user
   - `push_notifications:status` - Check system status
   - `push_notifications:deliver` - Manually deliver pending notifications
   - `push_notifications:setup_test` - Interactive setup wizard

2. **`setup_push_notifications.rb`** - Automated setup and verification script
   - Checks all dependencies (Redis, gems, database)
   - Creates Consumer Apps
   - Creates test users if needed
   - Provides detailed status and next steps

3. **`PUSH_NOTIFICATIONS_TESTING.md`** - Complete documentation
   - Configuration guide for Android (FCM) and iOS (APNs)
   - Step-by-step testing instructions
   - Troubleshooting guide
   - Examples for all common scenarios

4. **`test_push.sh`** - Quick start bash script
   - One-command setup check
   - Validates environment
   - Guides you through the process

5. **`quick_push_test.rb`** - Simple Rails runner script
   - Fast way to send test notifications
   - Usage: `rails runner quick_push_test.rb user@example.com`

## 🚀 Quick Start (3 Steps)

### Step 1: Setup
```bash
cd forem
./test_push.sh
```

This will check everything and guide you through setup.

### Step 2: Configure Credentials

Edit `.env` file and add:

**For Android:**
```bash
RPUSH_FCM_KEY="your-firebase-server-key"
```

**For iOS:**
```bash
RPUSH_IOS_PEM="your-apns-certificate-in-pem-format"
```

### Step 3: Test

```bash
# Check status
rake push_notifications:status

# Send test notification
rake push_notifications:test[user@example.com]
```

## 📱 How It Works

### The Flow

1. **User logs into mobile app** → App gets FCM/APNS token
2. **App registers device** → `POST /users/devices` with token
3. **Rails creates Device record** → Links user, platform, token
4. **Trigger notification** → `PushNotifications::Send.call(...)`
5. **Creates Rpush notification** → Queued in Redis
6. **Sidekiq worker runs** → Calls `Rpush.push` after 30 seconds
7. **Rpush delivers** → Sends to FCM/APNS
8. **User receives notification** → On mobile device

### Key Components

- **ConsumerApp**: Represents an app (iOS or Android) with credentials
- **Device**: A user's registered device with FCM/APNS token
- **Rpush**: Gem that handles actual delivery to FCM/APNS
- **PushNotifications::Send**: Service that creates notifications
- **PushNotifications::DeliverWorker**: Sidekiq job that triggers delivery

## 🔧 Rake Tasks Reference

### Send Test Notification
```bash
rake push_notifications:test[user@example.com]
```
Sends a test notification with timestamp to specified user.

### Check System Status
```bash
rake push_notifications:status
```
Shows:
- Rpush configuration
- Consumer Apps (iOS/Android)
- Registered devices count
- Recent notifications
- Environment variables status

### Deliver Pending Notifications
```bash
rake push_notifications:deliver
```
Immediately delivers all pending notifications (bypasses 30s delay).

### Interactive Setup
```bash
rake push_notifications:setup_test
```
Walks you through:
- Choosing platform (iOS/Android)
- Selecting/creating user
- Registering device token

## 🧪 Testing Scenarios

### Scenario 1: End-to-End Test
1. Start services:
   ```bash
   redis-server  # Terminal 1
   bundle exec sidekiq  # Terminal 2
   rails s  # Terminal 3
   ```

2. Register device (mobile app or manual)

3. Send notification:
   ```bash
   rake push_notifications:test[test@example.com]
   ```

4. Check delivery (after ~30 seconds)

### Scenario 2: Console Testing
```bash
rails console
```

```ruby
# Find user
user = User.find_by(email: 'test@example.com')

# Send notification
PushNotifications::Send.call(
  user_ids: [user.id],
  title: "Console Test",
  body: "Testing from console",
  payload: { type: "test" }
)

# Check queue
Rpush::Notification.where(delivered: false).count

# Force delivery
Rpush.push
```

### Scenario 3: Quick Test
```bash
rails runner quick_push_test.rb test@example.com
```

## 🐛 Common Issues & Solutions

### "No devices registered"
**Solution:** Register a device via mobile app or use:
```bash
rake push_notifications:setup_test
```

### "Consumer app not operational"
**Solution:** Set credentials in `.env`:
- `RPUSH_FCM_KEY` for Android
- `RPUSH_IOS_PEM` for iOS

Then restart Rails server.

### "Redis connection failed"
**Solution:**
```bash
redis-server  # Start Redis
redis-cli ping  # Verify it's running
```

### "Notification created but not delivered"
**Solution:** Ensure Sidekiq is running:
```bash
bundle exec sidekiq
```

Or manually deliver:
```bash
rake push_notifications:deliver
```

### "BadDeviceToken" error
**Solution:** Delete invalid device and re-register:
```ruby
Device.where(token: 'bad_token').destroy_all
```

## 📊 Monitoring

### Check Status
```bash
rake push_notifications:status
```

### View Logs
```bash
# Rails logs (look for 🔔 emoji)
tail -f log/development.log | grep "🔔"

# Sidekiq logs
tail -f log/sidekiq.log
```

### Redis Monitor
```bash
redis-cli monitor | grep rpush
```

## 🔐 Security Checklist

- [ ] Never commit `.env` file
- [ ] Never commit FCM keys or APNS certificates
- [ ] Add `.env` to `.gitignore`
- [ ] Use environment variables for all secrets
- [ ] Rotate keys regularly in production

## 📚 Documentation

- **Full Guide:** `PUSH_NOTIFICATIONS_TESTING.md`
- **Rake Tasks:** `rake -T push_notifications`
- **Code:**
  - `app/services/push_notifications/send.rb`
  - `app/models/device.rb`
  - `app/controllers/devices_controller.rb`
  - `config/initializers/rpush.rb`

## ✅ Pre-Flight Checklist

Before testing:
- [ ] Redis is running
- [ ] Sidekiq is running  
- [ ] Rails server is running
- [ ] Credentials set (RPUSH_FCM_KEY or RPUSH_IOS_PEM)
- [ ] Database migrated
- [ ] Test user exists
- [ ] Device registered
- [ ] `rake push_notifications:status` shows ✅

## 🎯 Success Criteria

You know it's working when:
1. `rake push_notifications:status` shows operational ConsumerApp
2. User has at least one registered Device
3. `rake push_notifications:test[email]` completes successfully
4. Notification appears in Rpush queue
5. Sidekiq processes PushNotifications::DeliverWorker
6. Mobile device receives notification

## 💡 Pro Tips

1. **Start with Android** - Easier to set up than iOS
2. **Check logs** - Look for 🔔 emoji in logs
3. **Use status command** - `rake push_notifications:status` is your friend
4. **Test incrementally** - Verify each step before moving on
5. **Monitor Redis** - Use `redis-cli monitor` to debug
6. **Check Sidekiq** - Ensure workers are processing jobs

## 🆘 Still Stuck?

1. Run the setup script:
   ```bash
   ruby setup_push_notifications.rb
   ```

2. Check status:
   ```bash
   rake push_notifications:status
   ```

3. Review full documentation:
   ```bash
   cat PUSH_NOTIFICATIONS_TESTING.md
   ```

4. Check existing logs for errors:
   ```bash
   tail -100 log/development.log | grep -i error
   ```

## 🎉 Next Steps

After successful testing:

1. **For Development:**
   - Keep credentials in `.env`
   - Use test FCM server key
   - Document for team

2. **For Production:**
   - Set credentials as environment variables
   - Use production FCM/APNS credentials
   - Monitor delivery rates
   - Set up alerting for failures

---

**Created:** $(date)
**Purpose:** Test push notifications between Rails backend and React Native app
**Tested on:** Local development environment

Happy testing! 🚀
