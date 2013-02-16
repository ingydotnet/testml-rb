##
# The Runtime object is responsible for running the TestML code and applying it
# to the Ruby test framework (default is Test::Unit).

class TestML::Runtime

# # TODO TestML should require the compiler and create the runtime object with it
# use TestML::Compiler;

# # Since there is only ever one test runtime, it makes things a LOT cleaner to
# # keep the reference to it in a global variable accessed by a method, than to
# # put a reference to it into every object that needs to access it.
# our $self;

# has base => default => sub {$0 =~ m!(.*)/! ? $1 : "."};   # Base directory
# has testml => ();       # TestML document filename, handle or text
# has bridge => ();       # Bridge transform module

# # XXX Add TestML.pm support for -library keyword.
# has library => default => sub {[]};    # Transform library modules

# has function => ();         # Current function executing
# has planned => default => sub {0};     # plan() has been called
# has test_number => default => sub {0}; # Number of tests run so far

# sub BUILD {
#     my $self = $TestML::Runtime::self = shift;
#     $self->function($self->compile_testml);
#     $self->load_variables;
#     $self->load_transform_module('TestML::Library::Standard');
#     $self->load_transform_module('TestML::Library::Debug');
#     if ($self->bridge) {
#         $self->load_transform_module($self->bridge);
#     }
# }
  def initialize(test)
    @testml = test.testml
    @bridge = test.bridge
    @compiler_class = test.compiler_class
    @function = compile_testml
    @library = test.library
    @test_number = 0
    @planned = false
  end

  def run
    context = TestML::None.new 
    args = []

    run_function(@function, context, args)
#     $self->run_plan();
#     $self->plan_end();

  end

end
# # XXX Move to TestML::Adapter
  def title; end
  def plan_begin; end
  def plan_end; end


# # XXX - TestML exception handling needs to happen at the function level, not
# # just at the expression level. Not yet handled here.
# sub run_function {
  def run_function(function, context, args)
    signature = function.signature
#     die sprintf(
#         "Function received %d args but expected %d",
#         scalar(@$args),
#         scalar(@$signature),
#     ) if @$signature and @$args != @$signature;
    function.setvar('Self', context)
#     for (my $i = 0; $i < @$signature; $i++) {
#         my $arg = $args->[$i];
#         $arg = $self->run_expression($arg)
#             if ref($arg) eq 'TestML::Expression';
#         $function->setvar($signature->[$i], $arg);
#     }

#     my $parent = $self->function;
#     $self->function($function);

    function.statements.each do |statement|
      run_statement(statement)
    end

#     $self->function($parent);

    return TestML::None.new
  end

  def run_statement statement
    blocks = statement.points.empty? ? [1] : select_blocks(statement.points)
    blocks.each do |block|
      @function.setvar('Block', block) if block != 1
      context = run_expression(statement.expression)
      if assertion = statement.assertion
        run_assertion(context, assertion)
      end
    end
  end

  def run_assertion left, assertion
    meth = method("assert_#{assertion.name}".to_sym)

    run_plan

    @test_number += 1

    @function.setvar('TestNumber', TestML::Num.new(@test_number))


#     # TODO - Should check 
#     my $results = ($left->type eq 'List')
#         ? $left->value
#         : [ $left ];
    results = [left]
    results.each do |result|
      if !assertion.expression.units.empty?
        right = run_expression(assertion.expression)
#             my $matches = ($right->type eq 'List')
#                 ? $right->value
#                 : [ $right ];
        matches = [right]
        matches.each do |match|
          meth.call(result, match)
        end
      else
        meth.call(result)
      end
    end
  end

  def run_expression expression
    if expression.kind_of? TestML::Point
      return get_point(expression)
    end
    if expression.kind_of? TestML::Object
      return expression
    end

    units = expression.units
    context = nil

    units.each do |unit|
      if expression.error
        next unless unit.kind_of?(TestML::Transform) && unit.name == 'Catch'
      end
      if unit.kind_of?(TestML::Object) || unit.kind_of?(TestML::Function)
        context = unit
        next
      end


      case unit
      when TestML::Transform

        args = unit.args.collect{|arg| run_expression(arg)}

        if callable = @function.getvar(unit.name)
          context = case callable
          when TestML::Native
            run_native(callable.value, context, args)
          when TestML::Object
            callable
          when TestML::Function
            fail "Function not supported yet"
#         elsif ($callable->isa('TestML::Function')) {
#             if ($i or $unit->explicit_call) {
#                 my $points = $self->function->getvar('Block')->points;
#                 for my $key (keys %$points) {
#                     $callable->setvar($key, TestML::Str->new(value => $points->{$key}));
#                 }
#                 $context = $self->run_function($callable, $context, $args);
#             }
#             $context = $callable;
#         }
          when TestML::Point
            get_point(callable)
          else
            fail "Unexpected callable"
          end
        elsif callable = @bridge.method(unit.name.to_sym)
          args.unshift context if context
          context = callable.call(*args)
          if context.kind_of?(String)
            context = TestML::Str.new(context)
          elsif !context.kind_of?(TestML::Str)
            fail "Not a value we can deal with"
          end
        elsif callable = @library.method(unit.name.to_sym)
          XXX unit
        else
          fail "Can't find TestML method #{unit.name}"
        end
      when TestML::Point
        context = get_point(unit)
      else
        fail("Unexpected unit: #{unit}")
      end
    end
    return context
  end


  def get_point(point)
    TestML::Str.new(@function.getvar('Block')[:points][point.name])
  end

# sub run_native {
#     my $self = shift;
#     my $function = shift;
#     my $context = shift;
#     my $args = shift;
#     my $value = eval {
#         &$function(
#             $context,
#             map {
#                 (ref($_) eq 'TestML::Expression')
#                 ? $self->run_expression($_)
#                 : $_
#             } @$args
#         );
#     };
#     if ($@) {
#         $self->function->expression->error($@);
#         $context = TestML::Error->new(value => $@);
#     }
#     elsif (UNIVERSAL::isa($value, 'TestML::Object')) {
#         $context = $value;
#     }
#     else {
#         $context = $self->object_from_native($value);
#     }
#     return $context;
# }

  def select_blocks(wanted)
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
#     OUTER: for my $block (@{$self->function->data}) {
#         my %points = %{$block->points};
#         next if exists $points{SKIP};
#         for my $point (@$wanted) {
#             next OUTER unless exists $points{$point};
#         }
#         if (exists $points{ONLY}) {
#             @$selected = ($block);
#             last;
#         }
#         push @$selected, $block;
#         last if exists $points{LAST};
#     }
#     return $selected;
# }

# sub object_from_native {
#     my $self = shift;
#     my $value = shift;
#     return
#         not(defined $value) ? TestML::None->new :
#         ref($value) eq 'ARRAY' ? TestML::List->new(value => $value) :
#         $value =~ /^-?\d+$/ ? TestML::Num->new(value => $value + 0) :
#         "$value" eq "$TestML::Constant::True" ? $value :
#         "$value" eq "$TestML::Constant::False" ? $value :
#         "$value" eq "$TestML::Constant::None" ? $value :
#         TestML::Str->new(value => $value);
# }

  def compile_testml
    @compiler_class.new.compile(@testml)
#     my $self = shift;
#     my $path = ref($self->testml)
#         ? $self->testml
#         : join '/', $self->base, $self->testml;
#     my $function = TestML::Compiler->new(base => $self->base)->compile($path)
#         or die "TestML document failed to compile";
#     return $function;
# }
  end

# sub load_variables {
#     my $self = shift;
#     my $global = $self->function->outer;
#     $global->setvar(Block => TestML::Block->new);
#     $global->setvar(Label => TestML::Str->new(value => '$BlockLabel'));
#     $global->setvar(True => $TestML::Constant::True);
#     $global->setvar(False => $TestML::Constant::False);
#     $global->setvar(None => $TestML::Constant::None);
# }

# sub load_transform_module {
#     my $self = shift;
#     my $module_name = shift;
#     if ($module_name ne 'main') {
#         eval "require $module_name; 1"
#             or die "Can't use $module_name:\n$@";
#     }

#     my $global = $self->function->outer;
#     no strict 'refs';
#     for my $key (sort keys %{"$module_name\::"}) {
#         next if $key eq "\x16";
#         my $glob = ${"$module_name\::"}{$key};
#         if (my $function = *$glob{CODE}) {
#             $global->setvar(
#                 $key => TestML::Native->new(value => $function),
#             );
#         }
#         elsif (my $object = *$glob{SCALAR}) {
#             if (ref($$object)) {
#                 $global->setvar($key => $$object);
#             }
#         }
#     }
# }

  def get_label
    return 'foo'
#     my $label = $self->function->getvar('Label')->value;
#     sub label {
#         my $self = shift;
#         my $var = shift;
#         my $block = $self->function->getvar('Block');
#         return $block->label if $var eq 'BlockLabel';
#         if (my $v = $block->points->{$var}) {
#             $v =~ s/\n.*//s;
#             $v =~ s/^\s*(.*?)\s*$/$1/;
#             return $v;
#         }
#         if (my $v = $self->function->getvar($var)) {
#             return $v->value;
#         }
#     }
#     $label =~ s/\$(\w+)/label($self, $1)/ge;
#     return $label ? ($label) : ();
  end

  def run_plan
    if !@planned
      title
      plan_begin
      @planned = true
    end
  end

# sub get_error {
#     my $self = shift;
#     return $self->function->expression->error;
# }

# sub clear_error {
#     my $self = shift;
#     return $self->function->expression->error(undef);
# }

# sub throw {
#     require Carp;
#     Carp::croak $_[1];
# }

# 
# TestML Function object class
class TestML::Function
  attr_accessor :expression
  attr_accessor :signature
  attr_accessor :statements
  attr_accessor :namespace
  attr_accessor :data

  def initialize
    @signature = []
    @statements = []
    @namespace = {}
    @data = []
  end

  def getvar name
    @namespace[name]
  end

  def setvar name, object
    @namespace[name] = object
  end

  def forgetvar name
    @namespace.delete name
  end
end

class TestML::Statement
  attr_accessor :expression
  attr_accessor :assertion
  attr_accessor :points

  def initialize(expression, assertion=nil, points=[])
    @expression = expression
    @assertion = assertion
    @points = points
  end
end

class TestML::Expression
  attr_accessor :units
  attr_accessor :error

  def initialize(units=[])
    @units = units
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

class TestML::Transform
  attr_accessor :name
  attr_accessor :args

  def initialize(name, args=[], explicit_call=false)
    @name = name
    @args = args
    @explicit_call = explicit_call
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

  def initialize value
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

class TestML::Num < TestML::Object

end

class TestML::Str < TestML::Object

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
