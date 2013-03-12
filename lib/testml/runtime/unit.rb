require 'test/unit'
require 'testml/runtime'

# This is the class that Test::Unit will use to run actual tests.  Every time
# that a test file creates a TestML object, we inject a method called
# "test_#{test_file_name}" into this class, since we know that Test::Unit
# calls methods that begin with 'test'.
class TestML::TestCase < Test::Unit::TestCase
end

# This is the Runtime class that support Ruby's Test::Unit test framework.
class TestML::Runtime::Unit < TestML::Runtime
  attr_accessor :testcase

  # As TestML objects are created, they get put into this class hash variable
  # keyed by the file name that instantiated them.
  @@Tests = Hash.new
  def self.Tests
    @@Tests
  end

  TestFilePattern = 'test\\/((?:.*\\/)?[-\\w+]+)\\.rb'
  def self.register test
    name = caller.map {|s| s.split(':').first} \
      .grep(/(^|\/)#{TestFilePattern}$/).first \
      or fail caller.join("\n")
    name.gsub!(/^(?:.*\/)?#{TestFilePattern}$/, '\1') \
      .gsub!(/[^\w]+/, '_')
    testname =  "test_#{name}"
    fail "There is already a test with the name '#{testname}" \
      if TestML::Runtime::Unit.Tests[testname]
    TestML::Runtime::Unit.Tests[testname] = test

    # Generate a method that Test::Unit will discover and run. This method will
    # run the tests defined in this TestML object.
    TestML::TestCase.send(:define_method, testname) do
      test = TestML::Runtime::Unit.Tests[testname] \
        or fail "No test object for '#{testname}'"
      # $TestMLRuntimeSingleton.testcase = self
      $testcase = self
      test.run
    end
  end

  def run
    super
  end

  def assert_EQ got, want
    got = got.value
    want = want.value
    # @testcase.assert_equal want, got, get_label
    $testcase.assert_equal want, got, get_label
    # TODO Move this logic to testml/diff
    if got != want
      if respond_to? 'on_fail'
        on_fail
      elsif want.value.match /\n/
        File.open('/tmp/got', 'w') {|f| f.write got}
        File.open('/tmp/want', 'w') {|f| f.write want}
        puts `diff -u /tmp/want /tmp/got`
      end
    end
  end

  def assert_HAS got, want
    # @testcase.assert_match want.value, got.value, get_label
    $testcase.assert_match want.value, got.value, get_label
  end

  # TODO Support OK
  def assert_OK got
    fail 'TODO'
  end

end
