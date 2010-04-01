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
  if x
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
  if x
    5
  elsif y
    10
  elsif z
    20
  else
    nil
  end
end
RESULT

    @single_unless = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
def test(x)
  unless x
    5
  end
end
CLASS
def test(x)
  if x
    nil
  else
    5
  end
end
RESULT

    @trailing_if = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
def test(x)
  x = 10 if y
end
CLASS
def test(x)
  if y
    x = 10
  else
    nil
  end
end
RESULT

    @trailing_unless = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
def test(x)
  x = 10 unless y
end
CLASS
def test(x)
  if y
    nil
  else
    x = 10
  end
end
RESULT
  end
  
  it "can decompile a single if statement" do
    @single_if.assert_correct_ignoring_indentation
  end
  
  it "can decompile elsif branches retaining the structure" do
    @elsif_branches.assert_correct_ignoring_indentation
  end
  
  it "can decompile a simple unless statement to equivalent code" do
    @single_unless.assert_correct_ignoring_indentation
  end
  
  it "can decompile a guard-if statement to equivalent code" do
    @trailing_if.assert_correct_ignoring_indentation
  end
  
  it "can decompile a guard-unless statement to equivalent code" do
    @trailing_unless.assert_correct_ignoring_indentation
  end
end