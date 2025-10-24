class Rpush300Updates < ActiveRecord::Migration[5.0]
  def self.up
    safety_assured do
    add_column :rpush_notifications, :mutable_content, :boolean, default: false
    change_column :rpush_notifications, :sound, :string, default: nil
  end

    end
  def self.down
    remove_column :rpush_notifications, :mutable_content
    change_column :rpush_notifications, :sound, :string, default: 'default'
  end
end
