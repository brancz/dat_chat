require 'sinatra/base'
require './models/user'

module ChatDemo
  class App < Sinatra::Base
    helpers do
      def protected!
        return if authorized?
        headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
        halt 401, "Not authorized\n"
      end

      def authorized?
        @auth ||=  Rack::Auth::Basic::Request.new(request.env)
        @auth.provided? and @auth.basic? and @auth.credentials and User.authenticate!(*@auth.credentials)
      end
    end

    get "/" do
      erb :"register_login.html"
    end

    post "/" do
      puts params
      user = User.new(email: params[:email], password: params[:password])
      if user.valid?
        @messages = ['Successfully singed up, you can now login']
        user.save
      else
        @errors = user.errors.full_messages
      end
      erb :"register_login.html"
    end

    get "/chat" do
      protected!
      @messages = Message.history(ChatDemo::ChatBackend::CHANNEL)
      erb :"chat.html"
    end

    get "/assets/js/application.js" do
      content_type :js
      @scheme = ENV['RACK_ENV'] == "production" ? "wss://" : "ws://"
      erb :"application.js"
    end
  end
end
