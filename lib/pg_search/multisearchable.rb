require "active_support/concern"
require "active_support/core_ext/class/attribute"

module PgSearch
  module Multisearchable
    extend ActiveSupport::Concern

    included do
      pg_search_multisearchable_options.each do |klass, options|
        # Define has_one association on including model to klass
        has_one klass.underscore.parameterize('_').to_sym,
          :as => :searchable,
          :class_name => klass.classify,
          :dependent => :delete

        # Declare after_save callback to update search document
        after_save :"update_#{klass.underscore.parameterize('_')}",
          :if => lambda { PgSearch.multisearch_enabled? }
        # Define the method that updates the search document
        define_method(:"update_#{klass.underscore.parameterize('_')}") do
          if_conditions = Array(options[:if])
          unless_conditions = Array(options[:unless])

          should_have_document =
            if_conditions.all? { |condition| condition.to_proc.call(self) } &&
            unless_conditions.all? { |condition| !condition.to_proc.call(self) }

          current_document = send(klass.underscore.parameterize('_').to_sym)

          if should_have_document
            if current_document
              current_document.save
            else
              send(:"create_#{klass.underscore.parameterize('_')}")
            end
          else
            if current_document
              current_document.destroy
            end
          end
        end
      end
    end
  end
end

#force_encoding
