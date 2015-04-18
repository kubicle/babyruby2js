
#comm1

class Test1

def testDeco1
  if true
    p "hi"
    raise 0 if x<0 # deco on trailing if
  else
    p "hi"
  end
end

def test1(a) # test1 decoring comment
  a.each do |n| # block arg n comment
    p a[1...4] + a[-1..-4]
  end
  a.block_fn do |x| # block arg x comment
    p x
  end
end

#bug2.1
def test2()
  a=1 # first time
  # call f1
  f1()
  b=2 # second time
  f3(a, #param a
     b, #param b
     c) #param c
  # call f2
  f1() #bug1.1
  #bug1.2
end
#bug1.3

end
