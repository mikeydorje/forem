class Rpush310AddPushy < ActiveRecord::Migration[5.0]
  def self.up
    safety_assured do
    add_column :rpush_notifications, :external_device_id, :string, null: true
  end

    end
  def self.down
    remove_column :rpush_notifications, :external_device_id
  end
end
