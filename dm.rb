require 'socket'
require 'monitor'
# Process.setrlimit(Process::RLIMIT_NOFILE, 1024)
require 'lib/base'
require 'lib/client'
require 'lib/server'
require 'lib/peer'



DM_SERVERS = %w{localhost:4000 localhost:4001 localhost:4002 localhost:4003}


DM::Server.new(DM_SERVERS[ARGV.first.to_i], DM_SERVERS).start

