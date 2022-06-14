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

require 'fiddle'
require 'fiddle/import'
require 'objspace'

class POINTER
  module Libc
    include Fiddle
    libc = Fiddle.dlopen(nil)
    MALLOC = Function.new libc['malloc'], [TYPE_SIZE_T], TYPE_VOIDP
    MEMCPY = Function.new libc['memcpy'], [TYPE_VOIDP, TYPE_VOIDP, TYPE_SIZE_T], TYPE_VOIDP
    FREE   = Function.new libc['free'], [TYPE_VOIDP], TYPE_VOID
  end

  def self.new value
    size = ObjectSpace.memsize_of(16)
    ptr = Fiddle::Pointer.malloc size
    ptr[0] = value.inspect[/0x(\h+)/, 1].hex
    # Libc::MEMCPY.(ptr, value.inspect[/0x(\h+)/, 1].hex, size)
    super ptr, value.class
  end

  def initialize ptr, type
    @ptr = ptr
    @type = '*' + type.to_s
  end

  def -@ = @ptr.ref
  def +@ = @ptr.ptr # one level closer  to the value
  def free = FREE[@ptr]
end

ptr = POINTER.new STRING.new("yup", 1)
p ptr
