class CreateQuestions < ActiveRecord::Migration
  def change
    create_table :questions do |t|
      t.integer :survey_id
      t.string :content
      t.integer :answer

      t.timestamps
    end
  end
end
