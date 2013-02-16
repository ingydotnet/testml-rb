class TestML::Bridge
  attr_accessor :runtime

  def String string
    return string.value
  end

  def Number number
    return Integer number
  end
end
