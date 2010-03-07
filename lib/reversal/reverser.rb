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
      @locals = (@iseq.locals + [:self]).reverse
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
    # If it's just top-level code, then there are no args - just decompile
    # the body straight away
    def decompile_class(iseq)
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
    def decompile_body(iseq, instruction = 0, stop = iseq.body.size)
      labels = {}
      # for now, using non-idiomatic while loop bc of a chance we might need to
      # loop back
      while instruction < stop do
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
          #############################
          ###### Variable Lookup ######
          #############################
          
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
            
          #############################
          ##### Variable Assignment ###
          #############################
          
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
            
          ###################
          ##### Strings #####
          ###################
          
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
          
          ##################
          ### Arrays #######
          ##################
          when :duparray
            # [:duparray, [array, here]]
            push inst[1]
          when :newarray
            # [:newarray, num_to_pop]
            arr = popn(inst[1])
            push("[#{arr.join(", ")}]")
          when :splatarray
            # [:splatarray]
            push "*#{pop}"
          when :concatarray
            # [:concatarray, ignored_boolean_flag]
            arg, receiver = pop, pop
            receiver = receiver[1..-1] if (receiver[0, 1]) == "*"
            push "(#{receiver} + #{arg})"
            
          ###################
          ### Ranges ########
          ###################
          when :newrange
            # [:newrange, exclusive_if_1]
            last, first = pop, pop
            exclusive = (inst[1] == 1)
            result = exclusive ? "(#{first}...#{last})" : "(#{first}..#{last})"
            push result
            
          ##############
          ## Hashes ####
          ##############
          when :newhash
            # [:newhash, number_to_pop]
            list = []
            0.step(inst[1] - 2, 2) do
              list.unshift [pop, pop].reverse
            end
            list.map! {|(k, v)| "#{k} => #{v}" }
            push "{#{list.join(', ')}}"
          
          #######################
          #### Weird Stuff ######
          #######################
          when :putspecialobject
            # these are for runtime checks - just put the number it asks for, and ignore it
            # later
            push inst[1]
            
          ############################
          ##### Stack Manipulation ###
          ############################
          when :setn
            # [:setn, num_to_move]
            amt = inst[1]
            val = pop
            @stack[-amt] = val
            push val
          when :dup
            # [:dup]
            val = pop
            push val
            push val
          when :putobject
            # [:putobject, literal]
            push inst[1].inspect
          when :putself
            # [:putself]
            push "self"
          when :putnil
            # [:putnil]
            push "nil"
          when :swap
            a, b = pop, pop
            push b
            push a
          # when :pop
          #   pop
            
          ####################
          #### Operators #####
          ####################
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
            
          ##############################
          ##### Method Dispatch ########
          ##############################
          when :invokesuper
            do_send :super, inst[1], inst[2], inst[3], inst[4], :implicit
          when :invokeblock
            do_send :yield, inst[1], nil, inst[2], nil, :implicit
          when :send
            # [:send, meth, argc, blockiseq, op_flag, inline_cache]
            do_send *inst[1..-1]
          
          #######################
          ##### Control Flow ####
          #######################
          when :throw
            # [:throw, level | state]
            # state: 0x01 = return
            #        0x02 = break
            #        0x03 = next
            #        0x04 = "retry" (rescue?)
            #        0x05 = redo
            throw_state = inst[1]
            # not sure what good these all are for decompiling. interesting though.
            state = throw_state & 0xff
            flag  = throw_state & 0x8000
            level = throw_state >> 16
            case state
            when 0x01
              push "return #{pop}"
            when 0x02
              push "break #{pop}"
            when 0x03
              push "next #{pop}"
            when 0x04
              pop #useless nil
              push "retry"
            when 0x05
              pop #useless nil
              push "redo"
            end
          
          #############################
          ###### Classes/Modules ######
          #############################
          when :defineclass
            name, new_iseq, type = inst[1..-1]
            superklass, base = pop, pop
            superklass_as_str = (superklass == "nil" ? "" : " < #{superklass}")
            new_reverser = Reverser.new(new_iseq, self)
            case type
            when 0 # class
              wrap_and_indent("class #{name}#{superklass_as_str}", "end") do
                add_line new_reverser.decompile
              end
            when 1
              wrap_and_indent("class << #{base}", "end") do
                add_line new_reverser.decompile
              end
            when 2
              wrap_and_indent("module #{name}", "end") do
                add_line new_reverser.decompile
              end
            end
          
          #########################
          ##### Tracing ###########
          #########################
          when :trace
            # [:trace, flag_num]
            case inst[1]
            when TRACE_NEWLINE, TRACE_EXIT
              # new line
              add_line pop if @stack.any?
            end
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