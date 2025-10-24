#!/usr/bin/env ruby

# Test notification flow
test_user = User.find_by(email: 'testuser@example.com')
article = Article.first

if test_user && article
  puts "Creating like reaction..."
  reaction = Reaction.create!(
    user: test_user,
    reactable: article,
    category: 'like'
  )
  puts "Created reaction ID: #{reaction.id}"
  
  puts "Checking for new notifications..."
  notifications = Notification.where(user_id: article.user_id, action: 'Reaction').order(created_at: :desc).limit(3)
  if notifications.any?
    notifications.each do |n|
      puts "  - ID: #{n.id}, Notified user: #{n.user.name}, Action: #{n.action}, Created: #{n.created_at}"
    end
  else
    puts "  No reaction notifications found"
  end
  
  # Also check all recent notifications for this user
  all_notifications = Notification.where(user_id: article.user_id).order(created_at: :desc).limit(5)
  puts "\nAll recent notifications for article author:"
  all_notifications.each do |n|
    puts "  - ID: #{n.id}, Action: #{n.action}, Created: #{n.created_at}"
  end
else
  puts "Could not find test user or article"
end