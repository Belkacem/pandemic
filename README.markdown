# Pandemic
Pandemic is a map-reduce-ish framework. It allows you to partition requests and distribute them as you please, then process the request (or parts of it) on any number of nodes, and then reduce the response however you please. It's designed to serve requests in real-time, but can also be used for offline tasks.

It's different from the typical map-reduce framework in that it doesn't have a master-worker structure. Every node does can do everything. It's actually not strictly a map-reduce framework, it's a bit more lenient on what you can do to your data/request other than map and reduce.

The framework is designed to be as flexible as possible, there is no rigid request format, or API, you can specify it however you want. You can send it http-style headers and a body, you can send it JSON, or you can even just send it a single line and have it do whatever you want. The only requirement is that you write your handler to appropriately act on the request and return the response.

## Usage
### Server
    
    require 'rubygems'
    require 'pandemic'

    class Handler < Pandemic::ServerSide::Handler
      def process(body)
        body.reverse
      end
    end

    pandemic_server = epidemic!
    pandemic_server.handler = Handler # Pandemic will call the initializer once per process
    pandemic_server.start.join

In this example, the handler doesn't define the partition or reduce methods, and the defaults are used. The default for each is as follows:

  * partition: Send the full request body to every connected node
  * process: Return the body (do nothing)
  * reduce: Concatenate all the responses

### Client

    require 'rubygems'
    require 'pandemic'

    class TextFlipper
      include Pandemize
      def flip(str)
        pandemic.request(str)
      end
    end


### Config
Both the server and client have config files:

    # pandemic_server.yml
    servers:
      - host1:4000
      - host2:4000
    response_timeout: 0.5

Each value for the server list is the _host:port_ that a node can bind to. The servers value can be a hash or an array of hashes, but I'll get to that later. The response timeout is how long to wait for responses from nodes before returning to the client.

    # pandemic_client.yml
    servers:
      - host1:4000
      - host2:4000
    max_connections_per_server: 10
    min_connections_per_server: 1
    response_timeout: 1
    
The min/max connections refers to how many connections to each node. If you're using the client in Rails, then just use 1 for both min/max since it's single threaded.

### More Config
There are three ways to start a server:

  * ruby server.rb -i 0
  * ruby server.rb -i machine1hostname
  * ruby server.rb -a localhost:4000
  
The first refers to the index in the servers array:

    servers:
      - host1:4000 # started with ruby server.rb -i 0
      - host2:4000 # started with ruby server.rb -i 1
      
The second refers to the index in the servers _hash_. This can be particularly useful if you use the hostname as the key.

    servers:
      machine1: host1:4000 # started with ruby server.rb -i machine1
      machine2: host2:4000 # started with ruby server.rb -i machine2
      
The third is to specify the host and port explicitly. Ensure that the host and port you specify is actually in the config otherwise the other nodes won't be able to communicate with it.

You can also set node-specific configuration options.

    servers:
      - host1:4000:
          database: pandemic_node_1
          host: localhost
          username: foobar
          password: f00bar
      - host2:4000:
          database: pandemic_node_2
          host: localhost
          username: fizzbuzz
          password: f1zzbuzz
            
And you can access these additional options using _config.get(keys)_ in your handler:

    class Handler < Pandemic::ServerSide::Handler
      def initialize
        @dbh = Mysql.real_connect(*config.get('host', 'username', 'password', 'database')) 
      end
    end
    
## Examples
To run the example in the _examples_ folder, fire up two to three terminal windows. And run one of these in each:

  * cd examples/server; ruby word\_count_server.rb -i 0
  * cd examples/server; ruby word\_count_server.rb -i 1
  * cd examples/client; ruby client.rb
  
The servers are going to try to bind to localhost:4000 and localhost:4001 so make sure those are available.

## Enabling Forking
By default, the handler runs in the same Ruby process as Pandemic. By setting the fork\_for\_processor to true in pandemic\_server.yml, you can have Pandemic fork to new processes to run the process method. This is particularly useful when your process method goes to MySQL which locks the entire process until MySQL returns.

## Change History
Version 0.3.1
 * Changed map to partition to more accurately reflect what it does. This breaks backwards compatibility, but all you have to do is rename your method.
Version 0.3.0

 * Pandemic can now fork to call the process method
 * Pandemic server now expects a class instead of a instance of the handler when booting the server, it will call the initializer method once per process.