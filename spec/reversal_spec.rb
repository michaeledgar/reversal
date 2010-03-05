require 'spec_helper'

describe "Reversal" do
  it "should have a version" do
    Reversal::VERSION.should.not.equal nil
  end
end

class A
  def simple
    a = 10
    b = 15
  end
  
  def has_one_arg(a)
  end
  
  def has_two_args(a,b,c)
  end
  
  def assigns_ivar(val)
    @some_ivar = 5
  end
  
  def assigns_and_gets_ivar
    @some_ivar = @another_ivar
  end
  
  def calls_a_method
    5.minutes()
  end
  
  def first_multiline(arg)
    hello = arg.crazy
    puts(hello)
  end
end

describe "Method Reversal" do
  before do
    @simple_case = DecompilationTestCase.new(A, :simple, <<-EOF)
def simple
  a = 10
  b = 15
  15
end
EOF
    
    @one_arg_case = DecompilationTestCase.new(A, :has_one_arg, <<-EOF)
def has_one_arg(a)
  nil
end
EOF
    
    @two_arg_case = DecompilationTestCase.new(A, :has_two_args, <<-EOF)
def has_two_args(a, b, c)
  nil
end
EOF
    
    @assigns_ivar_case = DecompilationTestCase.new(A, :assigns_ivar, <<-EOF)
def assigns_ivar(val)
  @some_ivar = 5
  5
end
EOF
    
    @assigns_ivar_set_get_case = DecompilationTestCase.new(A, :assigns_and_gets_ivar, <<-EOF)
def assigns_and_gets_ivar
  @some_ivar = @another_ivar
  @another_ivar
end
EOF
    
    
    @calls_a_method_case = DecompilationTestCase.new(A, :calls_a_method, <<-EOF)
def calls_a_method
  5.minutes()
end
EOF
    
    @first_multiline_case = DecompilationTestCase.new(A, :first_multiline, <<-EOF)
def first_multiline(arg)
  hello = arg.crazy()
  puts(hello)
end
EOF
  end
  
  it "can decompile a method with simple local assignments" do
    @simple_case.assert_correct
  end
  
  it "can decompile a method with one positional argument" do
    @one_arg_case.assert_correct
  end
  
  it "can decompile a method with two positional arguments" do
    @two_arg_case.assert_correct
  end
  
  it "can decompile a method that assigns an instance variable" do
    @assigns_ivar_case.assert_correct
  end
  
  it "can decompile a method that assigns and gets an instance variable" do
    @assigns_ivar_set_get_case.assert_correct
  end
  
  it "can decompile a method being called" do
    @calls_a_method_case.assert_correct
  end
  
  it "can handle a complex multiline decompilation" do
    @first_multiline_case.assert_correct
  end
end
