module Reversal
  class Sexp < Array
    def initialize(*args)
      super
      if self.respond_to?("post_init_#{self.type}".to_sym)
        send("post_init_#{self.type}".to_sym)
      end
    end

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

    def to_s_array
      "[#{self[1].map {|x| x.to_s}.join(", ")}]"
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

    def post_init_defmethod
      receiver, name, blockiseq, parent = self.body
      name = name.to_s
      # alter name if necessary
      name = name[1..-1] if name[0,1] == ":" # cut off leading :
      name = (receiver.kind_of?(Integer) || receiver.fixnum?) ? "#{name}" : "#{receiver}.#{name}"
      blockiseq[5] = name
      reverser = Reverser.new(blockiseq, parent)
      reverser.indent = 0
      self[3] = reverser.to_ir
    end

    def to_s_defmethod
      blockiseq = self[3]
      blockiseq.map {|x| x.to_s}.join("\n")
    end

    def post_init_send
      blockiseq, parent = self[4], self[5]
      if blockiseq
        reverser = Reverser.new(blockiseq, parent)
        reverser.indent = parent.indent
        self[4] = reverser.to_ir
      end
    end

    def to_s_send
      meth, receiver, args, blockiseq, parent = self.body
      result = meth.to_s
      result = "#{receiver}.#{result}" unless receiver == :implicit
      result << (args.any? ? "(#{args.map {|a| a.to_s}.join(", ")})" : "")

      if blockiseq
        # make a new reverser with a parent (for dynamic var lookups)
        result << blockiseq.map {|x| x.to_s}.join("\n")
      end
      result
    end

    ## classes and modules
    def to_s_defclass
      name, base_as_str, superklass_as_str, ir = self.body
      result = "class #{base_as_str}#{name}#{superklass_as_str}"
      definition = ir.map {|x| x.to_s.split("\n").map {|x| "  " + x}.join("\n")}.join("\n")
      result << "\n#{definition.to_s}\n"
      result << "end"
      result
    end
    def to_s_defmetaclass
      base, ir = self.body
      result = "class << #{base}"
      definition = ir.map {|x| x.to_s.split("\n").map {|x| "  " + x}.join("\n")}.join("\n")
      result << "\n#{definition.to_s}\n"
      result << "end"
      result
    end
    def to_s_defmodule
      name, base, ir = self.body
      result = "module #{base}#{name}"
      definition = ir.map {|x| x.to_s.split("\n").map {|x| "  " + x}.join("\n")}.join("\n")
      result << "\n#{definition.to_s}\n"
      result << "end"
      result
    end
  end
end

module Kernel
  def r(*args)
    Reversal::Sexp.new(args)
  end
end