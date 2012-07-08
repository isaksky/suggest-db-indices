module SuggestDbIndices
  # Learnings from Clojure for make great benefit ruby
  module Clojure
    class << self
      # Get multiple keys, e.g.,
      # h = {:b => {:a => 5}}
      # Clojure.get_in(h, [:b, :a]) # => 5
      # Clojure.get_in(h, [:b, :a, :c]) # => nil
      # Clojure.get_in(h, [:b, :a, :c], 1) # => 1
      def get_in enumerable, keys, default = nil
        current = enumerable
        while key = keys.shift
          unless current.is_a? Enumerable
            current = nil
            break
          end
          current = current[key]
        end
        current || default
      end
    end
  end
end
