require_relative 'config/environment'

app = ConsumerApp.create!(
  app_bundle: 'com.forem.android',
  platform: 'android',
  team_id: 'R9SWHSQNV8'
)

puts "Created ConsumerApp: #{app.inspect}"