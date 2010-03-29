require 'spec_helper'

describe "Intermediate Representation Strinfication" do

  it "converts literal integers" do
    r(:lit, 5).to_s.should.equal "5"
  end

  it "converts literal strings" do
    r(:lit, "hello").to_s.should.equal "\"hello\""
  end

  it "converts local getvar expressions" do
    r(:getvar, "somevar").to_s.should.equal "somevar"
  end

  it "converts ivar getvar expressions" do
    r(:getvar, "@some_ivar").to_s.should.equal "@some_ivar"
  end

  it "converts constant getvar expressions" do
    r(:getvar, :SOME_CONSTANT).to_s.should.equal "SOME_CONSTANT"
  end

  it "converts local setvar expressions" do
    r(:setvar, "some_var", "some_value").to_s.should.equal "some_var = some_value"
  end

  it "converts constant setvar expressions" do
    r(:setvar, "A_CONSTANT", r(:lit, 5)).to_s.should.equal "A_CONSTANT = 5"
  end

  it "converts splat expressions" do
    r(:splat, r(:lit, [1, 2, 3, 4])).to_s.should.equal "*[1, 2, 3, 4]"
  end

  it "converts array literal expressions" do
    r(:array, [r(:lit, 3), r(:lit, :hello)]).to_s.should.equal "[3, :hello]"
  end

  it "converts inclusive range literal expressions" do
    r(:range, r(:lit, "aaa"), r(:lit, "zzz"), true).to_s.should.equal "(\"aaa\"..\"zzz\")"
  end

  it "converts exclusive range literal expressions" do
    r(:range, r(:lit, 3), r(:lit, 300), false).to_s.should.equal "(3...300)"
  end

  it "converts a simple infix expression" do
    r(:infix, :+, [r(:lit, 3), r(:lit, 4)]).to_s.should.equal "3 + 4"
  end

  it "converts an infix expression with many arguments" do
    r(:infix, :*, [r(:lit, "hi"), r(:lit, 3), r(:lit, 20)]).to_s.should.equal "\"hi\" * 3 * 20"
  end

end