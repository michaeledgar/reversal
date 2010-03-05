##
# iseq.rb: Wrapper for instruction sequences that won't make you go nuts.
#
# Copyright 2010 Michael J. Edgar, michael.j.edgar@dartmouth.edu
#
# MIT License, see LICENSE file in gem package

module Reversal
  class InvalidInstructionSequenceError < StandardError; end
  class ISeq
    class << self
      def new(*args)
        case args.first
        when RubyVM::InstructionSequence
          array = args.first.to_a
        when Array
          array = args.first
        else
          array = args
        end
        if array[1] == 1 && array[2] == 1 && array[3] == 1
          return OneNineOneIseq.new(array)
        elsif array[1] == 1 && array[2] == 2 && array[3] == 1
          return OneNineTwoIseq.new(array)
        end
      end
    end
  end
  
  class SubclassableIseq < Struct.new(:magic, :major_version, :minor_version, :patch_version, :stats,
                                      :name, :filename, :line, :type, :locals, :args, :catch_tables, :body)
    def validate!
      unless self.magic == "YARVInstructionSequence/SimpleDataFormat" &&
             "#{version}" >= "1.1.1"
             raise InvalidInstructionSequenceError.new("Invalid YARV instruction sequence in array format: #{self.to_a}")
      end
    end
    
    def version
      "#{major_version}.#{minor_version}.#{patch_version}"
    end
  end
  
  class OneNineOneIseq < SubclassableIseq
    def initialize(*arguments)
      args = arguments.first
      self.magic = args[0]
      self.major_version = args[1]
      self.minor_version = args[2]
      self.patch_version = args[3]
      self.stats = args[4]
      self.name  = args[5]
      self.filename = args[6]
      self.type = args[7] # must skip line, not in this version
      self.locals = args[8]
      self.args = args[9]
      self.catch_tables = args[10]
      self.body = args[11]
    end
  end
  
  class OneNineTwoIseq < SubclassableIseq
    def initialize(*args)
      self.magic = args[0]
      self.major_version = args[1]
      self.minor_version = args[2]
      self.patch_version = args[3]
      self.stats = args[4]
      self.name  = args[5]
      self.filename = args[6]
      self.line = args[7]
      self.type = args[8] # must skip line, not in this version
      self.locals = args[9]
      self.args = args[10]
      self.catch_tables = args[11]
      self.body = args[12]
    end
  end
end