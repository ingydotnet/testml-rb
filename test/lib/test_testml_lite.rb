require './lib/testml/lite'

class TestTestMLLite < TestML::Lite
  include TestML::Lite::TestCases

  def json_load json
    require 'json'
    JSON.load json
  end

  def yaml_dump object
    require 'yaml'
    YAML.dump(object).sub(/\A---\n/, '')
  end
end
