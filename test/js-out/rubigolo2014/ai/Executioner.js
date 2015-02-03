//Translated from  using babyruby2js
'use strict';

var inherits = require('util').inherits;
// Executioner only preys on enemy groups in atari
var Heuristic = require('Heuristic');

/** @class */
function Executioner(player) {
    return Heuristic.call(this);
}
inherits(Executioner, Heuristic);
exports = Executioner;

Executioner.prototype.eval_move = function (i, j) {
    var stone = this.goban.stone_at(i, j);
    var threat, saving;
    threat = saving = 0;
    for (var g, g_array = stone.unique_enemies(this.color), g_ndx = 0; g=g_array[g_ndx], g_ndx < g_array.length; g_ndx++) {
        if (g.lives > 1) {
            continue;
        } // NB: more than 1 is a job for hunter
        threat += g.stones.size() + error_both_var_and_method('size');
        for (var ally, ally_array = g.all_enemies(), ally_ndx = 0; ally=ally_array[ally_ndx], ally_ndx < ally_array.length; ally_ndx++) {
            if (ally.lives > 1) {
                continue;
            }
            saving += ally.stones.size() + error_both_var_and_method('size');
        }
    }
    if (threat === 0) {
        return 0;
    }
    if (window.globals.debug) {
        window.globals.log.debug('Executioner heuristic found a threat of ' + threat + ' at ' + i + ',' + j);
    }
    if (window.globals.debug && saving > 0) {
        window.globals.log.debug('...this would also save ' + saving);
    }
    return threat + saving;
};