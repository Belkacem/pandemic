require 'rubygems'
require 'socket'
require 'fastthread' if RUBY_VERSION < '1.9'
require 'thread'
require 'monitor'
require 'yaml'
require 'digest/md5'
require 'logger'

require 'pandemic/util'
require 'pandemic/connection_pool'
require 'pandemic/mutex_counter'

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
# - tests
# - connection pool throttling
# - see if caching the connection statuses improves times
# - IO timeouts/robustness
# - documentation
# - PING/PONG?

def epidemic!
  if $pandemic_logger.nil?
    $pandemic_logger = Logger.new("pandemic.log")
    $pandemic_logger.level = Logger::INFO
    $pandemic_logger.datetime_format = "%Y-%m-%d %H:%M:%S "
  end
  Pandemic::ServerSide::Server.boot
end

::Pandemize = Pandemic::ClientSide::Pandemize