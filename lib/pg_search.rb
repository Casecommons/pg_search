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
              :match => query
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
        options = options_proc.call(*args).reverse_merge(:using => :tsearch)

        raise ArgumentError, "the search scope #{name} must have :against in its options" unless options[:against]

        matches_concatenated = Array.wrap(options[:against]).map do |match|
          "coalesce(#{quoted_table_name}.#{connection.quote_column_name(match)}, '')"
        end.join(" || ' ' || ")

        conditions_hash = {
          :tsearch => "to_tsvector('simple', #{matches_concatenated}) @@ plainto_tsquery('simple', :match)",
          :trigram => "(#{matches_concatenated}) % :match"
        }

        conditions = Array.wrap(options[:using]).map do |feature|
          "(#{conditions_hash[feature]})"
        end.join(" OR ")

        {:conditions => [conditions, {:match => options[:match]}]}
      })
    end
  end
end
