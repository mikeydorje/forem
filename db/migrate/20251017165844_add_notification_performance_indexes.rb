class AddNotificationPerformanceIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # Critical for notification loading - ordered by notified_at DESC
    add_index :notifications, [:user_id, :notified_at], 
              order: { notified_at: :desc }, 
              name: 'index_notifications_on_user_id_and_notified_at_desc',
              algorithm: :concurrently
    
    # For unread notification filtering
    add_index :notifications, [:user_id, :read, :notified_at], 
              name: 'index_notifications_on_user_id_read_notified_at',
              algorithm: :concurrently
    
    # For subforem filtering (used in from_subforem scope)
    add_index :notifications, [:subforem_id, :user_id, :notified_at], 
              name: 'index_notifications_on_subforem_user_notified_at',
              algorithm: :concurrently
    
    # For subscription lookups (eliminates N+1 in decorator)
    add_index :notification_subscriptions, [:user_id, :notifiable_type, :notifiable_id], 
              name: 'index_notification_subscriptions_on_user_notifiable',
              algorithm: :concurrently
    
    # For reaction checks (eliminates N+1 in any_cached_reactions_for?)
    # Split into two more targeted indexes instead of 4-column index
    add_index :reactions, [:user_id, :reactable_type, :reactable_id], 
              name: 'index_reactions_on_user_reactable',
              algorithm: :concurrently
  end
end
