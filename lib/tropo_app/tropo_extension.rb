require "sinatra/base"

module Sinatra
  module TropoExtension

    RECORDING_APP_ENDPOINT = APP_CONFIG['recording_endpoint']
    RECORDING_PATH = APP_CONFIG['recording_path']

    def tropo_object
      t = Tropo::Generator.new do
        on :event => 'error', :next => '/tropo/error.json'
        on :event => 'hangup', :next => '/tropo/hangup.json'
      end
    end

    def construct_welcome_message(client=nil)
      if client.nil?
        "Welcome to Ring RX. The number you are calling is not yet activated"
      else
        if client.welcome_message.blank?
          "Welcome to #{client.name}"
        else
          client.welcome_message
        end
      end
    end

    def no_doctor_on_call
      "Sorry there is no available on call doctor at the moment. Goodbye"
    end

    def verify_telephone(callerid)
      options = {
        :name => 'verify_phone',
        :timeout => 60,
        :bargein => false,
        :required => true,
        :say => { :value => "You are calling us from #{callerid}. If you want us to reach you here, press 1. If now press 2." },
        :choices => { :value => "1,2"}
      }
    end

    def ask_telephone
      options = {
        :name => 'caller_did',
        :timeout => 60,
        :bargein => false,
        :required => true,
        :say => { :value => "Please enter your 10 digit phone number including the area code." },
        :choices => { :value => "[10 DIGITS]" }
      }
    end

    def urgent_or_not
      options = {
        :name => 'routine_or_not',
        :timeout => 15,
        :bargein => false,
        :required => true,
        :say => { :value => "If your call is a routine and you would like to leave a non-urgent message for the office, please press 1. If you have an urgent medical issue and you need to reach the on-call doctor, please press 2." },
          :choices => { :value => "1,2" }
      }
    end

    def message_form(msg_id, account_id, caller_id, msg_type)
      options = {
        :name => msg_id,
        :timeout => 30,
        :maxSilence => 7,
        :format => 'audio/mp3',
        :required => true,
        :bargein => false,
        :url => "#{RECORDING_APP_ENDPOINT}/recording?msg_id=#{msg_id}&account_id=#{account_id}&caller_id=#{caller_id}&msg_type=#{msg_type}",
        :transcription => {
          :url => "#{RECORDING_APP_ENDPOINT}/recording/transcriptions",
          :id => "#{msg_type}_#{msg_id}_#{Time.now.strftime("%Y%m%d%H%M%s")}"
        },
          :choices => {
          :terminator => "#"
        }
      }
    end

    def conference_caller(msg_id)
      options = {
        :name => "ringrx_dev_#{msg_id}",
        :id => "ringrx_dev_#{msg_id}",
        :terminator => '#',
        :allowSignals => 'exit'
      }
    end

    def doctor_pin(msg)
      options = {
        :name => 'doctors_pin',
        :timeout => 30,
        :required => true,
        :say => { :value => "This is Ring R X. #{msg}. Please enter your 4 digit pass code." },
        :attempts => 3,
        :choices => { :value => "[4 DIGITS]", :mode => "dtmf"}
      }
    end

    def play_message_from_caller(desc_rec, account_id)
      options = {
        :name => 'callback_client',
        :timeout => 20,
        :required => true,
        :say => { :value => "Playing message from caller. #{RECORDING_PATH}/#{account_id}/#{desc_rec} . Do you want to call the patient back? Say yes to callback patient, no to end this call." },
        :attempts => 3,
        :bargein => false,
        :choices => { :value => "yes,no" }
      }
    end

    def play_relay_message(name_rec, desc_rec, account_id)
      options = {
        :name => 'callback_client',
        :timeout => 20,
        :required => true,
        :say => { :value => "Playing message from caller. #{RECORDING_PATH}/#{account_id}/#{name_rec} . Regarding. #{RECORDING_PATH}/#{account_id}/#{desc_rec} . Do you want to call the patient back? Say yes to callback patient, no to end this call." },
        :attempts => 3,
        :bargein => false,
        :choices => { :value => "yes,no" }
      }
    end

    def connect_or_not(name_rec, desc_rec, account_id)
      options = {
        :name => 'patch_me',
        :required => true,
        :timeout => 20,
        :say => { :value => "We have patient. #{RECORDING_PATH}/#{account_id}/#{name_rec} . Calling regarding. #{RECORDING_PATH}/#{account_id}/#{desc_rec} . If you want to talk to the patient, say yes, if not, say no." },
        :attempts => 3,
        :bargein => false,
        :choices => { :value => "yes,no" }
      }
    end

    def console_log(name, object)
      Rails.logger.debug '+' + '-'*10 + name + '-'*10 + '+'
      Rails.logger.debug object.inspect
      Rails.logger.debug '+' + '-'*10 + name + '-'*10 + '+'
    end

  end

  helpers TropoExtension

end
