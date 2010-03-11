module Reversal
  class Sexp < Array
    def type
      self.first
    end
    def body
      self[1..-1]
    end

    def simple?
      ![:infix, :if, :else, :send, :setvar, :aset].include?(self.type)
    end

    def nil?
      self.type == :nil
    end

    def true?
      self.type == :lit && self[1] == true
    end

    def fixnum?
      self.type == :lit && self[1].is_a?(Fixnum)
    end

    def to_s
      if self.respond_to?("to_s_#{self.type}".to_sym)
        send("to_s_#{self.type}".to_sym)
      else
        super
      end
    end

    ####### to_s methods #########
    def to_s_lit
      # [:lit, 5]
      self[1].inspect
    end

    def to_s_getvar
      # [:getvar, :HELLO]
      # [:getvar, :@hello]
      self[1].to_s
    end

    def to_s_setvar
      "#{self[1]} = #{self[2]}"
    end

    def to_s_splat
      "*#{self[1]}"
    end

    def to_s_range
      start, stop, flag = self[1..-1]
      if flag # inclusive?
        "(#{start}..#{stop})"
      else
        "(#{start}...#{stop})"
      end
    end

    def to_s_infix
      operator, args  = self[1], self[2]
      need_parens = (args.all? {|x| x.is_a?(Sexp) && x.simple?})
      if need_parens
        args.map {|a| a.to_s}.join(" #{operator} ")
      else
        "(" + args.map {|a| a.to_s}.join(" #{operator} ") + ")"
      end
    end

    def to_s_hash
      list = self[1]
      list.map! {|(k, v)| "#{k} => #{v}" }
      "{#{list.join(', ')}}"
    end

    def to_s_nil
      "nil"
    end

    def to_s_not
      "!#{self[1]}"
    end

    def to_s_aref
      "#{self[1]}[#{self[2]}]"
    end

    def to_s_aset
      "#{self[1]}[#{self[2]}] = #{self[3]}"
    end
  end
end

module Kernel
  def r(*args)
    Reversal::Sexp.new(args)
  end
end