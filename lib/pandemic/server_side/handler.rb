module Pandemic
  module ServerSide
    class Handler
      class << self
        # example/dummy handler
        def map(request, servers)
          count = 0
          servers.inject({}) {|h, e| h[e] = "#{request.body}:#{count+=1}"; h}
        end

        def reduce(request)
          request.responses.join(" | ")
        end

        def process(body)
          "#{body}!"
        end
      end
    end
  end
end