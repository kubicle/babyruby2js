m={}

class Obj
  attr_reader :hash

  ACONSTANT = 0

  def initialize(n)
    @val = n
    @hash = n
  end

  def to_s
    "val=#{@val}"
  end

  def func2
    num_tournaments.times do |i| # TODO: Find a way to appreciate the progress
      reproduction
      control
    end
  end
end

o1 = Obj.new(1)
o2 = Obj.new(1)
m[o1] = "hello"
m[o2] = "world"

p o1,o2
p m

# auto-add of parenthesis
p 9.modulo(3+2)
3.modulo(2).to_s()
