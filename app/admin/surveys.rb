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
  
  show :title => :name do
    panel "Question and Answers" do
      table_for survey.questions.all do |t|
        t.column "Question" do |question|
          question.content
        end
        t.column "Yes" do |question|
          question.survey_answers.yes.size
        end
        t.column "No" do |question|
          question.survey_answers.yes.size
        end
      end
    end
  end

  sidebar :notes do
    "Some stuff here"
  end
end
