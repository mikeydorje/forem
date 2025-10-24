# 🔔 Push Notifications Test Suite

**Complete testing toolkit for Rails/Forem ↔ React Native push notifications**

---

## 📖 Table of Contents

- [Quick Start](#-quick-start-3-commands)
- [Documentation](#-documentation)
- [Tools & Scripts](#-tools--scripts)
- [Troubleshooting](#-troubleshooting)
- [Architecture](#-architecture)

---

## 🚀 Quick Start (3 Commands)

### 1. Run Setup
```bash
cd forem
./test_push.sh
```

### 2. Add Credentials
Edit `.env` file:
```bash
# Android
RPUSH_FCM_KEY="your-firebase-server-key"

# iOS (optional)
RPUSH_IOS_PEM="your-apns-certificate"
```

### 3. Test
```bash
# Check everything is configured
rake push_notifications:status

# Send test notification
rake push_notifications:test[user@example.com]
```

**That's it!** 🎉

---

## 📚 Documentation

### Main Guides

1. **[PUSH_NOTIFICATION_SUMMARY.md](PUSH_NOTIFICATION_SUMMARY.md)**
   - 📋 Overview of entire test suite
   - 🎯 What was created and why
   - 💡 Quick reference for all tools

2. **[PUSH_NOTIFICATIONS_TESTING.md](PUSH_NOTIFICATIONS_TESTING.md)**
   - 📖 Complete testing guide
   - 🔧 Configuration instructions
   - 🧪 Testing scenarios
   - 🐛 Troubleshooting guide
   - **→ READ THIS FIRST for detailed setup**

3. **[PUSH_NOTIFICATION_ARCHITECTURE.md](PUSH_NOTIFICATION_ARCHITECTURE.md)**
   - 🏗️ System architecture diagrams
   - 🔄 Flow charts
   - 📊 Data model relationships
   - 🗺️ Visual guides

4. **[.env.push_notifications](.env.push_notifications)**
   - 🔑 Environment variable template
   - 📝 Detailed comments
   - ✅ Copy to `.env` and fill in

---

## 🛠️ Tools & Scripts

### Rake Tasks
Located in: `lib/tasks/push_notifications.rake`

```bash
# Send test notification
rake push_notifications:test[user@example.com]

# Check system status
rake push_notifications:status

# Manually deliver pending notifications
rake push_notifications:deliver

# Interactive setup wizard
rake push_notifications:setup_test
```

### Ruby Scripts

#### `setup_push_notifications.rb`
Comprehensive setup verification
```bash
ruby setup_push_notifications.rb
```

#### `quick_push_test.rb`
Fast test from Rails runner
```bash
rails runner quick_push_test.rb user@example.com
```

### Bash Scripts

#### `test_push.sh`
One-command setup and verification
```bash
./test_push.sh
```

---

## 🔍 Troubleshooting

### Quick Checks

1. **Check System Status**
   ```bash
   rake push_notifications:status
   ```

2. **Check Services Running**
   ```bash
   # Redis
   redis-cli ping
   
   # Sidekiq
   ps aux | grep sidekiq
   
   # Rails
   ps aux | grep rails
   ```

3. **Check Logs**
   ```bash
   # Rails logs (look for 🔔 emoji)
   tail -f log/development.log | grep "🔔"
   
   # Sidekiq logs
   tail -f log/sidekiq.log
   ```

### Common Issues

| Issue | Solution |
|-------|----------|
| "No devices registered" | Use mobile app or `rake push_notifications:setup_test` |
| "Consumer app not operational" | Set `RPUSH_FCM_KEY` or `RPUSH_IOS_PEM` in `.env` |
| "Redis connection failed" | Start Redis: `redis-server` |
| "Notification not delivered" | Ensure Sidekiq is running: `bundle exec sidekiq` |

**Full troubleshooting guide:** [PUSH_NOTIFICATIONS_TESTING.md](PUSH_NOTIFICATIONS_TESTING.md#-troubleshooting)

---

## 🏗️ Architecture

### The Flow

```
Mobile App → Register Device → Rails Backend
                                     ↓
                              Create Notification
                                     ↓
                              Queue in Redis (Rpush)
                                     ↓
                              Sidekiq Worker (30s delay)
                                     ↓
                              Rpush.push
                                     ↓
                          FCM/APNS → Mobile Device
```

### Key Components

- **Device Model** - Links user, platform, and token
- **ConsumerApp Model** - Stores app configuration & credentials
- **PushNotifications::Send** - Service to create notifications
- **Rpush** - Gem that handles FCM/APNS delivery
- **Sidekiq** - Background job processor

**Full architecture diagrams:** [PUSH_NOTIFICATION_ARCHITECTURE.md](PUSH_NOTIFICATION_ARCHITECTURE.md)

---

## 📋 Prerequisites

### Required Services
- ✅ Redis (for Rpush queue)
- ✅ Sidekiq (for background jobs)
- ✅ PostgreSQL (for data)

### Required Credentials
- 🔑 **Android:** Firebase Server Key (`RPUSH_FCM_KEY`)
- 🔑 **iOS:** APNS Certificate (`RPUSH_IOS_PEM`)

### Required Setup
```bash
# Install dependencies
bundle install

# Run migrations
rails db:migrate

# Start services
redis-server          # Terminal 1
bundle exec sidekiq   # Terminal 2
rails s               # Terminal 3
```

---

## ✅ Pre-Flight Checklist

Before testing, verify:

- [ ] Redis is running
- [ ] Sidekiq is running
- [ ] Rails server is running
- [ ] Credentials set in `.env`
- [ ] Database migrated
- [ ] Test user exists
- [ ] Device registered
- [ ] `rake push_notifications:status` shows ✅

---

## 📊 File Structure

```
forem/
├── README_PUSH_NOTIFICATIONS.md          ← You are here
├── PUSH_NOTIFICATION_SUMMARY.md          ← Overview
├── PUSH_NOTIFICATIONS_TESTING.md         ← Full guide (read this!)
├── PUSH_NOTIFICATION_ARCHITECTURE.md     ← Architecture diagrams
├── .env.push_notifications               ← ENV template
│
├── lib/tasks/
│   └── push_notifications.rake           ← Rake tasks
│
├── setup_push_notifications.rb           ← Setup script
├── quick_push_test.rb                    ← Quick test
└── test_push.sh                          ← Bash setup
```

---

## 🎯 Usage Examples

### Example 1: First Time Setup
```bash
# 1. Run setup
./test_push.sh

# 2. Add FCM key to .env
echo 'RPUSH_FCM_KEY="your-key"' >> .env

# 3. Restart Rails server
rails s

# 4. Register device via mobile app

# 5. Test
rake push_notifications:test[test@example.com]
```

### Example 2: Quick Test
```bash
# One command
rails runner quick_push_test.rb test@example.com
```

### Example 3: Console Testing
```bash
rails console
```
```ruby
user = User.find_by(email: 'test@example.com')
PushNotifications::Send.call(
  user_ids: [user.id],
  title: "Test",
  body: "Console test",
  payload: { type: "test" }
)
```

### Example 4: Status Check
```bash
rake push_notifications:status
```

---

## 💡 Pro Tips

1. **Start with Android** - Easier to set up than iOS
2. **Use the status command** - Shows everything at a glance
3. **Check logs with 🔔** - Easy to find notification logs
4. **Test incrementally** - Verify each step
5. **Keep Sidekiq running** - Required for delivery

---

## 🆘 Need Help?

### Step 1: Check Status
```bash
rake push_notifications:status
```

### Step 2: Review Logs
```bash
tail -f log/development.log | grep "🔔"
```

### Step 3: Read Full Guide
```bash
cat PUSH_NOTIFICATIONS_TESTING.md
```

### Step 4: Run Setup Again
```bash
ruby setup_push_notifications.rb
```

---

## 📝 Next Steps

### For Development
1. ✅ Test notifications locally
2. ✅ Document team setup
3. ✅ Create test users/devices
4. ✅ Monitor delivery rates

### For Production
1. 🔐 Set production credentials
2. 📊 Set up monitoring/alerting
3. 🔄 Configure failover
4. 📈 Track delivery metrics

---

## 🎉 Success Criteria

You know it's working when:
- ✅ `rake push_notifications:status` shows operational apps
- ✅ Devices are registered
- ✅ Test notification is sent
- ✅ Notification appears in Rpush queue
- ✅ Sidekiq processes the job
- ✅ **Mobile device receives notification** 🎊

---

## 📞 Support

- **Documentation:** See files listed above
- **Logs:** Check `log/development.log` and `log/sidekiq.log`
- **Debug:** Use `rake push_notifications:status`

---

**Created for:** Testing push notifications between Rails (Forem) and React Native app  
**Last Updated:** 2025-01-XX  
**Status:** ✅ Ready to use

Happy testing! 🚀
