# babyruby2js
Basic translator from Ruby to Javascript

# Run the test:
cd .\test
ruby ../babyruby2js.rb --src=. --target=js-out

# Translate a single file: (for debugging)
ruby ../babyruby2js.rb --src=. --target=js-out --debug=1 --file=./test1.rb


# Not handled:
- generated "require" need review
- class constants need to be moved *after* the constructor
- constants added to main class need to be "required" at least once
- we could find comments that were not used and dump them too
- "count" method on Array
- array.size not translated as "length"
- next & return not translated right in callbacks
- if x = f() changed into if (x = f()) not liked by JSHint; but if (x=f()) is OK
- s << str is replaced by s += str (with error if s is a parameter)
- << not handled on arrays (use push instead)
- chop!
- local var declared in "then" or "else" stmt but used after the "if" block
- 2 loops using same var for index => dupe decl in JS
- self instead of this (we could detect we are in a cb block)
- method calls with no params can be data members (Warning)
- object.rw_attrib=(exp); the method is "rw_attrib=" and it works by chance, no issue...
- break(value)
- retry exception
- cannot have parameters with a default value for a method using yield (block)
- iterators returned by each, upto, step, etc.
- in "case" (switch) a break is generated even if last stmt is return or throw (JSHint complains)
- map[:key] => map['key'] instead of map.key (JSHint complains)
- .size() called on arrays is not changed into .length
- 0 and "" are true in Ruby and false in JS, hence code like if !a.find_index(...) needs work
- for the reason above, we leave find_index untranslated
- negative index on arrays does not "loop back" from last item
