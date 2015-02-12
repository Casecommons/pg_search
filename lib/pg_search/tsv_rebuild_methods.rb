module PgSearch
  class TSVRebuildMethods
    def initialize(config, options)
      @config = config
      @options = options

      if tsvector_column.is_a? Array
        raise ArgumentError, "to use tsvector rebuilders `tsvector_column` must not be Array"
      end

      @instance_method_name = options[:instance_method]
      unless @instance_method_name || @instance_method_name == false
        @instance_method_name = "rebuild_#{tsvector_column}"
      end

      @class_method_name = options[:class_method]
      unless @class_method_name || @class_method_name == false
        @class_method_name = "rebuild_all_#{tsvector_column.to_s.pluralize}"
      end
    end

    def self.for_model(model, options)
      columns = options.delete(:against)
      if columns.blank?
        raise ArgumentError, "you must specify `against` columns for tsvector rebuilders"
      end
      columns = Array.wrap(columns)
      feature_name = options.delete(:type) || :tsearch
      rebuilders_options = options.extract!(:instance_method, :class_method)
      rebuilders_options[:feature_name] = feature_name
      scope_options = {
        :against => columns,
        :using => {
          feature_name => options
        }
      }
      config = Configuration.new(scope_options, model)
      new(config, rebuilders_options)
    end

    def define!
      rebuilder = self
      if instance_method_name
        model.send(:define_method, instance_method_name) do
          rebuilder.rebuild_single(self)
        end
      end
      if class_method_name
        Compatibility.define_singleton_method(model, class_method_name) do
          rebuilder.rebuild_all
        end
      end
      if call_after_save?
        columns_changed_proc = lambda do |object|
          rebuilder.any_column_changed? object
        end
        model.after_save(instance_method_name, :if => columns_changed_proc)
      end
    end

    def any_column_changed?(object)
      columns = build_feature.send(:regular_columns)
      columns.any? { |column| object.send "#{column.name}_changed?" }
    end

    def rebuild_single(object)
      update_part = build_feature.tsvector_update_part
      model.unscoped.where(model.arel_table[model.primary_key].eq(object.id)).update_all(update_part)
    end

    def rebuild_all
      update_part = build_feature.tsvector_update_part
      model.update_all(update_part)
    end

    protected

    attr_reader :config, :options, :instance_method_name, :class_method_name

    def feature_builder
      @feature_builder ||= Features::Builder.new(config)
    end

    def build_feature
      feature_builder.build(feature_name)
    end

    def feature_name
      options[:feature_name]
    end

    def call_after_save?
      options[:call_after_save]
    end

    def tsvector_column
      config.feature_options[feature_name][:tsvector_column]
    end

    def model
      config.model
    end
  end
end
