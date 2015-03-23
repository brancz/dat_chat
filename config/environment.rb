$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'redis'
Redis.current = Redis.new(url: ENV['REDIS_URL'])

