require 'bcrypt'
require 'active_model'

class User
  class HasErrors < StandardError; end
  include BCrypt
  include ActiveModel::Validations

  attr_reader :email, :password
  validates_presence_of :email, :password

  def initialize(attributes = {})
    @email = attributes[:email]
    @password = Password.create(attributes[:password]) unless attributes[:password].blank?
    @password = Password.new(attributes[:password_hash]) unless attributes[:password_hash].blank?
  end

  def save
    fail HasErrors unless self.valid?
    Redis.current.set(@email, @password)
  end

  def self.create(attributes)
    user = User.new(attributes)
    user.save
    user
  end

  def self.find(email)
    password_hash = Redis.current.get(email)
    return nil if password_hash.nil?
    User.new(email: email, password_hash: password_hash)
  end
end

