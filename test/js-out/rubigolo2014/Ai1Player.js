//Translated from ai1_player.rb using babyruby2js
'use strict';

var inherits = require('util').inherits;
var Heuristic = require('./ai/Heuristic');
var main = require('../main');
var Grid = require('./Grid');
var Stone = require('./Stone');
// TODO: 
// - do not fill my own territory (potential territory recognition will use analyser.enlarge method)
// - identify all foolish moves (like NoEasyPrisoner but once for all) in a map that all heuristics can use
// - foresee a poursuit = on attack/defense (and/or use a reverse-killer?)
// - an eye shape constructor
var Player = require('./Player');
var Goban = require('./Goban');
var InfluenceMap = require('./InfluenceMap');
var PotentialTerritory = require('./PotentialTerritory');
var AllHeuristics = require('./ai/AllHeuristics');
var TimeKeeper = require('./TimeKeeper');
var Genes = require('./Genes');

/** @class public read-only attribute: goban, inf, ter, enemyColor, genes, lastMoveScore
 */
function Ai1Player(goban, color, genes) {
    if (genes === undefined) genes = null;
    Player.call(this, false, goban);
    this.inf = new InfluenceMap(this.goban);
    this.ter = new PotentialTerritory(this.goban);
    this.size = this.goban.length;
    this.genes = (( genes ? genes : new Genes() ));
    this.minimumScore = this.getGene('smaller-move', 0.033, 0.02, 0.066);
    this.heuristics = [];
    this.negativeHeuristics = [];
    for (var cl, cl_array = Heuristic.allHeuristics(), cl_ndx = 0; cl=cl_array[cl_ndx], cl_ndx < cl_array.length; cl_ndx++) {
        var h = new cl(this);
        if (!h.negative) {
            this.heuristics.push(h);
        } else {
            this.negativeHeuristics.push(h);
        }
    }
    this.setColor(color);
    // genes need to exist before we create heuristics so passing genes below is done
    // to keep things coherent
    return this.prepareGame(this.genes); // @timer = TimeKeeper.new // @timer.calibrate(0.7)
}
inherits(Ai1Player, Player);
module.exports = Ai1Player;

Ai1Player.prototype.prepareGame = function (genes) {
    this.genes = genes;
    this.numMoves = 0;
};

Ai1Player.prototype.setColor = function (color) {
    Player.prototype.setColor.call(this, color);
    this.enemyColor = 1 - color;
    for (var h, h_array = this.heuristics, h_ndx = 0; h=h_array[h_ndx], h_ndx < h_array.length; h_ndx++) {
        h.initColor();
    }
    for (h, h_array = this.negativeHeuristics, h_ndx = 0; h=h_array[h_ndx], h_ndx < h_array.length; h_ndx++) {
        h.initColor();
    }
};

Ai1Player.prototype.getGene = function (name, defVal, lowLimit, highLimit) {
    if (lowLimit === undefined) lowLimit = null;
    if (highLimit === undefined) highLimit = null;
    return this.genes.get(this.constructor.name + '-' + name, defVal, lowLimit, highLimit);
};

// Returns the move chosen (e.g. c4 or pass)
// One can check last_move_score to see the score of the move returned
Ai1Player.prototype.getMove = function () {
    var bestScore, secondBest, bestI, bestJ;
    // @timer.start("AI move",0.5,3)
    this.numMoves += 1;
    if (this.numMoves >= this.size * this.size) { // force pass after too many moves
        main.log.error('Forcing AI pass since we already played ' + this.numMoves);
        return 'pass';
    }
    this.prepareEval();
    bestScore = secondBest = this.minimumScore;
    bestI = bestJ = -1;
    var bestNumTwin = 0; // number of occurrence of the current best score (so we can randomly pick any of them)
    for (var j = 1; j <= this.size; j++) {
        for (var i = 1; i <= this.size; i++) {
            var score = this.evalMove(i, j, bestScore);
            // Keep the best move
            if (score > bestScore) {
                secondBest = bestScore;
                if (main.debug) {
                    main.log.debug('=> ' + Grid.moveAsString(i, j) + ' becomes the best move with ' + score + ' (2nd best is ' + Grid.moveAsString(bestI, bestJ) + ' with ' + bestScore + ')');
                }
                bestScore = score;
                bestI = i;
                bestJ = j;
                bestNumTwin = 1;
            } else if (score === bestScore) {
                bestNumTwin += 1;
                if (~~(Math.random()*~~(bestNumTwin)) === 0) {
                    if (main.debug) {
                        main.log.debug('=> ' + Grid.moveAsString(i, j) + ' replaces equivalent best move with ' + score + ' (equivalent best was ' + Grid.moveAsString(bestI, bestJ) + ')');
                    }
                    bestScore = score;
                    bestI = i;
                    bestJ = j;
                }
            } else if (score >= secondBest) {
                if (main.debug) {
                    main.log.debug('=> ' + Grid.moveAsString(i, j) + ' is second best move with ' + score + ' (best is ' + Grid.moveAsString(bestI, bestJ) + ' with ' + bestScore + ')');
                }
                secondBest = score;
            }
        }
    }
    this.lastMoveScore = bestScore;
    // @timer.stop(false) # false: no exception if it takes longer but an error in the log
    if (bestScore > this.minimumScore) {
        return Grid.moveAsString(bestI, bestJ);
    }
    if (main.debug) {
        main.log.debug('AI is passing...');
    }
    return 'pass';
};

Ai1Player.prototype.prepareEval = function () {
    this.inf.buildMap();
    return this.ter.guessTerritories();
};

Ai1Player.prototype.evalMove = function (i, j, bestScore) {
    if (bestScore === undefined) bestScore = this.minimumScore;
    if (!Stone.validMove(this.goban, i, j, this.color)) {
        return 0.0;
    }
    var score = 0.0;
    // run all positive heuristics
    for (var h, h_array = this.heuristics, h_ndx = 0; h=h_array[h_ndx], h_ndx < h_array.length; h_ndx++) {
        score += h.evalMove(i, j);
    }
    // we run negative heuristics only if this move was a potential candidate
    if (score >= bestScore) {
        for (h, h_array = this.negativeHeuristics, h_ndx = 0; h=h_array[h_ndx], h_ndx < h_array.length; h_ndx++) {
            score += h.evalMove(i, j);
            if (score < bestScore) {
                break;
            }
        }
    }
    return score;
};

