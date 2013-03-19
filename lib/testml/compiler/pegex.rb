require 'pegex/parser'
require 'testml/compiler'

class TestML::Compiler::Pegex < TestML::Compiler
  attr_accessor :parser

  def compile_code
    @parser = ::Pegex::Parser.new do |p|
      p.grammar = TestML::Compiler::Pegex::Grammar.new
      p.receiver = TestML::Compiler::Pegex::AST.new
    end
    fixup_grammar
    parser.parse(@code, 'code_section') \
      or fail "Parse TestML code section failed"
  end

  def compile_data
    if !@data.empty?
      parser.parse(@data, 'data_section') \
        or fail "Parse TestML data section failed"
    end
    @function = parser.receiver.function
  end

  def fixup_grammar
    tree = @parser.grammar.tree
    point_lines = tree['point_lines']['.rgx']

    block_marker = @directives['BlockMarker']
    if block_marker
      block_marker.gsub! /([\$\%\^\*\+\?\|])/, '\\\1'
      tree['block_marker']['.rgx'] = %r!\A#{block_marker}!
      tree['point_lines']['.rgx'] = Regexp.new(
        point_lines.to_s.sub!(/===/, block_marker)
      )
    end

    point_marker = @directives['PointMarker']
    if point_marker
      point_marker.gsub! /([\$\%\^\*\+\?\|])/, '\\\1'
      tree['point_marker']['.rgx'] = %r!\A#{point_marker}!
      tree['point_lines']['.rgx'] = Regexp.new(
        point_lines.to_s.sub!(/\\-\\-\\-/, point_marker)
      )
    end
  end
end

require 'testml/compiler/pegex/grammar'
require 'testml/compiler/pegex/ast'
