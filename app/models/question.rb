class Question < ActiveRecord::Base
  belongs_to :survey
  has_many :survey_answers
  
  attr_accessible :answer, :content, :survey_id
  
  def next_question(survey_id)
    question = Question.where(["survey_id = ? AND id > ?", survey_id, self.id])
  end
end
