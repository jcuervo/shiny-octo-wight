class SurveyAnswer < ActiveRecord::Base
  belongs_to :question
  
  scope :yes, where(:answer => true)
  scope :no, where(:answer => false)
  
  attr_accessible :answer, :question_id, :caller_id
end
