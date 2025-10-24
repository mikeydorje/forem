class AddReactionIndex < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # For reaction checks (eliminates N+1 in any_cached_reactions_for?)
    add_index :reactions, [:user_id, :reactable_type, :reactable_id], 
              name: 'index_reactions_on_user_reactable',
              algorithm: :concurrently
  end
end
