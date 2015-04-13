#!/usr/bin/env ruby
# coding: utf-8
# Class comment
# another class comment
class Foo
  # attr_accessor comment
  attr_accessor :foo
  attr_reader :ra, # trailing on ra
    :rb # trailing on rb

  def initialize
    @ra = @rb = 0
  end

  # method comment
  def bar
    # expr comment
    1 + # intermediate comment
      2
    # stray comment
  end
end

def foo
  if true
    p "hi1"
    raise 0 if x<0 # deco on trailing if
  else
    p "hi2"
  end
end

#trailing comment after func foo
