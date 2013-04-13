class Question < ActiveRecord::Base
  belongs_to :survey
  has_many :survey_answers
  
  attr_accessible :answer, :content, :survey_id
end
