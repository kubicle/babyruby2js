//Translated from contacts.rb using babyruby2js
'use strict';

var main = require('./main');
//public read-only attribute: contacts;

/** @class */
function Contacts() {
    this.contacts = new main.Array(4);
    return this.contacts.clear();
}
module.exports = Contacts;

Contacts.prototype.clear = function () {
    return this.contacts.clear();
};

Contacts.prototype.empty = function () {
    return this.contacts.size() === 0;
};

Contacts.prototype.push = function (item) {
    if (this.contacts.find_index(item) === null) {
        return this.contacts.push(item);
    }
};

Contacts.prototype.each = function (, cb) {
    for (var x, x_array = this.contacts, x_ndx = 0; x=x_array[x_ndx], x_ndx < x_array.length; x_ndx++) {
        cb(x);
    }
};

Contacts.prototype.size = function () {
    return this.contacts.size();
};

Contacts.prototype.[] = function (ndx) {
    return this.contacts[ndx];
};
