require 'rake'

TESTML_CONF = './test/testml.yaml'

desc 'Update TestML files.'
task :testml do
  fail "TestML conf file '#{TESTML_CONF}' not found" \
    unless File.exists? TESTML_CONF
  dir = File.dirname TESTML_CONF
  fail "TestML conf file must be .yaml" \
    unless TESTML_CONF.match /\.ya?ml$/
  require 'yaml'
  conf = YAML.load File.read TESTML_CONF
  source = conf['source'] \
    or fail "`rake testml` requires 'source' key in #{TESTML_CONF}"
  target = conf['target'] \
    or fail "`rake testml` requires 'target' key in #{TESTML_CONF}"
  source = File.expand_path source, dir
  target = File.expand_path target, dir
  Dir.exists? source \
    or fail "'#{conf.source}' directory does not exist"
  Dir.exists? target or mkdir target
  template = conf['template']
  skip = conf['skip'] || []
  Dir.new(source).grep(/\.tml$/).each do |file|
    next if skip.include? file
    s = "#{source}/#{file}"
    t = "#{target}/#{file}"
    if (! File.exists?(t) or File.read(s) != File.read(t))
      cp rel(s), rel(t)
    end
    if template
      test = file.sub /\.tml$/, '.rb'
      test = File.expand_path test, dir
      hash = {
        file: rel(t, dir),
      }
      code = template % hash
      if ! File.exists?(test) or code != File.read(test)
        action = File.exists?(test) ? 'Updating' : 'Creating'
        puts "#{action} test file '#{rel test}'"
        File.write test, code
      end
    end
  end
end

def rel path, base=nil
  require 'pathname'
  base ||= '.'
  base = Pathname.new(File.absolute_path(base))
  Pathname.new(path).relative_path_from(base).to_s
end
