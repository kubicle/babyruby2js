#!/usr/bin/env ruby
# coding: utf-8
# Class comment
# another class comment
class Foo
  # attr_accessor comment
  attr_accessor :foo
  attr_reader :ra, # trailing on ra
    :rb # trailing on rb


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

# (if
#   (true)
#   (begin
#     (send nil :p
#       (str "hi1"))
#     (if
#       (send
#         (send nil :x) :<
#         (int 0))
#       (send nil :raise
#         (int 0)) nil))
#   (send nil :p
#     (str "hi2")))