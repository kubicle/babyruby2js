//Translated from test2.rb using babyruby2js
'use strict';

var main = require('./main');
var m = {};

/** @class public read-only attribute: hash
 */
function Obj(n) {
    this.val = n;
    this.hash = n;
}
module.exports = Obj;

Obj.ACONSTANT = 0;
Obj.prototype.toString = function () {
    return 'val=' + this.val;
};

Obj.prototype.func2 = function () {
    for (var i = 0; i < numTournaments(); i++) { // TODO: Find a way to appreciate the progress
        reproduction();
        control();
    }
};

var o1 = new Obj(1);
var o2 = new Obj(1);
m[o1] = 'hello';
m[o2] = 'world';
console.log(o1, o2);
console.log(m);
// auto-add of parenthesis
console.log(9 % (3 + 2));
(3 % 2).toString();
// use of is_a?
console.log(main.isA('Float', 3.2));
console.log(main.isA('Fixnum', 3));
console.log(main.isA(String, 't'));
console.log(main.isA(Array, []));
// use of gsub
console.log('abcbd'.replaceAll('b', 'x'));
console.log('abcbd'.replace(/b/g, 'x'));
console.log('abcbd'.replace(/B/ig, 'x'));
console.log('abcbd'.replaceAll(func2(), 'x'));
// call a block
main.prototype.fnBlock = function (p1, block) {
    block();
    return block(3);
};

// slice or []
var s = 'abcdef';
console.log(s[2]);
console.log(s.substr(2, 1));
console.log(s[2]);
console.log(s.substr(2, 1));
main.prototype.testLoops = function () {
    var x = 2;
    for (var i = 0; i <= 10; i += 2) {
        console.log(i);
    }
    for (i = 0; i >= -10; i -= 2) {
        console.log(i);
    }
    for (var i3 = 0, _stepi3 = x; (10 - i3) * _stepi3 > 0; i3 += _stepi3) {
        console.log(i3);
    }
    for (i3 = 0, _stepi3 = x; (10 - i3) * _stepi3 > 0; i3 += _stepi3) {
        console.log(i3);
    }
    for (var j = 0; j < 3; j++) {
        console.log(j);
    }
    for (j = 0; j < 3; j++) {
        console.log(j);
    }
    for (var _i = 0; _i < 3; _i++) {
        console.log(x);
    }
    for (var k in x) {
        console.log(Object.keys(x));
    }
};

// E02: unknown method: num_tournaments()
// W03: isA('Float',n) is true for all numbers
