#ifndef _FINALIZE_QUEUED_FINALIZERS_HPP_
#define _FINALIZE_QUEUED_FINALIZERS_HPP_


#include "../finalize.hpp"


namespace Finalize
{

  // A queue to hold Ruby finalizers of destroyed objects until they are ready to be executed.
  namespace QueuedFinalizers
  {

    // public

    // setup the data class and C methods
    void setup(mrb_state* mrb);

    // push an array of a destroyed object's finalizers to the queue
    // called from C++
    void push(mrb_state* mrb, mrb_value self, mrb_value monitor);

    // private

    // free the data container
    // called from the GC
    void _free(mrb_state* mrb, void* ptr);

    // setup the data container
    // called from Ruby
    mrb_value _initialize(mrb_state* mrb, mrb_value self);
    
    // pop a destroyed object's array of finalizers from the queue
    // called from Ruby
    mrb_value _pop(mrb_state* mrb, mrb_value self);

  }
}


#endif
