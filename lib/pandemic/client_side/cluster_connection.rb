module Pandemic
  module ClientSide
    class ClusterConnection
      class NotEnoughConnectionsTimeout < StandardError; end
      class NoNodesAvailable < StandardError; end
      class LostConnectionToNode < StandardError; end
      class NodeTimedOut < StandardError; end
      class RequestFailed < StandardError; end
      
      include Util
      def initialize
        Config.load
        @connections = []
        @available = []
        @grouped_connections = Hash.new { |hash, key| hash[key] = [] }
        @grouped_available = Hash.new { |hash, key| hash[key] = [] }
        @mutex = Monitor.new
        @connection_proxies = {}
        @queue = @mutex.new_cond # TODO: there should be a queue for each group
        
        @response_timeout = Config.response_timeout
        @response_timeout = nil if @response_timeout <= 0
        
        Config.servers.each_with_index do |server_addr, key|
          @connection_proxies[key] = ConnectionProxy.new(key, self)
          host, port = host_port(server_addr)
          Config.min_connections_per_server.times do
            add_connection_for_key(key)
          end
        end
        
        maintain_minimum_connections!
      end
      
      
      def [](key)
        @connection_proxies[key % @connection_proxies.size]
      end
      
      def request(body, key = nil, options = {})
        key, options = nil, key if key.is_a?(Hash)
        with_connection(key) do |socket|
          begin
            raise LostConnectionToNode if socket.nil?
            flags = []
            if options[:async]
              flags << "a"
            end
            flags = flags.empty? ? "" : " #{flags.join("")}"
            
            socket.write("#{body.size}#{flags}\n#{body}")
            socket.flush
            
            unless options[:async]
              is_ready = IO.select([socket], nil, nil, @response_timeout)
              raise NodeTimedOut if is_ready.nil?
              response_size = socket.gets
              if response_size && response_size.to_i >= 0
                socket.read(response_size.to_i)
              elsif response_size && response_size.to_i < 0
                raise RequestFailed
              else
                # nil response size
                raise LostConnectionToNode
              end
            end
          rescue Errno::ECONNRESET, Errno::EPIPE
            raise LostConnectionToNode
          end
        end
      end
      
      def shutdown
        @connections.each {|c| c.socket.close if c.alive? }
        @maintain_minimum_connections_thread.kill if @maintain_minimum_connections_thread
      end
      
      private
      def with_connection(key, &block)
        connection = nil
        begin
          connection = checkout_connection(key)
          block.call(connection.socket)
        rescue LostConnectionToNode
          connection.died!
          raise
        ensure
          checkin_connection(connection) if connection
        end
      end
      
      def checkout_connection(key)
        connection = nil
        select_from = key.nil? ? @available : @grouped_available[key]
        all_connections = key.nil? ? @connections : @grouped_connections[key]
        @mutex.synchronize do
          loop do
            if select_from.size > 0
              connection = select_from.pop
              connection.ensure_alive!
              if !connection.alive?
                # it's dead
                delete_connection(connection)
                next
              end
              
              if key.nil?
                @grouped_available[key].delete(connection)
              else
                @available.delete(connection)
              end
              break
            elsif (connection = create_connection(key)) && connection.alive?
              @connections << connection
              @grouped_connections[key] << connection
              break
            elsif all_connections.size > 0 && @queue.wait(Config.connection_wait_timeout)
              next
            else
              if all_connections.size > 0
                raise NotEnoughConnectionsTimeout
              else
                raise NoNodesAvailable
              end
            end
          end
        end
        return connection
      end
      
      def checkin_connection(connection)
        @mutex.synchronize do
          @available.unshift(connection)
          @grouped_available[connection.key].unshift(connection)
          @queue.signal
        end
      end
      
      def create_connection(key)
        if key.nil?
          # find a key where we can add more connections
          min, min_key = nil, nil
          @grouped_connections.each do |key, list|
            if min.nil? || list.size < min
              min_key = key
              min = list.size
            end
          end
          key = min_key
        end
        return nil if @grouped_connections[key].size >= Config.max_connections_per_server
        host, port = host_port(Config.servers[key])
        Connection.new(host, port, key)
      end
      
      def add_connection_for_key(key)
        connection = create_connection(key)
        if connection.alive?
          @connections << connection
          @available << connection
          @grouped_connections[key] << connection
          @grouped_available[key] << connection
        end
      end
      
      def delete_connection(connection)
        @connections.delete(connection)
        @available.delete(connection)
        @grouped_connections[connection.key].delete(connection)
        @grouped_available[connection.key].delete(connection)
      end
      
      def maintain_minimum_connections!
        return if @maintain_minimum_connections_thread
        @maintain_minimum_connections_thread = Thread.new do
          loop do
            sleep 60 #arbitrary
            @mutex.synchronize do
              @grouped_connections.keys.each do |key|
                currently_exist = @grouped_connections[key].size
                if currently_exist < Config.min_connections_per_server
                  (Config.min_connections_per_server - currently_exist).times do
                    add_connection_for_key(key)
                  end
                end
              end
            end
          end
        end
      end
      
    end
  end
end