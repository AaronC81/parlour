# typed: strong

module B
  extend T::Sig

  sig { returns(String) }
  def b
    "hello"
  end
end
