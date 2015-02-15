//main class for babyruby2js
'use strict';

function main() {
}
exports = main;

Array.prototype.clear = function () {
  for (var i=this.length; i>0; i--) this.pop();
};

main.prototype.assert_equal = function (val, expected) {
    if (val === expected) return;
    throw new Error('Failed assertion: expected [' + expected + '] but got [' + val + ']');
};

main.prototype.strChop = function (s) {
  return s.substr(0, s.length-1)
};

main.prototype.strFormat = function (fmt) {
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
