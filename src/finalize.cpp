#include "finalize.hpp"


using namespace std;


namespace Finalize
{


  // multiple states may exist at the same time so a container is used to keep track of them all
  unordered_set<mrb_state*> _alive_mrb_states;


  DefinitionAffiliation define_finalizer(mrb_state* mrb, mrb_value object, function<void()> finalizer)
  {
    DefinitionAffiliation affiliation = DefinitionAffiliation::direct;
    if (!mrb_obj_is_instance_of(mrb, object, mrb_class_ptr(Emittable::klass(mrb))))
      affiliation = DefinitionAffiliation::indirect;
    object = mrb_funcall_argv(mrb, module(mrb), mrb_intern_lit(mrb, "get_definable_object"), 1, &object);
    Emittable::define_finalizer(mrb, object, finalizer);
    return affiliation;
  }


  void finalize(mrb_state* mrb)
  {
    _alive_mrb_states.erase(mrb);
  }


  void initialize(mrb_state* mrb)
  {
    _setup(mrb);
    _alive_mrb_states.insert(mrb);
  }


  bool is_alive(mrb_state* mrb)
  {
    return _alive_mrb_states.count(mrb) != 0;
  }


  mrb_value module(mrb_state* mrb)
  {
    return mrb_obj_value(mrb_module_get(mrb, "Finalize"));
  }


  void queue_ruby_finalizers(mrb_state* mrb, mrb_value ruby_finalizers)
  {
    mrb_value queued_finalizers = mrb_iv_get(mrb, module(mrb), mrb_intern_lit(mrb, "@queued_finalizers"));
    QueuedFinalizers::push(mrb, queued_finalizers, ruby_finalizers);
  }


  void _setup(mrb_state* mrb)
  {
    mrb_define_module(mrb, "Finalize");

    QueuedFinalizers::setup(mrb);
    Emittable::setup(mrb);
  }


}


void mrb_mruby_finalize_gem_final(mrb_state* mrb)
{
  Finalize::finalize(mrb);
}


void mrb_mruby_finalize_gem_init(mrb_state* mrb)
{
  Finalize::initialize(mrb);
}
