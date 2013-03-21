require 'test/unit'
require 'testml/runtime'

# This is the class that Test::Unit will use to run actual tests.  Every time
# that a test file creates a TestML object, we inject a method called
# "test_#{test_file_name}" into this class, since we know that Test::Unit
# calls methods that begin with 'test'.
class TestML::TestCase < Test::Unit::TestCase
  attr_accessor :name
end

class TestML::Runtime::Unit < TestML::Runtime
  attr_accessor :testcase
  attr_accessor :planned

  def initialize(*args)
    @planned = false
    super(*args)
  end

  # As TestML objects are created, they get put into this class hash variable
  # keyed by the file name that instantiated them.
  @@Tests = Hash.new
  def self.Tests; @@Tests end

  TestFilePattern = 'test\\/((?:.*\\/)?[-\\w+]+)\\.rb'
  def self.register test
    filename = caller.map {|s| s.split(':').first} \
      .grep(/(^|\/)#{TestFilePattern}$/).first \
        or fail caller.join("\n")
    name = filename.clone
    test.base = filename.sub!(/(.*)\/.*/, '\1') ? filename : '.'
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
      # XXX This should probably not be a global variable.
      $testcase = self
      $testcase.name = testname
      test.run
    end
  end

  def run
    super
    check_plan
    plan_end
  end

  def run_assertion(*args)
    check_plan
    super(*args)
  end

  def check_plan
    if ! @planned
      title
      plan_begin
      @planned = true
    end
  end

  # XXX Need to disable by default and provide a simple way to turn on.
  def title
    if title = @function.getvar('Title') || $testcase.name
      title = title.value if title.kind_of? TestML::Str
      title = "\n=== #{title} ===\n"
      # TODO Figure out when to print titles.
      # STDERR.write title
    end
  end

  def skip_test(reason)
    fail "TODO"
  end

  def plan_begin;end

  def plan_end
    if plan = @function.getvar('Plan')
      count = @function.getvar('TestNumber').value
      $testcase.assert_equal plan.value.to_i, count, 'Tests Planned'
    end
  end

  def assert_EQ(got, want)
    got = got.value
    want = want.value
    # TODO Move this logic to testml/diff
    if got != want
      if want.match /\n/
        File.open('/tmp/got', 'w') {|f| f.write got}
        File.open('/tmp/want', 'w') {|f| f.write want}
        STDERR.write(`diff -u /tmp/want /tmp/got`)
      end
    end
    $testcase.assert_equal want, got, get_label
  end

  def assert_HAS(got, has)
    got = got.value
    has = has.value
    assertion = got.index(has)
    if !assertion
      msg = <<"..."
Failed TestML HAS (~~) assertion. This text:
'#{got}'
does not contain this string:
'#{has}'
...
      STDERR.write(msg)
    end
    $testcase.assert(assertion, get_label)
  end

  def assert_OK(got)
    $testcase.assert(got.bool.value, get_label)
  end

end
