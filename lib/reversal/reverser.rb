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
      @locals = (@iseq.locals + [:self]).reverse
      reset!
    end
    
    def reset!
      @output = []
      @indent ||= 0
      
      @current_line = 0
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
    # Adds a line with the proper indentation
    def add_line(line, indent = true)
      @output << (" " * @indent) + line.to_s if indent
      @output << line.to_s                   unless indent
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
      end
      if n == 1
        @stack.pop
      else
        popn(n)
      end
    end
    
    def popn(n = 1)
      ret = []
      1.upto(n) { ret.unshift pop }
      ret
    end
    
    def string_wrap(string, left, right)
      "#{left}#{string}#{right}"
    end
    
    # include specific modules for different reversal techniques
    def decompile
      reset!
      # dispatch on the iseq type
      self.__send__("decompile_#{@iseq.type}".to_sym, @iseq) do
        decompile_body @iseq
      end
      @output.join("\n")
    end
    
    def indented
      indent!
      yield
      outdent!
    end
    
    def wrap_and_indent(top, bottom)
      add_line top
      indented do
        yield
      end
      add_line bottom
    end
    
    def decompile_block(iseq)
      args = iseq.argstring
      args = string_wrap(args, "|", "|") if iseq.stats[:arg_size] > 0
      add_line(" do #{args}", false)
      indented do
        yield iseq
      end
      add_line "end"
    end
    
    def decompile_method(iseq)
      args = iseq.argstring
      args = string_wrap(args, "(", ")") if iseq.stats[:arg_size] > 0
      wrap_and_indent("def #{iseq.name}#{args}", "end") do
        yield iseq
      end
    end
    
    ##
    # If it's just top-level code, then there are no args - just decompile
    # the body straight away
    def decompile_top(iseq)
      yield iseq
    end
    
    ##
    # If it's just top-level code, then there are no args - just decompile
    # the body straight away
    def decompile_class(iseq)
      yield iseq
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
        #puts "Instruction #{instruction} #{inst.inspect} #{@stack.inspect}"
        case inst
        when Integer
          # x
          @current_line = inst
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
      @stack.each {|x| add_line x}
    end
    
  end
end