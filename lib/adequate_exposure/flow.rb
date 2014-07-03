module AdequateExposure
  class Flow
    attr_reader :controller, :options
    delegate :params, to: :controller

    def initialize(controller, options)
      @controller, @options = controller, options.with_indifferent_access
    end

    def name
      options.fetch(:name)
    end

    %i[fetch find build scope model id decorate].each do |method_name|
      define_method method_name do |*args|
        ivar_name = "@#{method_name}"
        return instance_variable_get(ivar_name) if instance_variable_defined?(ivar_name)
        instance_variable_set(ivar_name, handle_action(method_name, *args))
      end
    end

    protected

    def default_fetch
      computed_scope = scope(model)
      id ? decorate(find(id, computed_scope)) : decorate(build(computed_scope))
    end

    def default_id
      params["#{name}_id"] || params[:id]
    end

    def default_scope(model)
      model
    end

    def default_model
      name.to_s.classify.constantize
    end

    def default_find(id, scope)
      scope.find(id)
    end

    def default_build(scope)
      scope.new(exposure_params)
    end

    def default_decorate(instance)
      instance
    end

    def exposure_params
      params_method_name = "#{name}_params"

      if controller.respond_to?(params_method_name, true)
        controller.send(params_method_name)
      else
        {}
      end
    end

    private

    def handle_action(name, *args)
      if options.key?(name)
        handle_custom_action(name, *args)
      else
        send("default_#{name}", *args)
      end
    end

    def handle_custom_action(name, *args)
      value = options[name]

      if Proc === value
        args = args.first(value.parameters.length)
        controller.instance_exec(*args, &value)
      else
        fail ArgumentError, "Can't handle #{name.inspect} => #{value.inspect} option"
      end
    end
  end
end
