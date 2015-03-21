//Translated from test1.rb using babyruby2js
'use strict';

// comm1
TestStone.prototype.f1 = function (a) { // f1 decoring comment
    return a.slice(1, 4) + a.range(-1, -4);
};

// bug2.1
TestStone.prototype.myfunc = function () {
    var a = 1; // first time
    // call f1
    f1();
    var b = 2; // second time
    f3(a, b, c()); // param a
     // param b // param c
    // call f2
    return f1(); // bug1.1 // bug1.2
};
 // bug1.3