require "spec_helper"
describe "IR Lists" do

  it "should convert to a multiline string" do
    Reversal::IRList.new(["hello","world","there"]).to_s.should.equal("hello\nworld\nthere")
  end

  it "should indent using spaces" do
    Reversal::IRList.new(["line"]).indent.to_s[0,1].should.equal " "
  end

  it "should indent each line uniformly" do
    amt_to_indent = 3
    list = Reversal::IRList.new(["line 1", "line 2", "line 3"]).indent(amt_to_indent)
    list.each do |item|
      item.scan(/^\s+/).first.size.should.equal amt_to_indent
    end
  end

  it "should perform indentation" do
    amt_to_indent = 3
    Reversal::IRList.new(["line"]).indent(amt_to_indent).to_s.should.equal "   line"
  end
end