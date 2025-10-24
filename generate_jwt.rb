#!/usr/bin/env ruby
require 'jwt'

# Use the same secret key base that Rails uses
secret_key = 'your-secret-key-base-here'

# Create a payload with user_id 1 (assuming there's a user with ID 1)
payload = {
  user_id: 1,
  exp: (Time.now + 5.minutes).to_i
}

# Generate the JWT token
token = JWT.encode(payload, secret_key)

puts "JWT Token for user_id 1:"
puts token