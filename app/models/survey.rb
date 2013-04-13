class Survey < ActiveRecord::Base
  has_many :questions
  accepts_nested_attributes_for :questions, :reject_if => :all_blank, :allow_destroy => true
  
  attr_accessible :name, :questions_attributes
end