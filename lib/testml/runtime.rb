class TestML;end

class TestML::Runtime
  attr_accessor :testml
  attr_accessor :bridge
  attr_accessor :library
  attr_accessor :compiler
  attr_accessor :base
  attr_accessor :skip

  attr_accessor :function
  attr_accessor :error
  attr_accessor :global

  def initialize(attributes={})
    attributes.each { |k,v| self.send "#{k}=", v }
    $TestMLRuntimeSingleton = self
#     @base ||= 'test/lite'           # XXX remove this!
    @base ||= 'test'           # XXX remove this!
  end

  def run
    compile_testml
    initialize_runtime

    run_function(
      @function,
      [],
    )
  end

  def run_function(function, args)
    signature = apply_signature(function, args)

    parent = @function
    @function = function

    function.statements.each do |statement|
      if statement.kind_of? TestML::Assignment
        run_assignment(statement)
      else
        run_statement(statement)
      end
    end

    @function = parent
    return TestML::None.new
  end

  def apply_signature(function, args)
    signature = function.signature

    fail "Function received #{args.size} args but expected #{signature.size}" \
      if ! signature.empty? and @args.size != signature.size

    @function.setvar('Self', function)
    signature.each_with_index do |sig_elem, i|
      arg = args[i]
      arg = run_expression(arg) \
        if arg.kind_of TestML::Expression
      function.setvar(sig_elem, arg)
    end
  end

  def run_statement(statement)
    blocks = select_blocks(statement.points || [])
    blocks.each do |block|
      @function.setvar('Block', block) if block != 1

      result = run_expression(statement.expr)
      if assertion = statement.assert
        run_assertion(result, assertion)
      end
    end
  end

  def run_assignment(assignment)
    @function.setvar(
      assignment.name,
      run_expression(assignment.expr)
    )
  end

  def run_assertion left, assert
    method_ = method(('assert_' + assert.name).to_sym)

    @function.getvar('TestNumber').value += 1

    if assert.expr
      method_.call(left, run_expression(assert.expr))
    else
      method_.call(left)
    end
  end

  def run_expression(expr)
    context = nil
    @error = nil
    if expr.kind_of? TestML::Expression
      calls = expr.calls.clone
      fail if calls.size <= 1
      context = run_call(calls.shift)
      calls.each do |call|
        if @error
          next unless
            call.kind_of?(TestML::Call) and
            call.name == 'Catch'
        end
        context = run_call(call, context)
      end
    else
      context = run_call(expr)
    end
    if @error
      fail @error
    end
    return context
  end

  def run_call call, context=nil
    if call.kind_of? TestML::Object
      return call
    end
    if call.kind_of? TestML::Function
      return call
    end
    if call.kind_of? TestML::Point
      return get_point(call.name)
    end
    if call.kind_of? TestML::Call
      name = call.name
      callable =
          @function.getvar(name) ||
          get_point(name) ||
          lookup_callable(name) ||
          fail("Can't locate '#{name}' callable")
      if callable.kind_of? TestML::Object
        return callable
      end
      return callable unless call.args or !context.nil?
      call.args ||= []
      args = call.args.map{|arg| run_expression(arg)}
      args.unshift context if !context.nil?
      if callable.kind_of? TestML::Native
        return run_native(callable, args)
      end
      if callable.kind_of? TestML::Function
        return run_function(callable, args)
      end
      fail
    end
    fail
  end

  def lookup_callable(name)
    @function.getvar('Library').value.each do |library|
      if library.respond_to?(name)
        function = lambda do |*args|
          library.method(name).call(*args)
        end
        callable = TestML::Native.new(function)
        @function.setvar(name, callable)
        return callable
      end
    end
    return nil
  end

  def get_point(name)
    value = @function.getvar('Block').points[name] or return
    if value.sub!(/\n+\z/, "\n") and value == "\n"
      value = ''
    end
    return TestML::Str.new(value)
  end

  def run_native native, args
    begin
      value = native.value.call(*args)
    rescue
      @error = $!.message
      return TestML::None.new
    end
    if value.kind_of? TestML::Object
      return value
    else
      return object_from_native(value)
    end
  end

  def select_blocks(wanted)
    return [1] if wanted.empty?
    selected = []
    @function.data.each do |block|
      points = block.points
      next if points.key?('SKIP')
      next unless wanted.all?{|point| points.key?(point)}
      if points.key?('ONLY')
        selected = [block]
        last
      end
      selected << block
      last if points.key?('LAST')
    end
    return selected
  end

  def object_from_native(value)
    return
        value.is_nil? ? TestML::None.new :
        value.kind_of?(Array) ? TestML::List.new(value) :
        value.match(/^-?\d+$/) ? TestML::Num.new(value.to_i) :
        value == TestML::Constant::True ? value :
        value == TestML::Constant::False ? value :
        value == TestML::Constant::None ? value :
        TestML::Str.new(value)
  end

  def compile_testml
    fail "'testml' document required but not found" \
      unless @testml
    if @testml !~ /\n/
      @testml =~ /(.*)\/(.*)/ or fail
      testml = $2
      @base = @base + '/' + $1
      @testml = read_testml_file testml
    end
    @function = @compiler.new.compile(@testml)
  end

  def initialize_runtime
    @global = @function.outer

    @global.setvar('Block', TestML::Block.new)
    @global.setvar('Label', TestML::Str.new('$BlockLabel'))
    @global.setvar('True', TestML::Constant::True)
    @global.setvar('False', TestML::Constant::False)
    @global.setvar('None', TestML::Constant::None)
    @global.setvar('TestNumber', TestML::Num.new(0))
    @global.setvar('Library', TestML::List.new)

    library = @function.getvar('Library')
    [@bridge, @library].each do |lib|
      if lib.kind_of? Array
        lib.each {|l| library.push(l.new)}
      else
        library.push(lib.new)
      end
    end
  end

  # XXX need aocole's help to port this
  def get_label
    label = @function.getvar('Label').value
#     label.sub /\$(\w+)/ do |m|
#       var = $1
#       block = @function.getvar('Block')
#       return block.label if var == 'BlockLabel'
#       if v = block.points[var]
#           v.sub!(/\n.*/m, '')
#           v.strip!
#           return v
#       end
#       if v = function.getvar(var)
#           return v.value
#       end
#     end
  end

  def read_testml_file file
    path = @base + '/' + file
    File.read(path)
  end
end

#-----------------------------------------------------------------------------
class TestML::Function
  attr_accessor :type
  attr_accessor :signature
  attr_accessor :statements
  attr_accessor :namespace
  attr_accessor :data

  @@outer = {}
  def outer
    @@outer[self.object_id]
  end
  def outer=(value)
    @@outer[self.object_id] = value
  end

  def initialize
    @type = 'Func'
    @signature = []
    @namespace = {}
    @statements = []
    @data = []
  end

  def getvar name
    s = self
    while s
      if s.namespace.key? name
        return s.namespace[name]
      end
      s = s.outer
    end
    nil
  end

  def setvar name, value
    @namespace[name] = value
  end

  def forgetvar name
    @namespace.delete name
  end
end

#-----------------------------------------------------------------------------
class TestML::Assignment
  attr_accessor :name
  attr_accessor :expr

  def initialize(name, expr)
    @name = name
    @expr = expr
  end
end

#-----------------------------------------------------------------------------
class TestML::Statement
  attr_accessor :expr
  attr_accessor :assert
  attr_accessor :points

  def initialize(expr, assert=nil, points=nil)
    @expr = expr
    @assert = assert if assert
    @points = points if points
  end
end

#-----------------------------------------------------------------------------
class TestML::Expression
  attr_accessor :calls

  def initialize(calls=[])
    @calls = calls
  end
end

#-----------------------------------------------------------------------------
class TestML::Assertion
  attr_accessor :name
  attr_accessor :expr

  def initialize(name, expr=nil)
    @name = name
    @expr = expr
  end
end

#-----------------------------------------------------------------------------
class TestML::Call
  attr_accessor :name
  attr_accessor :args

  def initialize(name, args=[])
    @name = name
    @args = args if !args.empty?
  end
end

#-----------------------------------------------------------------------------
class TestML::Block
  attr_accessor :label
  attr_accessor :points

  def initialize
    @label = ''
    @points = {}
  end
end

#-----------------------------------------------------------------------------
class TestML::Point
  attr_accessor :name

  def initialize(name)
    @name = name
  end
end

#-----------------------------------------------------------------------------
class TestML::Object
  attr_accessor :value

  def initialize(value)
    @value = value
  end

  def type
    type = self.class.to_s
    type.sub! /^Type::/, '' or fail "Can't find type of '#{type}'"
    return type
  end

  def str
    fail "Cast from #{@value.class} to Str is not supported"
  end
  def num
    fail "Cast from #{@value.class} to Num is not supported"
  end
  def bool
    fail "Cast from #{@value.class} to Bool is not supported"
  end
  def list
    fail "Cast from #{@value.class} to List is not supported"
  end
  def none
    TestML::Constant::None
  end
end

#-----------------------------------------------------------------------------
class TestML::Str < TestML::Object
  def str
    self
  end
  def num
    TestML::Num.new(@value =~ /^-?\d+(?:\.\d+)$/ ? $1.to_i : 0)
  end
  def bool
    !@value.empty? ? TestML::Constant::True : TestML::Constant::False
  end
  def list
    TestML::List.new(@value.split //)
  end
end

#-----------------------------------------------------------------------------
class TestML::Num < TestML::Object
  def str
    TestML::Str.new(@value.to_s)
  end
  def num
    self
  end
  def bool
    @value != 0 ? TestML::Constant::True : TestML::Constant::False
  end
  def list
    list = []
    [1..(@value-1)].each { |i| list[i - 1] = nil }
  end
end

#-----------------------------------------------------------------------------
class TestML::Bool < TestML::Object
  def str
    TestML::Str.new(@value ? "1" : "")
  end
  def num
    TestML::Num.new(@value ? 1 : 0)
  end
  def bool
    self
  end
end

#-----------------------------------------------------------------------------
class TestML::List < TestML::Object
  def initialize(value=[])
    super(value)
  end
  def push elem
    @value.push elem
  end
end

#-----------------------------------------------------------------------------
class TestML::None < TestML::Object
  def initialize
    super(nil)
  end
  def str
    TestML::Str.new('')
  end
  def num
    TestML::Num.new(0)
  end
  def bool
    TestML::Constant::False
  end
  def list
    TestML::List.new []
  end
end

#-----------------------------------------------------------------------------
class TestML::Error < TestML::Object
end

#-----------------------------------------------------------------------------
class TestML::Native 
  attr_accessor :value
  def initialize value
    @value = value
  end
end

#-----------------------------------------------------------------------------
module TestML::Constant
  True = TestML::Bool.new(value: 1)
  False = TestML::Bool.new(value: 0)
  None = TestML::None.new
end
