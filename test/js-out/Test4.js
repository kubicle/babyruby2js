//Translated from test4.rb using babyruby2js
'use strict';

var main = require('./main');
main.prototype.initColor = function () {
    // For consultant heuristics we reverse the colors
    if (this.consultant) {
        this.color = this.player.enemyColor;
    } else {
        this.color = this.player.color;
    }
};

