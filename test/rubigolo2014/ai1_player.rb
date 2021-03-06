# TODO: 
# - do not fill my own territory (potential territory recognition will use analyser.enlarge method)
# - identify all foolish moves (like NoEasyPrisoner but once for all) in a map that all heuristics can use
# - foresee a poursuit = on attack/defense (and/or use a reverse-killer?)
# - an eye shape constructor

require_relative "player"
require_relative "goban"
require_relative "influence_map"
require_relative "potential_territory"
require_relative "ai/all_heuristics"
require_relative "time_keeper"
require_relative "genes"


class Ai1Player < Player
  
  attr_reader :goban, :inf, :ter, :enemy_color, :genes, :last_move_score
  
  def initialize(goban, color, genes=nil)
    super(false, goban)
    @inf = InfluenceMap.new(@goban)
    @ter = PotentialTerritory.new(@goban)
    @size = @goban.size

    @genes = (genes ? genes : Genes.new)
    @minimum_score = get_gene("smaller-move", 0.033, 0.02, 0.066)

    @heuristics = []
    @negative_heuristics = []
    Heuristic.all_heuristics.each do |cl|
      h = cl.new(self)
      if ! h.negative then @heuristics.push(h)
      else @negative_heuristics.push(h) end
    end

    set_color(color)

    # genes need to exist before we create heuristics so passing genes below is done
    # to keep things coherent
    prepare_game(@genes)
    
    # @timer = TimeKeeper.new
    # @timer.calibrate(0.7)
  end
  
  def prepare_game(genes)
    @genes = genes
    @num_moves = 0
  end

  def set_color(color)
    super(color)
    @enemy_color = 1 - color;
    @heuristics.each { |h| h.init_color }
    @negative_heuristics.each { |h| h.init_color }
  end
  
  def get_gene(name, def_val, low_limit=nil, high_limit=nil)
    @genes.get("#{self.class.name}-#{name}",def_val,low_limit,high_limit)
  end

  # Returns the move chosen (e.g. c4 or pass)
  # One can check last_move_score to see the score of the move returned
  def get_move
    # @timer.start("AI move",0.5,3)
    @num_moves += 1
    if @num_moves >= @size * @size # force pass after too many moves
      $log.error("Forcing AI pass since we already played #{@num_moves}")
      return "pass"
    end

    prepare_eval

    best_score = second_best = @minimum_score
    best_i = best_j = -1
    best_num_twin = 0 # number of occurrence of the current best score (so we can randomly pick any of them)
    1.upto(@size) do |j|
      1.upto(@size) do |i|
        score = eval_move(i,j,best_score)
        # Keep the best move
        if score > best_score
          second_best = best_score
          $log.debug("=> #{Grid.move_as_string(i,j)} becomes the best move with #{score} (2nd best is #{Grid.move_as_string(best_i,best_j)} with #{best_score})") if $debug
          best_score = score
          best_i = i
          best_j = j
          best_num_twin = 1
        elsif score == best_score
          best_num_twin += 1
          if rand(best_num_twin) == 0
            $log.debug("=> #{Grid.move_as_string(i,j)} replaces equivalent best move with #{score} (equivalent best was #{Grid.move_as_string(best_i,best_j)})") if $debug
            best_score = score
            best_i = i
            best_j = j
          end
        elsif score >= second_best
          $log.debug("=> #{Grid.move_as_string(i,j)} is second best move with #{score} (best is #{Grid.move_as_string(best_i,best_j)} with #{best_score})") if $debug
          second_best = score
        end
      end
    end
    @last_move_score = best_score

    # @timer.stop(false) # false: no exception if it takes longer but an error in the log
    return Grid.move_as_string(best_i, best_j) if best_score > @minimum_score

    $log.debug("AI is passing...") if $debug
    return "pass"
  end

  def prepare_eval
    @inf.build_map
    @ter.guess_territories
  end

  def eval_move(i, j, best_score=@minimum_score)
    return 0.0 if ! Stone.valid_move?(@goban, i, j, @color)
    score = 0.0
    # run all positive heuristics
    @heuristics.each { |h| score += h.eval_move(i,j) }
    # we run negative heuristics only if this move was a potential candidate
    if score >= best_score
      @negative_heuristics.each { |h| score += h.eval_move(i,j); break if score < best_score }
    end
    return score
  end

end
