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
    
    attr_accessor :locals, :parent, :indent
    
    def initialize(iseq, parent=nil)
      @iseq = ISeq.new(iseq)
      @iseq.validate!
      
      @parent = parent
      reset!
    end
    
    def reset!
      @output = []
      @indent ||= 0
      
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
    # Handle a send instruction in the bytecode
    def do_send(meth, argc, blockiseq, op_flag, ic, receiver = nil)
      # [:send, meth, argc, blockiseq, op_flag, inline_cache]
      args = popn(argc)
      receiver ||= pop
      receiver = :implicit if receiver == "nil"
      
      if meth == :[]=
        result = "#{receiver}[#{args[0]}] = #{args[1]}"
      elsif OPERATOR_LOOKUP.values.include?(meth.to_s)
        # did an operator sneak by as receiver.=~(arg) or something?
        result = "#{receiver} #{meth} #{args.first}"
      else
        result = meth.to_s
        result = "#{receiver}.#{result}" if receiver != :implicit
        result << (args.any? ? "(#{args.join(", ")})" : "")
      end
      
      # handle if it has a block
      if blockiseq
        # make a new reverser with a parent (for dynamic var lookups)
        reverser = Reverser.new(blockiseq, self)
        reverser.indent = @indent
        result << reverser.decompile
      end
      
      push result
    end
    
    OPERATOR_LOOKUP = {:opt_plus => "+", :opt_minus => "-", :opt_mult => "*", :opt_div => "/",
                       :opt_mod => "%", :opt_eq => "==", :opt_neq => "!=", :opt_lt => "<",
                       :opt_le => "<=", :opt_gt => ">", :opt_ge => ">=", :opt_ltlt => "<<",
                       :opt_regexpmatch2 => "=~"}
    TRACE_NEWLINE = 1
    TRACE_EXIT = 16
    def decompile_body(iseq, instruction = 0)
      instruction = 0
      # locals we'll use
      @locals = (iseq.locals + [:self]).reverse
      
      labels = {}
      # for now, using non-idiomatic while loop bc of a chance we might need to
      # loop back
      while instruction < iseq.body.size do
        inst = iseq.body[instruction]
        case inst
        when Integer
          # x
          @current_line = inst
        when Symbol
          # :label_y
          labels[inst] = instruction
        when Array
          case inst.first
          when :trace
            # [:trace, flag_num]
            case inst[1]
            when TRACE_NEWLINE, TRACE_EXIT
              # new line
              add_line pop if @stack.any?
            end
          when :dup
            # [:dup]
            val = pop
            push val
            push val
          when :putobject
            # [:putobject, literal]
            push inst[1].inspect
          when :getlocal
            # [:getlocal, local_num]
            push get_local(inst[1])
          when :getinstancevariable, :getglobal, :getconstant
            # [:getinstancevariable, :ivar_name_as_symbol]
            # [:getglobal, :global_name_as_symbol]
            # [:getconstant, :constant_name_as_symbol]
            push inst[1]
          when :getdynamic
            push get_dynamic(inst[1], inst[2])
          when :getspecial
            key, type = inst[1..2]
            if type == 0
              # some weird shit i don't get
            elsif (type & 0x01 > 0)
              push "$#{(type >> 1).chr}"
            else
              push "$#{(type >> 1)}"
            end
          when :setlocal
            # [:setlocal, local_num]
            push("#{locals[inst[1] - 1]} = #{pop}")
          when :setinstancevariable, :setglobal
            # [:setinstancevariable, :ivar_name_as_symbol]
            # [:setglobal, :global_name_as_symbol]
            push("#{inst[1]} = #{pop}")
          when :setconstant
            # [:setconstant, :const_name_as_symbol]
            name = inst[1]
            scoping_arg, value = pop, pop
            push("#{name} = #{value}")
          when :putself
            # [:putself]
            push "self"
          when :putnil
            # [:putnil]
            push "nil"
          ## Strings
          when :putstring
            # [:putstring, "the string to push"]
            push "\"#{inst[1]}\""
          when :tostring
            # [:tostring]
            push "(#{pop}).to_s"
          when :concatstrings
            # [:concatstrings, num_strings_to_pop_and_join]
            amt = inst[1]
            push pop(amt).join(" + ")
          when :putspecialobject
            # these are for runtime checks - just put the number it asks for, and ignore it
            # later
            push inst[1]
          when :setn
            # [:setn, num_to_move]
            amt = inst[1]
            val = pop
            @stack[-amt] = val
            push val
          when *OPERATOR_LOOKUP.keys
            # [:opt_#type]
            arg, receiver = pop, pop
            push "#{receiver} #{OPERATOR_LOOKUP[inst.first]} #{arg}"
          when :opt_aref
            # [:opt_aref]
            key, receiver = pop, pop
            push "#{receiver}[#{key}]"
          when :opt_aset
            # [:opt_aset]
            new_val, key, receiver = pop, pop, pop
            push "#{receiver}[#{key}] = #{new_val}"
          when :opt_not
            # [:opt_not]
            receiver = pop
            push "!#{receiver}"
          when :opt_length
            # [:opt_length]
            receiver = pop
            push "#{receiver}.length"
          when :opt_succ
            # [:opt_succ]
            receiver = pop
            push "#{receiver}.succ"
          when :invokesuper
            do_send :super, inst[1], inst[2], inst[3], inst[4], :implicit
          when :invokeblock
            do_send :yield, inst[1], nil, inst[2], nil, :implicit
          when :send
            # [:send, meth, argc, blockiseq, op_flag, inline_cache]
            do_send *inst[1..-1]
          when :leave
            # [:leave]
            add_line pop if iseq.type != :method && @stack.any?
          end
        end
        instruction += 1
      end
    end
    
  end
end