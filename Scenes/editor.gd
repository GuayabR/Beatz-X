extends Node2D

var selected_stream: AudioStream

var selected_title: String
var selected_artist: String
var selected_album: String
var selected_cover
var selected_year: int

var selected_beatz_path

var start_wait: int = 0 

var preview_start: float = 0.0
var preview_end: float = 30.0

var fade_in: bool = false
var fade_out: bool = false

var selected_difficulty: String

var selected_chart_name: String

var selected_charter: String

var selected_bpm: float

var note_speed : float = Globals.settings.game.note_speed

var zoom: float = 10.0

var notes := []

var NOTE := preload("res://Scenes/note.tscn")
var GAME := load("res://Scenes/main.tscn")

var preview_note: Node2D = null

var hovered_note: Node2D = null

var dragged_note: Node2D = null

var editor_mode: String = "view" # view, place, delete, select

var saved: bool = true

var buttons_to_disable_on_play

var buttons

var OFFSET = Globals.settings.misc_settings.note_offset

func _ready() -> void:
	print(GAME)
	$song.stream = selected_stream
	
	$Control/song_details/song_title.text = selected_title
	$Control/song_details/song_artist.text = selected_artist
	$Control/song_details/album.text = selected_album
	$Control/song_details/year.text = str(selected_year)
	
	$Control/chart_details/chart_name.text = "\"" + selected_chart_name + "\""
	$Control/chart_details/charter.text = selected_charter
	$Control/chart_details/diff.text = "Difficulty: " + selected_difficulty.to_pascal_case()
	$Control/chart_details/bpm.text = "BPM: " + str(selected_bpm)
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
	$Control/chart_details/note_speed.text = "Note speed: " + str(note_speed)
	
	buttons_to_disable_on_play = [
		$Control/zoom_scroll,
		$Control/editor_controls/place_btn,
		$Control/editor_controls/reload,
		$Control/editor_controls/dlt_btn,
		$Control/chart_btns/speed,
		$Control/chart_btns/playtest,
		$Control/chart_controls/chart_scroll,
		$Control/editor_controls/view_btn
	]
	
	buttons = [$Control/editor_controls/view_btn, $Control/zoom_scroll, $Control/editor_controls/place_btn, $Control/editor_controls/reload, $Control/editor_controls/dlt_btn, $Control/chart_btns/play, $Control/chart_btns/speed, $Control/chart_btns/playtest, $Control/chart_controls/chart_scroll, $Control/chart_controls/exit, $Control/chart_controls/save]
	
	_setup_notes(notes)

var playing := false

func _process(delta: float) -> void:
	if not playing:
		var speed := 5.0
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 3.0
		if Input.is_key_pressed(KEY_CTRL):
			speed *= 0.5
		
		if Input.is_action_pressed("ui_up") or Input.is_action_pressed("noteUp"):
			$notes.position.y += speed
			_update_scroll_from_notes_position()
		if Input.is_action_pressed("ui_down") or Input.is_action_pressed("noteDown"):
			$notes.position.y -= speed
			_update_scroll_from_notes_position()

	# Space bar toggles play/pause
	if Input.is_action_just_pressed("ui_select"): # space
		if playing:
			_pause()
		else:
			_play()
	
	if editor_mode == "place" and preview_note and not playing:
		var mouse_pos = get_viewport().get_mouse_position()
		var note_type = get_lane_type(mouse_pos)
		if note_type != "out":
			# Match X pos to correct lane sprite
			match note_type:
				"Left": preview_note.position.x = $stationary_notes/noteLeftSprite.position.x
				"Down": preview_note.position.x = $stationary_notes/noteDownSprite.position.x
				"Up": preview_note.position.x = $stationary_notes/noteUpSprite.position.x
				"Right": preview_note.position.x = $stationary_notes/noteRightSprite.position.x
			# Y follows mouse relative to notes container
			preview_note.position.y = $notes.get_local_mouse_position().y
			preview_note.edit = true
			preview_note.set_type(note_type)
			preview_note.z_index = 2
			preview_note.show()
		else:
			preview_note.hide()
	
	if editor_mode == "view" and not playing:
		var note_to_hover := get_note_under_mouse()

		# reset old hovered
		if note_to_hover != hovered_note:
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)

			hovered_note = note_to_hover
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

		# dragging active
		if dragged_note:
			var local_y = $notes.get_local_mouse_position().y
			dragged_note.position.y = local_y

			# lane switch
			var note_type = get_lane_type(get_viewport().get_mouse_position())
			match note_type:
				"Left": dragged_note.position.x = $stationary_notes/noteLeftSprite.position.x
				"Down": dragged_note.position.x = $stationary_notes/noteDownSprite.position.x
				"Up": dragged_note.position.x = $stationary_notes/noteUpSprite.position.x
				"Right": dragged_note.position.x = $stationary_notes/noteRightSprite.position.x
			
			var old_time = dragged_note.timestamp
			var old_type = dragged_note.type

			# update its metadata in notes array
			var timestamp = ((-local_y) * zoom / note_speed) - 540.0 - OFFSET
			dragged_note.timestamp = timestamp
			print(dragged_note.timestamp)
			dragged_note.set_type(note_type)

			for i in range(notes.size()):
				if notes[i].timestamp == old_time and notes[i].type == old_type:
					# replace old entry
					notes[i] = {"timestamp": timestamp, "type": note_type}
					print("updated index in note")
					break
	
	if editor_mode == "delete" and not playing:
		var note_to_hover := get_note_under_mouse()
		if note_to_hover:
			if note_to_hover.editor_deleted == true or note_to_hover.faded == true: return
		if note_to_hover != hovered_note:
			# reset old hovered NOTE
			if hovered_note:
				if hovered_note.editor_deleted:
					hovered_note.get_node("noteImg").scale = Vector2.ONE
					hovered_note.get_node("noteImg").modulate.a = 1.0
					return
					
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_IN)

			# set new hovered NOTE
			hovered_note = note_to_hover
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2(0.95, 0.95), 0.1).set_ease(Tween.EASE_OUT)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate:a", 0.6, 0.15).set_ease(Tween.EASE_OUT)
	
	if playing and $song.playing:
		var song_len = $song.stream.get_length()
		if song_len > 0:
			#var ratio = $song.get_playback_position() / song_len
			# map ratio to scrollbar (0 = bottom, max = top)
			# reversed: bottom = 0, top = max
			$notes.global_position.y += 100 / (zoom / 10) * (note_speed as int) * (delta) #lerp(max_val, min_val, ratio)
			
			_update_scroll_from_notes_position()
			$Control/chart_controls/pos_label.text = "Position: " + str(snapped($notes.position.y, 0.01))
			for n in $notes.get_children():
				if n.global_position.y > $stationary_notes/lines/linemiddle.global_position.y:
					n.hide()

	
	$Control/chart_controls/pos_label.text = "Position: " + str(snapped($notes.position.y, 0.01))
	$Control/chart_controls/scroll_val.text = "Scroll: " + str(snapped($Control/chart_controls/chart_scroll.value, 0.01))
	$Control/chart_controls/scroll_lbl.text = "Time: " + str(snapped($song.get_playback_position(), 0.01))
	
	$Control/chart_btns/RichTextLabel.text = str(playing)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		match editor_mode:
			"view":
				if event.pressed:
					print("press dragging")
					if hovered_note:
						dragged_note = hovered_note
				else:
					print("rel")
					dragged_note = null

			"place":
				if event.pressed:
					var note_type = get_lane_type(event.position)
					if note_type != "out" and note_type != null:
						var local_y = $notes.get_local_mouse_position().y
						place_note_at(local_y, note_type)

			"delete":
				if event.pressed:
					var note_to_delete := get_note_under_mouse()
					if note_to_delete == null: return
					
					for i in range(notes.size()):
						var n = notes[i]
						if n.timestamp == note_to_delete.timestamp and n.type == note_to_delete.type:
							print("removing ", n, " at notes index ", i)
							notes.remove_at(i)
							$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
							break
					
					if note_to_delete:
						if note_to_delete.editor_deleted == true or note_to_delete.faded == true: return
						note_to_delete.editor_deleted = true
						note_to_delete.z_index -= 1
						note_to_delete.editor_delete()
						
						saved = false
						$Control/chart_controls/save.text = "Save"
					else:
						print("No NOTE")

			"select":
				if event.pressed:
					get_note_under_mouse()
	
	if event is InputEventMouseButton:
		if playing: return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP: 
			if Input.is_key_pressed(KEY_CTRL):
				$Control/zoom_scroll.value += 1
			else:
				var step = 0.75 if Input.is_key_pressed(KEY_SHIFT) else 0.07
				$Control/chart_controls/chart_scroll.value += step

		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if Input.is_key_pressed(KEY_CTRL):
				$Control/zoom_scroll.value -= 1
			else:
				var step = 0.75 if Input.is_key_pressed(KEY_SHIFT) else 0.07
				$Control/chart_controls/chart_scroll.value -= step

func get_note_under_mouse() -> Node2D:
	var mouse_pos = $notes.get_local_mouse_position()
	for note_node in $notes.get_children():
		if note_node is Node2D:
			var rect = Rect2(note_node.position - note_node.scale*64, note_node.scale*128) # approx size
			if rect.has_point(mouse_pos) and not note_node.editor_deleted:
				return note_node
	return null

# Determines which lane was clicked and returns the NOTE type
func get_lane_type(mouse_pos: Vector2) -> String:
	if $Control/note_lane.get_global_rect().has_point(mouse_pos):
		return "Left"
	elif $Control/note_lane2.get_global_rect().has_point(mouse_pos):
		return "Down"
	elif $Control/note_lane3.get_global_rect().has_point(mouse_pos):
		return "Up"
	elif $Control/note_lane4.get_global_rect().has_point(mouse_pos):
		return "Right"
	return "out"

# Spawns a new NOTE at the correct lane x and given y
func place_note_at(y_pos: float, note_type: String):
	var new_note = NOTE.instantiate()
	match note_type:
		"Left": new_note.position.x = $stationary_notes/noteLeftSprite.position.x
		"Down": new_note.position.x = $stationary_notes/noteDownSprite.position.x
		"Up": new_note.position.x = $stationary_notes/noteUpSprite.position.x
		"Right": new_note.position.x = $stationary_notes/noteRightSprite.position.x
	new_note.position.y = y_pos
	new_note.set_type(note_type)
	new_note.scale = Vector2(0.65, 0.65)
	
	# --- Add to notes array ---
	var timestamp = ((-y_pos) * zoom / note_speed) - 540.0 - OFFSET
	print("appending new NOTE at timestamp ", timestamp)
	notes.append({
		"timestamp": timestamp,
		"type": note_type,
	})
	
	new_note.timestamp = timestamp
	
	$notes.add_child(new_note)
	
	print("appended: ", note_type)

	# Update UI
	saved = false
	$Control/chart_controls/save.text = "Save*"
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))

func _update_scroll_from_notes_position():
	var song_len = $song.stream.get_length()
	if song_len <= 0:
		return
	
	if playing and $song.playing:
		var song_time = $song.get_playback_position()
		$Control/chart_controls/chart_scroll.set_value_no_signal(song_time)
	else:
		var time = ((-$notes.position.y) * zoom / note_speed) - OFFSET
		time = clamp(time, 0.0, song_len)
		$Control/chart_controls/chart_scroll.set_value_no_signal(time)

func _on_chart_scroll_value_changed(value: float) -> void:
	if $song.stream.get_length() > 0.0:
		$notes.position.y = _time_to_y(value)
	
	$Control/chart_controls/scroll_lbl.text = "Time: " + str(snapped($song.get_playback_position(), 0.01))
	$Control/chart_controls/scroll_val.text = "Value: " + str(snapped(value, 0.01))
	$Control/chart_controls/pos_label.text = "Position: " + str(snapped($notes.position.y, 0.01))

func _time_to_y(time: float) -> float:
	var scroll_time = $song.stream.get_length() - time
	var ratio = scroll_time / $song.stream.get_length()
	return lerp(highest_note_y, 0.0, ratio)

func _on_zoom_scroll_value_changed(_value: float) -> void:
	zoom = 10
	return
	
	#zoom = value
	#$Control/zoom_label.text = "Zoom: " + str(zoom)
#
	#var highest_timestamp := 0.0
	#for n in $notes.get_children():
		#if not n.timestamp:
			#continue
#
		#var time = n.timestamp
		## original unscaled y based on timestamp
		#var base_y = (time * note_speed) * -1
		## scrunch around -1080
		#var y = 988.2 + ((base_y - 988.2) / zoom)
#
		#n.position.y = y
#
		#if -y > highest_timestamp:
			#highest_timestamp = -y
#
	#highest_note_y = highest_timestamp

func _play() -> void:
	$Control/chart_btns/play.text = "Pause"
	playing = true
	var song_len = $song.stream.get_length()
	if song_len > 0:
		var song_time = clamp($Control/chart_controls/chart_scroll.value, 0.0, song_len)
		if $Control/chart_controls/chart_scroll.value >= song_len: 
			printerr("overflowed")
			song_time = 0.0
			$Control/chart_controls/chart_scroll.value = 0.0
			$notes.position.y = 0.0
		$song.play(song_time)
		print("playing at: ", song_time)
		
		for btn in buttons_to_disable_on_play:
			if btn == null:
				continue
			if btn is Button:
				btn.disabled = true
			else:
				btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _pause() -> void:
	$Control/chart_btns/play.text = "Play"
	playing = false
	print("paused at: ", $song.get_playback_position())
	$song.stop()
	for n in $notes.get_children():
		n.show()
	
	for btn in buttons_to_disable_on_play:
		if btn == null:
			continue
		if btn is Button:
			btn.disabled = false
		else:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP

var highest_note_y := 0.0
var highest_timestamp := 0.0

func _setup_notes(ns: Array):
	var song_len : float = $song.stream.get_length()
	var song_len_ms: float = $song.stream.get_length() * 1000.0
	
	var highest_y := 0.0
	var highest_time: float = song_len
	
	for n in ns:
		var x :float 
		match n.type:
			"Left": x = $stationary_notes/noteLeftSprite.position.x
			"Down": x =$stationary_notes/noteDownSprite.position.x
			"Up": x = $stationary_notes/noteUpSprite.position.x
			"Right": x = $stationary_notes/noteRightSprite.global_position.x
			_: x = $stationary_notes/noteUpSprite.global_position.x
		
		var displacement = 540.0 + OFFSET
		var timestamp = n.timestamp + displacement

		highest_y = ((song_len_ms) * note_speed / zoom)

		var y = (timestamp * note_speed / zoom) * -1 
		
		if -y > highest_y: highest_y = -y
		
		if (n.timestamp + 1080.0) / 1000.0 > highest_time: highest_time = (n.timestamp + 1080.0) / 1000.0

		var obj := NOTE.instantiate()
		obj.timestamp = n.timestamp
		obj.set_type(n.type)
		obj.position = Vector2(x, y)
		obj.scale = Vector2(0.65, 0.65)
		$notes.add_child(obj)
	
	highest_note_y = highest_y
	highest_timestamp = highest_time
	
	$Control/chart_controls/chart_scroll.min_value = 0
	$Control/chart_controls/chart_scroll.max_value = highest_timestamp
	print(highest_timestamp)
	$Control/chart_controls/chart_scroll.value = 0

func _on_reload_pressed() -> void:
	for obj in $notes.get_children():
		if obj.name != "preview": obj.queue_free()
	$notes.position.y = 0
	_setup_notes(notes)
	
	
	$Control/editor_controls/reload.release_focus()

func _on_play_pressed() -> void:
	if playing:
		_pause()
	else:
		_play()
	
	$Control/chart_btns/play.release_focus()

func _on_song_finished() -> void:
	_pause()

func _on_place_btn_pressed() -> void:
	editor_mode = "place"
	# Create preview NOTE if it doesn't exist
	if preview_note == null:
		preview_note = NOTE.instantiate()
		preview_note.name = "preview"
		preview_note.modulate.a = 0.5 # make transparent
		preview_note.scale = Vector2(0.65, 0.65)
		$notes.add_child(preview_note)
	
	$Control/editor_controls/place_btn.add_theme_color_override("font_color", Color.GREEN)
	$Control/editor_controls/place_btn.add_theme_constant_override("outline_size", 12)
	$Control/editor_controls/place_btn.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	$Control/editor_controls/place_btn.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/dlt_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_outline_color")
	
	$Control/editor_controls/view_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/view_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/view_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/view_btn.remove_theme_color_override("font_outline_color")
	
	hovered_note = null
	
	$Control/editor_controls/place_btn.release_focus()

func _on_view_btn_pressed() -> void:
	editor_mode = "view"
	if preview_note:
		preview_note.queue_free()
		preview_note = null
	
	$Control/editor_controls/place_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/place_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/place_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/place_btn.remove_theme_color_override("font_outline_color")
	
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/dlt_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_outline_color")
	
	$Control/editor_controls/view_btn.add_theme_color_override("font_color", Color.GREEN)
	$Control/editor_controls/view_btn.add_theme_constant_override("outline_size", 12)
	$Control/editor_controls/view_btn.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	$Control/editor_controls/view_btn.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	
	hovered_note = null
	
	$Control/editor_controls/view_btn.release_focus()

func _on_dlt_btn_pressed() -> void:
	editor_mode = "delete"
	if preview_note:
		preview_note.queue_free()
		preview_note = null
	
	$Control/editor_controls/place_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/place_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/place_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/place_btn.remove_theme_color_override("font_outline_color")
	
	$Control/editor_controls/dlt_btn.add_theme_color_override("font_color", Color.GREEN)
	$Control/editor_controls/dlt_btn.add_theme_constant_override("outline_size", 12)
	$Control/editor_controls/dlt_btn.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	$Control/editor_controls/dlt_btn.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	
	$Control/editor_controls/view_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/view_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/view_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/view_btn.remove_theme_color_override("font_outline_color")
	
	hovered_note = null
	$Control/editor_controls/dlt_btn.release_focus()

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_save_pressed() -> void:
	saved = true
	$Control/chart_controls/save.text = "Saved"
	
	$Control/chart_controls/save.release_focus()

func _on_edit_meta_pressed() -> void:
	var t = create_tween()
	t.tween_property($Control/edit_meta_cont, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/chart_controls/edit_meta.release_focus()

func _on_save_meta_btn_pressed() -> void:
	var t = create_tween()
	t.tween_property($Control/edit_meta_cont, "scale", Vector2.ZERO, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/edit_meta_cont/save_btn.release_focus()

func _on_playtest_pressed() -> void:
	var test = GAME.instantiate()
	
	# Pass data to the loading scene (it will forward it to main when loaded)
	test.set("chart_path", selected_beatz_path)
	test.set("song", selected_stream)
	test.set("song_title", selected_title)
	test.set("album", selected_album)
	test.set("artist", selected_artist)
	test.set("year", selected_year)
	test.set("cover", selected_cover)
	test.set("customNotes", notes)
	test.set("chart_name", selected_chart_name)
	test.set("charter", selected_charter)
	test.set("start_wait", start_wait)
	
	get_tree().root.add_child(test)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = test
