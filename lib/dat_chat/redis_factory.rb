require 'redis'

module RedisFactory
  module_function

  def redis_client
    Redis.new(
      url: 'redis://mymaster',
      sentinels: [{ host: 'redissentinel', port: 26379 }],
      role: :master
    )
  end
end

