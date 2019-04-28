#ifndef _FINALIZE_HPP_
#define _FINALIZE_HPP_


#include <new>
#include <functional>
#include <unordered_set>
#include <mruby.h>
#include <mruby/class.h>
#include <mruby/data.h>
#include <mruby/variable.h>
#include <mruby/array.h>

#include <finalize.hpp>

#include "finalize/mrb_queue.tpp"


namespace Finalize
{

  // public

  // finalizer for the gem
  // we use it to stop any further object finalizers from being executed when the interpreter is
  // being closed, to avoid a segfault
  void finalize(mrb_state* mrb);

  // initializer for the gem
  // we use it to define the data classes and C methods
  // also used to enable future object finalizers
  void initialize(mrb_state* mrb);

  // check if the interpreter is still alive and finalizers can be safely executed
  bool is_alive(mrb_state* mrb);

  // shortcut function to get the 'Finalize' module
  mrb_value module(mrb_state* mrb);

  // notify {Finalize} that an object has been destroyed
  // the object's Ruby finalizers will be queued for later execution
  void queue_ruby_finalizers(mrb_state* mrb, mrb_value ruby_finalizers);

  // private

  // define the data classes and C methods
  void _setup(mrb_state* mrb);

}


// called by mruby when it is shutting down
extern "C"
void mrb_mruby_finalize_gem_final(mrb_state* mrb);

// called by mruby to setup the gem
extern "C"
void mrb_mruby_finalize_gem_init(mrb_state* mrb);


#include "finalize/queued_finalizers.hpp"
#include "finalize/emittable.hpp"

#endif
