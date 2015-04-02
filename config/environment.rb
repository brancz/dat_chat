$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'redis'
require 'dat_chat/redis_factory'

Redis.current = RedisFactory.redis_client

