assert("Finalize::Emittable#define_finalizer") do

  # set finalizer of wrong type
  f = 1
  o = Finalize::Emittable.new
  assert_raise(TypeError) { o.define_finalizer(f) }

  # set the same finalizer twice on an object
  f = Proc.new { }
  o = Finalize::Emittable.new
  o.define_finalizer(f)
  assert_raise(ArgumentError) { o.define_finalizer(f) }

end


assert("Finalize::Emittable#undefine_finalizer") do

  # remove a finalizer of wrong type
  f = 1
  o = Finalize::Emittable.new
  assert_raise(TypeError) { o.undefine_finalizer(f) }

  # remove a finalizer that was never set
  f = Proc.new { }
  o = Finalize::Emittable.new
  assert_raise(ArgumentError) { o.undefine_finalizer(f) }

end


assert("Finalize::Emittable") do
  # we will test the rest of the Ruby and C++ code for the Emittable with some functional tests

  # try no finalizers
  # checking that it does not cause any issues with no finalizer array set
  o = Finalize::Emittable.new
  Finalize.process
  GC.start
  Finalize.process
  o = nil
  GC.start
  Finalize.process

  # try single finalizer
  # checking that _free is called at correct time
  $count = 0
  f = Proc.new { $count += 1 }
  o = Finalize::Emittable.new
  o.define_finalizer(f)
  Finalize.process
  GC.start
  Finalize.process
  assert_equal(0, $count)
  o = nil
  GC.start
  Finalize.process
  assert_equal(1, $count)
  # ensure finalizers are cleaned up and won't be called again
  Finalize.process
  assert_equal(1, $count)
  GC.start
  Finalize.process
  assert_equal(1, $count)

  # hold on to the Emittable
  # checking that the finalizer array does not get destroyed
  o = Finalize::Emittable.new
  o._finalize__ensure_finalizers_initialized
  a = []
  1_000.times { a << Object.new }
  a = nil
  assert_kind_of(Array, o._finalize__finalizers)

  # subclass
  # checking that instances of a subclass of Emittable still behave the same way
  c = Class.new(Finalize::Emittable)
  $count = 0
  f = Proc.new { $count += 1 }
  o = c.new
  o.define_finalizer(f)
  GC.start
  Finalize.process
  assert_equal(0, $count)
  o = nil
  GC.start
  Finalize.process
  assert_equal(1, $count)

  # subclass with #initialize defined
  c = Class.new(Finalize::Emittable) { def initialize; super; end }
  $count = 0
  f = Proc.new { $count += 1 }
  o = c.new
  o.define_finalizer(f)
  GC.start
  Finalize.process
  assert_equal(0, $count)
  o = nil
  GC.start
  Finalize.process
  assert_equal(1, $count)

  # subclass with #initialize defined and #super not called
  c = Class.new(Finalize::Emittable) { def initialize; end }
  $count = 0
  f = Proc.new { $count += 1 }
  o = c.new
  o.define_finalizer(f)
  GC.start
  Finalize.process
  assert_equal(0, $count)
  o = nil
  GC.start
  Finalize.process
  assert_equal(1, $count)

  # subclass with no finalizers set
  c = Class.new(Finalize::Emittable)
  o = c.new
  o = nil
  GC.start

end
