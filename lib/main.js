//main class for babyruby2js
'use strict';

function main() {
}
exports = main;

//---Array functions

main.Array = function (size, init) {
  var i, a = [];
  if (typeof init === 'function') {
    for (i = 0; i < size; i++) { a[i] = init(); }
  } else {
    for (i = 0; i < size; i++) { a[i] = init; }
  }
  return a;
};

Array.prototype.indexOf = function (e) {
  for (var i = 0; i < this.length; i++) {
    if (this[i] === e) return i;
  }
  return -1;
};

Array.prototype.contains = function (e) {
  for (var i = 0; i < this.length; i++) {
    if (this[i] === e) return true;
  }
  return false;
};

Array.prototype.size = function () {
  return this.length;
};

Array.prototype.clear = function () {
  for (var i=this.length; i>0; i--) this.pop();
};

Array.prototype.select = function (testFunc) {
  var a = [];
  for (var i = 0; i < this.length; i++) {
    var e = this[i];
    if (testFunc(e)) a.push(e);
  }
  return a;
};

//--- Tests

main.TestCase = function (testName) {
  this.testName = testName;
};

main.TestCase.prototype.run = function () {
  for (var m in this) {
    var f = this[m];
    if (typeof f === 'function' && m.substr(0,4) === 'test') {
      console.log('Running test ' + this.testName + '::' + m + '...');
      f.call(this);
    }
  }
};

main.assert_equal = function (val, expected) {
    if (val === expected) return;
    throw new Error('Failed assertion: expected [' + expected + '] but got [' + val + ']');
};

//---

main.strChop = function (s) {
  return s.substr(0, s.length-1);
};

main.strFormat = function (fmt) {
  return fmt; //TODO
};

/** @class */
function Logger() {
}

Logger.prototype.debug = function (msg) {
  console.log(msg);
};
Logger.prototype.error = function (msg) {
  console.error(msg);
};

main.log = new Logger();