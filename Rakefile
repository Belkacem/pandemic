require 'rubygems'
require 'rake'
require 'echoe'

Echoe.new('pandemic', '0.2.2') do |p|
  p.description    = "Distribute MapReduce to any of the workers and it will spread, like a pandemic."
  p.url            = "https://github.com/arya/pandemic/"
  p.author         = "Arya Asemanfar"
  p.email          = "aryaasemanfar@gmail.com"
  p.ignore_pattern = ["tmp/*", "script/*", 'test/*', 'Manifest']
  p.development_dependencies = ["shoulda", "mocha"]
end

Dir["#{File.dirname(__FILE__)}/tasks/*.rake"].sort.each { |ext| load ext }
