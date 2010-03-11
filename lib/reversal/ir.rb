module Reversal
  class Sexp < Array
    
  end
end

module Kernel
  def r(*args)
    Sexp.new(args)
  end
end