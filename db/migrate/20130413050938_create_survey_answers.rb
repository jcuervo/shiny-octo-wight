class CreateSurveyAnswers < ActiveRecord::Migration
  def change
    create_table :survey_answers do |t|
      t.integer :question_id
      t.boolean :answer

      t.timestamps
    end
  end
end
