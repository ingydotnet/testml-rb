require 'pegex/tree'
require 'testml/compiler/pegex'

class TestML::Compiler::Pegex::AST < Pegex::Tree
  require 'testml/runtime'

  attr_accessor :points
  attr_accessor :function

  def initialize
    @points = []
    @function = TestML::Function.new
  end

  def got_code_section(code)
    @function.statements = code
  end

  def got_assignment_statement(match)
    return TestML::Assignment.new(match[0], match[1])
  end

  def got_code_statement(list)
    expression, assertion = nil, nil
    points = @points
    @points = []
    list.each do |e|
      if e.kind_of? TestML::Assertion
        assertion = e
      else
        expression = e
      end
    end
    return TestML::Statement.new(
      expression,
      assertion,
      !points.empty? ? points : nil,
    )
  end

  def got_code_expression(list)
    calls = []
    calls.push(list.shift) if !list.empty?
    list = !list.empty? ? list.shift : []
    list.each do |e|
      call = e[1]   # XXX this is e[0] in perl
      calls.push(call)
    end
    return calls[0] if calls.size == 1
    return TestML::Expression.new(calls)
  end

  def got_string_object(string)
    return TestML::Str.new(string)
  end

  def got_double_quoted_string(string)
    string.gsub '\\n', "\n"
  end

  def got_number_object(number)
    return TestML::Num.new(number.to_i)
  end

  def got_point_object(point)
    point.sub!(/^\*/, '') or fail
    @points.push(point)
    return TestML::Point.new(point)
  end

  def got_assertion_call(call)
    name, expr = nil, nil
    %w( eq has ok ).each do |a|
      if expr = call["assertion_#{a}"]
        name = a.upcase
        expr =
          expr.fetch("assertion_operator_#{a}", [])[0] ||
          expr.fetch("assertion_function_#{a}", [])[0]
        break
      end
    end
    return TestML::Assertion.new(name, expr)
  end

  def got_assertion_function_ok(ok)
    return { 'assertion_function_ok' => [] }
  end

  def got_function_start(dummy)
    function = TestML::Function.new
    function.outer = @function
    @function = function
    return true
  end

  def got_function_object(object)
    function = @function
    @function = function.outer

    if object[0].kind_of? Array and object[0][0].kind_of? Array
      function.signature = object[0][0]
    end
    function.statements = object[-1]

    return function
  end

  def got_call_name(name)
    return TestML::Call.new(name)
  end

  def got_call_object(object)
    call = object[0]
    args = object[1] && object[1][-1]
    if args
      args = args.map do |arg|
        (arg.kind_of?(TestML::Expression) and arg.calls.size == 1 and
        (
           arg.calls[0].kind_of?(TestML::Point) ||
           arg.calls[0].kind_of?(TestML::Object)
        )) ? arg.calls[0] : arg
      end
      call.args = args
    end
    return call
  end

  def got_call_argument_list(list)
    return list
  end

  def got_call_indicator(dummy)
    return
  end

  def got_data_section(data)
    @function.data = data
  end

  def got_data_block(block)
    label = block[0][0][0]
    points = block[1].inject({}){|r, h| r.merge!(h)}
    return TestML::Block.new(label, points)
  end

  def got_block_point(point)
    return { point[0] => point[1] }
  end
end
