require './lib/testml/lite'

class TestMLBridge < TestML::Bridge
  def uppercase string
    string.upcase
  end

  def lowercase string
    string.downcase
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
