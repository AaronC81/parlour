# typed: strong

module A
  extend T::Sig

  sig { returns(Integer) }
  def a
    3
  end
end
