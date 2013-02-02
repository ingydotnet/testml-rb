##
# The Runtime object is responsible for running the TestML code and applying it
# to the Ruby test framework (default is Test::Unit).

class TestML::Lite::Runtime
  attr_accessor :test
  attr_accessor :block
  attr_accessor :error

  # TODO runtime base class should not know about Test::Unit @testcase

  def initialize test
    @test = test
  end

  # These methods should be subclassed per test framework as appropriate
  def EQ got, want;end
  def HAS got, want;end
  def OK got;end
  def plan count;end
  def skip;end

  # Run the TestML test!
  def run
    if @test.skip
      @testcase.skip @test.skip
      return
    end
    @count = 0
    @test.function.statements.each {|s| execute(s)}
    if plan = @test.plan
      @testcase.assert_equal plan, @count, "Plan #{plan} tests"
    end
  end

  # Execute an expression/function.
  def execute expr, callback=nil
    get_blocks(expr, test.function.data).each do |block|
      @error = nil
      evaluate expr, block
      raise @error if @error
    end
  end

  # Evaluate a TestML method call.
  def evaluate expr, block
    @block = block
    expr = ['', expr] if expr.kind_of? String
    func = expr.first
    args = expr[1..expr.length-1].collect do |ex|
      if ex.kind_of? Array
        evaluate ex, block
      elsif ex =~ /\A\*(\w+)\z/
        block[:points][$1]
      else
        ex
      end
    end
    return if @error and func != 'Catch'
    # TODO func should not be ''
    return args.first if func.empty?
    begin
      return lookup_method(func).call(*args)
    rescue => e
      @error = e
    end
  end

  def lookup_method func
    return self.method(func) if %w(EQ HAS OK).include? func
    begin return @test.bridge.method(func)
    rescue NameError; end
    begin return @test.library.method(func)
    rescue NameError; end
  end

  # Get the data blocks that apply to an expression.
  def get_blocks expr, data
    want = expr.flatten.grep(/^\*/).collect{|p| p.gsub /^\*/, ''}
    return [nil] if want.empty?
    only = data.select{|block| block['ONLY']}
    data = only unless only.empty?
    blocks = []
    data.each do |block|
      next if block['SKIP']
      ok = true
      want.each do |w|
        unless block[:points][w]
          ok = false
          break
        end
      end
      if ok
        blocks << block
        break if block['LAST']
      end
    end
    return blocks
  end

  def get_label
    return(@block ?
      @block.kind_of?(String) ? @block : @block[:label] :
      "Test ##{@count}"
    )
  end
end
