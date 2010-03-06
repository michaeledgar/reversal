require 'spec_helper'

class A
  
  def has_one_arg(a)
  end
  
  def has_two_args(a,b,c)
  end
  
  def calls_a_method
    5.minutes()
  end
  
  def uses_a_string
    var = "a string"
  end
  
  def interpolates_a_string
    "hello #{world_method}"
  end
  
  def first_multiline(arg)
    hello = arg.crazy
    puts(hello)
  end
  
  def chained_methods(arg1, arg2)
    arg1.a_method(arg1, arg2).another_method.to_s
  end
end

describe "Method Reversal" do
  before do
    
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
    
    @calls_a_method_case = DecompilationTestCase.new(A, :calls_a_method, <<-EOF)
def calls_a_method
  5.minutes
end
EOF

    @uses_a_string_case = DecompilationTestCase.new(A, :uses_a_string, <<-EOF)
def uses_a_string
  var = "a string"
end
EOF

    @interpolates_a_string_case = DecompilationTestCase.new(A, :interpolates_a_string, <<-EOF)
def interpolates_a_string
  "hello " + (world_method).to_s
end
EOF

    @first_multiline_case = DecompilationTestCase.new(A, :first_multiline, <<-EOF)
def first_multiline(arg)
  hello = arg.crazy
  puts(hello)
end
EOF

    @chained_method_case = DecompilationTestCase.new(A, :chained_methods, <<-EOF)
def chained_methods(arg1, arg2)
  arg1.a_method(arg1, arg2).another_method.to_s
end
EOF
  end
  
  it "can decompile a method with one positional argument" do
    @one_arg_case.assert_correct
  end
  
  it "can decompile a method with two positional arguments" do
    @two_arg_case.assert_correct
  end
  
  it "can decompile a simple expression with a string" do
    @uses_a_string_case.assert_correct
  end
  
  it "can decompile a method being called" do
    @calls_a_method_case.assert_correct
  end
  
  it "can handle a complex multiline decompilation" do
    @first_multiline_case.assert_correct
  end
  
  it "decompiles chained methods appropriately" do
    @chained_method_case.assert_correct
  end
  
  it "interpolates a simple string" do
    @interpolates_a_string_case.assert_correct
  end
end
