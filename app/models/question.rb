class Question < ActiveRecord::Base
  belongs_to :survey
  
  attr_accessible :answer, :content, :survey_id
end
