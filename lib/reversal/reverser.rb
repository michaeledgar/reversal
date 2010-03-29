##
# reversal.rb: Reverser dispatcher for different types of decompilable code.
# 
#
# Copyright 2010 Michael J. Edgar, michael.j.edgar@dartmouth.edu
#
# MIT License, see LICENSE file in gem package

module Reversal
  class Reverser
    OPERATOR_LOOKUP = {:opt_plus => "+", :opt_minus => "-", :opt_mult => "*", :opt_div => "/",
                       :opt_mod => "%", :opt_eq => "==", :opt_neq => "!=", :opt_lt => "<",
                       :opt_le => "<=", :opt_gt => ">", :opt_ge => ">=", :opt_ltlt => "<<",
                       :opt_regexpmatch2 => "=~"}
                       
    # Instructions module depends on OPERATOR_LOOKUP
    include Instructions
    
    TAB_SIZE = 2          
    ALL_INFIX = OPERATOR_LOOKUP.values + ["<=>"]
    attr_accessor :locals, :parent, :indent
    
    def initialize(iseq, parent=nil)
      @iseq = ISeq.new(iseq)
      @iseq.validate!
      
      @parent = parent
      @locals = [:self] + @iseq.locals.reverse
      reset!
    end
    
    def reset!
      @indent ||= 0
      
      @stack = []
      @else_stack = []
      @end_stack  = []
    end
    
    def indent!
      @indent += TAB_SIZE
    end
    
    def outdent!
      @indent = [0, @indent - TAB_SIZE].max
    end
    
    ##
    # Gets a local variable at the given bytecode-style index
    def get_local(idx)
      get_dynamic(idx, 0)
    end
    
    ##
    # Gets a dynamic variable, based on the bytecode-style index and
    # the depth
    def get_dynamic(idx, depth)
      if depth == 0
        @locals[idx - 1]
      elsif @parent
        @parent.get_dynamic(idx, depth - 1)
      else
        raise "Invalid dynamic variable requested: #{idx} #{depth} from #{self.iseq}"
      end
    end 
    
    ##
    # Pushes a node onto the stack, as a decompiled string
    def push(str)
      @stack.push str
    end
    
    ##
    # Pops a node from the stack, as a decompiled string
    def pop(n = 1)
      if @stack.empty?
        raise "Popped an empty stack"
      elsif n == 1
        @stack.pop
      else
        popn(n)
      end
    end
    
    def popn(n = 1)
      (1..n).to_a.map {pop}.reverse
    end
    
    # include specific modules for different reversal techniques
    def to_ir
      reset!
      # dispatch on the iseq type
      self.__send__("decompile_#{@iseq.type}".to_sym, @iseq)
    end
    
    def indented
      indent!
      result = yield
      outdent!
      result
    end

    def indent_str(str)
      begin
        (" " * @indent) + str.to_s
      rescue TypeError
        require 'pp'
        pp str
        raise
        end
    end

    def indent_array(arr)
      arr.map {|x| indent_str x}
    end
    
    def decompile_block(iseq)
      args = iseq.argstring
      args = "|#{args}|" if iseq.stats[:arg_size] > 0
      result = [" do #{args}"]
      indented do
        result.concat indent_array(IRList.new(decompile_body(@iseq)))
      end
      result << indent_str("end")
    end
    
    def decompile_method(iseq)
      args = iseq.argstring
      args = "(#{args})" if iseq.stats[:arg_size] > 0
      result = []
      result << indent_str("def #{iseq.name}#{args}")
      indented do
        result.concat indent_array(IRList.new(decompile_body(@iseq)))
      end
      result << indent_str("end")
    end
    
    ##
    # If it's just top-level code, then there are no args - just decompile
    # the body straight away
    def decompile_top(iseq)
      IRList.new(decompile_body(@iseq))
    end
    
    ##
    # If it's just top-level code, then there are no args - just decompile
    # the body straight away
    def decompile_class(iseq)
      indent_array(IRList.new(decompile_body(@iseq)))
    end
    
    def remove_useless_dup
      pop unless @stack.empty?
    end
    
    TRACE_NEWLINE = 1
    TRACE_EXIT = 16
    
    def forward_jump?(current, label)
      @iseq.labels[label] && @iseq.labels[label] > current
    end
    
    def backward_jump?(current, label)
      !forward_jump?(current, label)
    end
    
    def decompile_body(iseq, instruction = 0, stop = iseq.body.size)
      # for now, using non-idiomatic while loop bc of a chance we might need to
      # loop back
      while instruction < stop do
        inst = iseq.body[instruction]
        #p inst, @stack
        #puts "Instruction #{instruction} #{inst.inspect} #{@stack.inspect}"
        case inst
        when Integer
          # x
          @current_line = inst    # unused
        when Symbol
          # :label_y
          while inst == @end_stack.last do
            @end_stack.pop
            outdent!
            push "end"
          end
        when Array
          # [:instruction, *args]
          # call "decompile_#{instruction}"
          send("decompile_#{inst.first}".to_sym, inst, instruction) if respond_to?("decompile_#{inst.first}".to_sym)
        end
        instruction += 1
      end
      @stack
    end
    
  end
end