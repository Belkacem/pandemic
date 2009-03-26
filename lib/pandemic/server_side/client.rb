module Pandemic
  module ServerSide
    class Client
      class DisconnectClient < Exception; end
      include Util
      
      attr_accessor :received_requests, :responded_requests
      
      def initialize(connection, server)
        @connection = connection
        @server = server
        @received_requests = 0
        @responded_requests = 0
        @current_request = nil
      end
    
      def listen
        unless @connection.nil?
          @listener_thread.kill if @listener_thread
          @listener_thread = Thread.new do
            begin
              while @server.running
                debug("Waiting for incoming request")
                request = @connection.gets
                info("Received incoming request")
                @received_requests += 1
                
                if request.nil?
                  debug("Incoming request is nil")
                  @connection.close
                  @connection = nil
                  break
                elsif request.strip! =~ /^([0-9]+)$/ # currently only asking for request size
                  size = $1.to_i
                  debug("Reading request body (size #{size})")
                  body = @connection.read(size)
                  debug("Finished reading request body")
                  
                  response = handle_request(body)
                  
                  debug("Writing response to client")
                  
                  # the connection could be closed, we'll let it be rescued if it is.
                  @connection.write("#{response.size}\n#{response}")
                  @connection.flush
                  @responded_requests += 1
                  debug("Finished writing response to client")
                end
              end
            rescue DisconnectClient
              info("Closing client connection")
              close_connection
            rescue Errno::EPIPE
              info("Connection to client lost")
              close_connection
            rescue Exception => e
              warn("Unhandled exception in client listen thread: #{e.inspect}")
            ensure
              @current_request.cancel! if @current_request
              @server.client_closed(self)
            end
          end
        end
        return self
      end
    
      def close
        @listener_thread.raise(DisconnectClient)
      end
      

    
      def handle_request(request)
        @current_request = Request.new(request)
        response = @server.handle_client_request(@current_request)
        @current_request = nil
        return response
      end
      
      private
      def close_connection
        @connection.close unless @connection.nil? || @connection.closed?
      end
      
      def signature
        @signature ||= @connection.peeraddr.values_at(3,1).join(":")
      end
      
      def debug(msg)
        logger.debug("Client #{signature}") {msg}
      end
      
      def info(msg)
        logger.info("Client #{signature}") {msg}
      end
      
      def warn(msg)
        logger.warn("Client #{signature}") {msg}
      end
    end
  end
end