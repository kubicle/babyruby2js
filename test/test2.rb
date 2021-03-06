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

# use of is_a?
p 3.2.is_a?(Float)
p 3.is_a?(Fixnum)
p "t".is_a?(String)
p [].is_a?(Array)

# use of gsub
p "abcbd".gsub("b", "x")
p "abcbd".gsub(/b/, "x")
p "abcbd".gsub(/B/i, "x")
p "abcbd".gsub(func2(), "x")

# call a block
def fnBlock(p1, &block)
  block.call
  block.call(3)
end

# slice or []
s = "abcdef"
p s[2]
p s[2,1]
p s.slice(2)
p s.slice(2,1)

def testLoops
  x = 2
  0.step(10,2) { |i| p i }
  0.step(-10,-2) { |i| p i }
  0.step(10,x) { |i3| p i3 }
  0.step(10,x) { |i3| p i3 }
  3.times { |j| p j }
  3.times { |j| p j }
  3.times { p x }
  x.each_key { |k| p x.keys }
end
