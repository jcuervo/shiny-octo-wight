class AddCallerIdToAnswers < ActiveRecord::Migration
  def change
    add_column :survey_answers, :caller_id, :string
  end
end
