require 'testml/runtime'

class TestML::Compiler

  attr_accessor :code
  attr_accessor :data
  attr_accessor :text
  attr_accessor :directives
  attr_accessor :function

  def compile(input)
    preprocess(input, 'top')
    compile_code
    compile_data

    if @directives['DumpAST']
      XXX @function
    end

    @function.namespace['TestML'] = @directives['TestML']

    @function.outer = TestML::Function.new
    return @function
  end

  def preprocess(input, top=nil)
    parts = input.split /^((?:\%\w+.*|\#.*|\ *)\n)/

    input = ''

    @directives = {
      'TestML' => nil,
      'DataMarker' => nil,
      'BlockMarker' => '===',
      'PointMarker' => '---',
    }

    order_error = false
    parts.each do |part|
      next if part.empty?
      if part =~ /^(\#.*|\ *)\n/
        input << "\n"
        next
      end
      if part =~ /^%(\w+)\s*(.*?)\s*\n/
        directive, value = $1, $2
        input << "\n"
        if directive == 'TestML'
          fail "Invalid TestML directive" \
            unless value =~ /^\d+\.\d+\.\d+$/
          fail "More than one TestML directive found" \
            if directives['TestML']
          directives['TestML'] = TestML::Str.new(value)
          next
        end
        order_error = true unless directives['TestML']
        if directive == 'Include'
          runtime = $TestML::Runtime::singleton \
            or fail "Can't process Include. No runtime available"
          include_ = self.class.new
          include_.preprocess(runtime.read_testml_file(value))
          input << include_.text
          directives['DataMarker'] =
            include_.directives['DataMarker']
          directives['BlockMarker'] =
            include_.directives['BlockMarker']
          directives['PointMarker'] =
            include_.directives['PointMarker']
          fail "Can't define %TestML in an Included file" \
            if include_.directives['TestML']
        elsif directive =~ /^(DataMarker|BlockMarker|PointMarker)$/
          directives[directive] = value
        elsif directive =~ /^(DebugPegex|DumpAST)$/
          value = true if value.empty?
          directives[directive] = value
        else
          fail "Unknown TestML directive '$#{directive}'"
        end
      else
        order_error = true if !input.empty? and !directives['TestML']
        input << part
      end
    end

    if top
      fail "No TestML directive found" \
        unless directives['TestML']
      fail "%TestML directive must be the first (non-comment) statement" \
        if order_error

      _DataMarker = directives['DataMarker'] ||= directives['BlockMarker']
      if split = input.index("\n#{_DataMarker}")
        @code = input[0..(split)]
        @data = input[(split + 1)..-1]
      else
        @code = input
        @data = ''
      end

      @code.gsub! /^\\(\\*[\%\#])/, '\1'
      @data.gsub! /^\\(\\*[\%\#])/, '\1'
    else
      @text = input
    end
  end
end
