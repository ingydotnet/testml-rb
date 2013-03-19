require 'pegex/grammar'
require 'testml/compiler/pegex'

class TestML::Compiler::Pegex::Grammar < Pegex::Grammar
  File = '../testml-pgx/testml.pgx'

  def make_tree
    {"+toprule"=>"testml_document",
    "assertion_call"=>
      {".any"=>
        [{"-wrap"=>1, ".ref"=>"assertion_eq"},
        {"-wrap"=>1, ".ref"=>"assertion_ok"},
        {"-wrap"=>1, ".ref"=>"assertion_has"}]},
    "assertion_call_test"=>
      {".rgx"=>
        /\A(?:\.(?:[\ \t]|\r?\n|\#.*\r?\n)*|(?:[\ \t]|\r?\n|\#.*\r?\n)*\.)(?:EQ|OK|HAS)/},
    "assertion_eq"=>
      {".any"=>
        [{"-wrap"=>1, ".ref"=>"assertion_operator_eq"},
        {"-wrap"=>1, ".ref"=>"assertion_function_eq"}]},
    "assertion_function_eq"=>
      {".all"=>
        [{".rgx"=>
          /\A(?:\.(?:[\ \t]|\r?\n|\#.*\r?\n)*|(?:[\ \t]|\r?\n|\#.*\r?\n)*\.)EQ\(/},
        {".ref"=>"code_expression"},
        {".rgx"=>/\A\)/}]},
    "assertion_function_has"=>
      {".all"=>
        [{".rgx"=>
          /\A(?:\.(?:[\ \t]|\r?\n|\#.*\r?\n)*|(?:[\ \t]|\r?\n|\#.*\r?\n)*\.)HAS\(/},
        {".ref"=>"code_expression"},
        {".rgx"=>/\A\)/}]},
    "assertion_function_ok"=>
      {".rgx"=>
        /\A(?:\.(?:[\ \t]|\r?\n|\#.*\r?\n)*|(?:[\ \t]|\r?\n|\#.*\r?\n)*\.)(OK)(?:\((?:[\ \t]|\r?\n|\#.*\r?\n)*\))?/},
    "assertion_has"=>
      {".any"=>
        [{"-wrap"=>1, ".ref"=>"assertion_operator_has"},
        {"-wrap"=>1, ".ref"=>"assertion_function_has"}]},
    "assertion_ok"=>{".ref"=>"assertion_function_ok"},
    "assertion_operator_eq"=>
      {".all"=>
        [{".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)+==(?:[\ \t]|\r?\n|\#.*\r?\n)+/},
        {".ref"=>"code_expression"}]},
    "assertion_operator_has"=>
      {".all"=>
        [{".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)+\~\~(?:[\ \t]|\r?\n|\#.*\r?\n)+/},
        {".ref"=>"code_expression"}]},
    "assignment_statement"=>
      {".all"=>
        [{".ref"=>"variable_name"},
        {".rgx"=>/\A\s+=\s+/},
        {".ref"=>"code_expression"},
        {".ref"=>"ending"}]},
    "blank_line"=>{".rgx"=>/\A[\ \t]*\r?\n/},
    "block_header"=>
      {".all"=>
        [{".ref"=>"block_marker"},
        {"+max"=>1, ".all"=>[{".rgx"=>/\A[\ \t]+/}, {".ref"=>"block_label"}]},
        {".rgx"=>/\A[\ \t]*\r?\n/}]},
    "block_label"=>{".ref"=>"unquoted_string"},
    "block_marker"=>{".rgx"=>/\A===/},
    "block_point"=>{".any"=>[{".ref"=>"lines_point"}, {".ref"=>"phrase_point"}]},
    "call_argument"=>{".ref"=>"code_expression"},
    "call_argument_list"=>
      {".all"=>
        [{".rgx"=>/\A\((?:[\ \t]|\r?\n|\#.*\r?\n)*/},
        {"+min"=>0,
          ".ref"=>"call_argument",
          ".sep"=>
          {".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)*,(?:[\ \t]|\r?\n|\#.*\r?\n)*/}},
        {".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)*\)/}]},
    "call_call"=>
      {".all"=>
        [{"+asr"=>-1, ".ref"=>"assertion_call_test"},
        {".ref"=>"call_indicator"},
        {".ref"=>"code_object"}]},
    "call_indicator"=>
      {".rgx"=>
        /\A(?:\.(?:[\ \t]|\r?\n|\#.*\r?\n)*|(?:[\ \t]|\r?\n|\#.*\r?\n)*\.)/},
    "call_name"=>{".any"=>[{".ref"=>"user_call"}, {".ref"=>"core_call"}]},
    "call_object"=>
      {".all"=>[{".ref"=>"call_name"}, {"+max"=>1, ".ref"=>"call_argument_list"}]},
    "code_expression"=>
      {".all"=>[{".ref"=>"code_object"}, {"+min"=>0, ".ref"=>"call_call"}]},
    "code_object"=>
      {".any"=>
        [{".ref"=>"function_object"},
        {".ref"=>"point_object"},
        {".ref"=>"string_object"},
        {".ref"=>"number_object"},
        {".ref"=>"call_object"}]},
    "code_section"=>
      {"+min"=>0,
      ".any"=>
        [{".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)+/},
        {".ref"=>"assignment_statement"},
        {".ref"=>"code_statement"}]},
    "code_statement"=>
      {".all"=>
        [{".ref"=>"code_expression"},
        {"+max"=>1, ".ref"=>"assertion_call"},
        {".ref"=>"ending"}]},
    "comment"=>{".rgx"=>/\A\#.*\r?\n/},
    "core_call"=>{".rgx"=>/\A([A-Z]\w*)/},
    "data_block"=>
      {".all"=>
        [{".ref"=>"block_header"},
        {"+min"=>0,
          "-skip"=>1,
          ".any"=>[{".ref"=>"blank_line"}, {".ref"=>"comment"}]},
        {"+min"=>0, ".ref"=>"block_point"}]},
    "data_section"=>{"+min"=>0, ".ref"=>"data_block"},
    "double_quoted_string"=>{".rgx"=>/\A(?:"((?:[^\n\\"]|\\"|\\\\|\\[0nt])*?)")/},
    "ending"=>{".rgx"=>/\A(?:;|\r?\n)/},
    "function_object"=>
      {".all"=>
        [{"+max"=>1, ".ref"=>"function_signature"},
        {".ref"=>"function_start"},
        {"+min"=>0,
          ".any"=>
          [{".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)+/},
            {".ref"=>"assignment_statement"},
            {".ref"=>"code_statement"}]},
        {".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)*\}/}]},
    "function_signature"=>
      {".all"=>
        [{".rgx"=>/\A\((?:[\ \t]|\r?\n|\#.*\r?\n)*/},
        {"+max"=>1, ".ref"=>"function_variables"},
        {".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)*\)/}]},
    "function_start"=>
      {".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)*(\{)(?:[\ \t]|\r?\n|\#.*\r?\n)*/},
    "function_variable"=>{".rgx"=>/\A([a-zA-Z]\w*)/},
    "function_variables"=>
      {"+min"=>1,
      ".ref"=>"function_variable",
      ".sep"=>
        {".rgx"=>/\A(?:[\ \t]|\r?\n|\#.*\r?\n)*,(?:[\ \t]|\r?\n|\#.*\r?\n)*/}},
    "lines_point"=>
      {".all"=>
        [{".ref"=>"point_marker"},
        {".rgx"=>/\A[\ \t]+/},
        {".ref"=>"point_name"},
        {".rgx"=>/\A[\ \t]*\r?\n/},
        {".ref"=>"point_lines"}]},
    "number"=>{".rgx"=>/\A([0-9]+)/},
    "number_object"=>{".ref"=>"number"},
    "phrase_point"=>
      {".all"=>
        [{".ref"=>"point_marker"},
        {".rgx"=>/\A[\ \t]+/},
        {".ref"=>"point_name"},
        {".rgx"=>/\A:[\ \t]/},
        {".ref"=>"point_phrase"},
        {".rgx"=>/\A\r?\n/},
        {".rgx"=>/\A(?:\#.*\r?\n|[\ \t]*\r?\n)*/}]},
    "point_lines"=>{".rgx"=>/\A((?:(?!===|\-\-\-).*\r?\n)*)/},
    "point_marker"=>{".rgx"=>/\A\-\-\-/},
    "point_name"=>{".rgx"=>/\A([a-z]\w*|[A-Z]\w*)/},
    "point_object"=>{".rgx"=>/\A(\*[a-z]\w*)/},
    "point_phrase"=>{".ref"=>"unquoted_string"},
    "quoted_string"=>
      {".any"=>
        [{".ref"=>"single_quoted_string"}, {".ref"=>"double_quoted_string"}]},
    "single_quoted_string"=>{".rgx"=>/\A(?:'((?:[^\n\\']|\\'|\\\\)*?)')/},
    "string_object"=>{".ref"=>"quoted_string"},
    "testml_document"=>
      {".all"=>[{".ref"=>"code_section"}, {"+max"=>1, ".ref"=>"data_section"}]},
    "unquoted_string"=>{".rgx"=>/\A([^\ \t\n\#](?:[^\n\#]*[^\ \t\n\#])?)/},
    "user_call"=>{".rgx"=>/\A([a-z]\w*)/},
    "variable_name"=>{".rgx"=>/\A([a-zA-Z]\w*)/}}
  end
end
