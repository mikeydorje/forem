#!/bin/bash

# Send FCM Push Notification Test
# Usage: ./send_fcm_test.sh <FCM_TOKEN> [user_email]

FCM_TOKEN="$1"
USER_EMAIL="${2:-michael@tonethreads.com}"
FCM_KEY="${RPUSH_FCM_KEY:-AIzaSyD-illZ_qkhQDC1_77hMyTTPIBPdgVBZtc}"

if [ -z "$FCM_TOKEN" ]; then
  echo "❌ Usage: $0 <FCM_TOKEN> [user_email]"
  echo ""
  echo "Get the FCM token from your app logs after it starts:"
  echo "  Look for: 🔑 FCM Token: ..."
  echo ""
  echo "Then run:"
  echo "  $0 'your-fcm-token-here'"
  exit 1
fi

echo "🔔 FCM Push Notification Test"
echo "=============================="
echo ""
echo "FCM Token: ${FCM_TOKEN:0:50}..."
echo "User: $USER_EMAIL"
echo ""

# Step 1: Register device in database
echo "📝 Step 1: Registering device in Rails..."
export DATABASE_URL="postgres://organicelectronics:Oe-5268452684@127.0.0.1:5432/forem_development"

rails runner "
user = User.find_by(email: '$USER_EMAIL')
if !user
  puts '❌ User not found: $USER_EMAIL'
  exit 1
end

# Delete old devices for this user to avoid duplicates
Device.where(user: user).destroy_all

consumer_app = ConsumerApp.find_by(app_bundle: 'com.forem.android', platform: 'Android')
device = Device.create!(
  user: user,
  consumer_app: consumer_app,
  platform: 'Android',
  token: '$FCM_TOKEN'
)

puts '✅ Device registered: ID=' + device.id.to_s
" 2>/dev/null

if [ $? -ne 0 ]; then
  echo "❌ Failed to register device"
  exit 1
fi

echo ""
echo "📤 Step 2: Sending FCM push notification..."

# Step 2: Send via FCM directly
RESPONSE=$(curl -s -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=$FCM_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"to\": \"$FCM_TOKEN\",
    \"notification\": {
      \"title\": \"🎉 TEST from Rails\",
      \"body\": \"Sent at $(date +%H:%M:%S) - IT WORKS!\",
      \"sound\": \"default\"
    },
    \"data\": {
      \"type\": \"test\",
      \"timestamp\": \"$(date +%s)\",
      \"message\": \"Direct FCM test\"
    },
    \"priority\": \"high\"
  }")

echo ""
echo "Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

if echo "$RESPONSE" | grep -q "\"success\":1"; then
  echo ""
  echo "✅✅✅ SUCCESS! Check your Android emulator NOW! ✅✅✅"
  echo ""
  echo "You should see a notification with:"
  echo "  Title: 🎉 TEST from Rails"
  echo "  Body: Sent at [time] - IT WORKS!"
else
  echo ""
  echo "❌ Failed to send. Check the error above."
  
  if echo "$RESPONSE" | grep -q "InvalidRegistration"; then
    echo ""
    echo "The token might be invalid. Make sure:"
    echo "1. The app is running"
    echo "2. You copied the full FCM token from logs"
    echo "3. The token starts with a long alphanumeric string (not 'ExponentPushToken')"
  fi
fi

echo ""
echo "💡 Next: Test via Rails Rpush system:"
echo "  cd forem && rails runner \\"
echo "    \"PushNotifications::Send.call(user_ids: [User.find_by(email: '$USER_EMAIL').id], \\"
echo "    title: 'Test from Rpush', body: 'Via Rails', payload: {type: 'test'}); Rpush.push\""
