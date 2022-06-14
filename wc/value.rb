class STRING
  attr_reader :string, :version
  def initialize string, version
    @string = string
    @version = version
  end

  def type = 'string'
end

class INTEGER
  attr_reader :num

  def initialize num
    @num = num
  end

  def type = 'int'

  def +(rhs) = INTEGER.new(@num + rhs.num)
  def *(rhs) = INTEGER.new(@num * rhs.num)
  def -(rhs) = INTEGER.new(@num - rhs.num)
  def /(rhs) = INTEGER.new(@num / rhs.num)
  def mod(rhs) = INTEGER.new(@num % rhs.num)
  def truthy? = @num.zero?
end

class BOOL
  attr_reader :data

  def initialize bool
    @bool = bool
  end

  def type = 'bool'
  alias truthy? data
end

class NULL
  def type = 'null'
  def truthy? = false
end

class POINTER
  def initialize to
    @to = to
  end

  def type
    @type ||= '*' + (@to.type || return)
  end

  def get(...) = @to.get(...)
  def set(...) = @to.set(...)

  def * = get
end

