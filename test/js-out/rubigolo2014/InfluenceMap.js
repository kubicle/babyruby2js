//Translated from influence_map.rb using babyruby2js
'use strict';

var main = require('../main');
var Grid = require('./Grid');

/** @class public read-only attribute: map
 */
function InfluenceMap(goban) {
    var self = this;
    this.goban = goban;
    this.size = goban.length;
    this.map = Array.new(this.size + 1, function () {
        return Array.new(self.size + 1, function () {
            return [0, 0];
        });
    });
}
module.exports = InfluenceMap;

InfluenceMap.prototype.clear = function () {
    for (var j = 1; j <= this.size; j++) {
        for (var i = 1; i <= this.size; i++) {
            for (var c = 0; c < 2; c++) {
                this.map[j][i][c] = 0;
            }
        }
    }
};

InfluenceMap.prototype.buildMap = function () {
    this.clear();
    var influence = [4, 2, 1];
    // First we get stones' direct influence
    for (var j = 1; j <= this.size; j++) {
        for (var i = 1; i <= this.size; i++) {
            var stone = this.goban.stoneAt(i, j);
            var color = stone.color;
            if (color !== main.EMPTY) {
                this.map[j][i][color] += influence[0];
                // Then we propagate it decreasingly with distance
                for (var n1, n1_array = stone.neighbors, n1_ndx = 0; n1=n1_array[n1_ndx], n1_ndx < n1_array.length; n1_ndx++) {
                    if (n1.color !== main.EMPTY) {
                        continue;
                    }
                    this.map[n1.j][n1.i][color] += influence[1];
                    // Second level
                    for (var n2, n2_array = n1.neighbors, n2_ndx = 0; n2=n2_array[n2_ndx], n2_ndx < n2_array.length; n2_ndx++) {
                        if (n2.color !== main.EMPTY) {
                            continue;
                        }
                        if (n2 === stone) {
                            continue;
                        }
                        this.map[n2.j][n2.i][color] += influence[2]; // 3rd level // n2.neighbors.each do |n3| //   next if n3 == n1 //   @map[n3.j][n3.i][color] += influence[3] // end
                    }
                }
            }
        }
    }
    if (main.debug) {
        return this.debugDump();
    }
};

InfluenceMap.prototype.debugDump = function () {
    for (var c = 0; c < 2; c++) {
        console.log('Influence map for ' + Grid.COLOR_NAMES[c] + ':');
        for (var j = this.size; j >= 1; j--) {
            console.log('' + '%2d'.format(j));
            for (var i = 1; i <= this.size; i++) {
                console.log('%2d'.format(this.map[j][i][c]) + '|');
            }
            console.log('\n');
        }
        console.log('  ');
        for (i = 1; i <= this.size; i++) {
            console.log(' ' + Grid.xLabel(i) + ' ');
        }
        console.log('\n');
    }
};

