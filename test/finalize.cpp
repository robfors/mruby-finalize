#include <queue>
#include <functional>
#include <mruby.h>

#include "finalize.hpp"


using namespace std;


namespace FinalizeTest
{


  queue<mrb_int> _finalizer_numbers;


  mrb_value _define_finalizer(mrb_state* mrb, mrb_value self)
  {
    mrb_value object;
    mrb_value num_value;

    mrb_get_args(mrb, "oo", &object, &num_value);

    mrb_int num = mrb_fixnum(num_value);

    auto finalizer = [num] { _finalizer_numbers.push(num); };

    Finalize::DefinitionAffiliation affiliation = Finalize::define_finalizer(mrb, object, finalizer);

    switch(affiliation)
    {
      case Finalize::DefinitionAffiliation::direct:
        return mrb_check_intern_cstr(mrb, "direct");
      case Finalize::DefinitionAffiliation::indirect:
        return mrb_check_intern_cstr(mrb, "indirect");
      default:
        return mrb_check_intern_cstr(mrb, "error");
    }
  }


  mrb_value _next_executed_finalizer_value(mrb_state* mrb, mrb_value self)
  {
    if (_finalizer_numbers.empty())
      return mrb_nil_value();
    else
    {
      mrb_int num = _finalizer_numbers.front();
      _finalizer_numbers.pop();
      return mrb_fixnum_value(num);
    }
  }


  void _setup(mrb_state* mrb)
  {
    _finalizer_numbers = queue<mrb_int>();

    struct RClass* module;

    module = mrb_define_module(mrb, "FinalizeTest");
    mrb_define_class_method(mrb, module, "define_finalizer", _define_finalizer, MRB_ARGS_REQ(2));
    mrb_define_class_method(mrb, module, "next_executed_finalizer_value", _next_executed_finalizer_value, MRB_ARGS_NONE());
  }


}


extern "C"
void mrb_mruby_finalize_gem_test(mrb_state* mrb)
{
  return FinalizeTest::_setup(mrb);
}
