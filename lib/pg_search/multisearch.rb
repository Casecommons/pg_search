module PgSearch
  module Multisearch
    autoload :Rebuilder, "pg_search/multisearch/rebuilder"

    class << self
      def rebuild(model, clean_up=true, document_model=nil)
        run = lambda { |doc_model|
          model.transaction do
            doc_model.where(:searchable_type => model.name).delete_all if clean_up
            Rebuilder.new(model, Time.method(:now), doc_model).rebuild
          end
        }

        if document_model.nil?
          model.pg_search_multisearchable_options.each do |klass, options|
            run.call(klass.constantize)
          end
        else
          run.call(document_model)
        end
      end
    end

    class ModelNotMultisearchable < StandardError
      def initialize(model_class)
        @model_class = model_class
      end

      def message
        "#{@model_class.name} is not multisearchable. See PgSearch::ClassMethods#multisearchable"
      end
    end
  end
end


