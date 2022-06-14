# container for a value
class Container
  def initialize(value: nil, type: nil)
    @type = type
    set value, first_time: true if value
  end

  def set(value, first_time:)
    if @type
      if @type.upcase != (vtype = value.type).upcase
        raise "expected #@type, got #{vtype}"
      end

      if @type.upcase == @type && !@value.nil?
        raise "reassigned to a constant value"
      end
    end

    raise "re-stored a value" if first_time && @value

    @value = value
    @type ||= vtype
  end

  def get
    @value or raise "loaded from an uninitialized container"
  end

  def type
    @type
  end
end
