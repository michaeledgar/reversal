require 'spec_helper'

class SomeTinyClass
  def sillymethod(a, b)
    a.do_something(b)
    b.and_also(a)
  end
end

describe "Instruction Sequence Wrapper" do
  before do
    @raw_empty_iseq = RubyVM::InstructionSequence.compile("")
    
    @raw_simple_seq = RubyVM::InstructionSequence.from_method(SomeTinyClass.new.method(:sillymethod))
    @simple = Reversal::ISeq.new(@raw_simple_seq)
  end
  
  it "can be created with a raw instruction sequence" do
    iseq = Reversal::ISeq.new(@raw_empty_iseq)
    should.not.raise {iseq.validate!}
  end
  
  it "can be created with an instruction sequence in array format" do
    iseq = Reversal::ISeq.new(@raw_empty_iseq.to_a)
    should.not.raise {iseq.validate!}
  end
  
  it "raises an error if initialized unknown version number" do
    should.raise(Reversal::UnknownInstructionSequenceError) do
      Reversal::ISeq.new(["YARVInstructionSequence/SimpleDataFormat", 0, 0, 0])
    end
  end
  
  it "raises an error if validation fails" do
    should.raise(Reversal::InvalidInstructionSequenceError) do
      Reversal::ISeq.new(["Bad Magic", 1, 2, 1]).validate!
    end
  end
  
  it "detects method types" do
    @simple.type.should == :method
  end
end
