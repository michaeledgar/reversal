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

    @nonempty_class = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
class A
  puts A
end
CLASS
class A
  puts(A)
end
RESULT
  end
  
  it "decompiles an empty class" do
    @empty_class.assert_correct
  end
  
  it "decompiles a class with some executable code (but no defs)" do
    @nonempty_class.assert_correct
  end
end