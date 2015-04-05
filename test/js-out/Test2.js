//Translated from test2.rb using babyruby2js
'use strict';

var m = {};
//public read-only attribute: hash;

/** @class */
function Obj(n) {
    this.val = n;
    this.hash = n;
}
module.exports = Obj;

Obj.prototype.toString = function () {
    return 'val=' + this.val;
};

Obj.prototype.func2 = function () {
    for (var i = 1; i <= numTournaments(); i++) { // TODO: Find a way to appreciate the progress
        reproduction();
        control();
    }
};

var o1 = new Obj(1);
var o2 = new Obj(1);
m[o1] = 'hello';
m[o2] = 'world';
p(o1, o2);
p(m);
// auto-add of parenthesis
p(9 % (3 + 2));
(3 % 2).toString();
// E01: unknown no-arg method num_tournaments()