require 'pegex/grammar'
require 'testml/compiler/pegex'

class TestML::Compiler::Pegex::Grammar < Pegex::Grammar
  File = '../testml-pgx/testml.pgx'

  def make_tree
    fail "TODO"
    # Plop TestML grammar ast in Ruby, here…
  end
end
