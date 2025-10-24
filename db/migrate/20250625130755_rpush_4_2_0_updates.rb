class Rpush420Updates < ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"]
  def self.up
    safety_assured do
    add_column :rpush_notifications, :sound_is_json, :boolean, null: true, default: false
  end

    end
  def self.down
    remove_column :rpush_notifications, :sound_is_json
  end
end

