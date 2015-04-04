//Translated from test3.rb using babyruby2js
'use strict';

var main = require('./main');
// Class comment
// another class comment
// attr_accessor comment
attrAccessor('foo');
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

// E02: unknown method attr_accessor(...)
// W01: lost comment: #!/usr/bin/env ruby <- line 1: [???]
// W01: lost comment: # coding: utf-8 <- line 2: [???]
// W01: lost comment: # (if <- line 30: [???]
// W01: lost comment: #   (true) <- line 31: [???]
// W01: lost comment: #   (begin <- line 32: [???]
// W01: lost comment: #     (send nil :p <- line 33: [???]
// W01: lost comment: #       (str "hi1")) <- line 34: [???]
// W01: lost comment: #     (if <- line 35: [???]
// W01: lost comment: #       (send <- line 36: [???]
// W01: lost comment: #         (send nil :x) :< <- line 37: [???]
// W01: lost comment: #         (int 0)) <- line 38: [???]
// W01: lost comment: #       (send nil :raise <- line 39: [???]
// W01: lost comment: #         (int 0)) nil)) <- line 40: [???]
// W01: lost comment: #   (send nil :p <- line 41: [???]
// W01: lost comment: #     (str "hi2"))) <- line 42: [???]