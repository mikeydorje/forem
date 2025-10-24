class Rpush410Updates < ActiveRecord::Migration["#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"]
  def self.up
    safety_assured do
    add_column :rpush_notifications, :dry_run, :boolean, null: false, default: false
  end

    end
  def self.down
    remove_column :rpush_notifications, :dry_run
  end
end
