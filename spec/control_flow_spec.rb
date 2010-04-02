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

    @uses_andand = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
def test(x)
  if x && y
    puts(x)
  end
end
CLASS
def test(x)
  if x
    if y
      puts(x)
    end
  end
end
RESULT

    @uses_oror = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
def test(x)
  if x || y
    puts(x)
  end
end
CLASS
def test(x)
  unless x
    if y
      puts(x)
    end
  else
    puts(x)
    nil
  end
end
RESULT
  end
  
  it "can decompile a single if statement" do
    @single_if.assert_correct
  end
  
  it "can decompile elsif branches retaining the structure" do
    @elsif_branches.assert_correct
  end
  
  it "can decompile a simple unless statement to equivalent code" do
    @single_unless.assert_correct
  end
  
  it "can decompile a guard-if statement to equivalent code" do
    @trailing_if.assert_correct
  end
  
  it "can decompile a guard-unless statement to equivalent code" do
    @trailing_unless.assert_correct
  end

  it "can decompile a conditional using the && operator" do
    @uses_andand.assert_correct
  end

  it "can decompile a condition using the || operator" do
    @uses_oror.assert_correct
  end
end