//Translated from test2.rb using babyruby2js
'use strict';

var Obj = require('./Obj');
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

var o1 = new Obj(1);
var o2 = new Obj(1);
m[o1] = 'hello';
m[o2] = 'world';
p(o1, o2);
p(m);