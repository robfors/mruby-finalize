# mruby-finalize

An _mruby_ gem that implements finalizers. The main purpose of this gem is work around the limitations of _mruby_ to expose an API similar to what you find in _CRuby_. As an equivalent API not possible, this gem exposes two independent APIs, one called from Ruby and one called from C++, each have their own limitations.

## Implementation

### The GC Callback

Internally, these finalizers are able to work by use of _mruby_'s GC cleanup callback. The gem starts by building an instance of its data class (`Finalize::Emittable`) and waits for the instance's GC callback to be called after the instance is destroyed. The GC callback was never intended to be used as a finalizer so this gem uses it cautiously.

The main limitation of this solution is that calling many of the _mruby_ functions inside this callback can cause segfaults or unexpected behaviour, and thus should be avoided in production code unless you know what you are doing. The two APIs offered by _mruby-finalize_ use different solutions get around this limitation. When an object is destroyed, the Ruby API will queue the object's finalizers for later whereas the C++ API executes them immediately but restricts what can be done in them.

Another limitation to consider is that all finalizers are disabled as soon as the interpreter is shutdown, specifically when the _mruby-finalize_ gem finalizer (`mrb_mruby_finalize_gem_final`) is called. Any gem that lists _mruby-finalize_ as a dependency can use its own finalizer to clean up any live objects that it defined a finalizer on. This will be safe as _mruby_ calls gem finalizers in a hierarchical order (dependee's finalizer before the dependent's finalizer).

### Indirect Finalizers

The destruction of all other kinds of objects can not be listened for directly.  _mruby-finalize_ solves this problem internally by attaching a `Finalize::Emittable` to the the given object. The finalizer will then be defined on the `Finalize::Emittable`, which can only be destroyed when the given object is no longer referenced. We call this an indirect finalizer.

The downside to this solution is that an indirect finalizer may be called shortly before or after the given object is actually destroyed. If at any point in time you need to guarantee that you don't have; a destroyed object whose indirect finalizer has not yet been executed (or queued), or, an executed (or queued) finalizer whose object has not yet been destroyed; then the GC must be manually run with `GC.start`. This will ensure the given object and the `Finalize::Emittable` are either both destroyed or both left alive.

Another downside to this solution is that indirect finalizers can not be defined on some core objects, however, _CRuby_ has a similar limitation.

You can avoid the pitfalls of indirect finalizers altogether by subclassing `Finalize::Emittable` in your code and defining finalizers on them directly.

## Ruby API

With the Ruby API you can define and undefine finalizers (`Proc`s) on most objects. The main difference from _CRuby_ is that these finalizers are non-preemptive, that is, you must manually call `Finalize::process` on occasion to execute the finalizers that are ready:
```ruby
$count = 0
f = Proc.new { $count += 1 }
o = Object.new
Finalize.define_finalizer(o, f)
GC.start
Finalize.process
$count #=> 0
o = nil
GC.start
$count #=> 0
Finalize.process
$count #=> 1
```

Multiple finalizers can be defined on an object:
```ruby
$count = 0
f1 = Proc.new { $count += 1 }
f2 = Proc.new { $count += 2 }
o = Object.new
Finalize.define_finalizer(o, f1)
Finalize.define_finalizer(o, f2)
GC.start
Finalize.process
$count #=> 3
```

Another difference from the _CRuby_ API is that `Finalize::undefine_finalizer` will undefine a specific finalizer rather than all of them:
```ruby
$count = 0
f = Proc.new { $count += 1 }
o = Object.new
Finalize.define_finalizer(o, f)
Finalize.undefine_finalizer(o, f)
GC.start
Finalize.process
$count #=> 0
```

It doesn't make sense to catch an error raised by a finalizer during a call to `Finalize::process` as the finalizer may have been defined by unrelated code. For this reason, an uncaught error in a finalizer is fatal.

Remember to avoid the common mistake where your finalizer inadvertently holds a reference to the object you are defining it on. See [_The Trouble with Ruby Finalizers_](https://www.mikeperham.com/2010/02/24/the-trouble-with-ruby-finalizers/).

## C++ API

With the C++ API you can define finalizers (`Lambda`s) on most objects. Unlink the Ruby API, these finalizers will be executed immediately after the object is destroyed:
```cpp
#include <finalize.hpp>
// ...
mrb_value object; // an instance of Object
// Lambda must accept no arguments and return no value
function<void()> finalizer = [] { printf("object_destroyed"); };
Finalize::define_finalizer(mrb, object, finalizer);
// ...
// when the object is destroyed you will see “object_destroyed” printed
```

The main limitation of this API is that many of the mruby functions can not be called from a finalizer, as discussed in the _Implementation_ section. +mrb_malloc+ and +mrb_free+ are some of the exceptions and can be safely called for memory management as needed.
```cpp
#include <finalize.hpp>
// ...
mrb_value object; // an instance of Object
mrb_value array; // an instance of Array
auto finalizer = [array] { mrb_ary_push(mrb, array, mrb_nil_value()); };
Finalize::define_finalizer(mrb, object, finalizer);
// ...
// when the object is destroyed you may get a segfault or another unexpected error
```

Also unlike the Ruby API, you are able to determine if a finalizer definition was direct or indirect:
```cpp
#include <finalize.hpp>
// ...
mrb_value object; // an instance of Object
auto finalizer = [] { printf("object_destroyed"); };
Finalize::DefinitionAffiliation affiliation = Finalize::define_finalizer(mrb, object, finalizer);
affiliation //=> Finalize::DefinitionAffiliation::indirect
```

