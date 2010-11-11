require "active_record"

module PgSearch
  def self.included(base)
    base.send(:extend, ClassMethods)
  end

  module ClassMethods
    def pg_search_scope(name, options)
      options_proc = case options
        when Proc
          options
        when Hash
          lambda { |query|
            options.reverse_merge(
              :query => query
            )
          }
        else
          raise ArgumentError, "#{__method__} expects a Proc or Hash for its options"
      end

      scope_method = if self.respond_to?(:scope) && !protected_methods.include?('scope')
                       :scope
                     else
                       :named_scope
                     end

      send(scope_method, name, lambda { |*args|
        options = options_proc.call(*args).reverse_merge(:using => :tsearch, :normalizing => [])
        query = options[:query]

        raise ArgumentError, "the search scope #{name} must have :against in its options" unless options[:against]

        document = Array.wrap(options[:against]).map do |column_name|
          column = "coalesce(#{quoted_table_name}.#{connection.quote_column_name(column_name)}, '')"
          column
        end.join(" || ' ' || ")


        normalized = lambda do |string|
          string = "unaccent(#{string})" if Array.wrap(options[:normalizing]).include?(:diacritics)
          string
        end

        tsquery = query.split(" ").join(" & ")

        normalized_document = normalized[document]
        normalized_query = normalized[":query"]
        normalized_tsquery = normalized[":tsquery"]

        conditions_hash = {
          :tsearch => "to_tsvector('simple', #{normalized_document}) @@ to_tsquery('simple', #{normalized_tsquery})",
          :trigram => "(#{normalized_document}) % #{normalized_query}"
        }

        conditions = Array.wrap(options[:using]).map do |feature|
          "(#{conditions_hash[feature]})"
        end.join(" OR ")

        {:conditions => [conditions, {:query => query, :tsquery => tsquery}]}
      })
    end
  end
end
