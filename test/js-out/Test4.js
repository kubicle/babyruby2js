//Translated from test4.rb using babyruby2js
'use strict';

main.prototype.init_color = function () {
    // For consultant heuristics we reverse the colors
    if (this.consultant) {
        this.color = this.player.enemy_color;
    } else {
        this.color = this.player.color;
    }
};
