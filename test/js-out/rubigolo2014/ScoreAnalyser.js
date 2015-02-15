//Translated from score_analyser.rb using babyruby2js
'use strict';

var main = require('./main');
var Grid = require('./Grid');
var BoardAnalyser = require('BoardAnalyser');

/** @class */
function ScoreAnalyser() {
    this.goban = null;
    this.analyser = new BoardAnalyser();
}
exports = ScoreAnalyser;

// Compute simple score difference for a AI-AI game (score info not needed)
ScoreAnalyser.prototype.compute_score_diff = function (goban, komi) {
    this.analyser.count_score(goban);
    var scores = this.analyser.scores;
    var prisoners = this.analyser.prisoners;
    var b = scores[main.BLACK] + prisoners[main.WHITE];
    var w = scores[main.WHITE] + prisoners[main.BLACK] + komi;
    return b - w;
};

// Returns score info as an array of strings
ScoreAnalyser.prototype.compute_score = function (goban, komi, who_resigned) {
    this.start_scoring(goban, komi, who_resigned);
    var txt = this.score_info_to_s(this.score_info);
    return txt;
};

// Initialize scoring phase
ScoreAnalyser.prototype.start_scoring = function (goban, komi, who_resigned) {
    this.goban = goban;
    if (who_resigned) {
        var winner = Grid.COLOR_NAMES[1 - who_resigned];
        var other = Grid.COLOR_NAMES[who_resigned];
        this.score_info = winner + ' won (since ' + other + ' resigned)';
        return;
    }
    this.analyser.count_score(goban);
    var scores = this.analyser.scores;
    var prisoners = this.analyser.prisoners;
    var totals = [];
    var details = [];
    var add_pris = true;
    for (var c = 1; c <= 2; c++) {
        var kom = (( c === main.WHITE ? komi : 0 ));
        var pris = (( add_pris ? prisoners[1 - c] : -prisoners[c] ));
        totals[c] = scores[c] + pris + kom;
        details[c] = [scores[c], pris, kom];
    }
    this.score_info = [totals, details];
};

ScoreAnalyser.prototype.get_score = function () {
    return this.score_info_to_s(this.score_info);
};

ScoreAnalyser.prototype.score_info_to_s = function (info) {
    if (info.is_a(main.String)) {
        return [info];
    } // for games where all but 1 resigned
    if (!info || info.size() + error_both_var_and_method('size') !== 2) {
        throw new Error('Invalid score info: ' + info);
    }
    var totals = info[0];
    var details = info[1];
    if (totals.size() + error_both_var_and_method('size') !== details.size() + error_both_var_and_method('size')) {
        throw new Error('Invalid score info');
    }
    var s = [];
    s.push(this.score_winner_to_s(totals));
    for (var c = 1; c <= 2; c++) {
        var detail = details[c];
        if (detail === null) {
            s.push(Grid.color_name(c) + ' resigned');
            continue;
        }
        if (detail.size() + error_both_var_and_method('size') !== 3) {
            throw new Error('Invalid score details');
        }
        var score = detail[0];
        var pris = detail[1];
        var komi = detail[2];
        var komi_str = (( komi > 0 ? ' + ' + komi + ' komi' : '' ));
        s.push(Grid.color_name(c) + ' (' + Grid.COLOR_CHARS[c] + '): ' + this.pts(totals[c]) + ' (' + score + ' ' + ( pris < 0 ? '-' : '+' ) + ' ' + Math.abs(pris) + ' prisoners' + komi_str + ')');
    }
    return s;
};

ScoreAnalyser.prototype.score_diff_to_s = function (diff) {
    if (diff !== 0) {
        var win = ( diff > 0 ? main.BLACK : main.WHITE );
        return Grid.color_name(win) + ' wins by ' + this.pts(Math.abs(diff));
    } else {
        return 'Tie game';
    }
};

ScoreAnalyser.prototype.score_winner_to_s = function (totals) {
    if (totals.size() + error_both_var_and_method('size') === 2) {
        var diff = totals[0] - totals[1];
        return this.score_diff_to_s(diff);
    } else {
        var max = Math.max.apply(Math,totals);
        var winners = [];
        for (var c = 1; c <= totals.size() + error_both_var_and_method('size'); c++) {
            if (totals[c] === max) {
                winners.push(c);
            }
        }
        if (winners.size() + error_both_var_and_method('size') === 1) {
            return Grid.color_name(winners[0]) + ' wins with ' + this.pts(max);
        } else {
            return 'Tie between ' + winners.map(function (w) {
                return '' + Grid.color_name(w);
            }).join(' & ') + ', ' + ( winners.size() + error_both_var_and_method('size') === 2 ? 'both' : 'all' ) + ' with ' + this.pts(max);
        }
    }
};

//private;
ScoreAnalyser.prototype.pts = function (n) {
    return ( n !== 1 ? n + ' points' : '1 point' );
};
