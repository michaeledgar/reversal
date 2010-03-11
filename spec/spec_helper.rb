require 'rubygems'
require 'bacon'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'reversal'

class DecompilationTestCase
  attr_accessor :seq, :reverser
  def initialize(klass, method, result)
    @seq = RubyVM::InstructionSequence.from_method(klass.new.method(method))
    @reverser = Reversal::Reverser.new(@seq)
    @result = result.strip
  end
  
  def assert_correct
    @reverser.decompile.should.equal @result
  end
  
  def assert_correct_ignoring_indentation
    decompiled = @reverser.decompile.split("\n").map {|x| x.lstrip}.join("\n")
    result     = @result.split("\n").map {|x| x.lstrip}.join("\n")
    decompiled.should.equal result
  end
end

class CompiledDecompilationTestCase < DecompilationTestCase
  def initialize(input, output)
    @seq = RubyVM::InstructionSequence.compile(input)
    @reverser = Reversal::Reverser.new(@seq)
    @result = output.strip
  end
end

Bacon.summary_on_exit
