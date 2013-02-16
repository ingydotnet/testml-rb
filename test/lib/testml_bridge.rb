require './lib/testml'

class TestMLBridge < TestML::Bridge
  def uppercase string
    string.value.upcase
  end

  def lowercase string
    string.value.downcase
  end

  def combine *args
    args.flatten.map(&:value).join(' ')
  end

  def json_load json
    require 'json'
    JSON.load json
  end

  def yaml_dump object
    require 'yaml'
    YAML.dump(object).sub(/\A---\n/, '')
  end
end
