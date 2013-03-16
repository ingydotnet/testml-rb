##
# This is the Lite version of the TestML compiler. It can parse simple
# statements and assertions and also parse the TestML data format.

class TestML::Compiler::Lite < TestML::Compiler
  require 'testml/runtime'

  attr_accessor :input
  attr_accessor :points
  attr_accessor :tokens
  attr_accessor :function

  WS = %r!\s+!
  ANY = %r!.!
  STAR = %r!\*!
  NUM = %r!-?[0-9]+!
  WORD = %r!\w+!
  HASH = %r!#!
  EQ = %r!=!
  TILDE = %r!~!
  LP = %r!\(!
  RP = %r!\)!
  DOT = %r!\.!
  COMMA = %r!,!
  SEMI = %r!;!
  SSTR = %r!'(?:[^']*)'!
  DSTR = %r!"(?:[^"]*)"!
  ENDING = %r!(?:#{RP}|#{COMMA}|#{SEMI})!

  POINT = %r!#{STAR}#{WORD}!
  QSTR = %r!(?:#{SSTR}|#{DSTR})!
  COMP = %r!(?:#{EQ}#{EQ}|#{TILDE}#{TILDE})!
  OPER = %r!(?:#{COMP}|#{EQ})!
  PUNCT = %r!(?:#{LP}|#{RP}|#{DOT}|#{COMMA}|#{SEMI})!

  TOKENS = %r!(?:#{POINT}|#{NUM}|#{WORD}|#{QSTR}|#{PUNCT}|#{OPER})!

  def compile_code
    @function = TestML::Function.new
    while not @code.empty? do
      @code.sub! /^(.*)(\r\n|\n|)/, ''
      @line = $1
      tokenize
      next if done
      parse_assignment ||
      parse_assertion ||
      fail_()
    end
  end

  def tokenize
    @tokens = []
    while not @line.empty? do
      next if @line.sub!(/^#{WS}/, '')
      next if @line.sub!(/^#{HASH}#{ANY}*/, '')
      if @line.sub!(/^(#{TOKENS})/, '')
        @tokens.push $1
      else
        fail_("Failed to get token here: '#{@line}'")
      end
    end
  end

  def parse_assignment
    return unless peek(2) == '='
    var, op = pop(2)
    expr = parse_expression
    pop if !done and peek == ''
    fail unless done
    @function.statements.push TestML::Assignment.new(var, expr)
    return true
  end

  def parse_assertion
    return unless @tokens.grep /^#{COMP}$/
    @points = []
    left = parse_expression
    token = pop
    op =
      token == '==' ? 'EQ' :
      token == '~~' ? 'HAS' :
      fail_
    right = parse_expression
    pop if !done and peek == ''
    fail_ unless done

    @function.statements.push TestML::Statement.new(
      left,
      TestML::Assertion.new(
        op,
        right,
      ),
      points.empty? ? nil : points
    )
    return true
  end

  def parse_expression
    calls = []
    while !done and peek !~ /^(#{ENDING}|#{COMP})$/ do
      token = pop
      if token =~ /^#{NUM}$/
        calls.push TestML::Num.new(token)
      elsif token =~ /^#{QSTR}$/
        str = token[1, -2]
        calls.push TestML::Str.new(str)
      elsif token =~ /^#{WORD}$/
        call = TestML::Call.new(token)
        if !done and peek == '('
          call.args = parse_args
        end
        calls.push call
      elsif token =~ /^#{POINT}$/
        token =~ /(#{WORD})/ or fail
        points.push $1
        calls.push TestML::Point.new($1)
      else
        fail_("Unknown token '#{token}'")
      end
      if !done and peek == '.'
        pop
      end
    end

    return calls.size == 1 ? calls[0] : TestML::Expression.new(calls)
  end

  def parse_args
    pop == '(' or fail
    args = []
    while peek != ')' do
      args.push parse_expression
      pop if peek == ','
    end
    pop
    return args
  end

  def compile_data
    input = @data
    input.gsub! /^#.*\n/, "\n"
    input.gsub! /^\\/, ''
    blocks = input.split(/(^===.*?(?=^===|\z))/m).select{|el|!el.empty?}
    blocks.each{|block| block.sub! /\n+\z/, "\n"}

    data = []
    blocks.each do |string_block|
      block = TestML::Block.new
      string_block.gsub! /\A===\ +(.*?)\ *\n/, '' or
        fail "No block label! #{string_block}"
      block.label = $1
      while !string_block.empty? do
        next if string_block.sub! /\A\n+/, ''
        key, value = nil, nil
        if string_block.gsub!(/\A---\ +(\w+):\ +(.*)\n/, '') or
            string_block.gsub!(/\A---\ +(\w+)\n(.*?)(?=^---|\z)/m, '')
          key, value = $1, $2
        else
          fail "Failed to parse TestML string:\n#{string_block}"
        end
        block.points ||= {}
        block.points[key] = $value

        if key =~ /^(ONLY|SKIP|LAST)$/
          block[key] = true
        end
      end
      data.push block
    end
    @function.data = data unless data.empty?
  end

  def done
    tokens.empty?
  end

  def peek(index=1)
    fail if index > @tokens.size
    @tokens[index - 1]
  end

  def pop(count=1)
    fail if count > @tokens.size
    array = @tokens.slice! 0..(count-1)
    count > 1 ? array : array[0]
  end

  def fail_(message)
    text = "Failed to compile TestML document.\n"
    text << "Reason: #{message}\n" if message
    text << "\nCode section of failure:\n#{@line}\n#{@code}\n"
    fail text
  end

end
