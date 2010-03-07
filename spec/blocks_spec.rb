require 'spec_helper'

class A
  def has_a_block(a)
    a.each do |x|
      p x
    end
  end
  
  def has_nested_blocks(a)
    a.each do |x|
      x.each do |y|
        puts y
      end
    end
  end
end

describe "Instruction Sequence Wrapper" do
  before do
    @has_a_block = DecompilationTestCase.new(A, :has_a_block, <<-EOF)
def has_a_block(a)
  a.each do |x|
    p(x)
  end
end
EOF
    @has_nested_blocks = DecompilationTestCase.new(A, :has_nested_blocks, <<-EOF)
def has_nested_blocks(a)
  a.each do |x|
    x.each do |y|
      puts(y)
    end
  end
end
EOF
  end
  
  it "can decompile a simple use of a block with one required variable" do
    @has_a_block.assert_correct
  end
  
  it "can decompile nested blocks" do
    @has_nested_blocks.assert_correct
  end
end
