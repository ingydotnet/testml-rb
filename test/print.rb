require 'minitest/unit'
require 'minitest/autorun'

class MiniTest::Print < MiniTest::Unit::TestCase
  def test_output
    success = nil
    out, err = capture_subprocess_io do
      success = system 'ruby', '-Ilib', 'test/script/hello.rb'
    end
    fail "Run failed:\nstdout: #{out}\nstderr:#{err}\n" unless success
    assert out =~ /^Goodbye, World!\n/
  end
end
