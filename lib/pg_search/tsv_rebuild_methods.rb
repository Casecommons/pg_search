module PgSearch
  class TSVRebuildMethods
    def initialize(feature, options)
      @feature = feature
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
      feature_name = options.delete(:type) || :tsearch
      columns = options.delete(:against)
      if columns.blank?
        raise ArgumentError, "you must specify `against` columns for tsvector rebuilders"
      end
      columns = Array.wrap(columns)
      rebuilders_options = options.extract!(:instance_method, :class_method)
      scope_options = {
        :against => columns,
        :using => {
          feature_name => options
        }
      }
      config = Configuration.new(scope_options, model)
      feature_builder = Features::Builder.new(config)
      feature = feature_builder.build(feature_name)
      new(feature, rebuilders_options)
    end

    def define!
      if instance_method_name
        model.send :define_method, instance_method_name, &rebuild_single_proc
      end
      if class_method_name
        Compatibility.define_singleton_method(model, class_method_name, &rebuild_all_proc)
      end
      if call_after_save?
        columns = self.columns
        columns_changed_proc = lambda do |object|
          columns.any? { |column| object.send "#{column.name}_changed?" }
        end
        model.after_save(instance_method_name, :if => columns_changed_proc)
      end
    end

    protected

    attr_reader :feature, :options, :instance_method_name, :class_method_name

    def rebuild_single_proc
      update_part = feature.tsvector_update_part
      model = self.model
      lambda do
        model.unscoped.where(model.arel_table[model.primary_key].eq(id)).update_all(update_part)
      end
    end

    def rebuild_all_proc
      update_part = feature.tsvector_update_part
      lambda do
        update_all(update_part)
      end
    end

    def columns
      feature.send(:regular_columns)
    end

    def call_after_save?
      options[:call_after_save]
    end

    def tsvector_column
      @tsvector_column ||= feature_options[:tsvector_column]
    end

    def feature_options
      @feature_options ||= feature.send(:options)
    end

    def model
      @model ||= feature.send(:model)
    end
  end
end
