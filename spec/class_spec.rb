require 'spec_helper'

describe "Class Reversal" do
  
  before do
    @empty_class = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
class A
end
CLASS
class A
  nil
end
RESULT
  end
  
  it "decompiles an empty class" do
    @empty_class.assert_correct
  end
end