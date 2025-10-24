class Rpush330Updates < ActiveRecord::Migration[5.0]
  def self.up
    safety_assured do
    add_column :rpush_notifications, :thread_id, :string, null: true
  end

    end
  def self.down
    remove_column :rpush_notifications, :thread_id
  end
end
