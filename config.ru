#\ -s puma
require './config/environment'

require 'dat_chat'
require 'dat_chat/middlewares/chat_backend'

use DatChat::ChatBackend
run DatChat::App
