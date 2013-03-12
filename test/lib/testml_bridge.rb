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

  def compile_testml(testml)
    @runtime.compiler_class.new.compile(testml.value)
  end

  def json_load json
    require 'json'
    JSON.load json
  end

  def yaml_dump object
    require 'yaml'
    str YAML.dump(object).sub(/\A---\n/, '')
  end
end
