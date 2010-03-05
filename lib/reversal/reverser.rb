##
# reversal.rb: Reverser dispatcher for different types of decompilable code.
# 
#
# Copyright 2010 Michael J. Edgar, michael.j.edgar@dartmouth.edu
#
# MIT License, see LICENSE file in gem package

module Reversal
  class Reverser
    TAB_SIZE = 2
    
    def initialize(iseq)
      @iseq = ISeq.new(iseq)
      @iseq.validate!
      
      @output = []
      @indent = 0
      
      @current_line = 0
      @stack = []
    end
    
    def indent!
      @indent += TAB_SIZE
    end
    
    def outdent!
      @indent = [0, @indent - TAB_SIZE].max
    end
    
    ##
    # Adds a line with the proper indentation
    def add_line(line)
      @output << (" " * @indent) + line.to_s
    end
    
    ##
    # Pushes a node onto the stack, as a decompiled string
    def push(str)
      @stack.push str
    end
    
    ##
    # Pops a node from the stack, as a decompiled string
    def pop
      if @stack.empty?
        raise "Popped an empty stack"
      end
      @stack.pop
    end
    
    # include specific modules for different reversal techniques
    def decompile
      # dispatch on the iseq type
      self.__send__("decompile_#{@iseq.type}".to_sym, @iseq)
      @output.join("\n")
    end
    
    def decompile_method(iseq)
      top_line = "def #{iseq.name}"
      if iseq.stats[:arg_size] > 0
        args_to_use = iseq.locals[0...iseq.args]
        args = "(" + args_to_use.map {|x| x.to_s}.join(", ") + ")"
      else
        args = ""
      end
      add_line("def #{iseq.name}#{args}")
      indent!
      decompile_body(iseq)
      outdent!
      add_line("end")
    end
    
    ##
    # If it's just top-level code, then there are no args - just decompile
    # the body straight away
    def decompile_top(iseq)
      decompile_body(iseq)
    end
    
    OPERATOR_LOOKUP = {:opt_plus => "+", :opt_minus => "-", :opt_mult => "*", :opt_div => "/",
                       :opt_mod => "%", :opt_eq => "==", :opt_neq => "!=", :opt_lt => "<",
                       :opt_le => "<=", :opt_gt => ">", :opt_ge => ">=", :opt_ltlt => "<<"}
    
    def decompile_body(iseq, instruction = 0)
      instruction = 0
      # locals we'll use
      locals = iseq.locals + [:self]
      locals.reverse!
      # for now, using non-idiomatic while loop bc of a chance we might need to
      # loop back
      while instruction < iseq.body.size do
        inst = iseq.body[instruction]
        case inst
        when Integer
          @current_line = inst
        when Symbol
          # a label here... don't use yet
        when Array
          case inst.first
          when :trace
          when :dup
            val = pop
            push val
            push val
          when :putobject
            push inst[1].inspect
          when :getlocal
            push locals[inst[1] - 1]
          when :getinstancevariable
            push inst[1]
          when :setlocal
            add_line("#{locals[inst[1] - 1]} = #{pop}")
          when :setinstancevariable
            add_line("#{inst[1]} = #{pop}")
          when :putself
            push "self"
          when :putnil
            push "nil"
          when *OPERATOR_LOOKUP.keys
            arg = pop
            receiver = pop
            push "#{receiver} #{OPERATOR_LOOKUP[inst.first]} #{arg}"
          when :send
            meth, argc, blockiseq, op_flag, ic = inst[1..-1]
            
            # args are popped first, in reverse order
            # (receiver.call(arg1, arg2, arg3)) will have a stack:
            # receiver
            # arg1   |
            # arg2   |
            # arg3   v
            # (growing downward)
            args = []
            1.upto(argc) do
              args.unshift pop
            end
            
            receiver = pop
            if (receiver == "nil")
              result = "#{meth}"
            else
              result = "#{receiver}.#{meth}"
            end
            
            result << "(#{args.join(",")})"
            push result
          when :leave
            add_line pop
          end
        end
        instruction += 1
      end
    end
    
  end
end