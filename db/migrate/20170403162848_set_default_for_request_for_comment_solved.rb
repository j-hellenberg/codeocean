class SetDefaultForRequestForCommentSolved < ActiveRecord::Migration[4.2]
  def change
    change_column_default :request_for_comments, :solved, false
    RequestForComment.where(solved: nil).update_all(solved: false)
  end
end