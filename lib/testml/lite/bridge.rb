#------------------------------------------------------------------------------
class TestML::Lite::Bridge
  attr_accessor :runtime

  def String string
    return super string
  end

  def Number number
    return Integer number
  end
end
