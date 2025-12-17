class AddAnnouncedAtToRyanairDestinations < ActiveRecord::Migration[8.0]
  def up
    add_column :ryanair_destinations, :announced_at, :datetime

    # Mark all existing routes as already announced to avoid spamming users on deploy
    execute <<-SQL
      UPDATE ryanair_destinations SET announced_at = CURRENT_TIMESTAMP WHERE announced_at IS NULL
    SQL
  end

  def down
    remove_column :ryanair_destinations, :announced_at
  end
end
