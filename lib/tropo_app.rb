require 'tropo-webapi-ruby'
require 'sinatra'

class TropoApp < Sinatra::Base

  before do 
    if request.request_method.eql? "POST"
      @t = Tropo::Generator.new do
        on event: 'error', next: '/tropo/error.json'
        on event: 'hangup', next: '/tropo/hangup.json'
      end
      @v = Tropo::Generator.parse request.env["rack.input"].read
    end
  end

  get '/index.json' do
    'Welcome to shiny shiny survey'
  end

  post '/hangup.json' do
  end

  post '/error.json' do
    @t.say 'We are sorry but something is messed up.'
    @t.response
  end

  post '/index.json' do
    caller_id = @v[:session][:from][:id]

    @t.on event: 'continue', next: "/tropo/find_survey.json?callerid=#{caller_id}"

    options = {
      name: 'survey_id_input',
      timeout: 30,
      required: true,
      say: {
        value: 'Please enter the 4 digit survey ID'
      },
      attempts: 3,
      choices: {
        value: '[4 DIGITS]', 
        mode: 'dtmf'
      }
    }

    @t.ask options
    @t.response
  end

  post '/find_survey.json' do
    survey_id = @v[:result][:actions][:survey_id_input][:value]
    callerid = params[:callerid]

    survey = Survey.find_by_padded_id survey_id

    if survey
      questions = survey.questions
      @t.on event: 'continue', next: "/tropo/ask_question.json?question_id=#{questions.first.id}"
      @t.say "You are now in #{survey.name} survey."
    else
      @t.say 'Sorry that is not a valid survey. Goodbye'
    end

    @t.response
  end

  post '/ask_question.json' do
    question = Question.find params[:question_id]

    if question
      @t.on event: 'continue', next: "/tropo/record_answer.json?question_id=#{question.id}"

      options = {
        name: 'survey_answer',
        timeout: 30,
        required: true,
        say: {
          value: question.content
        },
        attempts: 3,
        choices: {
          value: 'yes , no'
        }
      }

      @t.ask options

    else
      @t.say 'Thank you for using shiny shiny survey. Goodbye.'
    end

    @t.response
  end

  post '/record_answer.json' do
    question = Question.find params[:question_id]
    caller_id = @v[:session][:from][:id]
    answer = @v[:result][:actions][:survey_answer][:value]

    survey_answer = question.survey_answers.create(
      answer: answer.eql?('yes') ? true : false, 
      caller_id: caller_id)

    next_question = question.next_question(question.survey.id)

    if next_question
      @t.on event: 'continue', next: "/tropo/record_answer.json?question_id=#{question.id}"

      options = {
        name: 'survey_answer',
        timeout: 30,
        required: true,
        say: {
          value: next_question.content
        },
        attempts: 3,
        choices: {
          value: 'yes , no'
        }
      }

      @t.ask options
    else
      @t.say 'Thank you for using shiny shiny survey. Goodbye.'
    end

    @t.response
  end

end
