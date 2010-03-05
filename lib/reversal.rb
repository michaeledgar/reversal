##
# reversal.rb: decompiling YARV instruction sequences
#
# Copyright 2010 Michael J. Edgar, michael.j.edgar@dartmouth.edu
#
# MIT License, see LICENSE file in gem package

$:.unshift(File.dirname(__FILE__))

require 'reversal/iseq'
require 'reversal/reverser'

module Reversal
  VERSION = "0.1.0"
  
  class << self
    def decompile(meth_or_proc)
      iseq = RubyVM::InstructionSequence.from_method(meth_or_proc)
      Reverser.for(iseq).decompile
    end
  end
end