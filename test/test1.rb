
#comm1

class TestStone

#bug2.1
def myfunc()
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
