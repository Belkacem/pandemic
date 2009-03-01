require 'socket'
require 'fastthread'
require 'thread'
require 'monitor'
require 'yaml'
require 'digest/md5'
require 'logger'

require 'pandemic/util'

require 'pandemic/server_side/config'
require 'pandemic/server_side/client'
require 'pandemic/server_side/server'
require 'pandemic/server_side/peer'
require 'pandemic/server_side/request'
require 'pandemic/server_side/handler'

require 'pandemic/client_side/config'
require 'pandemic/client_side/cluster_connection'
require 'pandemic/client_side/connection'
require 'pandemic/client_side/connection_proxy'
require 'pandemic/client_side/pandemize'

# TODO:
# - work on protocol specs
# - client side code
# - IO timeouts
# - PING/PONG?

$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG

def epidemic!(handler)
  Pandemic::ServerSide::Server.boot(handler)
end

::Pandemize = Pandemic::ClientSide::Pandemize