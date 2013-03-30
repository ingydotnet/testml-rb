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

  def run(unittest_testcase)
    @testcase = unittest_testcase
    @planned = false
    super()
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
    if title = @function.getvar('Title')
      title = title.value
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
      testcase.assert_equal plan.value.to_i, count, 'Tests Planned'
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
    testcase.assert_equal want, got, get_label
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
    testcase.assert(assertion, get_label)
  end

  def assert_OK(got)
    testcase.assert(got.bool.value, get_label)
  end

end
