class Rpush210Updates < ActiveRecord::Migration[5.0]
  def self.up
    safety_assured do
    add_column :rpush_notifications, :url_args, :text, null: true
    add_column :rpush_notifications, :category, :string, null: true
  end

    end
  def self.down
    remove_column :rpush_notifications, :url_args
    remove_column :rpush_notifications, :category
  end
end
