require 'testml/library'
require 'testml/util'

class TestML::Library::Standard < TestML::Library
  include TestML::Util

  def Get(key)
    return runtime.function.getvar(key)
  end

#   def Set(key, value)
#     return runtime.function.setvar(key, value)
#   end

  def GetLabel
    return str(runtime.get_label)
  end

  def Type(var)
    return str(var.type)
  end

  def Catch(*args)
    error = runtime.error \
      or fail "Catch called but no TestML error found"
    runtime.error = nil
    return str(error)
  end

  def Throw(msg)
    fail(msg.value)
  end

  def Str(object)
    return str(object.str.value)
  end

#   def Num(object)
#     return num(object.num.value)
#   end

#   def Bool(object)
#     return bool(object.bool.value)
#   end

  def List(*args)
    return list(args)
  end

  def Join(list, separator=nil)
    separator = separator ? separator.value : ''
    return str(list.list.value.map {|e| e.value}.join(separator))
  end

  def Not(bool_)
    return bool(bool_.bool.value ? false : true)
  end

  def Text(lines)
    value = lines.list.value
    return str(((value.map {|l| l.value}) + ['']).join($/))
  end

  def Count(list)
    return num(list.list.value.size)
  end

  def Lines(text)
    return list(text.value.split(/\n/).map {|l| str(l)})
  end

  def Reverse(list)
    return list(list.list.value.reverse)
  end

  def Sort(list)
    return list(list.list.value.sort {|a, b| a.value <=> b.value})
  end

  def Strip(string, part)
    string = string.str.value
    part = part.str.value
    if i = string.index(part)
      string = string[0..i] + string[(i + part.length)..-1]
    end
    return str(string)
  end
end
