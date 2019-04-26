#ifndef _FINALIZE_EMITTABLE_HPP_
#define _FINALIZE_EMITTABLE_HPP_


#include "../finalize.hpp"


namespace Finalize
{

  // A data class that is used to gain access to the GC's cleanup callback so we know exactly when
  // the object is destroyed.
  //
  // We use this callback to execute defined C++ finalizers and queue defined Ruby finalizers.
  //
  // The data pointer is not initialized unless _initialize_data is called. This is to avoid the need
  // for the call to +super+ in a subclassed +initialize+ method as forgeting it would raise a
  // difficult to interpret error.
  //
  // The Ruby finalizers array is not initialized unless _initialize_ruby_finalizers is called.
  // This is to avoid a cleanup of the array when only C++ finalizers were defined as we can't
  // call many mruby functions during the GC's cleanup callback.
  namespace Emittable
  {

    // public

    // setup the data class and C methods
    void setup(mrb_state* mrb);

    // define a C++ finalizer on the object
    void define_finalizer(mrb_state* mrb, mrb_value self, std::function<void()> finalizer);

    // shortcut function to get the 'Emittable' class
    mrb_value klass(mrb_state* mrb);

    // private

    // the GC cleanup callback
    // execute defined C++ finalizers
    // queue defined Ruby finalizers
    void _free(mrb_state* mrb, void* ptr);

    // build the data container to hold Ruby and C++ finalizers (it will available during the GC callback)
    mrb_value _initialize_data(mrb_state* mrb, mrb_value self);

    // build the array to hold Ruby finalizers
    mrb_value _initialize_ruby_finalizers(mrb_state* mrb, mrb_value self);

    // get the array that holds Ruby finalizers
    mrb_value _ruby_finalizers(mrb_state* mrb, mrb_value self);

  }
}


#endif
