require 'tropo-webapi-ruby'

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


  end

end
