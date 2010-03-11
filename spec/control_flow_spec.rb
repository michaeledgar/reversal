require 'spec_helper'

describe "Control Flow Reversal" do
  before do
    @single_if = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
def test(x)
  if x
    5
  end
end
CLASS
def test(x)
  if (x)
    5
  else
    nil
  end
end
RESULT

    @elsif_branches = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
def test(x)
  if x
    5
  elsif y
    10
  elsif z
    20
  end
end
CLASS
def test(x)
  if (x)
    5
  elsif (y)
    10
  elsif (z)
    20
  else
    nil
  end
end
RESULT
  end
  
  it "can decompile a single if statement" do
    @single_if.assert_correct_ignoring_indentation
  end
  
  it "can decompile elsif branches (albeit in an ugly manner)" do
    @elsif_branches.assert_correct_ignoring_indentation
  end
end