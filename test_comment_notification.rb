#!/usr/bin/env ruby
# Test script to create a comment from a different user and verify notifications

puts 'All users in database:'
User.all.each do |u|
  puts "  #{u.id}: #{u.username} (#{u.email}) - #{u.devices.count} devices"
end

puts "\n" + ('='*60)

# Create a second user if we only have one
if User.count == 1
  puts "\nCreating a second user for testing..."
  user2 = User.create!(
    username: 'testuser',
    name: 'Test User',
    email: 'test@example.com',
    password: 'password123',
    password_confirmation: 'password123',
    confirmed_at: Time.now,
    registered: true
  )
  puts "✅ Created user: #{user2.username} (ID: #{user2.id})"
  
  # Find article by michael
  article = Article.published.last
  puts "\nCreating comment from testuser on michael's article..."
  puts "Article: '#{article.title}' by #{article.user.username}"
  
  comment = Comment.new(
    body_markdown: 'This is a test comment from a different user!',
    commentable: article,
    user: user2
  )
  
  if comment.save
    puts "✅ Comment created with ID: #{comment.id}"
    puts "This SHOULD trigger notification to #{article.user.username}"
    
    # Wait a moment for notification to be created
    sleep 1
    
    notifications = Notification.where(notifiable: comment)
    puts "\nNotifications created: #{notifications.count}"
    notifications.each do |n|
      puts "  To: #{n.user.username}, Type: #{n.class.name}"
    end
  else
    puts "❌ Failed: #{comment.errors.full_messages}"
  end
else
  puts "\n#{User.count} users found - we can use existing users"
  
  # Find two different users
  michael = User.find_by(username: 'michael')
  other_user = User.where.not(id: michael.id).first
  
  if other_user && michael
    article = Article.where(user: michael).published.last
    
    if article
      puts "\nCreating comment from #{other_user.username} on #{michael.username}'s article..."
      puts "Article: '#{article.title}'"
      
      comment = Comment.new(
        body_markdown: "Test comment from #{other_user.username} at #{Time.now}",
        commentable: article,
        user: other_user
      )
      
      if comment.save
        puts "✅ Comment created with ID: #{comment.id}"
        puts "This SHOULD trigger notification to #{michael.username}"
        
        # Wait a moment
        sleep 1
        
        notifications = Notification.where(notifiable: comment)
        puts "\nNotifications created: #{notifications.count}"
        notifications.each do |n|
          puts "  To: #{n.user.username}, Type: #{n.class.name}"
        end
      else
        puts "❌ Failed: #{comment.errors.full_messages.join(', ')}"
      end
    else
      puts "No article found by #{michael.username}"
    end
  else
    puts "Could not find required users"
  end
end
