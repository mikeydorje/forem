#!/bin/bash

# Quick Push Notification Test for Expo
# This sends a push notification directly to your Expo app

# Your Expo token (from database)
EXPO_TOKEN="ExponentPushToken[8lfbjZIAXLHMNe11glRXNn]"

# Get FCM key from environment
FCM_KEY="${RPUSH_FCM_KEY}"

if [ -z "$FCM_KEY" ]; then
  echo "❌ ERROR: RPUSH_FCM_KEY not set"
  echo "Set it with: export RPUSH_FCM_KEY='your-firebase-server-key'"
  exit 1
fi

echo "🔔 Sending push notification to Expo..."
echo "Token: $EXPO_TOKEN"
echo ""

# Send via Expo API
RESPONSE=$(curl -s -X POST https://exp.host/--/api/v2/push/send \
  -H "Content-Type: application/json" \
  -d "{
    \"to\": \"$EXPO_TOKEN\",
    \"title\": \"🎉 TEST from Rails\",
    \"body\": \"Sent at $(date +%H:%M:%S)\",
    \"sound\": \"default\",
    \"data\": {
      \"type\": \"test\",
      \"timestamp\": $(date +%s)
    }
  }")

echo "Response:"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

if echo "$RESPONSE" | grep -q "\"status\":\"ok\""; then
  echo ""
  echo "✅✅✅ SUCCESS! Check your Expo Android device! ✅✅✅"
else
  echo ""
  echo "❌ Failed. Check the error above."
  echo ""
  echo "If error is 'InvalidCredentials', you need to configure FCM in your Expo app:"
  echo "1. cd /home/organicelectronics/app"
  echo "2. Add to app.json:"
  echo "   \"android\": {"
  echo "     \"googleServicesFile\": \"./google-services.json\","
  echo "     \"config\": {"
  echo "       \"googleMaps\": {"
  echo "         \"apiKey\": \"YOUR_FCM_KEY\""
  echo "       }"
  echo "     }"
  echo "   }"
fi
