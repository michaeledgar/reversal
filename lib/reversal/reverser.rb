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
    TRACE_NEWLINE = 1
    TRACE_EXIT = 16
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
            case inst[1]
            when TRACE_NEWLINE, TRACE_EXIT
              # new line
              add_line pop if @stack.any?
            end
          when :dup
            val = pop
            push val
            push val
          when :putobject
            push inst[1].inspect
          when :getlocal
            push locals[inst[1] - 1]
          when :getinstancevariable, :getglobal
            push inst[1]
          when :getspecial
            key, type = inst[1..2]
            if type == 0
              # some weird shit i don't get
            elsif (type & 0x01 > 0)
              push "$#{(type >> 1).chr}"
            else
              push "$#{(type >> 1)}"
            end
          when :getconstant
            push inst[1]
          when :setlocal
            push("#{locals[inst[1] - 1]} = #{pop}")
          when :setinstancevariable
            push("#{inst[1]} = #{pop}")
          when :setglobal
            push("#{inst[1]} = #{pop}")
          when :setconstant
            name = inst[1]
            scoping_arg, value = pop, pop
            push("#{name} = #{value}")
          when :putself
            push "self"
          when :putnil
            push "nil"
            
          ## Strings
          when :putstring
            push "\"#{inst[1]}\""
          when :tostring
            push "(#{pop}).to_s"
          when :concatstrings
            amt = inst[1]
            ret = []
            1.upto(amt) do
              ret.unshift pop
            end
            push ret.join(" + ")
          when :putspecialobject
            # these are for runtime checks - just put the number it asks for, and ignore it
            # later
            push inst[1]
          when :setn
            amt = inst[1]
            val = pop
            @stack[-amt] = val
            push val
          when *OPERATOR_LOOKUP.keys
            arg, receiver = pop, pop
            push "#{receiver} #{OPERATOR_LOOKUP[inst.first]} #{arg}"
          when :opt_aref
            key, receiver = pop, pop
            push "#{receiver}[#{key}]"
          when :opt_aset
            new_val, key, receiver = pop, pop, pop
            push "#{receiver}[#{key}] = #{new_val}"
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
            if meth == :[]=
              result = "#{receiver}[#{args[0]}] = #{args[1]}"
            else
              if (receiver == "nil")
                result = "#{meth}"
              else
                result = "#{receiver}.#{meth}"
              end
              result << (args.any? ? "(#{args.join(", ")})" : "")
            end
            push result
          when :leave
            add_line pop if iseq.type == :top && @stack.any?
          end
        end
        instruction += 1
      end
    end
    
  end
end