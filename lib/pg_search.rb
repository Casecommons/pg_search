require "active_record"

module PgSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def pg_search_scope(name, matches)
      options_proc = case matches
        when Proc
          matches
        else
          lambda { |query|
            {
              :query => query,
              :matches => matches
            }
          }
      end

      scope_method = if self.respond_to?(:scope) && !protected_methods.include?('scope')
                       :scope
                     else
                       :named_scope
                     end

      send(scope_method, name, lambda { |*args|
        options = options_proc.call(*args)

        matches_concatenated = Array.wrap(options[:matches]).map do |match|
          "coalesce(#{quoted_table_name}.#{connection.quote_column_name(match)}, '')"
        end.join(" || ' ' || ")

        conditions = "to_tsvector('simple', #{matches_concatenated}) @@ plainto_tsquery('simple', :query)"

        {
          :conditions => [conditions, {:query => options[:query]}]
        }
      })
    end
  end
end
