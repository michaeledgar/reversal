module Reversal
  module Instructions
    ##
    # Handle a send instruction in the bytecode
    def do_send(meth, argc, blockiseq, op_flag, ic, receiver = nil)
      # [:send, meth, argc, blockiseq, op_flag, inline_cache]
      args = popn(argc)
      receiver ||= pop
      receiver = :implicit if receiver == "nil"
      result = ""
      
      # Weird special case, as far as syntax goes.
      if meth == :[]=
        result = "#{receiver}[#{args[0]}] = #{args[1]}"
        # Useless duplication of assigned value means we need to pop it
        remove_useless_dup
      # If it's an infix method, make it look pretty.
      elsif Reverser::ALL_INFIX.include?(meth.to_s)
        # did an operator sneak by as receiver.=~(arg) or something?
        result = "#{receiver} #{meth} #{args.first}"
      # define_method is a little bit special - it's what's used when you do "def"
      elsif meth == :"core#define_method" || meth == :"core#define_singleton_method"
        # args will be [iseq, name, receiver, scope_arg]
        receiver, name, blockiseq = args
        # alter name if necessary
        name = name[1..-1] if name[0,1] == ":" # cut off leading :
        name = receiver.kind_of?(Integer) ? "#{name}" : "#{receiver}.#{name}"
        blockiseq[5] = name
      # normal method call
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
    
    def do_super(argc, blockiseq, op_flag)
      args = popn(argc)
      explicit_args = (pop == "true")
      
      if explicit_args then result = "super(#{args.join(", ")})"
      else result = "super"
      end
      
      if blockiseq
        # make a new reverser with a parent (for dynamic var lookups)
        reverser = Reverser.new(blockiseq, self)
        reverser.indent = @indent
        result << reverser.decompile
      end
      
      push result
    end
    
    #############################
    ###### Variable Lookup ######
    #############################
    def decompile_getlocal(inst, line_no)
      push get_local(inst[1])
    end
    
    def decompile_getinstancevariable(inst, line_no)
      push inst[1]
    end
    alias_method :decompile_getglobal, :decompile_getinstancevariable
    
    def decompile_getconstant(inst, line_no)
      base = pop
      base_str = base == "nil" ? "" : "#{base}::"
      push "#{base_str}#{inst[1]}"
    end
    
    def decompile_getdynamic(inst, line_no)
      push get_dynamic(inst[1], inst[2])
    end
    
    def decompile_getspecial(inst, line_no)
      key, type = inst[1..2]
      if type == 0
        # some weird shit i don't get
      elsif (type & 0x01 > 0)
        push "$#{(type >> 1).chr}"
      else
        push "$#{(type >> 1)}"
      end
    end
    
    #############################
    ##### Variable Assignment ###
    #############################
    def decompile_setlocal(inst, line_no)
      # [:setlocal, local_num]
      result = "#{locals[inst[1] - 1]} = #{pop}"
      # for some reason, there seems to cause a :dup instruction to be inserted that fucks
      # everything up. So i'll pop the return value.
      remove_useless_dup
      push(result)
    end
      
    def decompile_setinstancevariable(inst, line_no)
      # [:setinstancevariable, :ivar_name_as_symbol]
      # [:setglobal, :global_name_as_symbol]
      result = "#{inst[1]} = #{pop}"
      # for some reason, there seems to cause a :dup instruction to be inserted that fucks
      # everything up. So i'll pop the return value.
      remove_useless_dup
      push result
    end
    alias_method :decompile_setglobal, :decompile_setinstancevariable
      
    def decompile_setconstant(inst, line_no)
      # [:setconstant, :const_name_as_symbol]
      name = inst[1]
      scoping_arg, value = pop, pop
      # for some reason, there seems to cause a :dup instruction to be inserted that fucks
      # everything up. So i'll pop the return value.
      remove_useless_dup
      push("#{name} = #{value}")
    end
    
    
    ###################
    ##### Strings #####
    ###################
    def decompile_putstring(inst, line_no)
      push "\"#{inst[1]}\""
    end
    
    def decompile_tostring(inst, line_no)
      push "(#{pop}).to_s"
    end
    
    def decompile_concatstrings(inst, line_no)
      amt = inst[1]
      push pop(amt).join(" + ")
    end
    
    ##################
    ### Arrays #######
    ##################
    
    def decompile_duparray(inst, line_no)
      push inst[1]
    end
    
    
    def decompile_newarray(inst, line_no)
      # [:newarray, num_to_pop]
      arr = popn(inst[1])
      push("[#{arr.join(", ")}]")
    end
    def decompile_splatarray(inst, line_no)
      # [:splatarray]
      push "*#{pop}"
    end
    def decompile_concatarray(inst, line_no)
      # [:concatarray, ignored_boolean_flag]
      arg, receiver = pop, pop
      receiver = receiver[1..-1] if (receiver[0, 1]) == "*"
      push "(#{receiver} + #{arg})"
    end
      
    ###################
    ### Ranges ########
    ###################
    def decompile_newrange(inst, line_no)
      # [:newrange, exclusive_if_1]
      last, first = pop, pop
      exclusive = (inst[1] == 1)
      result = exclusive ? "(#{first}...#{last})" : "(#{first}..#{last})"
      push result
    end
      
    ##############
    ## Hashes ####
    ##############
    def decompile_newhash(inst, line_no)
      # [:newhash, number_to_pop]
      list = []
      0.step(inst[1] - 2, 2) do
        list.unshift [pop, pop].reverse
      end
      list.map! {|(k, v)| "#{k} => #{v}" }
      push "{#{list.join(', ')}}"
    end
    
    #######################
    #### Weird Stuff ######
    #######################
    def decompile_putspecialobject(inst, line_no)
      # these are for runtime checks - just put the number it asks for, and ignore it
      # later
      push inst[1]
    end
      
      
    def decompile_putiseq(inst, line_no)
      push inst[1]
    end
      
    ############################
    ##### Stack Manipulation ###
    ############################
    def decompile_setn(inst, line_no)
      # [:setn, num_to_move]
      amt = inst[1]
      val = pop
      @stack[-amt] = val
      push val
    end
    def decompile_dup(inst, line_no)
      # [:dup]
      val = pop
      push val
      push val
    end
    def decompile_putobject(inst, line_no)
      # [:putobject, literal]
      push inst[1].inspect
    end
    def decompile_putself(inst, line_no)
      # [:putself]
      push "self"
    end
    def decompile_putnil(inst, line_no)
      # [:putnil]
      push "nil"
    end
    def decompile_swap(inst, line_no)
      a, b = pop, pop
      push b
      push a
    end
    def decompile_opt_aref(inst, line_no)
      # [:opt_aref]
      key, receiver = pop, pop
      push "#{receiver}[#{key}]"
    end
    def decompile_opt_aset(inst, line_no)
      # [:opt_aset]
      new_val, key, receiver = pop, pop, pop
      push "#{receiver}[#{key}] = #{new_val}"
    end
    def decompile_opt_not(inst, line_no)
      # [:opt_not]
      receiver = pop
      push "!#{receiver}"
    end
    def decompile_opt_length(inst, line_no)
      # [:opt_length]
      receiver = pop
      push "#{receiver}.length"
    end
    def decompile_opt_succ(inst, line_no)
      # [:opt_succ]
      receiver = pop
      push "#{receiver}.succ"
    end
      
    ##############################
    ##### Method Dispatch ########
    ##############################
    def decompile_invokesuper(inst, line_no)
      do_super inst[1], inst[2], inst[3]
    end
    def decompile_invokeblock(inst, line_no)
      do_send :yield, inst[1], nil, inst[2], nil, :implicit
    end
    def decompile_send(inst, line_no)
      # [:send, meth, argc, blockiseq, op_flag, inline_cache]
      do_send *inst[1..-1]
    end
    
    #######################
    ##### Control Flow ####
    #######################
    def decompile_branchunless(inst, line_no)
      target = inst[1]
      forward = forward_jump?(line_no, target)
      if forward
        # elsif check
        predicate = pop
        if @stack.last.to_s.strip == "else"
          pop
          @end_stack.pop # one less end
          push "elsif (#{predicate})"
        else
          push "if (#{predicate})"
        end
        indent!
        @else_stack.push target
      end
    end
    
    def decompile_jump(inst, line_no)
      target = inst[1]
      forward = forward_jump?(line_no, target)
      if forward
        # is this an else branch?
        if @iseq.body[line_no + 1] == @else_stack.last
          # we're an else!
          @end_stack.push target # that's when the else ends
          outdent!
          push "else"
          indent!
          @else_stack.pop
        end
      end
    end
    
    def decompile_throw(inst, line_no)
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
    end
    
    #############################
    ###### Classes/Modules ######
    #############################
    def decompile_defineclass(inst, line_no)
      name, new_iseq, type = inst[1..-1]
      superklass, base = pop, pop
      superklass_as_str = (superklass == "nil" ? "" : " < #{superklass}")
      base_as_str = (base.kind_of?(Fixnum) ? "" : "#{base}::")
      new_reverser = Reverser.new(new_iseq, self)
      case type
      when 0 # class
        push "class #{base_as_str}#{name}#{superklass_as_str}"
      when 1
        push "class << #{base}"
      when 2
        push "module #{base_as_str}#{name}"
      end
      new_reverser.decompile.split("\n").each {|x| push((" " * Reverser::TAB_SIZE)+x)}
      push "end"
    end
    
    ###############################
    ### Inline Cache Simulation ###
    ###############################
    def decompile_getinlinecache(inst, line_no)
      push "nil"
    end
    alias_method :decompile_onceinlinecache, :decompile_getinlinecache
    
    def decompile_operator(inst, line_no)
      arg, receiver = pop, pop
      push "#{receiver} #{Reverser::OPERATOR_LOOKUP[inst.first]} #{arg}"
    end
    
    Reverser::OPERATOR_LOOKUP.keys.each do |operator|
      alias_method "decompile_#{operator}".to_sym, :decompile_operator
    end
  end
end