ActiveAdmin.register Survey do

  index do
    column :name
    column "Questions" do |resource|
      resource.questions.size
    end
    default_actions
  end

  form do |f|
    f.inputs "Survey Detail" do
      f.input :name
    end
    f.has_many :questions, :name => "Question" do |j|
      j.input :content
      unless j.object.id.blank?
        j.input :_destroy, :as => :boolean, :label => "Delete?"
      end
      j.form_buffers.last
    end
    f.buttons
  end
  
  sidebar :notes do
    "Some stuff here"
  end
end
