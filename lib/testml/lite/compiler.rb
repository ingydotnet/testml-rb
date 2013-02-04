##
# This is the Lite version of the TestML compiler. It can parse simple
# statements and assertions and also parse the TestML data format.

class TestML::Lite::Compiler
  attr_accessor :function
  # TODO put plan into Plan var in @function
  attr_accessor :plan
  attr_accessor :testml_version

  # support assignment statement for any variable
  def compile document
    @function = TestML::Function.new
    lines = document.lines.to_a.map &:chomp
    while not lines.empty?
      line = lines.shift
      next unless line.match /\S/
      next if line.match /^\s*#/
      if line[0..2] == "==="
        lines.unshift line
        break
      end
      if line.rstrip.match /^%TestML +(\d+\.\d+\.\d+)$/
        @testml_version = $1
      elsif line.strip.match /^Plan *= *(\d+);?$/
        @function.setvar('Plan', $1.to_i)
      elsif line.strip.match /^.*(?:==|~~).*;?$/
        @function.statements << compile_assertion(line.sub /;$/, '')
      else
        lines.unshift line
        fail "Failed to parse TestML::Lite document, here:\n" +
          lines.join($/)
      end
    end
    unless lines.empty?
      @function.data = compile_data lines.push('').join $/
    end
    return @function
  end

  def compile_assertion expr
    left, op, right = [], nil, nil
    side = left
    while expr.length != 0
      token = get_token expr
      if token =~ /^(==|~~)$/
        op = token == '==' ? 'EQ' : 'HAS'
        left = side
        side = right = []
      else
        side = [side] if side.size >= 2
        side.unshift token
      end
    end
    right = side if right
    return left unless right
    left = left.first if left.size == 1
    right = right.first if right.size == 1
    return [op, left, right]
  end

  def get_token expr
    if expr.sub! /^(\w+)\(([^\)]+)\)\.?/, ''
      token, args = [$1], $2
      token.concat(
        args.split(/,\s*/).map {|t| t.sub /^(['"])(.*)\1$/, '\2'}
      )
    elsif expr.sub! /^\s*(==|~~)\s*/, ''
      token = $1
    elsif expr.sub! /^(['"])(.*?)\1/, ''
      token = ['String', $2]
    elsif expr.sub! /^(\d+)\1/, ''
      token = ['Number', $2]
    elsif expr.sub! /^([\*\w]+)\.?/, ''
      token = $1
    else
      fail "Can't get token from '#{expr}'"
    end
    return token
  end

  def compile_data string
    string.gsub! /^#.*\n/, ''
    string.gsub! /^\\/, ''
    string.gsub! /^\s*\n/, ''
    blocks = string.split /(^===.*?(?=^===|\z))/m
    blocks.reject!{|b| b.empty?}
    blocks.each do |block|
      block.gsub! /\n+\z/, "\n"
    end

    data = []
    blocks.each do |string_block|
      block = {}
      string_block.gsub! /^===\ +(.*?)\ *\n/, '' \
        or fail "No block label! #{string_block}"
      block[:label] = $1
      while !string_block.empty? do
        if string_block.gsub! /\A---\ +(\w+):\ +(.*)\n/, '' or
           string_block.gsub! /\A---\ +(\w+)\n(.*?)(?=^---|\z)/m, ''
          key, value = $1, $2
        else
          raise "Failed to parse TestML string:\n#{string_block}"
        end
        block[:points] ||= {}
        block[:points][key] = value

        if key =~ /^(ONLY|SKIP|LAST)$/
          block[key] = true
        end
      end
      data << block
    end
    return data
  end
end
