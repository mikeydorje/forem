#!/usr/bin/env ruby
# Test push notification by having testuser comment on michael's article

puts "Finding users..."
michael = User.find_by(email: 'michael@tonethreads.com')
testuser = User.find_by(email: 'testuser@example.com')

puts "Michael: #{michael.username} (ID: #{michael.id})" if michael
puts "Testuser: #{testuser.username} (ID: #{testuser.id})" if testuser

if !michael || !testuser
  puts "ERROR: Users not found!"
  puts "Michael exists: #{!michael.nil?}"
  puts "Testuser exists: #{!testuser.nil?}"
  exit 1
end

puts "\nFinding michael's article..."
article = Article.where(user: michael).published.last

if !article
  puts "ERROR: No article found for michael"
  exit 1
end

puts "Article: '#{article.title}' (ID: #{article.id})"

puts "\nChecking michael's devices..."
michael.devices.each do |d|
  puts "  Device #{d.id}: #{d.platform}, token: #{d.token[0..30]}..."
end

puts "\nCreating comment from testuser..."
comment = Comment.create!(
  body_markdown: "Test comment from testuser at #{Time.now}",
  commentable: article,
  user: testuser
)

puts "✅ Comment created with ID: #{comment.id}"
puts "\nThis should trigger notification to michael!"
puts "Watch the logs for 🔔 Device#create_notification"
