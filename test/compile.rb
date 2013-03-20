require 'test/unit'

require 'testml/runtime'
require 'testml/compiler/lite'
require 'testml/compiler/pegex'
require 'yaml'

class TestCompile < Test::Unit::TestCase
  def test_compile
    compile('test/testml/arguments.tml', TestML::Compiler::Pegex)
    compile('test/testml/basic.tml', TestML::Compiler::Pegex)
    compile('test/testml/dataless.tml', TestML::Compiler::Pegex)
    compile('test/testml/exceptions.tml', TestML::Compiler::Pegex)
    compile('test/testml/external.tml', TestML::Compiler::Pegex)
    compile('test/testml/function.tml', TestML::Compiler::Pegex)
    compile('test/testml/label.tml', TestML::Compiler::Pegex)
    compile('test/testml/markers.tml', TestML::Compiler::Pegex)
    compile('test/testml/semicolons.tml', TestML::Compiler::Pegex)
    compile('test/testml/truth.tml', TestML::Compiler::Pegex)
    compile('test/testml/types.tml', TestML::Compiler::Pegex)

    compile('test/testml/arguments.tml', TestML::Compiler::Lite)
    compile('test/testml/basic.tml', TestML::Compiler::Lite)
    compile('test/testml/exceptions.tml', TestML::Compiler::Lite)
    compile('test/testml/semicolons.tml', TestML::Compiler::Lite)
  end

  def compile(file, compiler=TestML::Compiler)
    filename = file.sub(/(.*)\//, '')
    runtime = TestML::Runtime.new({base: $1})
    testml = runtime.read_testml_file(filename)
    ast1 = compiler.new.compile(testml)
    got = YAML.dump(ast1)

    yaml = File.read("test/ast/#{filename}") \
      .gsub(/!!perl\/hash:/, '!ruby/object:') \
      .gsub(/(explicit_call: )(\d)/) do |m|
        "#{$1}#{($2 == '1') ? 'true' : 'false'}"
      end
#       .gsub(/^(\s*):(\w+:)/, "$1$2")

    ast2 = YAML.load(yaml)
    want = YAML.dump(ast2)

    label = "#{file} - #{compiler.to_s}"
    if got == want
      assert_equal want, got, label
    else
      puts "Failed test: #{label}"
      if want.match /\n/
        File.open('/tmp/got', 'w') {|f| f.write got}
        File.open('/tmp/want', 'w') {|f| f.write want}
        puts `diff -u /tmp/want /tmp/got`
      end
    end
  end
end
