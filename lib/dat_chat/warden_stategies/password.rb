require 'warden'
require 'dat_chat/models/user'

class PasswordStrategy < ::Warden::Strategies::Base
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

Warden::Strategies.add(:password, PasswordStrategy)

