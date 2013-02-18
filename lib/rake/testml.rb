require 'rake'
require 'pathname'

TESTML_CONF = './test/testml.yaml'

# Usage:
#   rake testml
#   rake testml ./test/mytestmlconf.yaml
#
# This rake task syncs your local testml setup with a testml repository and
# creates any needed shim test files.
desc 'Update TestML files.'
task :testml do
  testml_conf =
    ARGV.size == 2 ? ARGV[1] :
    ARGV.size == 1 ? TESTML_CONF :
    fail("Usage: rake testml [testml-conf-yaml-file]")
  fail "TestML conf file '#{testml_conf}' not found" \
    unless File.exists? testml_conf
  # File paths are relative to the yaml file location
  base = File.dirname testml_conf
  fail "TestML conf file must be .yaml" \
    unless testml_conf.match /\.ya?ml$/
  require 'yaml'
  conf = YAML.load File.read testml_conf
  source = conf['source_testml_dir'] \
    or fail "`rake testml` requires 'source_testml_dir' key in #{testml_conf}"
  target = conf['local_testml_dir'] \
    or fail "`rake testml` requires 'local_testml_dir' key in #{testml_conf}"
  tests = conf['test_file_dir'] || '.'
  source = File.expand_path source, base
  target = File.expand_path target, base
  tests = File.expand_path tests, base
  Dir.exists? source \
    or fail "'#{source}' directory does not exist"
  Dir.exists? target or mkdir target
  Dir.exists? tests or mkdir tests
  template = conf['test_file_template']
  skip = conf['exclude_testml_files'] || []
  files = conf['include_testml_files'] ||
    Dir.new(source).grep(/\.tml$/)
  files.each do |file|
    next if skip.include? file
    s = "#{source}/#{file}"
    t = "#{target}/#{file}"
    if ! uptodate?(t, [s])
      cp rel(s), rel(t)
    end
    if template
      test = file.sub /\.tml$/, '.rb'
      test = File.expand_path test, tests
      hash = {
        file: rel(t, base),
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

def rel path, base='.'
  base = Pathname.new(File.absolute_path(base))
  Pathname.new(path).relative_path_from(base).to_s
end
