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
  attr_accessor :hello
end
CLASS
class A
  attr_accessor(:hello)
end
RESULT

    @simple_module = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
module A
  module_function :silly
end
CLASS
module A
  module_function(:silly)
end
RESULT

    @simple_singleton_class = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
class << self
  x = self
end
CLASS
class << self
  x = self
end
RESULT

    
  end
  
  it "decompiles an empty class" do
    @empty_class.assert_correct
  end
  
  it "decompiles a class with some executable code (but no defs)" do
    @nonempty_class.assert_correct
  end
  
  it "decompiles a simple module" do
    @simple_module.assert_correct
  end
  
  it "decompiles access to singleton classes" do
    @simple_singleton_class.assert_correct
  end
end