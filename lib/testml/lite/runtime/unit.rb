require 'test/unit'

# This is the Runtime class that support Ruby's Test::Unit test framework.
class TestML::Lite::Runtime::Unit < TestML::Lite::Runtime
  # As TestML::Lite objects are created, they get put into this class hash
  # variable keyed by the file name that instantiated them.
  @@Tests = Hash.new
  def self.Tests;@@Tests end

  def self.register test, testname
    if testname
      fail "There is already a test with the name '#{testname}" \
        if TestML::Lite::Runtime::Unit.Tests[testname]
      TestML::Lite::Runtime::Unit.Tests[testname] = test
    end

    # Generate a method that Test::Unit will discover and run. This method will
    # run the tests defined in this TestML::Lite object.
    TestML::Lite::TestCase.send(:define_method, testname) do
      test = TestML::Lite::Runtime::Unit.Tests[testname] \
        or fail "No test object for '#{testname}'"
      test.runtime.testcase = self
      test.run
    end
  end

  attr_accessor :testcase

  def EQ got, want
    @count += 1
    @testcase.assert_equal want, got, get_label
                # TODO Move this logic to testml/diff
                if got != want
                  if respond_to? 'on_fail'
                    on_fail
                  elsif want.match /\n/
                    File.open('/tmp/got', 'w') {|f| f.write got}
                    File.open('/tmp/want', 'w') {|f| f.write want}
                    puts `diff -u /tmp/want /tmp/got`
                  end
                end
  end

  def HAS got, want
    @count += 1
    @testcase.assert_match want, got, get_label
  end

  # TODO Support OK
  def OK got
    @count += 1
    fail 'TODO'
  end
end

# This is the class that Test::Unit will use to run actual tests.  Every time
# that a test file creates a TestML::Lite object, we inject a method called
# "test_#{test_file_name}" into this class, since we know that Test::Unit calls
# methods that begin with 'test'.
class TestML::Lite::TestCase < Test::Unit::TestCase
end
