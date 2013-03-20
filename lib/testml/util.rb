require 'testml/runtime'

module TestML::Util
  def list(value)
    TestML::List.new(value)
  end
  def str(value)
    TestML::Str.new(value)
  end
  def num(value)
    TestML::Num.new(value)
  end
  def bool(value)
    TestML::Bool.new(value)
  end
  def none(value)
    TestML::None.new(value)
  end
  def native(value)
    TestML::Native.new(value)
  end
end
