##
# Usage:
#   rake testml
#   rake testml ./test/mytestmlconf.yaml
#
# This rake task syncs your local testml setup with a testml repository and
# creates any needed shim test files.

require 'testml/setup'

desc 'Update TestML files.'
task :testml do
  TestML::Setup.new.setup(ARGV[1])
end
