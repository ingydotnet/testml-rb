##
# name:      TestML::Setup
# author:    Ingy döt Net <ingy@cpan.org>
# abstract:  Generate Test Files for a TestML Suite
# license:   perl
# copyright: 2010-2013

require 'rake'
require 'yaml'
require 'pathname'
include FileUtils

DEFAULT_TESTML_CONF = './test/testml.yaml'

class TestML; end
class TestML::Setup
  def setup(testml_conf)
    testml_conf ||= DEFAULT_TESTML_CONF
    fail "TestML conf file '#{testml_conf}' not found" \
      unless File.exists? testml_conf
    fail "TestML conf file must be .yaml" \
      unless testml_conf.match /\.ya?ml$/
    # File paths are relative to the yaml file location
    base = File.dirname testml_conf
    conf = YAML.load File.read testml_conf
    source = conf['source_testml_dir'] \
      or fail "`rake testml` requires 'source_testml_dir' key in '#{testml_conf}'"
    target = conf['local_testml_dir'] \
      or fail "`rake testml` requires 'local_testml_dir' key in '#{testml_conf}'"
    tests = conf['test_file_dir'] || '.'
    source = File.expand_path source, base
    target = File.expand_path target, base
    tests = File.expand_path tests, base
    fail "'#{source}' directory does not exist" \
      unless Dir.exists? source
    mkdir target unless Dir.exists? target
    mkdir tests unless Dir.exists? tests
    template = conf['test_file_template']
    skip = conf['exclude_testml_files'] || []
    files = conf['include_testml_files'] ||
      Dir.new(source).grep(/\.tml$/)
    files.sort.each do |file|
      next if skip.include? file
      s = "#{source}/#{file}"
      t = "#{target}/#{file}"
      if ! uptodate?(t, [s])
        puts "Copying #{rel(s)} to #{rel(t)}"
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
end
