class RemoveEventIndices < ActiveRecord::Migration[4.2]
  def change
    remove_index :events, [:user_type, :user_id]
    remove_index :events, :exercise_id
    remove_index :events, :file_id
  end
end
