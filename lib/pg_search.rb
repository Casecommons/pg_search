require "active_record"

module PgSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def pg_search_scope(name, options)
      matches = options[:matches]
      column_name = "#{quoted_table_name}.#{connection.quote_column_name(matches)}"
      conditions = "to_tsvector('simple', #{column_name}) @@ to_tsquery('simple', :query)"

      scope_method = if self.respond_to?(:scope) && !protected_methods.include?('scope')
                       :scope
                     else
                       :named_scope
                     end
      send(scope_method, name, lambda { |query|
        {
          :conditions => [conditions, {:query => query}]
        }
      })
    end
  end
end
