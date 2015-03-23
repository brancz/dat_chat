require 'sinatra/base'
require 'dat_chat/models/user'
require 'dat_chat/middlewares/chat_backend'
require 'warden'
require 'rack-flash'

Warden::Strategies.add(:password) do
  def valid?
    params['user'] && params['user']['email'] && params['user']['password']
  end

  def authenticate!
    user = User.find(params['user']['email'])

    if user.nil?
      throw(:warden, message: "The email you entered does not exist.")
    elsif user.password == params['user']['password']
      success!(user)
    else
      throw(:warden, message: "The email and password combination ")
    end
  end
end

module DatChat
  class App < Sinatra::Base
    set :public_folder, settings.root + '/dat_chat/public'
    set :views,         settings.root + '/dat_chat/views'
    enable :sessions

    use Rack::Flash

    use Warden::Manager do |config|
      config.serialize_into_session{|user| user.email }
      config.serialize_from_session{|email| User.find(email) }

      config.scope_defaults :default,
        strategies: [:password],
        action: 'auth/unauthenticated'

      config.failure_app = self
    end

    Warden::Manager.before_failure do |env,opts|
      env['REQUEST_METHOD'] = 'POST'
    end

    use ChatBackend

    get "/" do
      env['warden'].authenticate!
      @messages = Message.history(DatChat::ChatBackend::CHANNEL)
      @email = env['warden'].user.email
      erb :"chat.html"
    end

    get "/assets/js/application.js" do
      content_type :js
      @scheme = ENV['RACK_ENV'] == "production" ? "wss://" : "ws://"
      erb :"application.js"
    end

    get "/auth/login" do
      erb :"login.html"
    end

    post '/auth/login' do
      env['warden'].authenticate!

      flash[:success] = env['warden'].message

      if session[:return_to].nil?
        redirect '/'
      else
        redirect session[:return_to]
      end
    end

    post "/auth/sign_up" do
      user = User.new(email: params[:user][:email], password: params[:user][:password])
      if user.valid?
        flash[:success] = 'Successfully singed up, you can now login'
        user.save
      else
        flash[:error] = user.errors.full_messages
      end
      erb :"login.html"
    end

    post '/auth/unauthenticated' do
      session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?

      flash[:error] = env['warden.options'][:message] || "You must log in"
      redirect '/auth/login'
    end
  end
end

