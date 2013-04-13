class SurveyAnswer < ActiveRecord::Base
  attr_accessible :answer, :question_id
end
