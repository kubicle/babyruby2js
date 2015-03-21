//Translated from test1.rb using babyruby2js
'use strict';

// comm1
TestStone.prototype.test1 = function (a) { // f1 decoring comment
    for (var n, n_array = a, n_ndx = 0; n=n_array[n_ndx], n_ndx < n_array.length; n_ndx++) { // block arg n comment
        p(a.slice(1, 4) + a.range(-1, -4));
    }
    return a.block_fn(function (x) { // block arg x comment
        return p(x);
    });
};

// bug2.1
TestStone.prototype.test2 = function () {
    var a = 1; // first time
    // call f1
    f1();
    var b = 2; // second time
    f3(a, b, c()); // param a // param b
    // param c
    // call f2
    return f1(); // bug1.1 // bug1.2
};
 // bug1.3