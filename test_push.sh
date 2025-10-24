#!/bin/bash

# Push Notification Quick Test Script
# This script helps you quickly test push notifications

set -e

echo "🔔 Push Notification Quick Test"
echo "================================"
echo ""

# Check if we're in the forem directory
if [ ! -f "Gemfile" ] || [ ! -d "app/models" ]; then
    echo "❌ Error: Please run this script from the forem directory"
    exit 1
fi

# Function to check if a process is running
check_process() {
    if pgrep -x "$1" > /dev/null; then
        echo "✅ $1 is running"
        return 0
    else
        echo "❌ $1 is not running"
        return 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo "Step 1: Checking dependencies..."
echo "--------------------------------"

# Check Redis
if command_exists redis-cli; then
    if redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis is running"
    else
        echo "❌ Redis is not running"
        echo "   Start it with: redis-server"
        exit 1
    fi
else
    echo "❌ redis-cli not found"
    echo "   Install Redis: brew install redis (Mac) or apt-get install redis (Linux)"
    exit 1
fi

# Check if Rails is available
if ! command_exists rails; then
    echo "❌ Rails not found"
    echo "   Run: bundle install"
    exit 1
fi

echo "✅ Rails is available"
echo ""

echo "Step 2: Checking environment variables..."
echo "------------------------------------------"

ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  No .env file found"
    echo "   Creating .env from .env_sample..."
    cp .env_sample .env
    echo "✅ Created .env file"
    echo ""
    echo "📝 Please edit .env and add your credentials:"
    echo "   - RPUSH_FCM_KEY for Android"
    echo "   - RPUSH_IOS_PEM for iOS"
    echo ""
    read -p "Press Enter when you've added your credentials..."
fi

# Check if credentials are set
if grep -q "RPUSH_FCM_KEY=" "$ENV_FILE" 2>/dev/null; then
    echo "✅ RPUSH_FCM_KEY found in .env"
else
    echo "⚠️  RPUSH_FCM_KEY not in .env (needed for Android)"
fi

if grep -q "RPUSH_IOS_PEM=" "$ENV_FILE" 2>/dev/null; then
    echo "✅ RPUSH_IOS_PEM found in .env"
else
    echo "⚠️  RPUSH_IOS_PEM not in .env (needed for iOS)"
fi

echo ""

echo "Step 3: Running setup script..."
echo "--------------------------------"
ruby setup_push_notifications.rb

echo ""
echo "Step 4: Next steps"
echo "--------------------------------"
echo ""
echo "🎯 To complete the test, you need to:"
echo ""
echo "1. Start Sidekiq (in a new terminal):"
echo "   cd $(pwd)"
echo "   bundle exec sidekiq"
echo ""
echo "2. Register a device either by:"
echo ""
echo "   Option A: Use the mobile app"
echo "   - Log in to the app"
echo "   - Grant notification permissions"
echo "   - Device will auto-register"
echo ""
echo "   Option B: Use the interactive setup"
echo "   - Run: rake push_notifications:setup_test"
echo "   - Follow the prompts"
echo ""
echo "3. Send a test notification:"
echo "   rake push_notifications:test[your@email.com]"
echo ""
echo "4. Check status anytime:"
echo "   rake push_notifications:status"
echo ""
echo "📚 For detailed instructions, see:"
echo "   PUSH_NOTIFICATIONS_TESTING.md"
echo ""
echo "================================"
echo "✨ Setup complete! Ready to test!"
echo "================================"
