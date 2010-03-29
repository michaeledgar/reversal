module Reversal
  module Instructions
    # Send a message without much fanfare. Just a receiver, a method,
    # and maybe some args.     Maybe a block too.
    def do_simple_send(receiver, meth, args = [], block = nil)
      push r(:send, meth, receiver, args, block, self)
    end

    ##
    # Handle a send instruction in the bytecode
    def do_send(meth, argc, blockiseq, op_flag, ic, receiver = nil)
      # [:send, meth, argc, blockiseq, op_flag, inline_cache]
      args = popn(argc)
      receiver ||= pop
      receiver = :implicit if receiver.nil?
      # Special operator cases. Weird, but keep in mind the oddity of
      # using an operator with a block!
      #
      # receiver.[]=(key, val) {|blockarg| ...} is possible!!!
      if !blockiseq
        if meth == :[]=
          remove_useless_dup
          push r(:aset, receiver, args[0], args[1])
          return
        elsif Reverser::ALL_INFIX.include?(meth.to_s)
          push r(:infix, meth, [receiver, args.first])
          return
        end
      end
      ## The rest of cases: either a normal method, a `def`, or an operator with a block
      if meth == :"core#define_method" || meth == :"core#define_singleton_method"
        # args will be [iseq, name, receiver, scope_arg]
        receiver, name, blockiseq = args
        push r(:defmethod, receiver, name, blockiseq, self)
      # normal method call
      else
        remove_useless_dup if meth == :[]=
        do_simple_send(receiver, meth, args, blockiseq)
      end
    end
    
    def do_super(argc, blockiseq, op_flag)
      args = popn(argc)
      explicit_check = pop
      explicit_args = explicit_check.true?
      args_to_pass = explicit_args ? args : []
      do_simple_send(:implicit, :super, args_to_pass, blockiseq)
    end
    
    #############################
    ###### Variable Lookup ######
    #############################
    def decompile_getlocal(inst, line_no)
      push r(:getvar, get_local(inst[1]))
    end
    
    def decompile_getinstancevariable(inst, line_no)
      push r(:getvar, inst[1])
    end
    alias_method :decompile_getglobal, :decompile_getinstancevariable
    
    def decompile_getconstant(inst, line_no)
      base = pop
      base_str = (base.nil?) ? "" : "#{base}::"
      push r(:getvar, "#{base_str}#{inst[1]}")
    end
    
    def decompile_getdynamic(inst, line_no)
      push r(:getvar, get_dynamic(inst[1], inst[2]))
    end
    
    def decompile_getspecial(inst, line_no)
      key, type = inst[1..2]
      if type == 0
        # some weird shit i don't get
      elsif (type & 0x01 > 0)
        push r(:getvar, "$#{(type >> 1).chr}")
      else
        push r(:getvar, "$#{(type >> 1)}")
      end
    end
    
    #############################
    ##### Variable Assignment ###
    #############################
    def decompile_setlocal(inst, line_no)
      # [:setlocal, local_num]
      value = pop
      # for some reason, there seems to cause a :dup instruction to be inserted that fucks
      # everything up. So i'll pop the return value.
      remove_useless_dup
      push r(:setvar, locals[inst[1] - 1], value)
    end
      
    def decompile_setinstancevariable(inst, line_no)
      # [:setinstancevariable, :ivar_name_as_symbol]
      # [:setglobal, :global_name_as_symbol]
      value = pop
      # for some reason, there seems to cause a :dup instruction to be inserted that fucks
      # everything up. So i'll pop the return value.
      remove_useless_dup
      push r(:setvar, inst[1], value)
    end
    alias_method :decompile_setglobal, :decompile_setinstancevariable
      
    def decompile_setconstant(inst, line_no)
      # [:setconstant, :const_name_as_symbol]
      name = inst[1]
      scoping_arg, value = pop, pop
      # for some reason, there seems to cause a :dup instruction to be inserted that fucks
      # everything up. So i'll pop the return value.
      remove_useless_dup
      push r(:setvar, name, value)
    end
    
    
    ###################
    ##### Strings #####
    ###################
    def decompile_putstring(inst, line_no)
      push r(:lit, inst[1])
    end
    
    def decompile_tostring(inst, line_no)
      do_simple_send(pop, :to_s)
    end
    
    def decompile_concatstrings(inst, line_no)
      amt = inst[1]
      push r(:infix, :+, pop(amt))
    end
    
    ##################
    ### Arrays #######
    ##################
    
    def decompile_duparray(inst, line_no)
      push r(:lit, inst[1])
    end
    
    def decompile_newarray(inst, line_no)
      # [:newarray, num_to_pop]
      arr = popn(inst[1])
      push r(:array, arr)
    end
    
    def decompile_splatarray(inst, line_no)
      # [:splatarray]
      push r(:splat, pop)
    end
    def decompile_concatarray(inst, line_no)
      # [:concatarray, ignored_boolean_flag]
      arg, receiver = pop, pop
      if receiver.type == :splat
        receiver = receiver[1]
      end
      push r(:infix, :+, [receiver, arg])
    end
      
    ###################
    ### Ranges ########
    ###################
    def decompile_newrange(inst, line_no)
      # [:newrange, exclusive_if_1]
      last, first = pop, pop
      inclusive = (inst[1] != 1)
      push r(:range, first, last, inclusive)

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
      push r(:hash, list)
    end
    
    #######################
    #### Weird Stuff ######
    #######################
    def decompile_putspecialobject(inst, line_no)
      # these are for runtime checks - just put the number it asks for, and ignore it
      # later
      push r(:lit, inst[1])
    end
      
      
    ## TODO: IR
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
      push r(:lit, inst[1])
    end
    def decompile_putself(inst, line_no)
      # [:putself]
      push r(:getvar, :self)
    end
    def decompile_putnil(inst, line_no)
      # [:putnil]
      push r(:nil)
    end
    def decompile_swap(inst, line_no)
      a, b = pop, pop
      push b
      push a
    end
    def decompile_opt_aref(inst, line_no)
      # [:opt_aref]
      key, receiver = pop, pop
      push r(:aref, receiver, key)
    end
    def decompile_opt_aset(inst, line_no)
      # [:opt_aset]
      new_val, key, receiver = pop, pop, pop
      push r(:aset, receiver, key, new_val)
    end
    def decompile_opt_not(inst, line_no)
      # [:opt_not]
      receiver = pop
      push r(:not, receiver)
    end
    def decompile_opt_length(inst, line_no)
      # [:opt_length]
      do_simple_send(pop, :length)
    end
    def decompile_opt_succ(inst, line_no)
      # [:opt_succ]
      do_simple_send(pop, :succ)
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
    ## TODO: IR
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
    
    ## TODO: IR
    def decompile_branchif(inst, line_no)
      target = inst[1]
      forward = forward_jump?(line_no, target)
      if forward
        # no elsif check
        predicate = pop
        push "unless (#{predicate})"
        indent!
        @else_stack.push target
      end
    end
    
    ## TODO: IR
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
        do_simple_send :implicit, :return, [pop]
      when 0x02
        do_simple_send :implicit, :break, [pop]
      when 0x03
        do_simple_send :implicit, :next, [pop]
      when 0x04
        pop #useless nil
        do_simple_send :implicit, :retry
      when 0x05
        pop #useless nil
        do_simple_send :implicit, :redo
      end
    end
    
    #############################
    ###### Classes/Modules ######
    #############################
    ## TODO: IR
    def decompile_defineclass(inst, line_no)
      name, new_iseq, type = inst[1..-1]
      superklass, base = pop, pop
      superklass_as_str = (superklass.nil? ? "" : " < #{superklass}")
      base_as_str = (base.kind_of?(Fixnum) || base.fixnum? ? "" : "#{base}::")
      new_reverser = Reverser.new(new_iseq, self)
      case type
       when 0 # class
        push r(:defclass, name, base_as_str, superklass_as_str, new_reverser.decompile_body(new_iseq))
      when 1
        push r(:defmetaclass, base, new_reverser.decompile_body(new_iseq))
      when 2
        push r(:defmodule, name, base_as_str, new_reverser.decompile_body(new_iseq))
      end
    end
    
    ###############################
    ### Inline Cache Simulation ###
    ###############################
    def decompile_getinlinecache(inst, line_no)
      push r(:nil)
    end
    alias_method :decompile_onceinlinecache, :decompile_getinlinecache
    
    def decompile_operator(inst, line_no)
      arg, receiver = pop, pop
      push r(:infix, Reverser::OPERATOR_LOOKUP[inst.first], [receiver, arg])
    end
    
    Reverser::OPERATOR_LOOKUP.keys.each do |operator|
      alias_method "decompile_#{operator}".to_sym, :decompile_operator
    end
  end
end