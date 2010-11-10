require "active_record"

module PgSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def pg_search_scope(name, matches)
      column_names = Array.wrap(matches).map do |column_name|
        "#{quoted_table_name}.#{connection.quote_column_name(column_name)}"
      end.join(" || ")

      conditions = "to_tsvector('simple', #{column_names}) @@ plainto_tsquery('simple', :query)"

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
