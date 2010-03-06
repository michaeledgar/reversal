require 'spec_helper'

class A
  def plus(a, b)
    a + b
  end
  
  def minus(a, b)
    a - b
  end
  
  def mult(a, b)
    a * b
  end
  
  def div(a, b)
    a / b
  end
  
  def mod(a, b)
    a % b
  end
  
  def eq(a, b)
    a == b
  end
  
  def lt(a, b)
    a < b
  end
  
  def lte(a, b)
    a <= b
  end
  
  def gt(a, b)
    a > b
  end
  
  def gte(a, b)
    a >= b
  end
  
  def ltlt(a, b)
    a << b
  end
  
  def aref(arr, key)
    arr[key]
  end
  
  def aset(arr, key, val)
    arr[key] = val
  end
end

describe "Operator Reversal" do
  before do
    @plus_case = DecompilationTestCase.new(A, :plus, <<-EOF)
def plus(a, b)
  a + b
end
EOF
    @minus_case = DecompilationTestCase.new(A, :minus, <<-EOF)
def minus(a, b)
  a - b
end
EOF

    @mult_case = DecompilationTestCase.new(A, :mult, <<-EOF)
def mult(a, b)
  a * b
end
EOF

    @div_case = DecompilationTestCase.new(A, :div, <<-EOF)
def div(a, b)
  a / b
end
EOF
    @mod_case = DecompilationTestCase.new(A, :mod, <<-EOF)
def mod(a, b)
  a % b
end
EOF
    @eq_case = DecompilationTestCase.new(A, :eq, <<-EOF)
def eq(a, b)
  a == b
end
EOF

    @lt_case = DecompilationTestCase.new(A, :lt, <<-EOF)
def lt(a, b)
  a < b
end
EOF

    @lte_case = DecompilationTestCase.new(A, :lte, <<-EOF)
def lte(a, b)
  a <= b
end
EOF
    @gt_case = DecompilationTestCase.new(A, :gt, <<-EOF)
def gt(a, b)
  a > b
end
EOF
    @gte_case = DecompilationTestCase.new(A, :gte, <<-EOF)
def gte(a, b)
  a >= b
end
EOF

    @ltlt_case = DecompilationTestCase.new(A, :ltlt, <<-EOF)
def ltlt(a, b)
  a << b
end
EOF
    @aref_case = DecompilationTestCase.new(A, :aref, <<-EOF)
def aref(arr, key)
  arr[key]
end
EOF

    ## YARV does not compile this to arr[key] = val. It compiles it to
    ## arr.[]=(key, val). So until I clean that up, it looks like this
    @aset_case = DecompilationTestCase.new(A, :aset, <<-EOF)
def aset(arr, key, val)
  arr[key] = val
end
EOF
  end
  
  it "can decompile a simple addition of local variables" do
    @plus_case.assert_correct
  end
  
  it "can decompile a simple subtraction of local variables" do
    @minus_case.assert_correct
  end
  
  it "can decompile a simple multiplication of local variables" do
    @mult_case.assert_correct
  end
  
  it "can decompile a simple division of local variables" do
    @div_case.assert_correct
  end
  
  it "can decompile a simple modulus of local variables" do
    @mod_case.assert_correct
  end
  
  it "can decompile a simple equality comparison of local variables" do
    @eq_case.assert_correct
  end
  
  it "can decompile a simple less-than comparison of local variables" do
    @lt_case.assert_correct
  end
  
  it "can decompile a simple less-than-or-equal comparison of local variables" do
    @lte_case.assert_correct
  end
  
  it "can decompile a simple greater-than comparison of local variables" do
    @gt_case.assert_correct
  end
  
  it "can decompile a simple greater-than-or-equal comparison of local variables" do
    @gte_case.assert_correct
  end
  
  it "can decompile a simple left-shift of local variables" do
    @ltlt_case.assert_correct
  end
  
  it "can decompile a simple array-style-reference operator of local variables" do
    @aref_case.assert_correct
  end
  
  it "can decompile a simple array-style-assignment operator of local variables" do
    @aset_case.assert_correct
  end
  
end
