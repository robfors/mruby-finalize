#ifndef _FINALIZE_MRB_QUEUE_TPP_
#define _FINALIZE_MRB_QUEUE_TPP_


#include <mruby.h>


namespace Finalize
{

  template <class T>
  struct MRBQueueElement
  {
    T value;
    MRBQueueElement<T>* next;

    MRBQueueElement(T value)
    : value(value), next(nullptr)
    {
    }

  };

  // A queue.
  // This is used inplace of a std::queue primarily because it uses +mrb_malloc+ and +mrb_free+
  //   to work with memory.
  template <class T>
  class MRBQueue
  {

    public:


    MRBQueue(mrb_state* mrb)
    : _first_element_ptr(nullptr), _last_element_ptr(nullptr), _mrb(mrb)
    {
    }


    // clears the queue during destruction
    ~MRBQueue()
    {
      clear();
    }


    // removes and frees all the elements
    void clear()
    {
      while(_first_element_ptr != nullptr)
        pop();
    }


    bool is_empty()
    {
      return _first_element_ptr == nullptr;
    }


    // get next element or raise an error is none exist
    T pop()
    {
      if (is_empty())
        throw std::runtime_error("queue is empty");
      else
      {
        MRBQueueElement<T>* element_ptr = _first_element_ptr;
        T value = element_ptr->value;

        _first_element_ptr = element_ptr->next;
        element_ptr->~MRBQueueElement<T>();
        mrb_free(_mrb, element_ptr);
        if (_first_element_ptr == nullptr)
          _last_element_ptr = nullptr;

        return value;
      }
    }


    void push(T value)
    {
      MRBQueueElement<T>* element_ptr = (MRBQueueElement<T>*)mrb_malloc(_mrb, sizeof(MRBQueueElement<T>));
      new (element_ptr) MRBQueueElement<T>(value);

      if (_last_element_ptr == nullptr)
      {
        _first_element_ptr = element_ptr;
        _last_element_ptr = element_ptr;
      }
      else
      {
        _last_element_ptr->next = element_ptr;
        _last_element_ptr = element_ptr;
      }
    }


    private:

    MRBQueueElement<T>* _first_element_ptr;
    MRBQueueElement<T>* _last_element_ptr;
    mrb_state* _mrb;

  };


}


#endif
