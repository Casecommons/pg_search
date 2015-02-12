module PgSearch
  class ScopeBuilder
    def initialize(model, name, options)
      @model = model
      @name = name
      @options = options
    end

    def define!
      options_proc = if options.respond_to?(:call)
                       options
                     else
                       unless options.respond_to?(:merge)
                         raise ArgumentError, "pg_search_scope expects a Hash or Proc"
                       end
                       lambda { |query| {:query => query}.merge(options) }
                     end

      name = self.name

      model.class_eval do
        method_proc = lambda do |*args|
          config = Configuration.new(options_proc.call(*args), self)
          scope_options = ScopeOptions.new(config)
          scope_options.apply(self)
        end
        Compatibility.define_singleton_method(self, name, &method_proc)
      end
      define_tsvector_rebuilders!
    end

    def define_tsvector_rebuilders!
      if options.is_a? Hash
        [:tsearch, :dmetaphone].each do |feature_name|
          if config.feature? feature_name
            define_tsvector_rebuilder(feature_name)
          end
        end
      end
    end

    protected

    attr_reader :model, :name, :options

    def config
      @config ||= Configuration.new(options, model)
    end

    def scope_options
      @scope_options ||= ScopeOptions.new(config)
    end

    def define_tsvector_rebuilder(feature_name)
      feature_options = config.feature_options[feature_name]
      return unless feature_options
      rebuilders_options = feature_options[:tsvector_rebuilders]
      return unless rebuilders_options
      rebuilders_options = if rebuilders_options.is_a? Hash
                             rebuilders_options = rebuilders_options.dup
                           else
                             {}
                           end
      rebuilders_options[:feature_name] = feature_name
      TSVRebuildMethods.new(config, rebuilders_options).define!
    end
  end
end
