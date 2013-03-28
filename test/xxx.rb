def XXX(*args)
  require 'yaml'
  args.each {|node| puts YAML.dump(node)}
  puts 'XXX from: ' + caller.first
  exit
end

def YYY(*args)
  require 'yaml'
  args.each {|node| puts YAML.dump(node)}
  puts 'YYY from: ' + caller.first
  return *args
end
