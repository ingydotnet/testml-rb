#------------------------------------------------------------------------------
class TestML::Lite::Function
  attr_accessor :statements
  attr_accessor :namespace
  attr_accessor :data

  def initialize
    @signature = []
    @statements = []
    @namespace = {}
    @data = []
  end

  def getvar name
    @namespace[name]
  end

  def setvar name, object
    @namespace[name] = object
  end

  def forgetvar name
    @namespace.delete name
  end
end
