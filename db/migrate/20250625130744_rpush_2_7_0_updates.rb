class Rpush270Updates < ActiveRecord::Migration[5.0]
  def self.up
    safety_assured do
    change_column :rpush_notifications, :alert, :text
    add_column :rpush_notifications, :notification, :text
  end

    end
  def self.down
    change_column :rpush_notifications, :alert, :string
    remove_column :rpush_notifications, :notification
  end
end

