require 'testml/library'

class TestML::Library::Standard < TestML::Library
  def Get(key)
    return runtime.function.getvar(key)
  end

  def Set(key, value)
    return runtime.function.setvar(key, value)
    return value
  end

  def Throw msg
    runtime.function.expression.error = msg
  end

  # TODO @error should probably just be the error message string
  def Catch any=nil
    fail "Catch called, but no error occurred" \
      unless error = runtime.function.expression.error
    runtime.function.expression.error = nil
    return error
  end
end
