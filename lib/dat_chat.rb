require 'sinatra/base'
require 'rack-flash'

require 'dat_chat/models/user'
require 'dat_chat/middlewares/chat_backend'
require 'dat_chat/warden_stategies/password'

module DatChat
  class App < Sinatra::Base
    set :public_folder,  settings.root + '/dat_chat/public'
    set :views,          settings.root + '/dat_chat/views'
    set :session_secret, ENV['SESSION_SECRET']
    enable :sessions
    enable :method_override

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
      erb :"chat.html"
    end

    get "/assets/js/application.js" do
      content_type :js
      @scheme = ENV['RACK_ENV'] == "production" ? "wss://" : "ws://"
      erb :"application.js", layout: false
    end

    get "/auth/sign_in" do
      erb :"sign_in.html"
    end

    post '/auth/sign_in' do
      env['warden'].authenticate!

      if session[:return_to].nil?
        redirect '/'
      else
        redirect session[:return_to]
      end
    end

    get "/auth/sign_up" do
      erb :"sign_up.html"
    end

    post "/auth/sign_up" do
      user = User.new(email: params[:user][:email], password: params[:user][:password])
      if user.valid?
        flash[:success] = 'Successfully singed up, you can now sign in'
        user.save
        redirect '/auth/sign_in'
      else
        flash[:error] = user.errors.full_messages
        erb :"sign_up.html"
      end
    end

    delete '/auth/sign_out' do
      env['warden'].logout
      flash[:success] = 'Successfully signed out'
      redirect '/auth/sign_in'
    end

    post '/auth/unauthenticated' do
      session[:return_to] = env['warden.options'][:attempted_path] if session[:return_to].nil?

      flash[:error] = env['warden.options'][:message] || "You must log in"
      redirect '/auth/sign_in'
    end
  end
end

