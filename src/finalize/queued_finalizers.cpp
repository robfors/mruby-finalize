#include "queued_finalizers.hpp"


namespace Finalize
{
  namespace QueuedFinalizers
  {


    struct mrb_data_type _data_type = {"Finalize::QueuedFinalizers", _free};


    void _free(mrb_state* mrb, void* ptr)
    {
      MRBQueue<mrb_value>* queue_ptr = (MRBQueue<mrb_value>*)ptr;

      queue_ptr->~MRBQueue<mrb_value>();
      mrb_free(mrb, queue_ptr);
    }


    mrb_value _initialize(mrb_state* mrb, mrb_value self)
    {
      // clear any existing data
      MRBQueue<mrb_value>* queue_ptr = (MRBQueue<mrb_value>*)DATA_PTR(self);
      if (queue_ptr != nullptr)
        mrb_free(mrb, queue_ptr);

      queue_ptr = (MRBQueue<mrb_value>*)mrb_malloc(mrb, sizeof(MRBQueue<mrb_value>));
      new (queue_ptr) MRBQueue<mrb_value>(mrb);

      mrb_data_init(self, queue_ptr, &_data_type);

      return self;
    }


    void push(mrb_state* mrb, mrb_value self, mrb_value monitor)
    {
      MRBQueue<mrb_value>* queue_ptr = (MRBQueue<mrb_value>*)mrb_data_get_ptr(mrb, self, &_data_type);
      queue_ptr->push(monitor);
    }


    mrb_value _pop(mrb_state* mrb, mrb_value self)
    {
      MRBQueue<mrb_value>* queue_ptr = (MRBQueue<mrb_value>*)mrb_data_get_ptr(mrb, self, &_data_type);
      if(queue_ptr->is_empty())
        return mrb_nil_value();
      else
      {
        mrb_value monitor = queue_ptr->pop();
        mrb_gc_unregister(mrb, monitor);
        return monitor;
      }
    }


    void setup(mrb_state* mrb)
    {
      RClass* klass = mrb_define_class_under(mrb, mrb_class_ptr(Finalize::module(mrb)), "QueuedFinalizers", mrb->object_class);
      MRB_SET_INSTANCE_TT(klass, MRB_TT_DATA);

      mrb_define_method(mrb, klass, "initialize", _initialize, MRB_ARGS_NONE());
      mrb_define_method(mrb, klass, "pop", _pop, MRB_ARGS_NONE());
    }


  }
}
