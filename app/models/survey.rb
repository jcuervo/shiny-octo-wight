class Survey < ActiveRecord::Base
  has_many :questions
  accepts_nested_attributes_for :questions, :reject_if => :all_blank, :allow_destroy => true
  
  attr_accessible :name, :questions_attributes
  
  after_save :pad_id
  
  private  
    def pad_id
      self.update_column(:padded_id, "0000#{self.id}")
    end
end
