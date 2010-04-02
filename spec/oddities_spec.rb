require "spec_helper"

describe "Odd Reversals" do

  it "reverses calls to defined? for a variable" do
    defined_simple = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
defined? hello
CLASS
defined?(hello)
RESULT
    defined_simple.assert_correct
  end

  it "reverses calls to defined? for a constant" do
    defined_simple = CompiledDecompilationTestCase.new <<CLASS, <<RESULT
defined? HAI
CLASS
defined?(HAI)
RESULT
    defined_simple.assert_correct
  end

end