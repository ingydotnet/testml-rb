require 'testml/runtime'

module TestML::Util
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
  def list(value)
    TestML::List.new(value)
  end
end
