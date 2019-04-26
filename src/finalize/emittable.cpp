#include "emittable.hpp"


using namespace std;


namespace Finalize
{
  namespace Emittable
  {


    // A data container to hold the Ruby and C++ finalizers for an {Emittable} object.
    struct Finalizers
    {
      
      MRBQueue<function<void()>> cpp;
      mrb_value ruby;

      Finalizers(mrb_state* mrb)
      : cpp(MRBQueue<function<void()>>(mrb)), ruby(mrb_nil_value())
      {
      }

    };


    struct mrb_data_type _data_type = {"Finalize::Emittable", _free};


    void define_finalizer(mrb_state* mrb, mrb_value self, function<void()> finalizer)
    {
      mrb_funcall(mrb, self, "_finalize__ensure_data_initialized", 0, nullptr);
      Finalizers* finalizers_ptr = (Finalizers*)mrb_data_get_ptr(mrb, self, &_data_type);

      finalizers_ptr->cpp.push(finalizer);
    }


    void _free(mrb_state* mrb, void* ptr)
    {
      Finalizers* finalizers_ptr = (Finalizers*)ptr;

      // to avoid a segfault we need to disable finalizers after the gem's finalizer has been called
      if (Finalize::is_alive(mrb))
      {

        // handle Ruby finalizers
        if (!mrb_nil_p(finalizers_ptr->ruby))
          Finalize::queue_ruby_finalizers(mrb, finalizers_ptr->ruby);

        // handle C++ finalizers
        while (!finalizers_ptr->cpp.is_empty())
        {
          function<void()> finalizer = finalizers_ptr->cpp.pop();
          finalizer();
        }

      }

      // clean up
      finalizers_ptr->~Finalizers();
      mrb_free(mrb, finalizers_ptr);
    }


    mrb_value _initialize_data(mrb_state* mrb, mrb_value self)
    {
      // clear any existing data
      Finalizers* finalizers_ptr = (Finalizers*)DATA_PTR(self);
      if (finalizers_ptr != nullptr)
        mrb_free(mrb, finalizers_ptr);

      finalizers_ptr = (Finalizers*)mrb_malloc(mrb, sizeof(Finalizers));
      new (finalizers_ptr) Finalizers(mrb);

      mrb_data_init(self, finalizers_ptr, &_data_type);

      return mrb_nil_value();
    }


    mrb_value _initialize_ruby_finalizers(mrb_state* mrb, mrb_value self)
    {
      Finalizers* finalizers_ptr = (Finalizers*)mrb_data_get_ptr(mrb, self, &_data_type);

      mrb_value ruby_finalizers = mrb_ary_new(mrb);
      mrb_gc_register(mrb, ruby_finalizers);
      finalizers_ptr->ruby = ruby_finalizers;

      return mrb_nil_value();
    }


    mrb_value klass(mrb_state* mrb)
    {
      return mrb_obj_value(mrb_class_get_under(mrb, mrb_class_ptr(Finalize::module(mrb)), "Emittable"));
    }


    mrb_value _ruby_finalizers(mrb_state* mrb, mrb_value self)
    {
      Finalizers* finalizers_ptr = (Finalizers*)mrb_data_get_ptr(mrb, self, &_data_type);

      return finalizers_ptr->ruby;
    }


    void setup(mrb_state* mrb)
    {
      RClass* klass = mrb_define_class_under(mrb, mrb_class_ptr(Finalize::module(mrb)), "Emittable", mrb->object_class);
      MRB_SET_INSTANCE_TT(klass, MRB_TT_DATA);

      mrb_define_method(mrb, klass, "_finalize__finalizers", _ruby_finalizers, MRB_ARGS_NONE());
      mrb_define_method(mrb, klass, "_finalize__initialize_data", _initialize_data, MRB_ARGS_NONE());
      mrb_define_method(mrb, klass, "_finalize__initialize_finalizers", _initialize_ruby_finalizers, MRB_ARGS_NONE());
    }


  }
}
