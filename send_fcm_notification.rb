#!/usr/bin/env ruby
# Standalone FCM push notification script for Forem
# Usage: ruby send_fcm_notification.rb <device_token> <title> <body>

require 'net/http'
require 'json'
require 'googleauth'

if ARGV.length < 3
  puts "Usage: ruby send_fcm_notification.rb <device_token> <title> <body>"
  exit 1
end

device_token = ARGV[0]
title = ARGV[1]
body = ARGV[2]

# Path to your Firebase service account JSON (must match Rails app)
json_key_path = File.expand_path('firebase-service-account.json', __dir__)
scope = 'https://www.googleapis.com/auth/firebase.messaging'
project_id = 'forem-5d94b' # Must match your Firebase project

begin
  file_io = File.open(json_key_path)
  authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: file_io,
    scope: scope
  )
  authorizer.fetch_access_token!
  access_token = authorizer.access_token
rescue => e
  puts "FIREBASE AUTH FAILED: #{e.class}: #{e.message}"
  exit 1
end

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
    data: {}
  }
}

request.body = payload.to_json
response = http.request(request)

if response.code == '200'
  puts "Push notification sent successfully to #{device_token}"
else
  puts "Failed to send push notification: #{response.body}"
end
