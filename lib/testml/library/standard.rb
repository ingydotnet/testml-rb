class TestML::Library::Standard
  attr_accessor :runtime

  def Throw msg
    @runtime.error = msg
  end

  # TODO @error should probably just be the error message string
  def Catch any=nil
    fail "Catch called, but no error occurred" unless @runtime.error
    error = @runtime.error
    @runtime.error = nil
    return error.respond_to?('message') ? error.message : error
  end
end
