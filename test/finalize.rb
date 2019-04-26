assert("Finalize::attach_emittable") do

  # ensure Emittable returned
  o = Object.new
  e = Finalize.attach_emittable(o)
  assert_kind_of(Finalize::Emittable, e)

  # Emittable should point to object
  o = Object.new
  e = Finalize.attach_emittable(o)
  assert_equal(o, e.instance_variable_get(:@object))

  # call again for the same object (object should point to Emittable)
  o = Object.new
  e1 = Finalize.attach_emittable(o)
  e2 = Finalize.attach_emittable(o)
  assert_same(e1, e2)

  # call for different object
  e1 = Finalize.attach_emittable(Object.new)
  e2 = Finalize.attach_emittable(Object.new)
  assert_not_same(e1, e2)

  # unsupported type
  assert_raise(TypeError) { Finalize.attach_emittable(2) }

end


assert("Finalize::define_finalizer") do

  # pass Finalize::Emittable or subclass
  $count = 0
  f = Proc.new { $count += 1 }
  o = Finalize::Emittable.new
  assert_equal(nil, Finalize.define_finalizer(o, f))
  o = nil
  GC.start
  Finalize.process
  assert_equal(1, $count)

  # pass object that is not a Finalize::Emittable or subclass of it
  $count = 0
  f = Proc.new { $count += 1 }
  o = Object.new
  assert_equal(nil, Finalize.define_finalizer(o, f))
  o = nil
  GC.start
  Finalize.process
  assert_equal(1, $count)

  # pass object that can not have a finalizer
  $count = 0
  f = Proc.new { $count += 1 }
  assert_raise(TypeError) { Finalize.define_finalizer(1, f) }

end


assert("Finalize::get_definable_object") do

  # pass Emittable
  e = Finalize::Emittable.new
  r = Finalize.get_definable_object(e)
  assert_same(e, r)

  # pass non Emittable
  o = Object.new
  r = Finalize.get_definable_object(o)
  assert_kind_of(Finalize::Emittable, r)

  # pass unsupported type
  assert_raise(TypeError) { Finalize.get_definable_object(2) }

end


assert("Finalize::process") do

  # set multiple finalizers on an object
  $count1 = 0
  $count2 = 0
  f1 = Proc.new { $count1 += 1 }
  f2 = Proc.new { $count2 += 1 }
  o = Finalize::Emittable.new
  Finalize.define_finalizer(o, f1)
  Finalize.define_finalizer(o, f2)
  o = nil
  GC.start
  Finalize.process
  assert_equal(1, $count1)
  assert_equal(1, $count2)

  # set a finalizer on multiple objects
  $count = 0
  f = Proc.new { $count += 1 }
  o1 = Finalize::Emittable.new
  o2 = Finalize::Emittable.new
  Finalize.define_finalizer(o1, f)
  Finalize.define_finalizer(o2, f)
  o1 = nil
  o2 = nil
  GC.start
  Finalize.process
  assert_equal(2, $count)

  # finalizers should be executed in order of definition
  $count = 0
  f1 = Proc.new { $count = 1 if $count == 0 }
  f2 = Proc.new { $count = 2 if $count == 1 }
  o = Finalize::Emittable.new
  Finalize.define_finalizer(o, f1)
  Finalize.define_finalizer(o, f2)
  o = nil
  GC.start
  Finalize.process
  assert_equal(2, $count)

  # finalizers should be executed in order of object destruction
  $count = 0
  f1 = Proc.new { $count = 1 }
  f2 = Proc.new { $count = 2 }
  o1 = Finalize::Emittable.new
  o2 = Finalize::Emittable.new
  Finalize.define_finalizer(o1, f1)
  Finalize.define_finalizer(o2, f2)
  o1 = nil
  GC.start
  Finalize.process
  assert_equal(1, $count)
  o2 = nil
  GC.start
  Finalize.process
  assert_equal(2, $count)

  # errors raised in a finalizer should be fatal
  f1 = Proc.new { raise StandardError }
  f2 = Proc.new { }
  o = Finalize::Emittable.new
  Finalize.define_finalizer(o, f1)
  Finalize.define_finalizer(o, f2)
  o = nil
  GC.start
  assert_raise(Exception) { Finalize.process }
  # should not be able to continue executing anymore finalizers
  assert_raise(Exception) { Finalize.process }
  # be sure to clean up after this test
  Finalize.instance_variable_set(:@error_raised, false)
  Finalize.process

  # should not be able to call ::process in a finalizer
  f = Proc.new { assert_raise(RuntimeError) { Finalize::process } }
  o = Finalize::Emittable.new
  Finalize.define_finalizer(o, f)
  o = nil
  GC.start
  Finalize.process

  # checking for memory leak
  # primarily checking that finalizers can be destroyed after being called
  start_count = ObjectSpace.count_objects[:TOTAL]
  10_000.times do
    f = Proc.new { }
    o = Finalize::Emittable.new
    Finalize.define_finalizer(o, f)
    f = nil
    o = nil
  end
  GC.start
  Finalize.process
  GC.start
  end_count = ObjectSpace.count_objects[:TOTAL]
  # some objects will be created temporarily, if less than 2_000 are created we can assume
  #   that finalizers are able to be destroyed
  assert_true(end_count - 2_000 <= start_count)

  # checking for memory leak
  # primarily checking that Emittables can be destroyed after their attached objects are destroyed
  start_count = ObjectSpace.count_objects[:TOTAL]
  10_000.times do
    f = Proc.new { }
    o = Object.new
    Finalize.define_finalizer(o, f)
    f = nil
    o = nil
  end
  GC.start
  Finalize.process
  GC.start
  end_count = ObjectSpace.count_objects[:TOTAL]
  # some objects will be created temporarily, if less than 2_000 are created we can assume
  #   that finalizers are able to be destroyed
  assert_true(end_count - 2_000 <= start_count)

  # set up an object that will only be destroyed when the interpreter
  #   is closing (after the gem finalizer has been called)
  # if something is wrong we may induce a segfault
  $finalizer_object = Finalize::Emittable.new
  f = Proc.new { }
  Finalize.define_finalizer($finalizer_object, f)

end


assert("Finalize::undefine_finalizer") do

  # pass finalizer that was never set
  f = Proc.new { }
  o = Finalize::Emittable.new
  assert_raise(ArgumentError) { Finalize.undefine_finalizer(o, f) }
  
  # pass finalizer that was set
  $count = 0
  f = Proc.new { $count += 1 }
  o = Finalize::Emittable.new
  Finalize.define_finalizer(o, f)
  Finalize.undefine_finalizer(o, f)
  o = nil
  GC.start
  Finalize.process
  assert_equal(0, $count)

  # pass finalizer that was set on indirect object
  $count = 0
  f = Proc.new { $count += 1 }
  o = Object.new
  Finalize.define_finalizer(o, f)
  Finalize.undefine_finalizer(o, f)
  o = nil
  GC.start
  Finalize.process
  assert_equal(0, $count)

  # pass a non Finalize::Emittable object that does not have any finalizers
  f = Proc.new { }
  o = Object.new
  assert_raise(ArgumentError) { Finalize.undefine_finalizer(o, f) }

  # pass object that could never have a finalizer
  f = Proc.new { }
  o = 1
  assert_raise(TypeError) { Finalize.undefine_finalizer(o, f) }

end


assert("Finalize:CPP_API") do

  # pass a Finalize::Emittable or subclass
  o = Finalize::Emittable.new
  assert_equal(:direct, FinalizeTest.define_finalizer(o, 1))
  o = nil
  GC.start
  assert_equal(1, FinalizeTest.next_executed_finalizer_value)

  # pass object that is not a Finalize::Emittable or subclass of it
  o = Object.new
  assert_equal(:indirect, FinalizeTest.define_finalizer(o, 1))
  o = nil
  GC.start
  assert_equal(1, FinalizeTest.next_executed_finalizer_value)

  # pass object that can not have a finalizer
  assert_raise(TypeError) { FinalizeTest.define_finalizer(1, 1) }

  # single finalizer
  o = Finalize::Emittable.new
  FinalizeTest.define_finalizer(o, 1)
  GC.start
  assert_nil(FinalizeTest.next_executed_finalizer_value)
  o = nil
  GC.start
  assert_equal(1, FinalizeTest.next_executed_finalizer_value)

  # set multiple finalizers on an object
  # finalizers should be executed in order of definition
  o = Finalize::Emittable.new
  FinalizeTest.define_finalizer(o, 1)
  FinalizeTest.define_finalizer(o, 3)
  FinalizeTest.define_finalizer(o, 2)
  GC.start
  assert_nil(FinalizeTest.next_executed_finalizer_value)
  o = nil
  GC.start
  assert_equal(1, FinalizeTest.next_executed_finalizer_value)
  assert_equal(3, FinalizeTest.next_executed_finalizer_value)
  assert_equal(2, FinalizeTest.next_executed_finalizer_value)

  # finalizers should be executed in order of object destruction
  o1 = Finalize::Emittable.new
  o2 = Finalize::Emittable.new
  o3 = Finalize::Emittable.new
  FinalizeTest.define_finalizer(o1, 1)
  FinalizeTest.define_finalizer(o2, 2)
  FinalizeTest.define_finalizer(o3, 3)
  GC.start
  assert_nil(FinalizeTest.next_executed_finalizer_value)
  o1 = nil
  GC.start
  o3 = nil
  GC.start
  o2 = nil
  GC.start
  assert_equal(1, FinalizeTest.next_executed_finalizer_value)
  assert_equal(3, FinalizeTest.next_executed_finalizer_value)
  assert_equal(2, FinalizeTest.next_executed_finalizer_value)

end
