require './lib/testml'
require './lib/testml/bridge'
require './lib/testml/util'
include TestML::Util

class TestMLBridge < TestML::Bridge
  def uppercase string
    str string.value.upcase
  end

  def lowercase string
    str string.value.downcase
  end

  def combine *args
    str args.flatten.map(&:value).join(' ')
  end

  def f1(num)
    num = num.value
    return num num * 42 + num
  end

  def f2(num)
    num = num.value
    return num num * num + num
  end
end
