extends Line2D

var line_move_t: Tween

## The farther the [code]at[/code] is from 0, if positive, the line will move to the right, if negative, line moves to the left.
func hit(at: float, earliest_window: float):
	var x = clampf(remap(at, -earliest_window, earliest_window, 200, -200), -200, 200)
	
	if line_move_t and line_move_t.is_valid() and line_move_t.is_running(): 
			line_move_t.kill()
	
	if x != $line/hit_outline.position.x:
		var line_move := create_tween()
		var col: Color
		
		line_move.tween_property($line/hit_outline, "position:x", x, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		var a: float = abs(at)
		if a < 55.0:
			col = Color.GREEN
		elif a < 110.0:
			col = Color.ORANGE
		else:
			col = Color.RED
		
		line_move.parallel().tween_property($line/hit_outline/glow, "modulate", col, 0.3)
		line_move_t = line_move
