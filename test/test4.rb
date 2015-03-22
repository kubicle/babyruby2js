def init_color
  # For consultant heuristics we reverse the colors
  if @consultant
    @color = @player.enemy_color
  else
    @color = @player.color
  end
end
