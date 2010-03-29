require 'delegate'
module Reversal
  class IRList < DelegateClass(Array)
    def initialize(list)
      @source = list
      super(@source)
    end

    def indent(amt = 2)
      @source.map! do |item|
        item.to_s.split("\n").map {|x| " " * amt + x.to_s}.join("\n")
      end
    end

    def to_s
      @source.map {|x| x.to_s}.join("\n")
    end
  end
end