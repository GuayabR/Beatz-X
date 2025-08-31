extends Control

var points_ref : Array = []
var value_updated_callback: Callable = Callable()

var radius := 6
var dragging_point := -1

func _ready():
	# Default points if empty
	if points_ref.is_empty():
		points_ref = [
			Vector2(0.0, 1.0),
			Vector2(0.5, 1.0),
			Vector2(1.0, 1.0)
		]
	set_process_input(true)

func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				for i in range(points_ref.size()):
					var p = _to_canvas(points_ref[i])
					if p.distance_to(event.position) <= radius:
						dragging_point = i
						break
			else:
				dragging_point = -1
	elif event is InputEventMouseMotion and dragging_point != -1:
		var local_pos = _to_local_space(event.position)
		local_pos.x = clamp(local_pos.x, 0.0, 1.0)
		local_pos.y = clamp(local_pos.y, 0.0, 3.5)
		points_ref[dragging_point] = local_pos
		if value_updated_callback:
			value_updated_callback.call()
		queue_redraw()

func _draw():
	# Border
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1), false, 2)

	# Vertical marker lines
	for i in range(11):
		var x_pos = i * size.x / 10.0
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, size.y), Color(0.3, 0.3, 0.3))

	# Build Curve
	var curve := Curve.new()
	for p in points_ref:
		curve.add_point(Vector2(p.x, p.y))

	# Draw Curve
	var prev_point = Vector2(0, _to_canvas_y(curve.sample(0)))
	for i in range(1, size.x):
		var t = float(i) / size.x
		var y = _to_canvas_y(curve.sample(t))
		var current_point = Vector2(t * size.x, y)
		draw_line(prev_point, current_point, Color(1, 0.6, 0.0), 2)
		prev_point = current_point

	# Draw control points
	for i in range(points_ref.size()):
		var p = _to_canvas(points_ref[i])
		draw_circle(p, radius, Color(1, 0, 0))
		var text := "%.2f, %.2f" % [points_ref[i].x, points_ref[i].y]
		var font := get_theme_default_font()
		draw_string_outline(font, p + Vector2(5, -5), text, 0, 1, 16, 1, Color.BLACK)
		draw_string(font, p + Vector2(5, -5), text)

func _to_canvas(p: Vector2) -> Vector2:
	return Vector2(p.x * size.x, size.y - (p.y / 3.5) * size.y)

func _to_local_space(pos: Vector2) -> Vector2:
	return Vector2(pos.x / size.x, 1.0 - (pos.y / size.y)) * Vector2(1.0, 3.5)

func _to_canvas_y(value: float) -> float:
	return size.y - clamp(value / 3.5, 0.0, 1.0) * size.y

func get_sampled_array(samples := 11) -> Array:
	var curve := Curve.new()
	for p in points_ref:
		curve.add_point(Vector2(p.x, p.y))

	var result := []
	for i in range(samples):
		var t = float(i) / (samples - 1)
		var y = curve.sample(t)
		result.append(Vector2(t, y))
	return result
