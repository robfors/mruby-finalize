# Assign non-preemptive finalizers to most objects and execute when ready.
module Finalize

  # a lock to prevent {::process} from being called inside a finalizer
  @executing = false

  # a lock to prevent {::process} from working after an uncaught error is raised in a finalizer
  @error_raised = false

  # a queue of the finalizers from destroyed objects, that are ready to be executed
  @queued_finalizers = QueuedFinalizers.new

  # Attach an {Emittable} to an object or retrieve an existing one.
  # @api private
  # @param object [Object] to attach {Emittable} to
  # @raise TypeError if a {Finalize::Emittable} can not be attached
  # @return [Emittable]
  def self.attach_emittable(object)
    emittable = Attribute.get(object, :_finalize__emittable)
    unless emittable
      emittable = Emittable.new(object)

      # point the object to the Finalize::Emittable
      unless Attribute.set(object, :_finalize__emittable, emittable)
        raise TypeError, "can not attach a Finalize::Emittable to an #{object.class}"
      end

      # point the Finalize::Emittable to the object
      emittable.instance_variable_set(:@object, object)
    end
    emittable
  end

  # Define a finalizer on an object.
  # The finalizer will be executed when the object had been destroyed and {#process} is called.
  # If the object is not a {Finalize::Emittable}, one will be attached and the finalizer will be
  # defined on it instead. We call this an indirect finalizer. It should be noted that indirect
  # finalizers may be called shortly before or after the given object is actually destroyed.
  # However, this behaviour is considered insignificant for the Ruby api. The C/C++ api offers
  # tighter control over this behaviour if needed.
  # @param object [Object]
  # @param finalizer [Proc]
  # @raise TypeError if the object does not support finalizers
  # @raise TypeError if +finalizer+ is not a Proc
  # @raise ArgumentError if the +finalizer+ is already defined on the object
  # @return [void]
  def self.define_finalizer(object, finalizer)
    object = get_definable_object(object)
    object.define_finalizer(finalizer)
    nil
  end

  # Gets an object that supports finalizers directly.
  # If the passed object does not, an attached one will retrieved or created for the object.
  # @api private
  # @param object [Object]
  # @raise TypeError if the object does not support finalizers
  # @return [Emittable] the given object or one that support finalizers directly
  def self.get_definable_object(object)
    begin
      object = attach_emittable(object) unless object.is_a?(Emittable)
    rescue TypeError
      raise TypeError, "a #{object.class} does not support finalizers"
    end
    object
  end

  # Executes all finalizers on the objects that have been destroyed since the last call.
  # @note it doesn't make sense to catch errors raised by finalizers, as such, uncaught errors are
  #   assumed to be fatal in order to simplify the codebase
  # @raise Exception if a finalizer raised an uncaught error during this call 
  # @raise RuntimeError if a finalizer raised an uncaught error during a previous call
  # @raise RuntimeError if called within a finalizer
  # @return [void]
  def self.process
    raise RuntimeError, 'error was raised in a finalizer, finalizers can not be processed anymore' if @error_raised == true
    raise RuntimeError, 'can not call Finalize::process within a finalizer' if @executing == true
    @executing = true
    loop do
      queued_finalizers = @queued_finalizers.pop
      break unless queued_finalizers
      begin
        queued_finalizers.each(&:call)
      rescue
         @error_raised = true
        raise Exception, 'error raised in a finalizer'
      end
    end
    nil
  ensure
    @executing = false
  end

  # Undefine a finalizer on an object.
  # @param object [Object]
  # @param finalizer [Proc]
  # @raise ArgumentError if the +finalizer+ is not defined on the object
  # @raise TypeError if +finalizer+ is not a Proc
  # @return [void]
  def self.undefine_finalizer(object, finalizer)
    object = get_definable_object(object)
    object.undefine_finalizer(finalizer)
    nil
  end

end
