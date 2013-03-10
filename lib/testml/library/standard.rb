require 'testml/library'

class TestML::Library::Standard < TestML::Library
  def Get(key)
    return @runtime.function.getvar(key)
  end

  def Throw msg
    @runtime.error = msg
  end

  # TODO @error should probably just be the error message string
  def Catch any=nil
    fail "Catch called, but no error occurred" unless @runtime.error
    error = @runtime.error
    @runtime.error = nil
    return error
  end
end
