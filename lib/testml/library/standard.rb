require 'testml/library'

class TestML::Library::Standard < TestML::Library
  def Get(key)
    return runtime.function.getvar(key)
  end

  def Set(key, value)
    return runtime.function.setvar(key, value)
    return value
  end

  def Throw(msg)
    fail(msg.value)
  end

  def Catch any=nil
    fail "Catch called, but no error occurred" \
      unless error = runtime.error
    runtime.error = nil
    return str error
  end
end
