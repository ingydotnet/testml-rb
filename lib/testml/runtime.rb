class TestML;end

class TestML::Runtime
  attr_accessor :testml
  attr_accessor :bridge
  attr_accessor :library
  attr_accessor :compiler
  attr_accessor :base
  attr_accessor :skip

  attr_accessor :function

  def initialize(attributes={})
    attributes.each { |k,v| self.send "#{k}=", v }
    $TestMLRuntimeSingleton = self
    @base ||= 'test/lite' # XXX remove this!
  end

  def run
    compile_testml
    initialize_runtime

    run_function(
      @function,
      nil,
      [],
    )
  end

  def run_function(function, context, args)
    signature = function.signature ||= {}
    function.setvar('Self', context)

    function.statements.each do |statement|
      run_statement(statement)
    end

    return TestML::None.new
  end

  def apply_signature(function, args)
    fail "Function received #{args.size} args but expected #{signature.size}" \
      if ! @signature.enpty? and @args.size != @signature.size

    @function.setvar('Self', @function)
    @signature.each_with_index do |sig_elem, i|
      arg = args[i]
      arg = run_expression(arg) \
        if arg.kind_of TestML::Expression
      function.setvar(sig_elem, arg)
    end
  end

  def run_statement(statement)
    blocks = select_blocks(statement.points)
    blocks.each do |block|
      @function.setvar('Block', block) if block != 1
      context = run_expression(statement.expression)
      if assertion = statement.assertion
        run_assertion(context, assertion)
      end
    end
  end

  def run_assertion(left, assertion)
    method_ = method("assert_#{assertion.name}".to_sym)

    @function.getvar('TestNumber').value += 1

    results = [left]
    results.each do |result|
      if !assertion.expression.calls.empty?
        right = run_expression(assertion.expression)
        matches = [right]
        matches.each do |match|
          method_.call(result, match)
        end
      else
        method_.call(result)
      end
    end
  end

  def run_expression(expression)
    prev_expression = @function.expression
    @function.expression = expression

    context = nil

    expression.calls.each do |call|
      if expression.error
        next unless
            call.kind_of?(TestML::Call) &&
            call.name == 'Catch'
      end
      if call.kind_of? TestML::Point
        context = get_point(call.name)
        next
      end
      if call.kind_of? TestML::Object
        context = call
        next
      end
      if call.kind_of? TestML::Function
        context = call
        next
      end
      if call.kind_of? TestML::Call
        name = call.name
        callable = @function.getvar(name) ||
          lookup_callable(name) \
            or fail "Can't locate '#{name}' callable"
        args = call.args.map do |arg|
          arg.kind_of?(TestML::Point) ? get_point(arg.name) : arg
        end
        if callable.kind_of?(TestML::Native)
          context = run_native(callable, context, args)
        elsif callable.kind_of?(TestML::Object)
          context = callable
        elsif callable.kind_of?(TestML::Function)
          fail 'TODO'
        else
          fail 'TODO'
        end
      else
        fail "Unexpected call: #{call}"
      end
      if call.kind_of?(TestML::Object) || call.kind_of?(TestML::Function)
        context = call
        next
      end
    end
    if expression.error
      fail expression.error
    end
    function.expression = prev_expression
    return context
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
    value = @function.getvar('Block')[:points][name]
    if value.match /\n+\z/
      value.sub!(/\n+\z/, "\n")
      value = '' if value == "\n"
    end
    TestML::Str.new(value)
  end

  def run_native(native, context, args)
    function = native.value
    args = (args.map do |arg|
      arg.kind_of?(TestML::Expression) ? run_expression(arg) : arg
    end)
    args.unshift(context) if context
#     begin
      value = function.call(*args)
#     rescue Exception => e
#       XXX e
#       error @function.expression.error = e.message
#       return TestML::Error.new(error)
#     end
    if value.kind_of?(TestML::Object)
      return value
    else
      return object_from_native(value)
    end
  end

  def select_blocks(wanted)
    return [1] if wanted.nil? or wanted.empty?
    selected = []
    @function.data.each do |block|
      points = block[:points]
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
    if not @testml.match /\n/
      m = @testml.match(/(.*)\/(.*)/) or fail
      testml = m[2]
      @base = @base + '/' + m[1]
      @testml = read_testml_file testml
    end
    # require_class_library(@compiler)
    @function = @compiler.new.compile(@testml)
  end

  def initialize_runtime
    global = @function.outer

    # Set global variables.
    global.setvar('Block', TestML::Block.new)
    global.setvar('Label', TestML::Str.new('$BlockLabel'))
    global.setvar('True', TestML::Constant::True)
    global.setvar('False', TestML::Constant::False)
    global.setvar('None', TestML::Constant::None)
    global.setvar('TestNumber', TestML::Num.new(0))
    global.setvar('Library', TestML::List.new)

    [@bridge, @library].each do |lib|
      if lib.kind_of? Array
        lib.each {|l| add_library(l)}
      else
        add_library(lib)
      end
    end
  end

  def add_library library
    if (not library.respond_to? :new)
      fail
      #eval "require $library";
    end
    @function.getvar('Library').push(library.new);
  end

  def get_label
    return 'foo'
    label = @function.getvar('Label').value
    def label(var)
      block = @function.getvar('Block')
      return block.label if var == 'BlockLabel'
      if v = block.points[var]
          v.sub!(/\n.*/m, '')
          v.strip!
          return v
      end
      if v = function.getvar(var)
          return v.value
      end
    end
    # label.sub!(/\$(\w+)/g, label($self, $1)
    return label
  end

  def run_plan
    if !@planned
      title
      plan_begin
      @planned = true
    end
  end

  def read_testml_file file
    path = @base + '/' + file
    File.read(path)
  end
end

# TestML Function object class
class TestML::Function
  attr_accessor :expression
  attr_accessor :signature
  attr_accessor :statements
  attr_accessor :namespace
  attr_accessor :data

  @@outer = {}

  def outer=(value)
    @@outer[self.object_id] = value
  end
  def outer
    @@outer[self.object_id]
  end

  def initialize
    # @signature = []
    @statements = []
    @namespace = {}
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
    return nil
  end

  def setvar name, object
    @namespace[name] = object
  end

  def forgetvar name
    @namespace.delete name
  end
end

class TestML::Assignment
  attr_accessor :name
  attr_accessor :expression

  def initialize(name, expr)
    @name = name
    @expr = expr
  end
end

class TestML::Statement
  attr_accessor :expression
  attr_accessor :assertion
  attr_accessor :points

  def initialize(expression, assertion=nil, points=nil)
    @expression = expression
    @assertion = assertion if assertion
    @points = points if points
  end
end

class TestML::Expression
  attr_accessor :calls
  attr_accessor :error

  def initialize(calls=[])
    @calls = calls
  end
end

class TestML::Assertion
  attr_accessor :name
  attr_accessor :expression

  def initialize(name, expression=nil)
    @name = name
    @expression = expression
  end
end

class TestML::Call
  attr_accessor :name
  attr_accessor :args

  def initialize(name, args=[], explicit_call=false)
    @name = name
    @args = args if !args.empty?
    @explicit_call = explicit_call if explicit_call
  end
end

class TestML::Block
  attr_accessor :label
  attr_accessor :points

  def initialize
    @label = ''
    @points = {}
  end
end

class TestML::Point
  attr_accessor :name

  def initialize(name)
    @name = name
  end
end

class TestML::Object
  attr_accessor :value

  def initialize(value)
    @value = value
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

class TestML::List < TestML::Object
  def initialize(value=[])
    super(value)
  end

  def push elem
    @value.push elem
  end
end

class TestML::Str < TestML::Object
end

class TestML::Num < TestML::Object
end

class TestML::Bool < TestML::Object
end

class TestML::None < TestML::Object
  def initialize
    super(nil)
  end

  def bool
    TestML::Constant::False
  end

  def list
    TestML::List.new []
  end
end

class TestML::Error < TestML::Object
end

class TestML::Native < TestML::Object
end

module TestML::Constant
  True = TestML::Bool.new(value: 1)
  False = TestML::Bool.new(value: 0)
  None = TestML::None.new
end
