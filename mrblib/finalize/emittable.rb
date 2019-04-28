module Finalize

  # {Emittable}s can hold finalizers that will be executed after being destroyed.
  # Typically this class will be subclassed where custom functionality can be added, but
  # it can also be instantiated directly.
  #
  # It is called +Emittable+ as they are able to emit a call when the GC is freeing its data.
  # We take advantage of this by queueing any defined finalizers so they can be executed the
  # next time {Finalize#process} is called.
  #
  # Some methods are prefixed to avoid a name collision with subclasses.
  class Emittable

    # Define a finalizer on the object.
    # The finalizer will be executed when the object had been destroyed and {Finalize#process} is called.
    # @param finalizer [Proc]
    # @raise TypeError if +finalizer+ is not a Proc
    # @raise ArgumentError if the +finalizer+ is already defined on the object
    # @return [void]
    def define_finalizer(finalizer)
      raise TypeError, 'finalizer must be a Proc' unless finalizer.is_a?(Proc)
      _finalize__ensure_finalizers_initialized
      finalizers = _finalize__finalizers
      raise ArgumentError, 'that finalizer is already defined on that object' if finalizers.include?(finalizer)
      finalizers << finalizer
      nil
    end

    # Initializes the data C++ structure that will hold the Ruby and C++ finalizers.
    # @api private
    # @return [void]
    def _finalize__ensure_data_initialized
      unless @_finalize__data_initialized
        _finalize__initialize_data
        @_finalize__data_initialized = true
      end
    end

    # Initializes the +Array+ that will hold the Ruby finalizers.
    # @api private
    # @return [void]
    def _finalize__ensure_finalizers_initialized
      _finalize__ensure_data_initialized
      unless @_finalize__finalizers_initialized
        _finalize__initialize_finalizers
        @_finalize__finalizers_initialized = true
      end
    end

    # Undefine a finalizer on the object.
    # @param finalizer [Proc]
    # @raise TypeError if +finalizer+ is not a Proc
    # @raise ArgumentError if the +finalizer+ is not defined on the object
    # @return [void]
    def undefine_finalizer(finalizer)
      raise TypeError, 'finalizer must be a Proc' unless finalizer.is_a?(Proc)
      _finalize__ensure_finalizers_initialized
      finalizers = _finalize__finalizers
      raise ArgumentError, 'that finalizer is not defined on that object' unless finalizers.include?(finalizer)
      finalizers.delete(finalizer)
      nil
    end

  end

end
