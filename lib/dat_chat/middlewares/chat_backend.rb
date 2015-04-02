require 'faye/websocket'
require 'thread'
require 'redis'
require 'json'
require 'erb'
require 'dat_chat/models/message'
require 'dat_chat/redis_factory'

module DatChat
  class ChatBackend
    KEEPALIVE_TIME = 15 # in seconds
    CHANNEL        = "chat-demo"

    def initialize(app)
      @app     = app
      @clients = []
      @redis = RedisFactory.redis_client
      Thread.new do
        redis_sub = RedisFactory.redis_client
        redis_sub.subscribe(CHANNEL) do |on|
          on.message do |channel, msg|
            @clients.each {|ws| ws.send(msg) }
          end
        end
      end
    end

    def call(env)
      if Faye::WebSocket.websocket?(env)
        ws = Faye::WebSocket.new(env, nil, { ping: KEEPALIVE_TIME })

        ws.on :open do |event|
          if env['warden'].authenticated?
            @clients << ws
          end
        end

        ws.on :message do |event|
          sanitized_json = sanitize(event.data)
          message_json = JSON.parse(sanitized_json, symbolize_names: true)
          message = Message.new(message_json)
          message.handle = env['warden'].user.email
          if message.valid?
            message_json = message.to_json
            @redis.lpush(CHANNEL, message_json)
            @redis.publish(CHANNEL, message_json)
          end
        end

        ws.on :close do |event|
          @clients.delete(ws)
          ws = nil
        end

        # Return async Rack response
        ws.rack_response
      else
        @app.call(env)
      end
    end

    private

    def sanitize(message)
      json = JSON.parse(message)
      json.each {|key, value| json[key] = ERB::Util.html_escape(value) }
      JSON.generate(json)
    end
  end
end
