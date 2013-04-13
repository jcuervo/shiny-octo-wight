require 'tropo-webapi-ruby'
require 'tropo_app/tropo_extension'

class TropoApp < Sinatra::Base
  helpers Sinatra::TropoExtension

  before do
    if request.request_method.eql? "POST"
      @t = tropo_object
      @v = Tropo::Generator.parse request.env["rack.input"].read
      Rails.logger.debug console_log "#{request.request_method} #{request.path_info}", @v
    end
  end

  after do
    Rails.logger.debug console_log "#{request.request_method} #{request.path_info}", @t
  end

  get '/index.json' do
    "Welcome to Ring Rx" 
  end

  ##
  # Acts as the action router for TROPO-API-Calls
  #
  post '/index.json' do

    if @v[:session][:parameters]
      ##
      # Outbound call from resque-workers
      #
      msg = Message.find(@v[:session][:parameters][:msg_id])

      call_type = @v[:session][:parameters][:call_type]
      pin = @v[:session][:parameters][:pin]
      callerid = @v[:session][:parameters][:caller_id]
      telephone_numbers = @v[:session][:parameters][:number_to_dial]
      list_size = @v[:session][:parameters][:list_size]
      sms_number = @v[:session][:parameters][:sms_number]
      call_index = @v[:session][:parameters][:call_index]
      call_attempts = @v[:session][:parameters][:call_attempts]

      ##
      # Identify the outbound call type if voice or sms
      #
      case  call_type
      when 'patch', 'relay'
        @t.on :event => 'error', :next => "/tropo/dial_next.json?msg_id=#{msg.id}&call_index=#{call_index.to_i + 1}&list_size=#{list_size}&session_id=#{msg.session_id}&telephone_number=#{telephone_numbers}&caller_id=#{callerid}&call_attempts=#{call_attempts}&call_type=#{call_type}"
        @t.on :event => 'incomplete', :next => "/tropo/dial_next.json?msg_id=#{msg.id}&call_index=#{call_index.to_i}&list_size=#{list_size}&session_id=#{msg.session_id}&telephone_number=#{telephone_numbers}&caller_id=#{callerid}&call_attempts=#{call_attempts}&call_type=#{call_type}"
        @t.on :event => 'continue', :next => "/tropo/prompt_doctor.json?msg_id=#{msg.id}&desc_rec=#{msg.description}&account_id=#{msg.account_id}&session_id=#{msg.session_id}&call_type=#{call_type}&pin=#{pin}&sms=#{sms_number}"

        @t.call :to => telephone_numbers, :from => callerid, :timeout => 22
      when 'sms'
        if sms_number
          @t.call :to => @v[:session][:parameters][:sms_number], :from => callerid, :network => 'SMS'
          @t.say :value => "You have a message from caller: #{msg.callerid}. Regarding: #{msg.desc_transcription}"
        end
      when 'callback'
        @t.call :to => telephone_numbers, :from => callerid
        @t.say :value => "Welcome to #{@v[:session][:parameters][:clinic_name]}. We have calling you because the on call provider wants to talk to you regarding your call earlier today."
        @t.conference conference_caller(msg.id)
      end

    else
      ##
      # Regular inbound call
      #
      trunk_line = @v[:session][:to][:id]
      callerid = @v[:session][:from][:id]
      client = Account.where(:trunkline => "+1#{trunk_line}").first

      ##
      # Identify if the trunkline belongs to a clinic
      #
      if client.nil?
        @t.say :value => construct_welcome_message
      else
        @t.on :event => 'continue', :next => "/tropo/get_message_type.json?account_id=#{client.id}&caller_id=#{callerid}&session_id=#{session[:session_id]}"
        @t.say :value => construct_welcome_message(client)
      end

    end

    @t.response
  end

  ##
  # Call the next in the list base on the call_index
  #
  post '/dial_next.json' do
    Rails.logger.debug console_log "dial_next.json", params

    retry_limit = 1

    if params[:list_size].to_i >= params[:call_index].to_i
      if params[:call_attempts].to_i < retry_limit
        CallLog.create(:status => 'redial',
                      :call_to => "+#{params[:telephone_number].to_s.strip}",
                      :call_from => params[:caller_id],
                      :msg_id => params[:msg_id],
                      :attempts => params[:call_attempts].to_i + 1,
                      :session_id => params[:session_id])
        Resque.enqueue(TropoDialer, params[:msg_id].to_i, params[:call_index].to_i, 'relay', 'redial')
        Rails.logger.debug console_log "dial_next.json", "redial phone: #{params[:telephone_number]} [#{params[:call_attempts].to_i + 1}]"
      else
        Resque.enqueue(TropoDialer, params[:msg_id].to_i, params[:call_index].to_i + 1, 'relay', 'new')
        Rails.logger.debug console_log "dial_next.json", "calling next phone to queue: #{params[:telephone_number]} [#{params[:call_attempts].to_i + 1}]"
      end
    else
      if params[:call_type].eql? 'patch'
        rest_response = RestAccount.get "https://api.tropo.com/1.0/sessions/#{params[:session_id]}/signals", :params => {:action => 'signal', :value => 'exit'}
        Rails.logger.debug rest_response
      end
    end
  end

  ##
  # Call the next in the list base on the call_index
  #
  post '/prompt_doctor.json' do
    if params[:sms]
      unless params[:sms].blank? or params[:sms].nil?
        Rails.logger.debug console_log "prompt_doctor.json", "QUEUEING SMS SENDER NOW"
        Resque.enqueue(TropoTextMessenger, params[:msg_id])
      end
    end

    @t.on :event => 'continue', :next => "/tropo/authenticate_doctor.json?msg_id=#{params[:msg_id]}&desc_rec=#{params[:desc_rec]}&account_id=#{params[:account_id]}&session_id=#{params[:session_id]}&call_type=#{params[:call_type]}&pin=#{params[:pin]}"
    @t.ask doctor_pin(params[:call_type].eql?('patch') ? "We have a caller on the line for you" : "You have a message")

    @t.response
  end

  ##
  # Authenticates doctor for the pin number
  # that they input in the provider settings
  #
  post '/authenticate_doctor.json' do
    input_pin = @v[:result][:actions][:doctors_pin][:value]
    pin = params[:pin]
    call_type = params[:call_type]

    if  input_pin.eql? pin
      case call_type
      when 'patch'
        @t.on :event => 'continue', :next => "/tropo/patch_caller.json?msg_id=#{params[:msg_id]}&session_id=#{params[:session_id]}"
        @t.ask connect_or_not(params[:name_rec], params[:desc_rec], params[:account_id])
      when 'relay'
        @t.on :event => 'continue', :next => "/tropo/relay_message.json?msg_id=#{params[:msg_id]}"
        @t.ask play_message_from_caller(params[:desc_rec], params[:account_id])
      end
    else
      @t.say :value => "I'm sorry that is not a valid pin number. Goodbye!"
    end

    @t.response
  end

  ##
  # Play the mssage to the doctor/provider
  # and present an option if he/she wants to
  # do a callback
  #
  post '/relay_message.json' do
    ##
    # Trigger a callback to patient
    # and put the provider in conference.
    # If the doctor/provider says no,
    # call will be disconnected
    #
    if @v[:result][:actions][:callback_client][:value].eql? 'yes'
      msg = Message.find(params[:msg_id])
      @t.say "Please wait while we transfer your call. Press star to cancel the transfer."
      @t.transfer  :to => "+1#{msg.callerid}",
        :timeout => 30,
        :terminator => '*',
        :playvalue => "http://www.phono.com/audio/holdmusic.mp3",
        :onTimeout => lambda { |event|
          say "Sorry, but nobody answered."
        },
        :onError => lambda {|event|
          say "Sorry we are not able to process your call."
        },
        :onCallFailure => lambda {|event|
          say "Sorry the patients number is incorrect."
        }
    else
      @t.say :value => "Goodbye!"
    end


    @t.response
  end

  ##
  # Ask the doctor if he/she wants to talk
  # to the patient in the line. If yes the doctor will be redirected to the conference.
  # If no the call will end and will trigger a disconnect signal to the patients line to end the call.
  #
  post '/patch_caller.json' do
    if @v[:result][:actions][:patch_me][:value].eql? 'yes'
      @t.conference conference_caller(params[:msg_id])
      @t.say :value => "This system is provided by Ring R X. If you want to know more about our service, kindly visit Ring R X dot com."
    else
      rest_response = RestAccount.get "https://api.tropo.com/1.0/sessions/#{params[:session_id]}/signals", :params => {:action => 'signal', :value => 'exit'}
      Rails.logger.debug console_log 'rest_response_signal', rest_response
      @t.say :value => "Ok we will let the patient know. Goodbye!"
    end

    @t.response
  end

  post '/get_message_type.json' do
    msg = Message.create(:account_id => params[:account_id], :callerid => params[:caller_id], :session_id => params[:session_id], :status => 0)
    account_id = params[:account_id]
    callerid = params[:caller_id]

    @t.on :event => 'continue', :next => "/tropo/get_caller_did.json?account_id=#{account_id}&msg_id=#{msg.id}&caller_id=#{callerid}"
    @t.ask urgent_or_not

    @t.response
  end

  post '/get_caller_did.json' do
    msg = Message.find(params[:msg_id]).update_attribute(:call_type, @v[:result][:actions][:routine_or_not][:value])
    msg_id = params[:msg_id]
    account_id = params[:account_id]
    caller_id = params[:caller_id]

    @t.on :event => 'continue', :next => "/tropo/get_call_desc.json?msg_id=#{msg_id}&account_id=#{account_id}&caller_id=#{caller_id}"
    @t.ask ask_telephone

    @t.response
  end

  post '/get_call_desc.json' do
    msg = Message.find(params[:msg_id]).update_attribute(:callerid_input, @v[:result][:actions][:caller_did][:value])
    msg_id = params[:msg_id]
    account_id = params[:account_id]
    caller_id = params[:caller_id]

    @t.on :event => 'continue', :next => "/tropo/call_identifier.json?msg_id=#{msg_id}&account_id=#{account_id}"
    @t.record(message_form(msg_id, account_id, caller_id, 'desc')) do
      say :value => "Please say your name and a brief description of your call. When done press the pound key."
    end

    @t.response
  end

  post '/call_identifier.json' do
    msg = Message.find(params[:msg_id])
    client = Account.find(params[:account_id])

    if msg.call_type == 1
      @t.say :value => "Thank you for calling #{client.name}. This system is provided by Ring R X. If you want to know more about our service, kindly visit Ring R X dot com."
    else
      on_call_data = client.on_call_now

      unless on_call_data.blank?
        case on_call_data['ring_type'].downcase
        when 'patch caller'
          @t.say :value => "Please stay on the line and we will connect you."
          Resque.enqueue(TropoDialer, msg.id, 0, 'patch', 'new')
          @t.conference conference_caller(msg.id)
          @t.say :value => "This system is provided by Ring R X. If you want to know more about our service, kindly visit Ring R X dot com."
        when 'relay message'
          Resque.enqueue(TropoDialer, msg.id, 0, 'relay', 'new')
          @t.say :value => "Thank you for calling, the on call doctor will be calling you shortly. Goodbye!"
        when 'text message'
          @t.say :value => "Thank you for calling, we will notify the on call doctor about your call. Goodbye!"
        end
      else
        @t.say :value => "Sorry there is no available doctor on call at the moment. Goodbye!"
      end
    end

    @t.response
  end

  post '/hangup.json' do
  end

  post '/error.json' do
  end

end
