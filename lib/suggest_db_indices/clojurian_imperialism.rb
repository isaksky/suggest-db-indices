# Learnings from Clojure for make great benefit ruby

module Enumerable
  # E.g., {:foo => {:bar => 5}}.get_in(:foo, :bar) #=> 5
  def get_in keys, default = nil
    v = self[keys.first]
    rest = keys.drop 1
    if rest.any?
      v.get_in rest, default
    else
      v ? v : default
    end
  rescue NoMethodError => ex
    default
  end
end
