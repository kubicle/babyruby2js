m={}

class Obj
  attr_reader :hash

  def initialize(n)
    @val = n
    @hash = n
  end

  def to_s
    "val=#{@val}"
  end
end

o1 = Obj.new(1)
o2 = Obj.new(1)
m[o1] = "hello"
m[o2] = "world"

p o1,o2
p m
