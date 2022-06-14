require './pointer'

GC.start
ObjectSpace.garbage_collect

1000.times do
  x = POINTER.new 'a'
  1000.times {
    x = x.ref
  }

  1000.times {
    x = x.deref
  }
end
