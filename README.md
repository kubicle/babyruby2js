# babyruby2js
Basic translator from Ruby to Javascript.
Idea is to get the generated JS to be the most "readable" as possible and conform to usual style. I used babyruby2js to translate my own project (rubigolo) from Ruby to JavaScript. This is a 1-way trip and the generated JS will become the new base code - which also explains why I cared about some details like code comments, usually left behind by most translators.

See also, a more complete/evolved translator at https://github.com/rubys/ruby2js

## Run the test:
cd .\test
ruby ../babyruby2js.rb
(this uses ruby2js.json in test directory for config src & target)

## Translate a single file: (for debugging)
ruby ../babyruby2js.rb --src=. --target=js-out --debug=./test1.rb


## Not handled:
- constants added to main class need to be "required" at least once
- standard method names are tranlated without type-check (e.g. size => length)
- next & return not translated right in callbacks
- if x = f() changed into if (x = f()) not liked by JSHint; but if (x=f()) is OK
- s << str is replaced by s += str (with error if s is a parameter)
- << not handled on arrays (use push instead)
- Set class not handled (esp. Set#each wrongly translated into array-style for-loop)
- chop! and other mutable string methods
- ranges (only [n..m] and [n...m] supported on strings and arrays)
- slice on arrays (slice on string is OK)
- local var declared in "then" or "else" stmt but used after the "if" block (JSHint complains but code runs OK)
- method calls with no params can be data members (but an error is logged)
- object.rw_attrib=(exp); the method is "rw_attrib=" and it works by chance, no issue...
- break(value)
- retry exception
- cannot have parameters with a default value for a method using yield (block)
- iterators returned by each, upto, step, etc.
- in "case" (switch) a break is generated even if last stmt is return or throw (JSHint complains)
- map[:key] => map['key'] instead of map.key (JSHint complains)
- 0 and "" are true in Ruby and false in JS, hence code like if !a.find_index(...) needs work
- for the reason above, we leave find_index untranslated
- negative index on arrays does not "loop back" from last item
- only 1 class exported per file
- JS computations on Date.now() are in ms. They are in seconds (float) with Ruby Time.now
- ...plus anything I did not notice yet...
