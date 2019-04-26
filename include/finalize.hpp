#ifndef _INCLUDE_FINALIZE_HPP_
#define _INCLUDE_FINALIZE_HPP_


#include <functional>
#include <mruby.h>


namespace Finalize
{

  // public


  // Describes the affiliation of a finalizer definition.
  //
  // +direct+ indicates the finalizer was defined on the object itself and will be executed
  // immediately when the object is destroyed.
  //
  //+indirect+ indicates that the finalizer was
  // defined on an attached object and will be executed shortly before or after the given
  // object is destroyed.
  enum DefinitionAffiliation { direct, indirect };


  // Define a preemptive finalizer on an object.
  //
  // The finalizer will be executed immediately after the object is destroyed.
  //
  // If the object given is not a {Finalize::Emittable}, one will be attached and the finalizer will
  // be defined on it instead. We call this an indirect finalizer and DefinitionAffiliation::indirect
  // will be returned it indicate such.
  //
  // It should be noted that an indirect finalizer may be executed shortly before or after the given
  // object is actually destroyed. If at any time you need to guarantee that:
  // - an indirect finalizer has been called for a destroyed object
  // - an object, whose indirect finalizer had been executed, is destroyed
  // then the GC should be manually run with +GC.start+. This will ensure the given object and the
  // {Finalize::Emittable} are both destroyed or both left alive.
  //
  // Calling many of the mruby functions from the finalizer will cause a segfault or unexpected
  // behaviour and should be avoided. +mrb_malloc+ and +mrb_free+ can be safely called for memory
  // management if needed. If a more complex finalizer is needed the Ruby API should be considered
  // instead. It just won't be preemptive.
  //
  // @param mrb [mrb_state*]
  // @param object [mrb_value]
  // @param finalizer [std::function<void()>]
  // @raise TypeError if the object does not support finalizers
  // @return [DefinitionAffiliation]
  DefinitionAffiliation define_finalizer(mrb_state* mrb, mrb_value object, std::function<void()> finalizer);


}


#endif
