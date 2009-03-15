require 'test_helper'

class ServerTest < Test::Unit::TestCase
  include TestHelper
  
  should "initialize peers" do
    Pandemic::ServerSide::Config.expects(:bind_to).at_least_once.returns("localhost:4000")
    Pandemic::ServerSide::Config.expects(:servers).returns(["localhost:4000", "localhost:4001"])
    Pandemic::ServerSide::Peer.expects(:new).with("localhost:4001", is_a(Pandemic::ServerSide::Server))
    @server = Pandemic::ServerSide::Server.new    
  end
  
  context "with a server" do
    setup do
      Pandemic::ServerSide::Config.expects(:bind_to).at_least_once.returns("localhost:4000")
      Pandemic::ServerSide::Config.expects(:servers).returns(["localhost:4000", "localhost:4001"])
      @peer = mock()
      Pandemic::ServerSide::Peer.expects(:new).with("localhost:4001", is_a(Pandemic::ServerSide::Server)).returns(@peer)
      @server = Pandemic::ServerSide::Server.new
    end
    
    should "start a TCPServer, and connect to peers" do
      ignore_threads = Thread.list
      @tcpserver = mock()
      TCPServer.expects(:new).with("localhost", 4000).returns(@tcpserver)
      @peer.expects(:connect).once
      @tcpserver.expects(:accept).twice.returns(nil).then.raises(Pandemic::ServerSide::Server::StopServer)
      @tcpserver.expects(:close)
      @peer.expects(:disconnect)
      @server.handler = mock()
      @server.start
      wait_for_threads(ignore_threads)
    end
    
    should "create a new client object for a client connection" do
      ignore_threads = Thread.list
      
      @tcpserver = mock()
      TCPServer.expects(:new).with("localhost", 4000).returns(@tcpserver)
      @peer.expects(:connect).once
      
      @conn = mock(:peeraddr => ['','','',''])
      @tcpserver.expects(:accept).twice.returns(@conn).then.raises(Pandemic::ServerSide::Server::StopServer)
      client = mock()
      @conn.expects(:setsockopt).with(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      
      Pandemic::ServerSide::Client.expects(:new).with(@conn, @server).returns(client)

      
      @conn.expects(:gets).returns("CLIENT\n")
      @tcpserver.expects(:close)
      @peer.expects(:disconnect)
      client.expects(:listen).returns(client)
      client.expects(:close).at_most_once # optional due to threaded nature, this may not actually happen
      @server.handler = mock()
      @server.start
      wait_for_threads(ignore_threads)
    end
    
    should "connect with the corresponding peer object" do
      ignore_threads = Thread.list
      @tcpserver = mock()
      TCPServer.expects(:new).with("localhost", 4000).returns(@tcpserver)
      @peer.expects(:connect).once
      
      @conn = mock(:peeraddr => ['','','',''])
      @tcpserver.expects(:accept).twice.returns(@conn).then.raises(Pandemic::ServerSide::Server::StopServer)
      @tcpserver.expects(:close)
      @peer.expects(:disconnect)
      
      @conn.expects(:setsockopt).with(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
      @conn.expects(:gets).returns("SERVER localhost:4001\n")
      
      @peer.expects(:host).returns("localhost")
      @peer.expects(:port).returns(4001)
      @peer.expects(:add_incoming_connection).with(@conn)
      @server.handler = mock()
      
      @server.start
      wait_for_threads(ignore_threads)
    end
   
    should "call process on handler" do
      handler = mock()
      handler.expects(:process).with("body")
      @server.handler = handler
      @server.process("body")
    end
    
    should "map request, distribute to peers, and reduce" do
      handler = mock()
      request = mock()
      request.expects(:hash).at_least_once.returns("abcddef134123")
      @peer.expects(:connected?).returns(true)
      handler.expects(:map).with(request, is_a(Hash)).returns({"localhost:4000" => "1", "localhost:4001" => "2"})
      request.expects(:max_responses=).with(2)
      @peer.expects(:client_request).with(request, "2")
      
      handler.expects(:process).with("1").returns("2")
      request.expects(:add_response).with("2")
      
      request.expects(:wait_for_responses).once
      handler.expects(:reduce).with(request)
      
      @server.handler = handler
      
      @server.handle_client_request(request)
      # wait_for_threads
    end
  end
end