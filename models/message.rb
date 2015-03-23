require 'json'

class Message
  include ActiveModel::Model

  attr_accessor :handle, :text

  def self.history(channel)
    Redis.current.lrange(channel, 0, -1).map do |entry|
      Message.from_json(entry)
    end
  end

  def self.from_json(json)
    Message.new(JSON.parse(json, symbolize_names: true))
  end

  def to_json
    { handle: handle, text: text }.to_json
  end
end

