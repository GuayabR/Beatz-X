extends Node

var System: Variant

func _ready() -> void:
	System = get_parent()

var rendered_beatlines := {}
const NOTE_RENDER_DISTANCE: float = 986.0
const BEAT_RENDER_DISTANCE := 1000.0
var difficulty_thread: Thread
var difficulty_result: Dictionary = {}
var difficulty_calculating := false
var difficulty_dirty := false
var difficulty_graph_data := {}

func _on_note_hovered(note: Node2D) -> void:
	if System.hovered_note == note:
		return

	if System.hovered_note:
		var t = create_tween()
		t.tween_property(System.hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15)
		t.parallel().tween_property(System.hovered_note.get_node("noteImg"), "modulate", Color(1,1,1,1), 0.2)

	System.hovered_note = note

	if System.editor_mode == "view":
		var t = create_tween()
		t.tween_property(note.get_node("noteImg"), "scale", Vector2(1.05, 1.05), 0.1)
		t.parallel().tween_property(note.get_node("noteImg"), "modulate", Color(0.607, 1.0, 0.577, 1.0), 0.2)

	elif System.editor_mode == "delete":
		var t = create_tween()
		t.tween_property(note.get_node("noteImg"), "scale", Vector2(0.95, 0.95), 0.1)
		t.parallel().tween_property(note.get_node("noteImg"), "modulate", Color(1,1,1,0.6), 0.15)

func _on_note_unhovered(note: Node2D) -> void:
	if System.hovered_note != note:
		return

	var t = create_tween()
	t.tween_property(note.get_node("noteImg"), "scale", Vector2.ONE, 0.15)
	t.parallel().tween_property(note.get_node("noteImg"), "modulate", Color(1,1,1,1), 0.2)

	System.hovered_note = null

func _on_note_pressed(note: Node2D, event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if System.editor_mode == "view":
			System.dragged_note = note

		elif System.editor_mode == "delete":
			System.delete_note(note)

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if System.editor_mode in ["view"]:
			System.resizing_hold_note = note

			# if note has no hold yet, create a temporary one so visuals appear
			if System.resizing_hold_note.hold_ms < 0.0:
				System.resizing_hold_note.hold_ms = 0.0

				var bar = System.resizing_hold_note.get_node("HoldBar2D")
				var bar2 = System.resizing_hold_note.get_node("HoldBar")
				var end = System.resizing_hold_note.get_node("note_hold_end")

				bar.visible = true
				bar2.visible = true
				if Settings.misc.editor_show_note_hold_ends: end.visible = true

				bar.points[1].y = 0.0
				bar.points[2].y = 20.0
				bar2.size.y = 0.0
				end.position.y = 0.0

func calculate_difficulty_threaded() -> void:
	difficulty_dirty = true

	if difficulty_calculating:
		return

	difficulty_calculating = true
	difficulty_dirty = false

	if difficulty_thread and difficulty_thread.is_started():
		difficulty_thread.wait_to_finish()

	difficulty_thread = Thread.new()
	difficulty_thread.start(calculate_difficulty)

func calculate_difficulty() -> Dictionary:
	#print("runnning")
	if System.notes.is_empty():
		return {
			"rating": 0.0,
			"peak_nps": 0.0,
			"average_nps": 0.0
		}

	var sorted_notes = System.notes.duplicate()

	sorted_notes.sort_custom(func(a, b):
		return a.timestamp < b.timestamp
	)

	var note_counts := {}
	var graph_data := {}

	var total_notes = sorted_notes.size()
	var diagonal_notes := 0

	var break_penalty := 0.0

	var first_timestamp: float = sorted_notes[0].timestamp
	var last_timestamp: float = sorted_notes[-1].timestamp

	var previous_timestamp := first_timestamp

	for i in total_notes:
		var note = sorted_notes[i]

		var timestamp: float = note.timestamp

		var second := int(timestamp * 0.001)

		var new_count = note_counts.get(second, 0) + 1

		note_counts[second] = new_count
		graph_data[second] = new_count

		match note.type:
			"Upright", "Downright", "Upleft", "Downleft":
				diagonal_notes += 1

		if i != 0:
			var gap_seconds := (timestamp - previous_timestamp) * 0.001

			if gap_seconds > 3.0:
				break_penalty += (gap_seconds - 3.0) * 0.005

		previous_timestamp = timestamp

	var peak_nps := 0.0
	var total_nps := 0.0

	for nps in note_counts.values():
		total_nps += nps

		if nps > peak_nps:
			peak_nps = nps

	var active_sections: float = max(note_counts.size(), 1)

	var average_nps: float = total_nps / active_sections

	var song_length: float = max((last_timestamp - first_timestamp) * 0.001, 1.0)

	var length_factor: float = clamp(song_length / 120.0, 0.85, 1.15)

	var diagonal_ratio: float = float(diagonal_notes) / max(total_notes, 1)
	var diagonal_bonus: float = 1.0 + (diagonal_ratio * 0.08)

	var difficulty_rating := (
		average_nps * 0.95 +
		peak_nps * 0.3
	)

	difficulty_rating *= length_factor
	difficulty_rating *= diagonal_bonus

	difficulty_rating -= break_penalty

	return {
		"rating": snappedf(max(difficulty_rating, 0.0), 0.01),
		"peak_nps": snappedf(peak_nps, 0.01),
		"average_nps": snappedf(average_nps, 0.01),
		"song_length": snappedf(song_length, 0.01),
		"break_penalty": snappedf(break_penalty, 0.01),
		"diagonal_ratio": snappedf(diagonal_ratio, 0.001),
		"graph_data": graph_data
	}

func get_nps_color(nps: float) -> Color:
	var t = clamp(nps / 35.0, 0.0, 1.0)

	var cyan := Color(0.0, 1.0, 1.0, 0.5)        # 0 NPS
	var blue := Color(0.702, 0.0, 1.0, 0.6)
	var purple := Color(1.0, 0.0, 0.482, 0.7)
	var red := Color(1.0, 0.0, 0.0, 0.9)
	var black := Color(0.0, 0.0, 0.0, 1.0)       # 35 NPS

	if t < 0.25:
		return cyan.lerp(blue, t / 0.25)
	elif t < 0.5:
		return blue.lerp(purple, (t - 0.25) / 0.25)
	elif t < 0.8:
		return purple.lerp(red, (t - 0.5) / 0.25)
	else:
		return red.lerp(black, (t - 0.75) / 0.25)

func update_difficulty_graph() -> void:
	if not Settings.misc.editor_show_diff_graph:
		return

	var scroll = System.get_node("Control/chart_controls/chart_scroll")

	for child in scroll.get_children():
		if child is ColorRect:
			child.queue_free()

	if difficulty_result.is_empty():
		return

	if not difficulty_result.has("graph_data"):
		return

	var graph_data: Dictionary = difficulty_result["graph_data"]
	if graph_data.is_empty():
		return

	var peak_nps: float = max(difficulty_result["peak_nps"], 1.0)

	var scroll_height = scroll.size.y
	var max_second = max(int(System.song_len), 1)

	var BAR_COUNT: int = int(scroll_height / 4.0)
	var seconds_per_bar: float = float(max_second) / float(BAR_COUNT)

	for bar_index in range(BAR_COUNT):
		var start_second: float = bar_index * seconds_per_bar
		var end_second: float = (bar_index + 1) * seconds_per_bar

		var total_nps := 0.0
		var samples := 0

		for second in graph_data.keys():
			if second >= start_second and second < end_second:
				total_nps += graph_data[second]
				samples += 1

		var nps := 0.0
		if samples > 0:
			nps = total_nps / samples

		var rect := ColorRect.new()
		rect.name = "diff_rect_%s" % bar_index

		# WIDTH = strength (relative)
		var width_strength = clamp(nps / peak_nps, 0.0, 1.0)
		rect.size = Vector2(lerpf(20.0, 75.0, width_strength), 2)

		var y = scroll_height - (
			(float(bar_index) / float(BAR_COUNT)) * scroll_height
		)

		rect.position = Vector2(12, y - 4)

		rect.z_index = -1
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# COLOR = absolute NPS scale (0 → 35)
		rect.color = get_nps_color(nps)

		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		rect.material = mat

		scroll.add_child(rect)

func _setup_notes():
	if System.setting_up:
		return

	for child in System.get_node("notes").get_children():
		child.queue_free()

	System.rendered_notes.clear()

	var highest_y: float = ((System.song_len_ms) * System.note_speed / System.zoom)
	#var highest_time: float = song_len

	for n: Dictionary in System.notes:
		var timestamp = n.timestamp + System.OFFSET + System.BASE_TIME
		var y = (timestamp * System.note_speed / 10.0) * -1

		if -y > highest_y:
			highest_y = -y

		#if (n.timestamp + 1080.0) / 1000.0 > highest_time:
			#highest_time = (n.timestamp + 1080.0) / 1000.0

	System.highest_note_y = highest_y
	System.highest_timestamp = System.song_len

	System.get_node("Control/chart_controls/chart_scroll").min_value = 0
	System.get_node("Control/chart_controls/chart_scroll").max_value = System.highest_timestamp

	System.get_node("Control/chart_details/note_count").text = "Total notes: " + str(System.notes.size())

	_update_visible_notes()

	calculate_difficulty_threaded()

	_update_visible_beatlines()

func _update_visible_notes():
	var min_y = -1 * System.get_y() - NOTE_RENDER_DISTANCE
	var max_y = -1 * System.get_y() + NOTE_RENDER_DISTANCE

	var visible_notes := {}

	for i in range(System.notes.size()):
		var n = System.notes.get(i)

		if n == null:
			print("Note not found in index ", i)
			continue

		var timestamp = n.timestamp + (System.OFFSET * 2) + System.BASE_TIME
		var y = (timestamp * System.note_speed / 10.0) * -1

		var hold_ms: float = 0.0
		if n.has("hold"):
			hold_ms = n.hold

		var tail_y = y
		if hold_ms > 0.0:
			var hold_pixels = (hold_ms * System.note_speed / 10.0)
			tail_y = y + -hold_pixels  # downward extension (because y is inverted)

		var on_screen = not (
			(max(y, tail_y) < min_y) or
			(min(y, tail_y) > max_y)
		)

		if not on_screen:
			continue

		visible_notes[i] = true

		if System.rendered_notes.has(i):
			var existing = System.rendered_notes[i]

			if is_instance_valid(existing):
				continue

			System.rendered_notes.erase(i)

		var obj = System.NOTE.instantiate()

		obj.note_index = i

		obj.note_id = n.get("id", -1)

		obj.edit = true
		obj.timestamp = n.timestamp

		var x := _get_note_x(n.type)

		obj.position = Vector2(x, y)
		obj.scale = Vector2(0.65, 0.65)

		if n.has("hold") and n.hold > 0.0:
			obj.hold_ms = n.hold

		var effects := []

		for fx in n.keys():
			if fx == "timestamp" or fx == "type":
				continue

			effects.append([fx, n[fx]])

		obj.effects = effects

		obj.set_type(n.type)
		System.EditorRecordingSystem.refresh_note_range_visual(obj)

		obj.editor_hovered.connect(_on_note_hovered)
		obj.editor_unhovered.connect(_on_note_unhovered)
		obj.editor_pressed.connect(_on_note_pressed)

		if System.menu_open: obj.get_node("editor_hitbox").mouse_filter = Control.MOUSE_FILTER_IGNORE

		System.get_node("notes").add_child(obj)

		System.rendered_notes[i] = obj

	var to_remove := []

	for i in System.rendered_notes.keys():
		if visible_notes.has(i):
			continue

		var obj = System.rendered_notes[i]

		# keep selected notes alive even offscreen
		if System.selected_notes.has(obj):
			continue

		if is_instance_valid(obj):
			obj.queue_free()

		to_remove.append(i)

	for i in to_remove:
		System.rendered_notes.erase(i)

func _get_note_x(type: String) -> float:
	match type:
		"Effect",  "Section":
			return System.get_node("stationary_notes/noteEffectSprite").position.x

		"Upleft":
			return System.get_node("stationary_notes/noteUpleftSprite").position.x

		"Downleft":
			return System.get_node("stationary_notes/noteDownleftSprite").position.x

		"Left":
			return System.get_node("stationary_notes/noteLeftSprite").position.x

		"Down":
			return System.get_node("stationary_notes/noteDownSprite").position.x

		"Up":
			return System.get_node("stationary_notes/noteUpSprite").position.x

		"Right":
			return System.get_node("stationary_notes/noteRightSprite").position.x

		"Downright":
			return System.get_node("stationary_notes/noteDownrightSprite").position.x

		"Upright":
			return System.get_node("stationary_notes/noteUprightSprite").position.x

	if type != "out": print("Unrecognized note type: ", type)
	return System.get_node("stationary_notes/noteEffectSprite").position.x

func y_to_timestamp(y: float) -> float:
	return (-y * System.zoom / System.note_speed) - System.BASE_TIME - (System.OFFSET * 2.0)

func timestamp_to_y(t: float) -> float:
	return ((t + System.BASE_TIME + (System.OFFSET * 2.0)) * System.note_speed / System.zoom) * -1.0

func _update_visible_beatlines():
	var min_y = -1 * System.get_y() - BEAT_RENDER_DISTANCE
	var max_y = -1 * System.get_y() + BEAT_RENDER_DISTANCE

	var min_time = y_to_timestamp(max_y)
	var max_time = y_to_timestamp(min_y)

	var interval = System.beattime_ms
	var sub_div := 4

	# IMPORTANT: align start to actual interval grid
	var start_t = floor(min_time / interval) * interval

	var visible_beatlines := {}
	var t = start_t

	while t <= max_time:
		# DO NOT SNAP main_time
		var main_time = t

		var main_key := "beat_%d" % round(main_time * 1000.0)
		visible_beatlines[main_key] = true

		if not rendered_beatlines.has(main_key):
			var y := timestamp_to_y(main_time)

			var line = System.BEAT.instantiate()
			line.position = Vector2(960, y)
			line.process_mode = Node.PROCESS_MODE_DISABLED
			System.get_node("beatlines").add_child(line)

			rendered_beatlines[main_key] = line
		else:
			var line = rendered_beatlines[main_key]
			if is_instance_valid(line):
				line.position.y = timestamp_to_y(main_time)

		# SUBDIVISIONS (pure math, no snapping
		for i in range(1, sub_div):
			var sub_time = t + (interval * float(i) / sub_div)

			var sub_key := "beat_%d_%d" % [round(t * 1000.0), i]
			visible_beatlines[sub_key] = true

			if not rendered_beatlines.has(sub_key):
				var y := timestamp_to_y(sub_time)

				var sub = System.BEAT.instantiate()
				sub.position = Vector2(960, y)
				sub.scale = Vector2(2.6, 0.3)
				sub.modulate = Color(0.5, 0.5, 0.5, 1.0)
				sub.process_mode = Node.PROCESS_MODE_DISABLED

				System.get_node("beatlines").add_child(sub)
				rendered_beatlines[sub_key] = sub
			else:
				var sub = rendered_beatlines[sub_key]
				if is_instance_valid(sub):
					sub.position.y = timestamp_to_y(sub_time)

		t += interval

	# cleanup
	var to_remove := []

	for k in rendered_beatlines.keys():
		if not visible_beatlines.has(k):
			if is_instance_valid(rendered_beatlines[k]):
				rendered_beatlines[k].queue_free()
			to_remove.append(k)

	for k in to_remove:
		rendered_beatlines.erase(k)

func _setup_beatlines():
	for line in System.get_node("beatlines").get_children():
		line.queue_free()

	var t = 0.0 - System.beattime * 16
	var times = System.local_beat_offset

	while t <= System.song_len:
		# MAIN BEAT
		var main_timestamp = t + times

		var y = (
			((main_timestamp * 1000.0) + System.BASE_TIME - System.OFFSET)
			* System.note_speed
			/ System.zoom
		) * -1.0

		var main_line = System.BEAT.instantiate()

		main_line.position = Vector2(960, y)
		main_line.process_mode = Node.PROCESS_MODE_DISABLED

		System.get_node("beatlines").add_child(main_line)

		# SUBDIVISIONS
		for i in range(1, 4):
			var sub_t = t + (System.beattime / 4.0) * i

			if sub_t > System.song_len:
				break

			var sub_timestamp = sub_t + times

			var sub_y = (
				((sub_timestamp * 1000.0) + System.BASE_TIME - System.OFFSET)
				* System.note_speed
				/ System.zoom
			) * -1.0

			var sub_line = System.BEAT.instantiate()

			sub_line.position = Vector2(960, sub_y)
			sub_line.scale = Vector2(2.6, 0.3)
			sub_line.modulate = Color(0.5, 0.5, 0.5, 1.0)
			sub_line.process_mode = Node.PROCESS_MODE_DISABLED

			System.get_node("beatlines").add_child(sub_line)

		t += System.beattime
