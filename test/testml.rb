require 'test/unit'
require 'testml'
require 'testml/compiler/pegex'
require 'testml/compiler/lite'
$:.unshift "#{Dir.getwd}/test"
require 'testml_bridge'

class TestMLTestCase < Test::Unit::TestCase
  def run_testml_file(file, compiler=TestML::Compiler::Pegex)
    TestML.new(
      testml: file,
      bridge: TestMLBridge,
      compiler: compiler,
    ).run(self)
  end

  (Dir.glob('test/testml/*.tml')
    .select { |f| f !~ /external\d/ }
    .collect {|f| f.sub(/^test\//, '')}
  ).each do |file|
    method_name = 'test_' + file.gsub(/\W/, '_').sub(/_tml$/, '')
    define_method(method_name.to_sym) do
      run_testml_file(file)
    end
  end

  %w(
    testml/arguments.tml
    testml/basic.tml
    testml/exceptions.tml
    testml/semicolons.tml
  ).each do |file|
    method_name = 'test_lite_' + file.gsub(/\W/, '_').sub(/_tml$/, '')
    define_method(method_name.to_sym) do
      run_testml_file(file, TestML::Compiler::Lite)
    end
  end
end
