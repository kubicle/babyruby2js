//Translated from test3.rb using babyruby2js
'use strict';

var main = require('./main');

/** @class Class comment
 *  another class comment
 *  public read-only attribute: ra, rb  *  trailing on ra  *  trailing on rb
 */
function Foo() {
    this.ra = this.rb = 0;
}
module.exports = Foo;

// attr_accessor comment
attrAccessor('foo');
// method comment
Foo.prototype.bar = function () {
    // expr comment
    return 1 + 2; // intermediate comment // stray comment
};

main.prototype.foo = function () {
    if (true) {
        console.log('hi1');
        if (x() < 0) { // deco on trailing if
            throw new Error(0);
        }
    } else {
        console.log('hi2');
    }
};

// E02: unknown method: attr_accessor(...)
// E02: unknown method: x()
// W01: lost comment: #!/usr/bin/env ruby <- line 1: [???]
// W01: lost comment: # coding: utf-8 <- line 2: [???]
// W01: lost comment: #trailing comment after func foo <- line 33: [???]
