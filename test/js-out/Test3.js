//Translated from test3.rb using babyruby2js
'use strict';

// Class comment
// another class comment
// attr_accessor comment
attr_accessor('foo');
//public read-only attribute: ra, rb; // trailing on ra // trailing on rb
// method comment
Foo.prototype.bar = function () {
    // expr comment
    return 1 + 2; // intermediate comment // stray comment
};

main.prototype.foo = function () {
    if (true) {
        p('hi1');
        if (x() < 0) { // deco on trailing if
            throw new Error(0);
        }
    } else {
        return p('hi2');
    }
};
