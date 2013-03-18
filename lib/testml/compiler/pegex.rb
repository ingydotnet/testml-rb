require 'pegex/parser'
require 'testml/compiler'
require 'testml/compiler/pegex/grammar'
require 'testml/compiler/pegex/ast'

class TestML::Compiler::Pegex < TestML::Compiler
  attr_accessor :parser

  def compile_code
    @parser = Pegex::Parser.new(
      TestML::Compiler::Pegex::Grammar,
      TestML::Compiler::Pegex::AST,
    )
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
      point_lines.sub!(/===/, block_marker)
    end

    point_marker = @directives['PointMarker']
    if point_marker
      point_marker.gsub! /([\$\%\^\*\+\?\|])/, '\\\1'
      tree['point_marker']['.rgx'] = %r!\A#{point_marker}!
      point_lines.sub!(/\\-\\-\\-/, point_marker)
    end
  end
end
