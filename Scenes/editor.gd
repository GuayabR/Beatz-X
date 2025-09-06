extends Node2D

const BASE_TIME = 360.0

var new_beatzmap := true

var selected_stream: AudioStream
var selected_stream_path: String

var song_len: float

var song_path: String

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
var selected_diff_texture

var selected_chart_name: String

var selected_charter: String

var selected_bpm: float

var note_speed : float = 15.0 # Globals.settings.game.note_speed

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

var setting_up := false

var mandatory := []

func create_beatzmap():
	save_editor_mode()
	setting_up = true
	var t = create_tween()
	t.tween_property($Control/create_map_panel, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_CUBIC)
	
	$Control/chart_controls/save.text = "Unsaved*"

func create_from_dropped_file(path):
	$Control/create_map_panel/metadata_use_check.button_pressed = true
	
	_on_song_select_file_selected(true, [path], 0)
	
	$Control/chart_controls/save.text = "Unsaved*"

func _ready() -> void:
	buttons_to_disable_on_play = [
		$Control/zoom_scroll,
		$Control/editor_controls/place_btn,
		$Control/editor_controls/reload,
		$Control/editor_controls/dlt_btn,
		$Control/chart_btns/playtest,
		$Control/chart_controls/chart_scroll,
		$Control/editor_controls/view_btn,
		$Control/editor_controls/view_notes_array,
		$Control/editor_controls/tools
	]
	
	buttons = [$Control/editor_controls/tools, $Control/editor_controls/view_notes_array, $Control/editor_controls/view_btn, $Control/zoom_scroll, $Control/editor_controls/place_btn, $Control/editor_controls/reload, $Control/editor_controls/dlt_btn, $Control/chart_btns/play, $Control/chart_btns/playtest, $Control/chart_controls/chart_scroll, $Control/chart_controls/exit, $Control/chart_controls/save]
	
	$Control/chart_details/note_speed.text = "Note speed: " + str(note_speed)
	
	if new_beatzmap:
		create_beatzmap()
		return
	
	$song.stream = selected_stream
	
	song_len = $song.stream.get_length()
	
	$Control/song_details/song_title.text = selected_title
	$Control/song_details/song_artist.text = selected_artist
	$Control/song_details/album.text = selected_album
	$Control/song_details/year.text = str(selected_year)
	
	$Control/chart_details/chart_name.text = "\"" + selected_chart_name + "\""
	$Control/chart_details/charter.text = selected_charter
	$Control/chart_details/diff.text = "Difficulty: " + selected_difficulty.to_pascal_case()
	$Control/chart_details/diff_tex.texture = selected_diff_texture
	
	$Control/chart_details/bpm.text = "BPM: " + str(selected_bpm)
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
	
	$Control/song_details/sha/cover_spin.texture = selected_cover
	
	$Control/song_details/sha.show()
	
	if not song_path:
		var reading := FileAccess.open(selected_beatz_path, FileAccess.READ).get_as_text()
		
		# Look for the first section "Song:" and grab until the first backslash
		var song_file_name := ""
		var song_section_index := reading.find("Song:")
		if song_section_index != -1:
			var after_song := reading.substr(song_section_index + 5, reading.length()) # skip "Song:"
			var backslash_index := after_song.find("\\")
			if backslash_index != -1:
				song_file_name = after_song.substr(0, backslash_index).strip_edges()
			else:
				song_file_name = after_song.strip_edges() # fallback if no backslash
		
		# Construct the full path relative to the beatz file
		song_path = ProjectSettings.globalize_path(selected_beatz_path.get_base_dir() + "/" + song_file_name)
	
	$Control/song_details/song_path.text = "Path: " + song_path
	
	print(selected_beatz_path)
	print(song_path)
	
	_setup_notes()

var playing := false

func _process(delta: float) -> void:
	if not playing:
		if editor_mode == "none": return
		var speed := 5.0
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 3.0
		if Input.is_key_pressed(KEY_CTRL):
			speed *= 0.5
		
		if Input.is_action_pressed("ui_up") or Input.is_action_pressed("noteUp"):
			move(speed)
			_update_scroll_from_notes_position()
		if Input.is_action_pressed("ui_down") or Input.is_action_pressed("noteDown"):
			move(-speed)
			_update_scroll_from_notes_position()

	# Space bar toggles play/pause
	if Input.is_action_just_pressed("ui_select"): # space
		if playing:
			_pause()
		else:
			_play()
	
	if playing and $song.playing:
		var amount = 100 / (zoom / 10) * (note_speed as int * $song.pitch_scale) * (delta)
		if song_len > 0:
			#var ratio = $song.get_playback_position() / song_len
			# map ratio to scrollbar (0 = bottom, max = top)
			# reversed: bottom = 0, top = max
			move(amount)
			_update_scroll_from_notes_position()
			$Control/chart_controls/pos_label.text = "Position: " + str(snapped(get_y(), 0.01))
			#for n in $notes.get_children():
				#if n.global_position.y > $stationary_notes/lines/linemiddle.position.y:
					#n.hide()
	
	if editor_mode == "place" and preview_note:
		var mouse_pos = get_viewport().get_mouse_position()
		var note_type = get_lane_type(mouse_pos)
		if note_type != "out":
			# Match X pos to correct lane sprite
			match note_type:
				"Upleft": preview_note.position.x = $stationary_notes/noteUpleftSprite.position.x
				"Downleft": preview_note.position.x = $stationary_notes/noteDownleftSprite.position.x
				"Left": preview_note.position.x = $stationary_notes/noteLeftSprite.position.x
				"Down": preview_note.position.x = $stationary_notes/noteDownSprite.position.x
				"Up": preview_note.position.x = $stationary_notes/noteUpSprite.position.x
				"Right": preview_note.position.x = $stationary_notes/noteRightSprite.global_position.x
				"Downright": preview_note.position.x = $stationary_notes/noteDownrightSprite.position.x
				"Upright": preview_note.position.x = $stationary_notes/noteUprightSprite.position.x
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
				"Upleft": dragged_note.position.x = $stationary_notes/noteUpleftSprite.position.x
				"Downleft": dragged_note.position.x = $stationary_notes/noteDownleftSprite.position.x
				"Left": dragged_note.position.x = $stationary_notes/noteLeftSprite.position.x
				"Down": dragged_note.position.x = $stationary_notes/noteDownSprite.position.x
				"Up": dragged_note.position.x = $stationary_notes/noteUpSprite.position.x
				"Right": dragged_note.position.x = $stationary_notes/noteRightSprite.global_position.x
				"Downright": dragged_note.position.x = $stationary_notes/noteDownrightSprite.position.x
				"Upright": dragged_note.position.x = $stationary_notes/noteUprightSprite.position.x
			
			var old_time = dragged_note.timestamp
			var old_type = dragged_note.type

			# update its metadata in notes array
			var timestamp = ((-local_y) * zoom / note_speed) - BASE_TIME - OFFSET
			dragged_note.timestamp = timestamp
			#print(dragged_note.timestamp)
			dragged_note.set_type(note_type)

			for i in range(notes.size()):
				if notes[i].timestamp == old_time and notes[i].type == old_type:
					# replace old entry
					notes[i] = {"timestamp": timestamp, "type": note_type}
					#print("updated index in note")
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
	
	$Control/chart_controls/pos_label.text = "D Y Pos: " + str(snapped(get_y(), 0.01))
	if not setting_up: $Control/chart_controls/scroll_lbl.text = "D Song time: " + str(snapped($song.get_playback_position(), 0.01))
	$Control/chart_controls/scroll_val.text = "Time: " +  Globals.format_time($Control/chart_controls/chart_scroll.value)

func move(amnt: float = 0.0, use_old_logic: bool = true):
	if use_old_logic:
		$notes.position.y += amnt
		return
	$cam.global_position.y -= amnt
	$Control.global_position.y -= amnt
	$stationary_notes.global_position.y -= amnt
	$lanes.global_position.y -= amnt
	$lanes2.global_position.y -= amnt

func set_y(value: float = 0.0, use_old_logic: bool = true):
	if use_old_logic:
		$notes.position.y = value
		return
	$cam.global_position.y = value + 540.0
	$Control.global_position.y = value
	$stationary_notes.global_position.y = value
	$lanes.global_position.y = value
	$lanes2.global_position.y = value

func get_y(use_old_logic: bool = true):
	if use_old_logic: return $notes.global_position.y 
	else: return -$cam.global_position.y

func _input(event):
	if Input.is_action_just_pressed("fast_restart"):
		_on_reload_pressed()
	if Input.is_action_just_pressed("pause-back"):
		if editor_mode == "settings": _on_back_pressed()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		match editor_mode:
			"view":
				if setting_up: return
				if event.pressed:
					if hovered_note:
						dragged_note = hovered_note
				else:
					dragged_note = null

			"place":
				if setting_up: return
				if event.pressed and not playing:
					var note_type = get_lane_type(event.position)
					if note_type != "out" and note_type != null:
						var local_y = $notes.get_local_mouse_position().y
						place_note_at(local_y, note_type)

			"delete":
				if setting_up: return
				if event.pressed and not playing:
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
				if setting_up: return
				if event.pressed:
					get_note_under_mouse()
	
	if event is InputEventMouseButton:
		if playing or setting_up or editor_mode == "none": return

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
		if note_node is Node2D and not note_node.editor_deleted:
			var rect = Rect2(note_node.position - note_node.scale*64, note_node.scale*128) # approx size
			if rect.has_point(mouse_pos):
				return note_node
	return null

# Determines which lane was clicked and returns the NOTE type
func get_lane_type(mouse_pos: Vector2) -> String:
	if $Control/note_ul_lane.get_rect().has_point(mouse_pos):
		return "Upleft"
	elif $Control/note_dl_lane.get_rect().has_point(mouse_pos):
		return "Downleft"
	elif $Control/note_l_lane.get_rect().has_point(mouse_pos):
		return "Left"
	elif $Control/note_d_lane.get_rect().has_point(mouse_pos):
		return "Down"
	elif $Control/note_u_lane.get_rect().has_point(mouse_pos):
		return "Up"
	elif $Control/note_r_lane.get_rect().has_point(mouse_pos):
		return "Right"
	elif $Control/note_dr_lane.get_rect().has_point(mouse_pos):
		return "Downright"
	elif $Control/note_ur_lane.get_rect().has_point(mouse_pos):
		return "Upright"
	return "out"

# Spawns a new NOTE at the correct lane x and given y
func place_note_at(y_pos: float, note_type: String):
	if setting_up or editor_mode == "settings": return
	
	var new_note = NOTE.instantiate()
	match note_type:
		"Upleft": new_note.position.x = $stationary_notes/noteUpleftSprite.position.x
		"Downleft": new_note.position.x = $stationary_notes/noteDownleftSprite.position.x
		"Left": new_note.position.x = $stationary_notes/noteLeftSprite.position.x
		"Down": new_note.position.x = $stationary_notes/noteDownSprite.position.x
		"Up": new_note.position.x = $stationary_notes/noteUpSprite.position.x
		"Right": new_note.position.x = $stationary_notes/noteRightSprite.global_position.x
		"Downright": new_note.position.x = $stationary_notes/noteDownrightSprite.position.x
		"Upright": new_note.position.x = $stationary_notes/noteUprightSprite.position.x
	new_note.global_position.y = y_pos
	new_note.set_type(note_type)
	new_note.scale = Vector2(0.65, 0.65)
	
	# --- Add to notes array ---
	var timestamp = ((-y_pos) * zoom / note_speed) - BASE_TIME - OFFSET
	print("appending new NOTE at timestamp ", timestamp)
	notes.append({
		"timestamp": timestamp,
		"type": note_type,
	})
	
	new_note.timestamp = timestamp
	print(y_pos)
	print(new_note.global_position.y)
	print(new_note.position.y)
	$notes.add_child(new_note)
	
	print("appended: ", note_type)

	# Update UI
	saved = false
	$Control/chart_controls/save.text = "Save*"
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))

func _update_scroll_from_notes_position():
	if song_len <= 0:
		return
	
	if playing and $song.playing:
		var song_time = $song.get_playback_position()
		$Control/chart_controls/chart_scroll.set_value_no_signal(song_time)
	else:
		var time = ((get_y()) * zoom / note_speed) - OFFSET
		time /= 1000
		time = clamp(time, 0.0, song_len)
		$Control/chart_controls/chart_scroll.set_value_no_signal(time)

func _on_chart_scroll_value_changed(value: float) -> void:
	if setting_up: return
	
	if $song.stream.get_length() > 0.0:
		set_y(_time_to_y(value))
	
	$Control/chart_controls/pos_label.text = "D Y Pos: " + str(snapped(get_y(), 0.01))
	$Control/chart_controls/scroll_lbl.text = "D Song time: " + str(snapped($song.get_playback_position(), 0.01))
	$Control/chart_controls/scroll_val.text = "Time: " +  Globals.format_time(value)

func _time_to_y(time: float) -> float:
	if setting_up: return 0.0
	
	var scroll_time = $song.stream.get_length() - time
	var ratio = scroll_time / $song.stream.get_length()
	return lerp(highest_note_y, 0.0, ratio)

func _on_zoom_scroll_value_changed(value: float) -> void:
	
	zoom = value
	$Control/zoom_label.text = "Zoom: " + str(zoom)

	var highest_y := 0.0
	for n in $notes.get_children():
		if not n.timestamp:
			continue

		var time = n.timestamp
		# original unscaled y based on timestamp
		var base_y = ((time + BASE_TIME + OFFSET) * note_speed) * -1
		var origin = $stationary_notes/lines/linemiddle.position.y  # or your receptor line Y if that’s fixed

		var y = ((base_y - origin) / zoom)
		n.position.y = y #+ origin

		if -y > highest_y:
			highest_y = -y

	highest_note_y = highest_y

func _play() -> void:
	if setting_up or editor_mode == "settings": return
	
	save_editor_mode()
	if preview_note: preview_note.hide()
	
	$Control/chart_btns/play.text = "Pause"
	playing = true
	if song_len > 0:
		var song_time = clamp($Control/chart_controls/chart_scroll.value, 0.0, song_len)
		if $Control/chart_controls/chart_scroll.value >= song_len: 
			printerr("overflowed")
			song_time = 0.0
			$Control/chart_controls/chart_scroll.value = 0.0
			set_y(0.0)
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
	if setting_up: return
	
	restore_editor_mode()
	if preview_note: preview_note.show()
	
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

func _setup_notes():
	if setting_up: return
	var song_len_ms: float = song_len * 1000.0
	
	var highest_y := ((song_len_ms) * note_speed / zoom)
	var highest_time: float = song_len
	
	for n in notes:
		var x :float 
		match n.type:
			"Upleft": x = $stationary_notes/noteUpleftSprite.position.x
			"Downleft": x = $stationary_notes/noteDownleftSprite.position.x
			"Left": x = $stationary_notes/noteLeftSprite.position.x
			"Down": x = $stationary_notes/noteDownSprite.position.x
			"Up": x = $stationary_notes/noteUpSprite.position.x
			"Right": x = $stationary_notes/noteRightSprite.global_position.x
			"Downright": x = $stationary_notes/noteDownrightSprite.position.x
			"Upright": x = $stationary_notes/noteUprightSprite.position.x
			_: x = $stationary_notes/noteUpSprite.global_position.x
		
		var displacement = OFFSET + BASE_TIME
		var timestamp = n.timestamp + displacement
		var y = (timestamp * note_speed / 10) * -1
		
		if -y > highest_y: highest_y = -y
		
		if (n.timestamp + 1080.0) / 1000.0 > highest_time: highest_time = (n.timestamp + 1080.0) / 1000.0

		var obj := NOTE.instantiate()
		obj.edit = true
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
	
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))

func _on_reload_pressed() -> void:
	for obj in $notes.get_children():
		if obj.name != "preview": obj.queue_free()
	_setup_notes()
	
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

func _on_exit_warn_pressed() -> void:
	save_editor_mode()
	$Control/exit_warn/warn_lbl.text = "Are you sure you want to exit editing \"%s\"\n\nUnsaved edits will be lost." % selected_chart_name
	
	var t = create_tween()
	t.tween_property($Control/exit_warn, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/chart_controls/exit.release_focus()

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_cancel_exit_pressed() -> void:
	restore_editor_mode()
	var t = create_tween()
	t.tween_property($Control/exit_warn, "scale", Vector2.ZERO, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/chart_controls/exit.release_focus()

func _on_edit_meta_pressed() -> void:
	$song.pitch_scale = 0.82
	save_editor_mode()
	
	var t = create_tween()
	t.tween_property($Control/edit_meta_cont, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/chart_controls/edit_meta.release_focus()
	
	$Control/edit_meta_cont/chart_name_edit.text = selected_chart_name
	$Control/edit_meta_cont/song_name_edit.text = selected_title
	$Control/edit_meta_cont/charter_edit.text = selected_charter
	$Control/edit_meta_cont/diff_edit.text = selected_difficulty
	$Control/edit_meta_cont/diff_texture_edit.icon = selected_diff_texture
	$Control/edit_meta_cont/bpm_edit.text = str(selected_bpm)
	$Control/edit_meta_cont/song_file_select.text = "Change song file..."
	$Control/edit_meta_cont/song_file_label.text = song_path
	
	$Control/edit_meta_cont/artist_edit.text = selected_artist
	$Control/edit_meta_cont/album_edit.text = selected_album
	$Control/edit_meta_cont/year_edit.text = str(selected_year)
	$Control/edit_meta_cont/album_cover_edit.icon = selected_cover
	
	$Control/edit_meta_cont/metadata_use_check.button_pressed = use_meta_check

func _on_save_meta_btn_pressed() -> void:
	$song.pitch_scale = 1.0
	restore_editor_mode()
	var t = create_tween()
	t.tween_property($Control/edit_meta_cont, "scale", Vector2.ZERO, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/edit_meta_cont/save_btn.release_focus()
	
	$Control/chart_details/chart_name.text = '"' + $Control/edit_meta_cont/chart_name_edit.text + '"'
	selected_chart_name = $Control/edit_meta_cont/chart_name_edit.text
	
	$Control/song_details/song_title.text = $Control/edit_meta_cont/song_name_edit.text
	selected_title = $Control/edit_meta_cont/song_name_edit.text
	
	$Control/chart_details/charter.text = $Control/edit_meta_cont/charter_edit.text
	selected_charter = $Control/edit_meta_cont/charter_edit.text
	
	var diff_text: String = $Control/edit_meta_cont/diff_edit.text.strip_edges()
	$Control/chart_details/diff.text = "Difficulty: " + diff_text.to_pascal_case() if diff_text != "" else "Easy"
	selected_difficulty = $Control/edit_meta_cont/diff_edit.text
	
	$Control/chart_details/diff_tex.texture = $Control/edit_meta_cont/diff_texture_edit.icon
	selected_diff_texture = $Control/edit_meta_cont/diff_texture_edit.icon
	
	var bpm_text: String = $Control/edit_meta_cont/bpm_edit.text.strip_edges()
	$Control/chart_details/bpm.text = "BPM: " + bpm_text if bpm_text != "" else "BPM: 120"
	selected_bpm = float($Control/edit_meta_cont/bpm_edit.text)
	
	$Control/song_details/song_artist.text = $Control/edit_meta_cont/artist_edit.text
	selected_artist = $Control/edit_meta_cont/artist_edit.text
	
	$Control/song_details/album.text = $Control/edit_meta_cont/album_edit.text
	selected_album = $Control/edit_meta_cont/album_edit.text
	
	selected_cover = $Control/edit_meta_cont/album_cover_edit.icon
	
	$Control/song_details/sha/cover_spin.texture = selected_cover
	
	$Control/song_details/year.text = $Control/edit_meta_cont/year_edit.text
	selected_year = int($Control/edit_meta_cont/year_edit.text)
	
	$Control/song_details/song_path.text = "Path: " + song_path

func _on_playtest_pressed() -> void:
	if setting_up: return
	
	var test = GAME.instantiate()
	
	# Pass data to the loading scene (it will forward it to main when loaded)
	test.set("chart_path", selected_beatz_path)
	test.set("song_path", song_path)
	test.set("song", selected_stream)
	test.set("song_title", selected_title)
	test.set("album", selected_album)
	test.set("artist", selected_artist)
	test.set("year", selected_year)
	test.set("cover", selected_cover)
	test.set("customNotes", notes)
	test.set("chart_name", selected_chart_name)
	test.set("charter", selected_charter)
	
	get_tree().root.add_child(test)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = test

func _on_complete_setup_btn_pressed() -> void:
	restore_editor_mode()
	$Control/chart_details/chart_name.text = $Control/create_map_panel/chart_name_edit.text
	selected_chart_name = $Control/create_map_panel/chart_name_edit.text
	
	$Control/song_details/song_title.text = $Control/create_map_panel/song_name_edit.text
	selected_title = $Control/create_map_panel/song_name_edit.text
	
	$Control/chart_details/charter.text = $Control/create_map_panel/charter_edit.text
	selected_charter = $Control/create_map_panel/charter_edit.text
	
	var diff_text: String = $Control/create_map_panel/diff_edit.text.strip_edges()
	$Control/chart_details/diff.text = diff_text if diff_text != "" else "Easy"
	selected_difficulty = $Control/create_map_panel/diff_edit.text
	
	$Control/chart_details/diff_tex.texture = $Control/create_map_panel/diff_texture_edit.icon
	selected_diff_texture = $Control/create_map_panel/diff_texture_edit.icon
	
	var bpm_text: String = $Control/create_map_panel/bpm_edit.text.strip_edges()
	$Control/chart_details/bpm.text = bpm_text if bpm_text != "" else "120"
	selected_bpm = float($Control/create_map_panel/bpm_edit.text)
	
	$Control/song_details/song_artist.text = $Control/create_map_panel/artist_edit.text
	selected_artist = $Control/create_map_panel/artist_edit.text
	
	$Control/song_details/album.text = $Control/create_map_panel/album_edit.text
	selected_album = $Control/create_map_panel/album_edit.text
	
	selected_cover = $Control/create_map_panel/album_cover_edit.icon
	
	$Control/song_details/sha/cover_spin.texture = selected_cover
	
	$Control/song_details/sha.show()
	
	$Control/song_details/year.text = $Control/create_map_panel/year_edit.text
	selected_year = int($Control/create_map_panel/year_edit.text)
	
	$Control/song_details/song_path.text = "Path: " + song_path
	
	setting_up = false
	
	var t = create_tween()
	t.tween_property($Control/create_map_panel, "scale", Vector2.ZERO, .2).set_trans(Tween.TRANS_CUBIC)
	await t.finished
	
	_on_reload_pressed()

func _on_song_file_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .mp3, .wav or .ogg file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		["*.mp3", "*.wav", "*.ogg"],   # File filters
		Callable(self, "_on_song_select_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("create_song_file", err, error_string(err))

func _on_edit_song_file_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .mp3, .wav or .ogg file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		["*.mp3", "*.wav", "*.ogg"],   # File filters
		Callable(self, "_on_edit_song_select_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("edit_song_file", err, error_string(err))

func _on_song_select_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	if paths[0].get_extension() not in ["mp3", "ogg", "wav"]:
		$Control/create_map_panel/song_file_label.text = "Song has to be an mp3, ogg or wav file."
		return
	
	song_path = paths[0]
	$Control/create_map_panel/song_file_label.text = "Song: " + str(paths[0])
	
	var song_didnt_fail := true
	if song_path.ends_with(".mp3") or song_path.ends_with(".ogg") or song_path.ends_with(".wav"):
		if song_path.ends_with(".mp3"):
			selected_stream = AudioStreamMP3.load_from_file(song_path)
			print("Song created as mp3 ", selected_stream)
		elif song_path.ends_with(".ogg"):
			selected_stream = AudioStreamOggVorbis.load_from_file(song_path)
			print("Song created as ogg ", selected_stream)
		elif song_path.ends_with(".wav"):
			selected_stream = AudioStreamWAV.load_from_file(song_path)
			print("Song created as wav ", selected_stream)
		else:
			song_didnt_fail = false
			print("Unsupported audio format in: %s" % song_path)
			selected_stream = null
			
	if song_didnt_fail: 
		$song.stream = selected_stream
		song_len = $song.stream.get_length()
		if "song_file" not in mandatory:
			mandatory.append("song_file")
		_check_mandatory()
		
		print("Song saved ", $song.stream)
		$Control/create_map_panel/song_file_select.text = "Change song file..."
	
	if not song_path.get_extension() == "mp3":
		$Control/create_map_panel/metadata_use_check.button_pressed = false
		$Control/create_map_panel/metadata_use_check.text = "File is not an mp3."
	else:
		$Control/create_map_panel/metadata_use_check.disabled = false
		$Control/create_map_panel/metadata_use_check.text = "Use Song Metadata"
	
	if $Control/create_map_panel/metadata_use_check.button_pressed: _on_metadata_use_check_toggled(true)

func _on_edit_song_select_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	if paths[0].get_extension() not in ["mp3", "ogg", "wav"]:
		$Control/edit_meta_cont/song_file_label.text = "Song has to be an mp3, ogg or wav file."
		return
	
	song_path = paths[0]
	$Control/edit_meta_cont/song_file_label.text = "Song: " + str(paths[0])
	$Control/song_details/song_path.text = "Path: " + song_path
	
	var song_didnt_fail := true
	if song_path.ends_with(".mp3") or song_path.ends_with(".ogg") or song_path.ends_with(".wav"):
		if song_path.ends_with(".mp3"):
			selected_stream = AudioStreamMP3.load_from_file(song_path)
			print("Song created as mp3 ", selected_stream)
		elif song_path.ends_with(".ogg"):
			selected_stream = AudioStreamOggVorbis.load_from_file(song_path)
			print("Song created as ogg ", selected_stream)
		elif song_path.ends_with(".wav"):
			selected_stream = AudioStreamWAV.load_from_file(song_path)
			print("Song created as wav ", selected_stream)
		else:
			song_didnt_fail = false
			print("Unsupported audio format in: %s" % song_path)
			selected_stream = null
			
	if song_didnt_fail: 
		$song.stream = selected_stream
		song_len = $song.stream.get_length()
		print("Song saved ", $song.stream)
		
		$Control/edit_meta_cont/song_file_select.text = "Change song file..."
	
	if not song_path.get_extension() == "mp3":
		$Control/edit_meta_cont/metadata_use_check.button_pressed = false
		$Control/edit_meta_cont/metadata_use_check.text = "File is not an mp3."
	else:
		$Control/edit_meta_cont/metadata_use_check.disabled = false
		$Control/edit_meta_cont/metadata_use_check.text = "Use Song Metadata"
	
	if $Control/edit_meta_cont/metadata_use_check.button_pressed: _on_metadata_use_check_toggled(true)

var use_meta_check := false

func _on_metadata_use_check_toggled(toggled_on: bool) -> void:
	use_meta_check = toggled_on
	
	if not toggled_on or not selected_stream:
		return
	
	if selected_stream is not AudioStreamMP3:
		$Control/create_map_panel/metadata_use_check.button_pressed = false
		$Control/create_map_panel/metadata_use_check.text = "File is not an mp3."
		$Control/create_map_panel/metadata_use_check.release_focus()
		return
	
	# Parse ID3
	var metaRead := MP3ID3Tag.new()
	metaRead.stream = selected_stream
	
	# Track name
	var track := metaRead.getTrackName()
	if track and track.strip_edges() != "":
		$Control/create_map_panel/song_name_edit.text = track
		$Control/create_map_panel/chart_name_edit.text = track
		$Control/create_map_panel/chart_name_edit.text_changed.emit()
	else:
		print("Track name not in metadata")
	
	# Artist
	var artist := metaRead.getArtist()
	if artist and artist.strip_edges() != "":
		$Control/create_map_panel/artist_edit.text = artist
	else:
		print("Artist not in metadata")
	
	# Album
	var album := metaRead.getAlbum()
	if album and album.strip_edges() != "":
		$Control/create_map_panel/album_edit.text = album
	else:
		print("Album not in metadata")
	
	# Year
	var year := metaRead.getYear()
	if year and year.strip_edges() != "":
		$Control/create_map_panel/year_edit.text = year
	else:
		print("Year not in metadata")
	
	# Cover
	var cover_img: Image = metaRead.getAttachedPicture()
	if cover_img:
		var tex := ImageTexture.create_from_image(cover_img)
		$Control/create_map_panel/album_cover_edit.icon = tex
	else:
		
		print("Cover image not in metadata")

func _on_album_cover_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		["*.png", "*.jpg", "*"],   # File filters
		Callable(self, "_on_album_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("create_album", err, error_string(err))

var album_cover_path: String

func _on_album_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	album_cover_path = paths[0]

	var image := Image.new()
	var err := image.load(album_cover_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		$Control/edit_meta_cont/album_cover_edit.icon = tex
		$Control/create_map_panel/album_cover_edit.icon = tex
	else:
		print("Failed to load image: ", album_cover_path)

func _on_edit_metadata_use_check_toggled(toggled_on: bool) -> void:
	use_meta_check = toggled_on
	
	if not toggled_on or not selected_stream:
		return
	
	if selected_stream is not AudioStreamMP3:
		$Control/edit_meta_cont/metadata_use_check.button_pressed = false
		$Control/edit_meta_cont/metadata_use_check.text = "File is not an mp3."
		$Control/edit_meta_cont/metadata_use_check.release_focus()
		return
	
	# Parse ID3
	var metaRead := MP3ID3Tag.new()
	metaRead.stream = selected_stream
	
	# Track name
	var track := metaRead.getTrackName()
	if track and track.strip_edges() != "":
		$Control/edit_meta_cont/song_name_edit.text = track
		$Control/edit_meta_cont/chart_name_edit.text = track
	else:
		print("Track name not in metadata")
	
	# Artist
	var artist := metaRead.getArtist()
	if artist and artist.strip_edges() != "":
		$Control/edit_meta_cont/artist_edit.text = artist
	else:
		print("Artist not in metadata")
	
	# Album
	var album := metaRead.getAlbum()
	if album and album.strip_edges() != "":
		$Control/edit_meta_cont/album_edit.text = album
	else:
		print("Album not in metadata")
	
	# Year
	var year := metaRead.getYear()
	if year and year.strip_edges() != "":
		$Control/edit_meta_cont/year_edit.text = year
	else:
		print("Year not in metadata")
	
	# Cover
	var cover_img: Image = metaRead.getAttachedPicture()
	if cover_img:
		var tex := ImageTexture.create_from_image(cover_img)
		$Control/edit_meta_cont/album_cover_edit.icon = tex
	else:
		print("Cover image not in metadata")

func _get_save_path(overwrite: bool = true) -> String:
	var username := selected_charter.strip_edges()
	if username == "":
		username = "Unknown"
		
	var user_chart_name := selected_chart_name.strip_edges()
	if user_chart_name == "":
		user_chart_name = "Untitled"
	
	# Base filename
	var base_filename := "%s-%s" % [user_chart_name, username]
	var base_title := selected_title
	var folder_path: String
	var save_path: String
	if not selected_beatz_path:
		folder_path = "user://Custom/" + base_title + "/"
		save_path = folder_path + base_filename + ".beatz"
	else: save_path = selected_beatz_path
	
	# Handle copy case (no overwrite → increment folder)
	if not overwrite:
		if DirAccess.dir_exists_absolute("user://Custom/" + base_title):
			var time := Time.get_datetime_dict_from_system()
			folder_path = "user://Custom/" + base_title + " " + str(time.day) + "-" + str(time.month) + "-" + str(time.year) + "/"
			save_path = folder_path + base_filename + ".beatz"
	
	# Make sure folder exists
	DirAccess.make_dir_recursive_absolute(folder_path)
	
	return save_path

func _on_save_pressed() -> void:
	$song.pitch_scale = 0.82
	var save_path := _get_save_path()
	$Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(save_path)
	
	save_editor_mode()

	var t = create_tween()
	t.tween_property($Control/save_to_list, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/chart_controls/save.release_focus()

func _on_save_to_list_pressed() -> void:
	$song.pitch_scale = 1.0
	_encode_beatz_file(notes, song_path)
	
	saved = true
	$Control/chart_controls/save.text = "Saved"

func _on_save_copy_to_list_pressed() -> void:
	$song.pitch_scale = 1.0
	_encode_beatz_file(notes, song_path, false)
	
	saved = true
	$Control/chart_controls/save.text = "Saved"

func _on_share_chart_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"SHARE your Beatzmap!",
		"", # starting dir
		selected_title + " by " + selected_charter, # starting file
		true,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		["*.bx"],
		Callable(self, "_on_share_chart_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("share", err, error_string(err))

func nat_file_dialog_fail(which: String, err: Error, err_string: String):
	const BASE_CONTACT = "\nPlease contact playbeatzx@gmail.com\nthis error message and screen."
	match which:
		"share":
			$Control/save_to_list/saving_to_lbl.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"create_cover":
			$Control/create_map_panel/album_cover_edit.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"create_song_file":
			$Control/create_map_panel/song_file_label.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"diff_texture":
			$Control/create_map_panel/diff_texture_edit.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
			$Control/edit_meta_cont/diff_texture_edit.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"edit_cover":
			$Control/edit_meta_cont/album_cover_edit.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"edit_song_file":
			$Control/edit_meta_cont/song_file_label.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT

# Must accept exactly 1 argument (PackedStringArray)
func _on_share_chart_file_selected(status: bool, paths: PackedStringArray, filter_idx: int) -> void:
	print("sta", status)
	print("paths ", paths)
	print("filter idx", filter_idx)
	
	if paths.is_empty():
		return

	var save_path = paths[0]
	if not save_path.ends_with(".bx"):
		save_path += ".bx"

	_encode_beatz_file(notes, song_path, true, true, save_path)

func _encode_beatz_file(decoded_notes, current_song_path: String, overwrite: bool = true, share_mode: bool = false, share_save_path: String = "") -> void:
	# Make sure we have notes
	if decoded_notes.is_empty():
		push_error("No custom notes found. Record some!")
		return

	# Encode notes
	var encoded_notes := Globals.encode_notes(decoded_notes)

	# Determine note mode based on note types
	var user_note_mode := 4
	for note_str in encoded_notes.split(","):
		if note_str.find("DL") != -1 or note_str.find("DR") != -1:
			user_note_mode = 6
		elif note_str.find("UL") != -1 or note_str.find("UR") != -1:
			user_note_mode = 8

	# Prompt the user for metadata
	var username := selected_charter.strip_edges()
	if username == "":
		username = "Unknown"

	var user_chart_name := selected_chart_name.strip_edges()
	if user_chart_name == "":
		user_chart_name = "Untitled"

	var song_name := current_song_path.get_file().get_basename()
	var user_bpm := selected_bpm
	var user_note_speed := note_speed

	# Find lowest negative timestamp for start_wait
	@warning_ignore("unused_variable")
	var wait := 0.0
	var negatives: Array = []
	for n in decoded_notes:
		if n.has("timestamp") and n.timestamp < 0:
			negatives.append(n.timestamp)
	if not negatives.is_empty():
		wait = -float(negatives.min())  # Convert negative to positive

	# Format the content for the .beatz file
	var content := "Song: %s\\" % song_name
	content += "Charter: %s\\" % username
	content += "ChartName: %s\\" % user_chart_name
	content += "noteMode: %d\\" % user_note_mode
	content += "BPM: %s\\" % str(user_bpm)
	content += "noteSpeed: %s\\" % str(user_note_speed)
	content += "noteSpawnY: %s\\" % str(360)
	content += "Difficulty: %s\\" % selected_difficulty
	content += "StartWait: %s\\" % str(start_wait)
	content += "PrevStart: 0.0\\PrevEnd: 99999.0\\"
	content += "Notes:%s" % encoded_notes

	# Build base save path and folder
	var save_path := _get_save_path(overwrite)
	var folder_path := save_path.get_base_dir()

	# Make sure folder exists
	DirAccess.make_dir_recursive_absolute(folder_path)

	# Save the .beatz file
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("Notes exported to %s successfully." % save_path)
		$Control/save_to_list/saving_to_lbl.text = "Saved succesfully!"
		saved = true
		$Control/chart_controls/save.text = "Saved"
	else:
		$Control/save_to_list/saving_to_lbl.text = "Failed to save."
		push_error("Failed to save file: %s" % save_path)
		return

	# Save audio
	if selected_stream and selected_stream is AudioStream:
		var audio_save_path := folder_path + "/" + song_name + ".mp3"
		var audio_file := FileAccess.open(audio_save_path, FileAccess.WRITE)
		if audio_file:
			# Save raw data (works if stream has `data` property, like AudioStreamMP3/WAV)
			if selected_stream.has_method("save_to_wav"): 
				# safer if it’s a generated stream
				selected_stream.save_to_wav(audio_save_path)
			elif "data" in selected_stream: 
				audio_file.store_buffer(selected_stream.data)
				audio_file.close()
			print("Saved audio to %s" % audio_save_path)

	# Save cover image
	if selected_cover and selected_cover is Texture2D:
		var img = selected_cover.get_image()
		if img:
			var cover_save_path := folder_path + "/" + selected_album + ".png"
			img.save_png(cover_save_path)
			print("Saved cover image to %s" % cover_save_path)
	
	# Save difficulty texture
	if selected_diff_texture and selected_diff_texture is Texture2D:
		var img = selected_diff_texture.get_image()
		if img:
			var diff_tex_save_path := folder_path + "/" + selected_difficulty + ".png"
			img.save_png(diff_tex_save_path)
			print("Saved cover image to %s" % diff_tex_save_path)

	# Save info.json
	var info_dict := {
		"info": {
			"title": selected_title,
			"artist": selected_artist,
			"album": selected_album,
			"year": selected_year
		}
	}
	
	var info_save_path := folder_path + "/info.json"
	var info_file := FileAccess.open(info_save_path, FileAccess.WRITE)
	if info_file:
		info_file.store_string(JSON.stringify(info_dict, "\t"))
		info_file.close()
		print("Saved info.json to %s" % info_save_path)
	
	# ----- SHARE MODE -----
	if share_mode:
		# Create a temporary zip
		var zip_path = share_save_path
		var zipper := ZIPPacker.new()
		if zipper.open(zip_path) != OK:
			push_error("Could not create zip: %s" % zip_path)
			$Control/save_to_list/saving_to_lbl.text = "Failed to save .zip"
			return

		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var f = dir.get_next()
			while f != "":
				if not dir.current_is_dir():
					var file_path = folder_path.path_join(f) # <-- safer than string concat
					zipper.start_file(f)
					var zipped = FileAccess.open(file_path, FileAccess.READ)
					if zipped:
						zipper.write_file(zipped.get_buffer(zipped.get_length()))
						zipped.close()
					zipper.close_file()
				f = dir.get_next()
			dir.list_dir_end()
		zipper.close()

		# Rename zip to .bx
		if not zip_path.ends_with(".bx"):
			var final_path = zip_path.get_basename() + ".bx"
			DirAccess.rename_absolute(zip_path, final_path)
			print("Shared chart packaged to %s" % final_path)
			saved = true
			$Control/chart_controls/save.text = "SHARED!"
		else:
			print("Shared chart packaged to %s" % zip_path)
			saved = true
			$Control/chart_controls/save.text = "SHARED!"
		return

func _on_saving_back_pressed() -> void:
	$song.pitch_scale = 1.0
	restore_editor_mode()
	
	var t = create_tween()
	t.tween_property($Control/save_to_list, "scale", Vector2.ZERO, .2).set_trans(Tween.TRANS_CUBIC)

func _on_chart_name_edit_text_changed() -> void:
	if "chart_name" not in mandatory:
		mandatory.append("chart_name")
	_check_mandatory()

func _check_mandatory() -> void:
	var required = ["song_file", "chart_name"]
	if required.all(func(x): return x in mandatory):
		$Control/create_map_panel/mandatory_notice.hide()
		$Control/create_map_panel/complete_setup_btn.disabled = false
		$Control/create_map_panel/complete_setup_btn.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND

func _on_view_notes_array_pressed() -> void:
	save_editor_mode()
	var t = create_tween()
	t.tween_property($Control/note_array_panel, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/note_array_panel/array.text = "Notes: " + str(notes)

func _on_n_array_back_pressed() -> void:
	restore_editor_mode()
	var t = create_tween()
	t.tween_property($Control/note_array_panel, "scale", Vector2.ZERO, .2).set_trans(Tween.TRANS_CUBIC)
	$Control/note_array_panel/array.text = "Notes: "

var saved_editor_mode: String = "none"

func save_editor_mode():
	saved_editor_mode = editor_mode
	editor_mode = "none"
	
	$Control/editor_controls/place_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/place_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/place_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/place_btn.remove_theme_color_override("font_outline_color")
	
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/dlt_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/dlt_btn.remove_theme_color_override("font_outline_color")
	
	$Control/editor_controls/view_btn.remove_theme_color_override("font_color")
	$Control/editor_controls/view_btn.remove_theme_constant_override("outline_size")
	$Control/editor_controls/view_btn.remove_theme_color_override("font_outline_color")
	$Control/editor_controls/view_btn.remove_theme_color_override("font_outline_color")

func restore_editor_mode():
	if saved_editor_mode == "none": saved_editor_mode = "view"
	editor_mode = saved_editor_mode
	
	match editor_mode:
		"view":
			_on_view_btn_pressed()
		"place":
			_on_place_btn_pressed()
		"delete":
			_on_dlt_btn_pressed()
		"settings":
			_on_view_btn_pressed()

func _on_tools_pressed() -> void:
	$song.pitch_scale = 0.82
	save_editor_mode()
	var t = create_tween()
	t.tween_property($Control/tools, "scale", Vector2.ONE, .2).set_trans(Tween.TRANS_CUBIC)

func _on_tools_exit_pressed() -> void:
	$song.pitch_scale = 1.0
	restore_editor_mode()
	$Control/tools/offset_lbl.text = "Offset all notes by specified time"
	var t = create_tween()
	t.tween_property($Control/tools, "scale", Vector2.ZERO, .2).set_trans(Tween.TRANS_CUBIC)

func _on_offset_all_text_submitted(new_text: String) -> void:
	if not new_text.is_valid_float():
		$Control/tools/offset_lbl.text = "Offset must be a number."
		return
	
	var value = float(new_text)
	
	for n in notes:
		n.timestamp += value
	_on_reload_pressed()
	$Control/tools/offset_all.text = ""
	$Control/tools/offset_lbl.text = "Notes set off by " + str(value)

func _on_offset_all_text_changed(new_text: String) -> void:
	if not new_text.is_valid_float():
		$Control/tools/offset_lbl.text = "Offset must be a number."
		return
	$Control/tools/offset_lbl.text = "Offset all notes by specified time"

func _on_save_to_list_mouse_entered() -> void:
	if $Control/save_to_list/saving_to_lbl.text != "Saved succesfully!": $Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(true))

func _on_save_copy_to_list_mouse_entered() -> void:
	if $Control/save_to_list/saving_to_lbl.text != "Saved succesfully!": $Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(false))

func _on_settings_btn_pressed() -> void:
	$song.pitch_scale = 0.82
	$Control/editor_controls/settings_btn.release_focus()
	save_editor_mode()
	editor_mode =  "settings"
	$AnimationPlayer.play("go_to_settings")

func _on_back_pressed() -> void:
	$song.pitch_scale = 1.0
	$Control/back.release_focus()
	restore_editor_mode()
	$AnimationPlayer.play("back_to_edit")

func _on_diff_texture_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		["*.png", "*.jpg", "*"],   # File filters
		Callable(self, "_on_diff_texture_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("diff_texture", err, error_string(err))

var diff_texture_path: String

func _on_diff_texture_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	diff_texture_path = paths[0]

	var image := Image.new()
	var err := image.load(diff_texture_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		$Control/edit_meta_cont/diff_texture_edit.icon = tex
		$Control/create_map_panel/diff_texture_edit.icon = tex
	else:
		print("Failed to load image: ", diff_texture_path)
