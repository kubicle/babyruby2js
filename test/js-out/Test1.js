//Translated from test1.rb using babyruby2js
'use strict';

// comm1

/** @class */
function Test1() {}
module.exports = Test1;

Test1.prototype.testDeco1 = function () {
    if (true) {
        console.log('hi');
        if (x() < 0) { // deco on trailing if
            throw new Error(0);
        }
    } else {
        console.log('hi');
    }
};

Test1.prototype.test1 = function (a) { // test1 decoring comment
    for (var n, n_array = a, n_ndx = 0; n=n_array[n_ndx], n_ndx < n_array.length; n_ndx++) { // block arg n comment
        console.log(a.slice(1, 4) + a.range(-1, -4));
    }
    return a.blockFn(function (x) {
        console.log(x);
    }); // block arg x comment
};

// bug2.1
Test1.prototype.test2 = function () {
    var a = 1; // first time
    // call f1
    f1();
    var b = 2; // second time
    f3(a, b, c()); // param a // param b // param c
    // call f2
    return f1(); // bug1.1 // bug1.2
};
 // bug1.3
// E02: unknown method: x()
// E02: unknown method: block_fn(...)
// E02: unknown method: f1()
// E02: unknown method: f3(...)
// E02: unknown method: c()
