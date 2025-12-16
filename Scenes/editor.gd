extends Control

signal save

const BASE_TIME: float = 360.0

var edit_start_time

var history: Dictionary = {}
var redo_stack: Dictionary = {}

func add_history(mode: String, note_type: String, timestamp: float):
	var new_key = history.size()
	history[new_key] = {
		"mode": mode,
		"type": note_type,
		"timestamp": timestamp
	}

	# Clear redo stack because timeline has branched
	redo_stack.clear()
	_update_undo_redo_buttons()

func undo() -> void:
	if history.is_empty():
		print("Nothing to undo.")
		return

	var last_key = history.keys().max()
	var action = history[last_key]

	print("Undoing: ", action["mode"], " ", action["type"], " at ", action["timestamp"])

	match action["mode"]:
		"place":
			var note_to_delete = {
				"type": action["type"],
				"timestamp": action["timestamp"]
			}
			undo_place(note_to_delete)

		"delete":
			undo_delete(action["type"], action["timestamp"])

	# Move undone action to redo stack
	var redo_key = redo_stack.size()
	redo_stack[redo_key] = action

	# Remove from history
	history.erase(last_key)

	_update_undo_redo_buttons()


func undo_place(note_to_delete: Dictionary) -> void:
	if note_to_delete == null:
		return
	
	for i in range(notes.size()):
		var n = notes[i]
		if n.timestamp == note_to_delete.timestamp and n.type == note_to_delete.type:
			#print("removing ", n, " at notes index ", i)
			notes.remove_at(i)
			$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
			break

	# Handle scene node
	var found_node = null
	for c in $notes.get_children():
		if c.timestamp == note_to_delete.timestamp and c.type == note_to_delete.type:
			found_node = c
			break

	if found_node:
		if found_node.editor_deleted or found_node.faded:
			return
		found_node.editor_deleted = true
		found_node.z_index -= 1
		found_node.hit()

		saved = false
		$Control/chart_controls/save.text = "Save*"

func undo_delete(note_type: String, timestamp: float) -> void:
	print("Restoring note ", note_type, " at timestamp ", timestamp)
	place_note_at(0.0, note_type, timestamp) # ignore y, use timestamp directly

func redo() -> void:
	if redo_stack.is_empty():
		print("Nothing to redo.")
		return

	var last_key = redo_stack.keys().max()
	var action = redo_stack[last_key]

	print("Redoing: ", action["mode"], " ", action["type"], " at ", action["timestamp"])

	match action["mode"]:
		"place":
			undo_delete(action["type"], action["timestamp"])
		"delete":
			var note_to_delete = {
				"type": action["type"],
				"timestamp": action["timestamp"]
			}
			undo_place(note_to_delete)

	# Move redone action back to history
	var new_history_key = history.size()
	history[new_history_key] = action

	# Remove it from redo stack
	redo_stack.erase(last_key)

	_update_undo_redo_buttons()

func _update_undo_redo_buttons() -> void:
	var undo_btn = $Control/editor_controls/undo_btn
	var redo_btn = $Control/editor_controls/redo_btn

	undo_btn.disabled = history.is_empty()
	redo_btn.disabled = redo_stack.is_empty()

var new_beatzmap := true

var selected_stream: AudioStream

var song_len:
	get():
		return $song.stream.get_length() if $song.stream else 0.0
var song_len_ms:
	get():
		return $song.stream.get_length() * 1000 if $song.stream else 0.0

var song_path: String

var selected_title: String
var selected_artist: String
var selected_album: String
var selected_cover: Image
var selected_year: int

var selected_background: Image
var selected_background_name: String

var colors: Array[Color]

var selected_beatz_path: String

var start_wait: int = 0 

var preview_start: float = 0.0
var preview_end: float = 30.0

var fade_in: bool = false
var fade_out: bool = false

var selected_difficulty: String
var selected_diff_texture

var selected_chart_name: String

var selected_charter: String

@export_enum("1/2", "1/4", "1/8", "1/16", "1/32", "1/64", "1/128", "1/256") var snap_division: String = "1/8"

func _on_grid_snap_switch_pressed() -> void:
	$Control/editor_controls/grid_snap_switch.release_focus()
	var options = ["Free", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64", "1/128", "1/256"]
	var current_index = options.find(snap_division)
	if current_index == -1:
		current_index = 0
	
	var next_index = (current_index + 1) % options.size()
	snap_division = options[next_index]
	
	# Update UI text and tooltip
	var button = $Control/editor_controls/grid_snap_switch
	button.text = snap_division
	
	if snap_division == "Free":
		button.tooltip_text = "Move and place your notes freely"
	else:
		button.tooltip_text = "Snap placed and dragged notes to " + snap_division + " of a beat"

func get_snap_interval() -> float:
	match snap_division:
		"1/2": return doubles
		"1/4": return beattime
		"1/8": return eights
		"1/16": return sixteenths
		"1/32": return thirtyseconds
		"1/64": return sixtyfourths
		"1/128": return hundredtwentyeights
		"1/256": return twohundredfixtysixths
		_: return 0.0 # Free mode disables snapping

var selected_bpm: float

var beattime: float: # Time in seconds between beats (1/4 notes)
	get():
		return 60.0 / selected_bpm

var doubles: float: # 1/2 note
	get():
		return beattime * 2

var quads: float: # Whole note
	get():
		return beattime * 4

var eights: float: # 1/8 note
	get():
		return beattime / 2

var sixteenths: float: # 1/16 note
	get():
		return beattime / 4

var thirtyseconds: float: # 1/32 note
	get():
		return beattime / 8

var sixtyfourths: float: # 1/64 note
	get():
		return beattime / 16

var hundredtwentyeights: float: # 1/128 note
	get():
		return beattime / 32

var twohundredfixtysixths: float: # 1/256 note
	get():
		return beattime / 64

var note_speed : float = 15.0 # Settings.game.note_speed

var zoom: float = 10.0

var notes: Array = []

var local_beat_offset: float = 0

var NOTE := preload("res://Scenes/note.tscn")
var GAME := load("res://Scenes/main.tscn")
var BEAT := preload("res://Scenes/beat_line.tscn")

var preview_note: Node2D = null

var hovered_note: Node2D = null

var dragged_note: Node2D = null

var editor_mode: String = "view" # view, place, delete, select

var saved: bool = true

var buttons_to_disable_on_play

var buttons

var menus

var OFFSET = Settings.misc.note_offset

var setting_up := false

var mandatory := []

func set_discord_rpc():
	if not setting_up: 
		General._set_rpc(selected_title + " - " + selected_artist, "Editing a Song!", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(edit_start_time), 0)
	else:
		General._set_rpc("No Song Set.", "Creating a Beatzmap...", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(edit_start_time), 0)

func create_beatzmap():
	save_editor_mode()
	setting_up = true
	await get_tree().process_frame
	transition($Control/create_map_panel, "scale", Vector2.ONE, .2, false)
	
	$Control/chart_controls/save.text = "Unsaved*"
	
	$Control/create_map_panel/cover_img_details.text = ""

func create_from_dropped_file(path):
	$Control/create_map_panel/metadata_use_check.button_pressed = true
	await get_tree().process_frame
	_on_song_select_file_selected(true, [path], 0)
	
	$Control/create_map_panel/cover_img_details.text = ""
	
	$Control/chart_controls/save.text = "Unsaved*"

func time_to_y(time: float) -> float:
	#return (timestamp * zoom * note_speed / 100.0) # * -1.0
	var timestamp = time
	return (timestamp * note_speed / 10) * -1

func y_to_time(y: float) -> float:
	return ((-y) * zoom / note_speed)

func _init() -> void:
	edit_start_time = Time.get_unix_time_from_system()

func _ready() -> void:
	if Settings.misc.menu_bg_img_path != "":
		var img := Image.load_from_file(Settings.misc.menu_bg_img_path)
		if img: # make sure it loaded
			var tex := ImageTexture.create_from_image(img)
			$overlay.texture = tex
		else:
			print("Failed to load image at path:", Settings.misc.menu_bg_img_path)
	
	_update_undo_redo_buttons()
	
	if not Settings.misc.editor_bg_videos:
		$Control/VideoPlayback.process_mode = Node.PROCESS_MODE_DISABLED
		$Control/VideoPlayback.hide()
	else:
		$Control/VideoPlayback.process_mode = Node.PROCESS_MODE_ALWAYS
		$Control/VideoPlayback.show()
	
	$Control/chart_details/bpm.text = "BPM: 120.0"
	$Control/chart_details/note_count.text = "Total notes: 0"
	
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
	
	menus = [$Control/edit_meta_cont, $Control/create_map_panel, $Control/save_to_list, $Control/exit_warn, $Control/note_array_panel, $Control/tools, $Control/help]
	
	$Control/chart_details/note_speed.text = "Note speed: " + str(note_speed)
	
	$Control/bg.self_modulate = Color(Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness)
	#$Control/VideoPlayback.self_modulate = Color(Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness)
	
	$note_backdrop.self_modulate = Color(0.0, 0.0, 0.0, Settings.misc.editor_notes_backdrop_opacity)
	
	$Control/edit_meta_cont/charter_edit.text = Settings.game.username
	$Control/create_map_panel/charter_edit.text = Settings.game.username
	$Control/chart_details/charter.text = Settings.game.username
	
	if new_beatzmap:
		await get_tree().process_frame
		create_beatzmap()
		return
	
	$song.stream = selected_stream
	
	$Control/chart_details/bpm.text = "BPM: " + str(selected_bpm)
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
	
	$Control/song_details/song_title.text = selected_title
	if selected_artist.to_upper() == "LINKIN PARK":
		$Control/song_details/song_artist.text = "[b]" + selected_artist.to_upper() + "[/b]"
		$Control/song_details/song_artist.position.y = 56.0
	else:
		$Control/song_details/song_artist.text = selected_artist
		$Control/song_details/song_artist.position.y = 62.0
	
	$Control/song_details/album.text = selected_album
	$Control/song_details/year.text = str(selected_year)
	
	$Control/chart_details/chart_name.text = "\"" + selected_chart_name + "\""
	$Control/chart_details/charter.text = selected_charter
	$Control/chart_details/diff.text = "Difficulty: " + selected_difficulty.to_pascal_case()
	if selected_diff_texture: $Control/chart_details/diff_tex.texture = selected_diff_texture
	else:
		var diff_img = Image.load_from_file(diff_texture_path)
		var diff_tex = ImageTexture.create_from_image(diff_img)
		$Control/chart_details/diff_tex.texture = diff_tex
		selected_diff_texture = diff_tex
		print("Created diff tex from path ", diff_texture_path)
	
	$Control/song_details/sha/cover_spin.texture = ImageTexture.create_from_image(selected_cover)
	
	if selected_background: 
		$Control/bg.texture = ImageTexture.create_from_image(selected_background)
	
	if background_vid_path: 
		background_vid_path = ProjectSettings.globalize_path(background_vid_path)
		print("Setting bg vid as ", background_vid_path)
		_on_bg_vid_file_selected(background_vid_path)
	
	$Control/tools/beat_offset_value.text = "(Current offset: %s)" % [str(local_beat_offset)]
	
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
	
	$Control/edit_meta_cont/explorer_open_btn.tooltip_text = "Open " + ProjectSettings.globalize_path(selected_beatz_path.get_base_dir()) + " in your explorer."
	
	print(selected_beatz_path)
	print(song_path)
	
	set_discord_rpc()
	
	_setup_notes()

var playing := false

var video_seek_timer: float = 0.0
const VIDEO_UPDATE_INTERVAL: float = 0.125 # 8 fps, FPS = 1 / interval s | Interval = 1 / FPS

func _process(delta: float) -> void:
	if chart_scroll_tween and chart_scroll_tween.is_running():
		video_seek_timer += delta
		if video_seek_timer >= VIDEO_UPDATE_INTERVAL:
			video_seek_timer = 0.0
			_update_video_frame()
	
	if not playing:
		if editor_mode == "none": return
		var speed := 5.0
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 3.0
		if Input.is_key_pressed(KEY_CTRL):
			speed *= 0.5
		
		if Input.is_action_pressed("ui_up") or Input.is_action_pressed("noteUp") and not Input.is_action_pressed("editor_save"):
			print("m up")
			move(5)
			_update_scroll_from_notes_position()
		if Input.is_action_pressed("ui_down") or Input.is_action_pressed("noteDown") and not Input.is_action_pressed("editor_save"):
			print("m down")
			move(-35)
			_update_scroll_from_notes_position()

	# Space bar toggles play/pause
	if Input.is_action_just_pressed("ui_select"): # space
		if playing:
			_pause()
		else:
			# Kill any previous tween if it's still active
			if chart_scroll_tween and chart_scroll_tween.is_running():
				chart_scroll_tween.kill()
			
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
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and editor_mode in ["view", "place"]:
		var hovered = get_note_under_mouse()
		# this matches your old debug print
		if hovered:
			var mouse_y_global = get_global_mouse_position().y
			
			var bar = hovered.get_node("HoldBar2D")
			var end = hovered.get_node("note_hold_end")
			var local_y = bar.to_local(get_global_mouse_position()).y
			
			bar.points[1].y = local_y 
			
			end.global_position.y = mouse_y_global
	
	if not playing and editor_mode == "place" and preview_note:
		var note_to_hover := get_note_under_mouse()
		# reset old hovered
		if note_to_hover != hovered_note:
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate", Color(1, 1, 1, 1), 0.2).set_ease(Tween.EASE_IN)

			hovered_note = note_to_hover
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate", Color(1, 1, 1, 1), 0.2).set_ease(Tween.EASE_IN)
		
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
	
	if not playing and editor_mode == "view":
		var note_to_hover := get_note_under_mouse()

		# reset old hovered
		if note_to_hover != hovered_note:
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate", Color(1, 1, 1, 1), 0.2).set_ease(Tween.EASE_IN)

			hovered_note = note_to_hover
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate", Color(0.607, 1.0, 0.577, 1.0), 0.2).set_ease(Tween.EASE_IN)

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
			var hold: float = -1.0
			if dragged_note.hold_ms > 0.0:
				hold = dragged_note.hold_ms
			dragged_note.timestamp = timestamp
			#print(dragged_note.timestamp)
			dragged_note.set_type(note_type)
			dragged_note.hold_ms = hold

			for i in range(notes.size()):
				if notes[i].timestamp == old_time and notes[i].type == old_type:
					# replace old entry
					if hold < 0.0: notes[i] = {"timestamp": timestamp, "type": note_type}
					else: notes[i] = {"timestamp": timestamp, "type": note_type, "hold": hold}
					#print("updated index in note")
					break
	
	if not playing and editor_mode == "delete":
		var note_to_hover := get_note_under_mouse()
		if note_to_hover:
			if note_to_hover.editor_deleted == true or note_to_hover.faded == true: return
		if note_to_hover != hovered_note:
			# reset old hovered NOTE
			if hovered_note:
				if hovered_note.editor_deleted:
					hovered_note.get_node("noteImg").scale = Vector2.ONE
					hovered_note.get_node("noteImg").modulate = Color(1, 1, 1, 1)
					return
					
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15).set_ease(Tween.EASE_IN)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate", Color(1, 1, 1, 1), 0.2).set_ease(Tween.EASE_IN)

			# set new hovered NOTE
			hovered_note = note_to_hover
			if hovered_note:
				var t = create_tween()
				t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2(0.95, 0.95), 0.1).set_ease(Tween.EASE_OUT)
				t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate", Color(1, 1, 1, 0.6), 0.15).set_ease(Tween.EASE_OUT)
	
	$Control/chart_controls/pos_label.text = "D Y Pos: " + str(snapped(get_y(), 0.01))
	if not setting_up: $Control/chart_controls/scroll_lbl.text = "D Song time: " + str(snapped($song.get_playback_position(), 0.01))
	$Control/chart_controls/scroll_val.text = "Time: " +  General.format_time($Control/chart_controls/chart_scroll.value)

func move(amnt: float = 0.0, use_old_logic: bool = true):
	if use_old_logic:
		$notes.position.y += amnt
		$beatlines.position.y += amnt
		return
	$cam.global_position.y -= amnt
	$Control.global_position.y -= amnt
	$stationary_notes.global_position.y -= amnt
	$lanes.global_position.y -= amnt
	$lanes2.global_position.y -= amnt

func set_y(value: float = 0.0, use_old_logic: bool = true):
	if use_old_logic:
		$notes.position.y = value
		$beatlines.position.y = value
		return
	$cam.global_position.y = value + 540.0
	$Control.global_position.y = value
	$stationary_notes.global_position.y = value
	$lanes.global_position.y = value
	$lanes2.global_position.y = value

func get_y(use_old_logic: bool = true):
	if use_old_logic: return $notes.global_position.y 
	else: return -$cam.global_position.y

func close_panel_from_input():
	for menu in menus:
		if menu.name == "note_array_panel":
			_on_n_array_back_pressed()
			continue
		
		if menu.scale > Vector2.ZERO:
			transition(menu, "scale", Vector2.ZERO, 0.2, true)

func _on_save() -> void:
	print("Succesful Save")

func _input(event):
	if Input.is_action_just_pressed("fast_restart"):
		if editor_mode == "none":
			return
		_on_reload_pressed()
	if Input.is_action_just_pressed("pause-back"):
		if editor_mode == "settings": _on_back_pressed()
		close_panel_from_input()
	
	if Input.is_action_just_pressed("quit"):
		if editor_mode == "none":
			return
		_on_exit_pressed()
	
	if Input.is_action_just_pressed("save_quit"):
		if editor_mode == "none":
			return
		_on_save_to_list_pressed()
		await save
		_on_exit_pressed()
	
	if Input.is_action_just_pressed("editor_save"):
		if editor_mode == "none":
			return
		_on_save_to_list_pressed()
		$Control/chart_controls/saved_to_popup.text = "Saved!"
		$Control/chart_controls/saved_to_popup.size = Vector2(121.0, 40.0)
		$popups.stop()
		$popups.play("saved_popup")
	
	if Input.is_action_just_pressed("editor_save_copy"):
		if editor_mode == "none":
			return
		_on_save_copy_to_list_pressed()
		$Control/chart_controls/saved_to_popup.text = "Saved\nCopy!"
		$popups.stop()
		$popups.play("saved_popup")
	
	if Input.is_action_just_pressed("editor_share"):
		if editor_mode == "none":
			return
		_on_share_chart_pressed()
		$Control/chart_controls/saved_to_popup.text = "Sharing..."
		$Control/chart_controls/saved_to_popup.size = Vector2(121.0, 40.0)
		$popups.stop()
		$popups.play("saved_popup")
	
	if Input.is_action_just_pressed("editor_place"):
		if editor_mode == "none":
			return
		_on_place_btn_pressed()
	
	if Input.is_action_just_pressed("editor_delete"):
		if editor_mode == "none":
			return
		_on_dlt_btn_pressed()
	
	if Input.is_action_just_pressed("editor_view"):
		if editor_mode == "none":
			return
		_on_view_btn_pressed()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		match editor_mode:
			"view":
				if setting_up or playing: return
				if event.pressed:
					if hovered_note:
						dragged_note = hovered_note
						saved = false
						$Control/chart_controls/save.text = "Save*"
				else:
					dragged_note = null

			"place":
				if setting_up or playing: return
				if event.pressed:
					var note_type = get_lane_type(event.position)
					if note_type != "out" and note_type != null:
						var local_y = $notes.get_local_mouse_position().y
						place_note_at(local_y, note_type)

			"delete":
				if setting_up or playing: return
				if event.pressed:
					var note_to_delete := get_note_under_mouse()
					delete_note(note_to_delete)

			"select":
				if setting_up: return
				if event.pressed:
					get_note_under_mouse()
	if event is InputEventMouseButton:
		if playing or setting_up or editor_mode == "none" or editor_mode == "settings":
			return

		var zoom_scroll = $Control/zoom_scroll
		var chart_scroll = $Control/chart_controls/chart_scroll

		var now := Time.get_ticks_msec() / 1000.0
		var delta_time := now - last_scroll_time
		last_scroll_time = now

		var direction := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			direction = 1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			direction = -1.0
		else:
			return  # not scroll event

		# Handle CTRL for zoom instead of chart scroll
		if Input.is_key_pressed(KEY_CTRL):
			var zoom_target = zoom_scroll.value + direction * 1.0
			if chart_scroll_tween and chart_scroll_tween.is_running():
				chart_scroll_tween.kill()
			chart_scroll_tween = create_tween()
			chart_scroll_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			chart_scroll_tween.tween_property(zoom_scroll, "value", zoom_target, 0.1)
			return

		# ----- CHART SCROLL MOMENTUM -----
		var base_step := 1.5
		if Input.is_key_pressed(KEY_SHIFT):
			base_step = 4.0

		if delta_time < 0.10:
			chart_scroll_velocity += base_step * direction * 3.0
		else:
			chart_scroll_velocity = base_step * direction

		# Clamp velocity to prevent insane speeds
		chart_scroll_velocity = clampf(chart_scroll_velocity, -3.0, 3.0) / 10.0

		# Calculate target value
		var target_value := clampf(chart_scroll.value + chart_scroll_velocity, chart_scroll.min_value, chart_scroll.max_value)

		# Kill old tween if still going
		if chart_scroll_tween and chart_scroll_tween.is_running():
			chart_scroll_tween.kill()

		# Duration scales with momentum
		var duration := clampf(abs(chart_scroll_velocity), 0.12, 3.0)

		# Create tween
		chart_scroll_tween = create_tween()
		chart_scroll_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		chart_scroll_tween.tween_property(chart_scroll, "value", target_value, duration)

		# Decay momentum smoothly after tween
		chart_scroll_tween.finished.connect(func():
			chart_scroll_velocity *= 0.6
		)

var chart_scroll_tween: Tween = null
var chart_scroll_velocity := 0.0
var last_scroll_time := 0.0

func get_note_under_mouse() -> Node2D:
	var mouse_pos = $notes.get_local_mouse_position()

	for note_node in $notes.get_children():
		if note_node is Node2D and not note_node.editor_deleted:

			var end_y = note_node.get_node("note_hold_end").position.y

			var rect = Rect2(
				note_node.position.x - 40.0,
				note_node.position.y - 40,
				note_node.scale.y * 128,
				(note_node.scale.y * 128) + end_y
			).abs() # ← normalize to positive size

			if rect.has_point(mouse_pos):
				return note_node

	return null

# Determines which lane was clicked and returns the NOTE type
func get_lane_type(mouse_pos: Vector2) -> String:
	if playing: pass
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

func delete_note(note_to_delete):
	if note_to_delete == null:
		return
	
	for i in range(notes.size()):
		var n = notes[i]
		if n.timestamp == note_to_delete.timestamp and n.type == note_to_delete.type:
			print("removing ", n, " at notes index ", i)
			notes.remove_at(i)
			$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
			break

	if note_to_delete:
		if note_to_delete.editor_deleted or note_to_delete.faded:
			return

		note_to_delete.editor_deleted = true
		note_to_delete.z_index -= 1
		note_to_delete.hit()

		saved = false
		$Control/chart_controls/save.text = "Save*"

		add_history("delete", note_to_delete.type, note_to_delete.timestamp)
	else:
		print("No NOTE")

# Spawns a new NOTE at the correct lane x and given y
func place_note_at(y_pos: float, note_type: String, timestamp_override: float = -1.0, record_history: bool = true):
	if setting_up or editor_mode == "settings":
		return

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

	var y: float
	if timestamp_override != -1.0:
		var displacement = OFFSET + BASE_TIME
		var t = timestamp_override + displacement
		y = (t * note_speed / 10) * -1
		#y = time_to_y(timestamp_override)
	else: 
		y = y_pos
	
	new_note.global_position.y = y
	new_note.set_type(note_type)
	new_note.scale = Vector2(0.65, 0.65)

	var timestamp: float
	if timestamp_override != -1.0:
		timestamp = timestamp_override
	else:
		timestamp = ((-y_pos) * zoom / note_speed) - OFFSET - BASE_TIME

	print("appending new NOTE at timestamp ", timestamp)
	notes.append({
		"timestamp": timestamp,
		"type": note_type,
	})

	new_note.timestamp = timestamp
	$notes.add_child(new_note)

	saved = false
	$Control/chart_controls/save.text = "Save*"
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))

	print("appended: ", note_type)

	# Add to undo history (only if not from undo/redo)
	if record_history:
		add_history("place", note_type, timestamp)

func _update_scroll_from_notes_position():
	if song_len <= 0:
		return
	
	if playing and $song.playing:
		var song_time = $song.get_playback_position()
		$Control/chart_controls/chart_scroll.set_value_no_signal(song_time)
	else:
		var time = ((get_y()) * zoom / note_speed)
		time /= 1000
		time = clamp(time, 0.0, song_len)
		$Control/chart_controls/chart_scroll.value = time

func _on_chart_scroll_value_changed(value: float) -> void:
	if setting_up:
		return

	set_y(_scroll_time_to_y(value))

	if not (chart_scroll_tween and chart_scroll_tween.is_running()):
		# Only update video immediately when not tweening
		_update_video_frame()

	# Update UI labels
	$Control/chart_controls/pos_label.text = "D Y Pos: " + str(snapped(get_y(), 0.01))
	$Control/chart_controls/scroll_lbl.text = "D Song time: " + str(snapped($song.get_playback_position(), 0.01))
	$Control/chart_controls/scroll_val.text = "Time: " + General.format_time(value)

func _update_video_frame() -> void:
	if not $Control/VideoPlayback.is_open():
		return

	var fps = $Control/VideoPlayback.get_video_framerate()
	var total_frames = $Control/VideoPlayback.get_video_frame_count()
	var value = $Control/chart_controls/chart_scroll.value

	var target_frame = int(value * fps)
	target_frame = clamp(target_frame, 0, total_frames - 1)

	var current_frame = $Control/VideoPlayback.current_frame
	if target_frame != current_frame:
		$Control/VideoPlayback.seek_frame(target_frame)


func _scroll_time_to_y(time: float) -> float:
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
		var base_y = ((time) * note_speed) * -1
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
		
		if $Control/VideoPlayback.is_open():
			var fps = $Control/VideoPlayback.get_video_framerate()
			var time_sec = song_time  # this is already in seconds
			var target_frame = int(time_sec * fps)
			var total_frames = $Control/VideoPlayback.get_video_frame_count()
			target_frame = clampi(target_frame, 0, total_frames - 1)

			$Control/VideoPlayback.seek_frame(target_frame)
			$Control/VideoPlayback.play()

		
		
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
	$song.stop()
	if $Control/VideoPlayback.is_open(): $Control/VideoPlayback.pause()
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
	
	var highest_y: float = ((song_len_ms) * note_speed / zoom)
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
		#var y = time_to_y(n.timestamp)
		
		if -y > highest_y: highest_y = -y
		
		if (n.timestamp + 1080.0) / 1000.0 > highest_time: highest_time = (n.timestamp + 1080.0) / 1000.0

		var obj := NOTE.instantiate()
		obj.edit = true
		obj.timestamp = n.timestamp
		if n.has("hold") and n.hold > 0.0: obj.hold_ms = n.hold
		obj.set_type(n.type)
		obj.position = Vector2(x, y)
		obj.scale = Vector2(0.65, 0.65)
		$notes.add_child(obj)
	
	_setup_beatlines()
	
	#print(beattime, " ",  song_len, " ", song_len_ms)
	#print($beatlines.get_child_count())
	highest_note_y = highest_y
	highest_timestamp = highest_time
	
	$Control/chart_controls/chart_scroll.min_value = 0
	$Control/chart_controls/chart_scroll.max_value = highest_timestamp
	print(highest_timestamp)
	#$Control/chart_controls/chart_scroll.value = 0
	
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))

func _setup_beatlines():
	for line in $beatlines.get_children():
		line.queue_free()
	
	var t := 0.0
	var times := (local_beat_offset + 25.0) / 1000
	print()
	
	while t <= song_len:
		# main beatline
		var y: float = ((t + times - beattime * 4) * note_speed * 100) * -1
		var main_line := BEAT.instantiate()
		main_line.position = Vector2(960, y)
		main_line.process_mode = Node.PROCESS_MODE_DISABLED
		$beatlines.add_child(main_line)
		
		# spawn 3 in-between lines (quarter divisions)
		for i in range(1, 4): # 1/4, 2/4, 3/4 between beats
			var sub_t := t + (beattime / 4.0) * i
			if sub_t > song_len:
				break
			
			var sub_y: float = ((sub_t + times - beattime * 4) * note_speed * 100) * -1
			var sub_line := BEAT.instantiate()
			sub_line.position = Vector2(960, sub_y)
			sub_line.scale = Vector2(2.6, 0.3)
			sub_line.modulate = Color(0.5, 0.5, 0.5, 1.0)
			sub_line.process_mode = Node.PROCESS_MODE_DISABLED
			$beatlines.add_child(sub_line)
		
		t += beattime

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



# PANELS
# AND MENUS

var menu_open: bool = false

var active_tweens: Array[Tween] = []

func transition(panel: Object, property: String, to: Variant, time: float, close: bool): 
	if menu_open and close == false: return
	if close:
		menu_open = false
	else:
		menu_open = true
	var t = create_tween() 
	t.tween_property(panel, property, to, time).set_trans(Tween.TRANS_CIRC) 
	t.parallel().tween_property($overlay, "modulate", Color(0, 0, 0, 0.5) if not close else Color(0, 0, 0, 0.0), 0.2).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property($song, "pitch_scale", 0.85 if not close else 1.0, 0.2)
	t.parallel().tween_property($Control/VideoPlayback, "playback_speed", 0.85 if not close else 1.0, 0.2)

func _on_exit_warn_pressed() -> void:
	save_editor_mode()
	$Control/exit_warn/warn_lbl.text = "Are you sure you want to exit editing \"%s\"\n\nUnsaved edits will be lost." % selected_chart_name
	
	transition($Control/exit_warn, "scale", Vector2.ONE, .2, false)
	$Control/chart_controls/exit.release_focus()

func _on_exit_pressed() -> void:
	$AnimationPlayer.play("exit")
	transition($Control/exit_warn, "scale", Vector2.ZERO, .2, true)
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func _on_cancel_exit_pressed() -> void:
	restore_editor_mode()
	transition($Control/exit_warn, "scale", Vector2.ZERO, .2, true)
	$Control/chart_controls/exit.release_focus()

func _on_edit_meta_pressed() -> void:
	save_editor_mode()
	
	transition($Control/edit_meta_cont, "scale", Vector2.ONE, .2, false)
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
	$Control/edit_meta_cont/album_cover_edit.icon = ImageTexture.create_from_image(selected_cover)
	
	$Control/edit_meta_cont/bg_img_edit.icon = ImageTexture.create_from_image(selected_background)
	
	if selected_background: $Control/edit_meta_cont/bg_img_details.text = str(selected_background.get_width()) + "x" + str(selected_background.get_height()) + "\n" + selected_background_name + "\n" + General.format_file_size(selected_background.get_data_size())
	
	$Control/edit_meta_cont/bg_img_details.set_meta("background_name", selected_background_name)
	
	$Control/edit_meta_cont/cover_img_details.text = str(selected_cover.get_width()) + "x" + str(selected_cover.get_height()) + "\n" + selected_album + "\n" + General.format_file_size(selected_cover.get_data_size())
	
	$Control/edit_meta_cont/metadata_use_check.set_pressed_no_signal(use_meta_check)
	
	if not colors.is_empty():
		var brightest_color = colors[0]
		var max_value = colors[0].r + colors[0].g + colors[0].b

		for color in colors:
			var value = color.r + color.g + color.b
			if value > max_value:
				max_value = value
				brightest_color = color
		
		$Control/edit_meta_cont/bg_color_pick.color = brightest_color
		
		$Control/edit_meta_cont/sig_colors_cont/sig_color_pick.color = colors[0]
		if colors.get(1): $Control/edit_meta_cont/sig_colors_cont/sig_color_pick2.color = colors[1]
		if colors.get(2): $Control/edit_meta_cont/sig_colors_cont/sig_color_pick3.color = colors[2]
		if colors.get(3): $Control/edit_meta_cont/sig_colors_cont/sig_color_pick4.color = colors[3]
		if colors.get(4): $Control/edit_meta_cont/sig_colors_cont/sig_color_pick5.color = colors[4]

func _on_save_meta_btn_pressed() -> void:
	restore_editor_mode()
	transition($Control/edit_meta_cont, "scale", Vector2.ZERO, .2, true)
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
	
	_setup_beatlines()
	
	$Control/song_details/song_artist.text = $Control/edit_meta_cont/artist_edit.text
	selected_artist = $Control/edit_meta_cont/artist_edit.text
	
	$Control/song_details/album.text = $Control/edit_meta_cont/album_edit.text
	selected_album = $Control/edit_meta_cont/album_edit.text
	
	var cov: ImageTexture = $Control/edit_meta_cont/album_cover_edit.icon
	selected_cover = cov.get_image()
	
	selected_background_name = $Control/edit_meta_cont/bg_img_details.get_meta("background_name")
	
	var bg: ImageTexture
	
	if $Control/edit_meta_cont/bg_img_edit.icon: 
		bg = $Control/edit_meta_cont/bg_img_edit.icon
		selected_background = bg.get_image()
	
	if bg and removed_bg:
		selected_background = null
		selected_background_name = ""
	
	if not bg:
		var t = load("res://Resources/defaultBG.png")
		bg = ImageTexture.create_from_image(t.get_image())
	
	$Control/bg.texture = bg
	
	$Control/song_details/sha/cover_spin.texture = ImageTexture.create_from_image(selected_cover)
	
	$Control/song_details/year.text = $Control/edit_meta_cont/year_edit.text
	selected_year = int($Control/edit_meta_cont/year_edit.text)
	
	$Control/song_details/song_path.text = "Path: " + song_path
	
	saved = false
	$Control/chart_controls/save.text = "Save*"
	
	set_discord_rpc()

func _on_cancel_btn_pressed() -> void:
	restore_editor_mode()
	transition($Control/edit_meta_cont, "scale", Vector2.ZERO, .2, true)
	$Control/edit_meta_cont/save_btn.release_focus()

func _on_playtest_pressed() -> void:
	if setting_up: return
	
	$AnimationPlayer.play("exit", -1, 1.3)
	
	
	var test = GAME.instantiate()
	
	test.set("chart_path", selected_beatz_path)
	test.set("song_path", song_path)
	test.set("song", selected_stream)
	test.set("song_title", selected_title)
	test.set("album", selected_album)
	test.set("artist", selected_artist)
	test.set("year", selected_year)
	test.set("cover", selected_cover)
	test.set("customNotes", notes)
	test.set("difficulty", selected_difficulty)
	test.set("chart_name", selected_chart_name)
	test.set("charter", selected_charter)
	test.set("BPM", selected_bpm)
	test.set("local_beat_offset", local_beat_offset)
	test.set("selected_background", selected_background)
	test.set("selected_background_name", selected_background_name)
	test.set("colors", colors)
	test.set("background_vid_path", background_vid_path)
	
	await $AnimationPlayer.animation_finished
	
	get_tree().root.add_child(test)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = test

func _on_complete_setup_btn_pressed() -> void:
	$Control/create_map_panel/complete_setup_btn.release_focus()
	
	restore_editor_mode()
	$Control/chart_details/chart_name.text = '"' + $Control/create_map_panel/chart_name_edit.text + '"'
	selected_chart_name = $Control/create_map_panel/chart_name_edit.text
	
	$Control/song_details/song_title.text = $Control/create_map_panel/song_name_edit.text
	selected_title = $Control/create_map_panel/song_name_edit.text
	
	$Control/chart_details/charter.text = $Control/create_map_panel/charter_edit.text
	selected_charter = $Control/create_map_panel/charter_edit.text
	
	var diff_text: String = $Control/create_map_panel/diff_edit.text.strip_edges()
	$Control/chart_details/diff.text = "Difficulty: " + diff_text if diff_text != "" else "Easy"
	selected_difficulty = $Control/create_map_panel/diff_edit.text
	
	$Control/chart_details/diff_tex.texture = $Control/create_map_panel/diff_texture_edit.icon
	selected_diff_texture = $Control/create_map_panel/diff_texture_edit.icon
	
	var bpm_text: String = "BPM: " + $Control/create_map_panel/bpm_edit.text.strip_edges()
	$Control/chart_details/bpm.text = bpm_text
	selected_bpm = float($Control/create_map_panel/bpm_edit.text)
	
	$Control/song_details/song_artist.text = $Control/create_map_panel/artist_edit.text
	selected_artist = $Control/create_map_panel/artist_edit.text
	
	$Control/song_details/album.text = $Control/create_map_panel/album_edit.text
	selected_album = $Control/create_map_panel/album_edit.text
	
	var cov: ImageTexture = $Control/create_map_panel/album_cover_edit.icon
	if cov:
		selected_cover = cov.get_image()
		
		$Control/song_details/sha/cover_spin.texture = cov
		
		$Control/song_details/sha.show()
	
	selected_background_name = $Control/edit_meta_cont/bg_img_details.get_meta("background_name")
	
	var bg: ImageTexture
	
	if $Control/edit_meta_cont/bg_img_edit.icon: 
		bg = $Control/edit_meta_cont/bg_img_edit.icon
		selected_background = bg.get_image()
	
	if bg and removed_bg:
		selected_background = null
		selected_background_name = ""
	
	if not bg:
		var t = load("res://Resources/defaultBG.png")
		bg = ImageTexture.create_from_image(t.get_image())
	
	$Control/bg.texture = bg
	
	selected_background_name = $Control/edit_meta_cont/bg_img_details.get_meta("background_name")
	
	$Control/song_details/year.text = $Control/create_map_panel/year_edit.text
	selected_year = int($Control/create_map_panel/year_edit.text)
	
	$Control/song_details/song_path.text = "Path: " + song_path
	
	$Control/edit_meta_cont/explorer_open_btn.tooltip_text = "Open " + song_path.get_base_dir() + " in your explorer."
	
	setting_up = false
	
	transition($Control/create_map_panel, "scale", Vector2.ZERO, .2, true)
	await get_tree().create_timer(0.3).timeout
	
	_on_reload_pressed()
	set_discord_rpc()

func _on_song_file_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .mp3, .wav or .ogg file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.AUDIO_FORMATS,   # File filters
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
		General.AUDIO_FORMATS,   # File filters
		Callable(self, "_on_edit_song_select_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("edit_song_file", err, error_string(err))

func _on_song_select_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("song select file status", status)
	print("song select paths ", paths)
	print("song select filter idx", _filter_idx)
	
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
		if "song_file" not in mandatory:
			mandatory.append("song_file")
		_check_mandatory()
		
		General._set_rpc(str(song_path.get_file()), "Creating a Beatzmap...", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", edit_start_time, 0)
		
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
	print("edit song select sta", status)
	print("edit song select paths ", paths)
	print("edit song select filter idx", _filter_idx)
	
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
		if tex:
			$Control/create_map_panel/album_cover_edit.icon = tex
			$Control/create_map_panel/cover_img_details.text = str(tex.get_width()) + "x" + str(tex.get_height())
	else:
		
		print("Cover image not in metadata")

func _on_album_cover_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		Settings.game.last_editor_path,             # Initial path (empty means default)
		"",                                            
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_album_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("create_album", err, error_string(err))

var album_cover_path: String

func _on_album_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("album file sta", status)
	print("album file paths ", paths)
	print("album file filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	album_cover_path = paths[0]
	Settings.game.last_editor_path = album_cover_path.get_base_dir()
	
	var image := Image.new()
	var err := image.load(album_cover_path)
	
	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		$Control/edit_meta_cont/album_cover_edit.icon = tex
		$Control/create_map_panel/album_cover_edit.icon = tex
		var text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + paths[0].get_file() + "\n" + General.format_file_size(FileAccess.get_size(paths[0]))
		$Control/edit_meta_cont/cover_img_details.text = text
		$Control/create_map_panel/cover_img_details.text = text
	else:
		print("Failed to load image: ", album_cover_path)

func _on_rotate_cover_pressed() -> void:
	if selected_cover == null:
		print("No cover loaded yet.")
		return

	# Get the underlying image data
	var image := Image.new()
	image.copy_from(selected_cover)
	
	if image == null:
		print("Failed to get image from texture.")
		return
	
	# Rotate and recreate texture
	image.rotate_90(CLOCKWISE)
	
	selected_cover = image
	
	$Control/edit_meta_cont/album_cover_edit.icon = ImageTexture.create_from_image(image)
	$Control/create_map_panel/album_cover_edit.icon = ImageTexture.create_from_image(image)

func _on_bg_img_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		Settings.game.last_editor_path,             # Initial path (empty means default)
		"",                                            
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_bg_img_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("create_bg_img", err, error_string(err))

var background_img_path: String
var removed_bg: bool = false

func _on_bg_img_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("bg img sta ", status)
	print("bg img paths ", paths)
	print("bg img filter idx ", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	background_img_path = paths[0]
	Settings.game.last_editor_path = background_img_path.get_base_dir()
	
	var image := Image.new()
	var err := image.load(background_img_path)
	
	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		$Control/edit_meta_cont/bg_img_edit.icon = tex
		$Control/create_map_panel/bg_img_edit.icon = tex
		var text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + paths[0].get_file() + "\n" + General.format_file_size(FileAccess.get_size(paths[0]))
		$Control/edit_meta_cont/bg_img_details.text = text
		$Control/create_map_panel/bg_img_details.text = text
		
		$Control/edit_meta_cont/bg_img_details.set_meta("background_name", paths[0].get_file())
		
		removed_bg = false
	else:
		print("Failed to load background image: ", background_img_path, " ", err, " ", error_string(err))

func _on_clear_bg_pressed() -> void:
	$Control/edit_meta_cont/clear_bg.release_focus()
	$Control/create_map_panel/clear_bg.release_focus()
	removed_bg = true
	background_img_path = ""
	$Control/edit_meta_cont/bg_img_details.text = "No Background"
	$Control/edit_meta_cont/bg_img_edit.icon = null
	$Control/create_map_panel/bg_img_edit.icon = null

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
		$Control/edit_meta_cont/cover_img_details.text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + "Attached Album Cover" + "\n" + General.format_file_size(cover_img.get_data_size())
	else:
		print("Cover image not in metadata")

func _get_save_path(overwrite: bool = true, only_file: bool = false) -> String:
	var username := selected_charter.strip_edges()
	if username == "":
		username = "Unknown"
		
	var user_chart_name := selected_chart_name.strip_edges()
	if user_chart_name == "":
		user_chart_name = "Untitled"
	
	# Base filename
	var base_filename := "%s-%s" % [General._sanitize(user_chart_name), username]
	var base_title := General._sanitize(selected_title, true)
	var folder_path: String
	var save_path: String
	if not selected_beatz_path:
		folder_path = "user://Custom/" + base_title + "/"
		if only_file: save_path = base_filename + ".beatz"
		else: save_path = folder_path + base_filename + ".beatz"
	else: save_path = selected_beatz_path
	
	# Handle copy case (no overwrite → increment folder)
	if not overwrite:
		if DirAccess.dir_exists_absolute("user://Custom/" + base_title):
			var time := Time.get_datetime_dict_from_system()
			folder_path = "user://Custom/" + base_title + " " + str(time.day) + "-" + str(time.month) + "-" + str(time.year) + "/"
			if only_file: save_path = base_filename + ".beatz"
			else: save_path = folder_path + base_filename + ".beatz"
	
	# Make sure folder exists
	#DirAccess.make_dir_recursive_absolute(folder_path)
	
	return save_path

func _on_save_pressed() -> void:
	var save_path := _get_save_path()
	$Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(save_path)
	
	save_editor_mode()

	transition($Control/save_to_list, "scale", Vector2.ONE, .2, false)
	$Control/chart_controls/save.release_focus()

func _on_save_to_list_pressed() -> void:
	$Control/save_to_list/save_to_list.release_focus()
	_encode_beatz_file(notes, song_path)
	
	saved = true
	$Control/chart_controls/save.text = "Saved"

func _on_save_copy_to_list_pressed() -> void:
	$Control/save_to_list/save_copy_to_list.release_focus()
	_encode_beatz_file(notes, song_path, false)
	
	saved = true
	$Control/chart_controls/save.text = "Saved"

func _on_share_chart_pressed() -> void:
	$Control/save_to_list/share_to_bx.release_focus()
	
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
	print("Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT)
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
		"create_bg_img":
			$Control/edit_meta_cont/bg_img_details.text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT

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
		$Control/save_to_list/saving_to_lbl.text = "No custom notes found. Record some!"
		return

	# Encode notes
	var encoded_notes := General.encode_notes(decoded_notes)

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

	var song_name := current_song_path.get_file()

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
	content += "BPM: %s\\" % str(selected_bpm)
	content += "noteSpeed: %s\\" % str(5)
	content += "noteSpawnY: %s\\" % str(360)
	content += "Difficulty: %s\\" % selected_difficulty
	content += "StartWait: %s\\" % str(start_wait)
	content += "PrevStart: 0.0\\PrevEnd: 99999.0\\"
	content += "BeatOffset: %s\\" % str(local_beat_offset)
	content += "Notes:%s" % encoded_notes
	
	# Save info.json
	var info_dict := {
		"info": {
			"title": selected_title,
			"artist": selected_artist,
			"album": selected_album,
			"year": selected_year,
			"chart": _get_save_path(overwrite, true),
			"audio": General._sanitize(song_name),
			"cover": General._sanitize(selected_album) + ".png",
			"background": selected_background_name,
			"video": background_vid_path.get_file(),
			"difficulty_texture": General._sanitize(selected_difficulty) + ".png"
		}
	}
	
	# ----- SHARE MODE (no saving to disk) -----
	if share_mode:
		$Control/save_to_list/saving_to_lbl.text = "Sharing..."
		
		var zip_path = share_save_path
		var zipper := ZIPPacker.new()
		if zipper.open(zip_path) != OK:
			push_error("Could not create zip: %s" % zip_path)
			$Control/save_to_list/saving_to_lbl.text = "Could not create zip at %s" % zip_path
			return

		# Add .beatz (in-memory string)
		var chart_file_name := _get_save_path(overwrite, true).get_file()
		zipper.start_file(chart_file_name)
		zipper.write_file(content.to_utf8_buffer())
		zipper.close_file()

		# Add info.json (in-memory string)
		zipper.start_file("info.json")
		zipper.write_file(JSON.stringify(info_dict, "\t").to_utf8_buffer())
		zipper.close_file()

		# Add audio (if possible)
		if selected_stream and "data" in selected_stream:
			zipper.start_file(info_dict["info"]["audio"])
			zipper.write_file(selected_stream.data)
			zipper.close_file()

		# Add cover image
		if selected_cover and selected_cover is Image:
			var img = selected_cover
			if img:
				var cover_name = info_dict["info"]["album"]
				var ext = cover_name.get_extension().to_lower()

				var buffer: PackedByteArray
				match ext:
					"png":
						buffer = img.save_png_to_buffer()
					"jpg", "jpeg":
						buffer = img.save_jpg_to_buffer(1.0)
					"webp":
						buffer = img.save_webp_to_buffer(false, 1.0)
					"exr":
						buffer = img.save_exr_to_buffer()
					"hdr":
						buffer = img.save_hdr_to_buffer()
					_:
						push_warning("Unsupported background format '%s', saving as PNG instead." % ext)
						cover_name = cover_name.get_basename() + ".png"
						buffer = img.save_png_to_buffer()

				zipper.start_file(cover_name)
				zipper.write_file(buffer)
				zipper.close_file()
		
		# Add background image with correct format
		if selected_background and selected_background is Image:
			var img := selected_background
			if img:
				var bg_name = info_dict["info"]["background"]
				var ext = bg_name.get_extension().to_lower()

				var buffer: PackedByteArray
				match ext:
					"png":
						buffer = img.save_png_to_buffer()
					"jpg", "jpeg":
						buffer = img.save_jpg_to_buffer(1.0)
					"webp":
						buffer = img.save_webp_to_buffer(false, 1.0)
					"exr":
						buffer = img.save_exr_to_buffer()
					"hdr":
						buffer = img.save_hdr_to_buffer()
					_:
						push_warning("Unsupported background format '%s', saving as PNG instead." % ext)
						bg_name = bg_name.get_basename() + ".png"
						buffer = img.save_png_to_buffer()

				zipper.start_file(bg_name)
				zipper.write_file(buffer)
				zipper.close_file()


		# Add difficulty texture
		if selected_diff_texture and selected_diff_texture is Texture2D:
			var img = selected_diff_texture.get_image()
			if img:
				zipper.start_file(info_dict["info"]["difficulty_texture"])
				zipper.write_file(img.save_png_to_buffer())
				zipper.close_file()
		
		# Add video background if one is set
		if background_vid_path != "" and FileAccess.file_exists(background_vid_path):
			var video_file_name := background_vid_path.get_file()
			info_dict["info"]["video"] = video_file_name

			var video_bytes := FileAccess.get_file_as_bytes(background_vid_path)
			if not video_bytes.is_empty():
				print("Adding background video to .bx:", video_file_name)
				zipper.start_file(video_file_name)
				zipper.write_file(video_bytes)
				zipper.close_file()
			else:
				push_warning("Video file could not be read or is empty: %s" % background_vid_path)
		else:
			print("No background video set or file missing skipping video")
		
		
		zipper.close()

		# Rename zip to .bx
		if not zip_path.ends_with(".bx"):
			var final_path = zip_path.get_basename() + ".bx"
			DirAccess.rename_absolute(zip_path, final_path)
			print("Shared chart packaged to %s" % final_path)
			$Control/save_to_list/saving_to_lbl.text = "Shared succesfully!"
		else:
			print("Shared chart packaged to %s" % zip_path)
			$Control/save_to_list/saving_to_lbl.text = "Shared succesfully!"
			
		return
	
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
		var audio_save_path := folder_path + "/" + General._sanitize(song_name)
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
	if selected_cover and selected_cover is Image:
		var img = selected_cover
		if img:
			var cover_save_path := folder_path + "/" + General._sanitize(selected_album) + ".png"
			General.save_image_with_correct_extension(img, cover_save_path)
			print("Saved cover image to %s" % cover_save_path)
	
	# Save background image
	if selected_background and selected_background is Image:
		var img = selected_background
		var bg_save_path := folder_path + "/" + selected_background_name
		if img and not removed_bg:
			General.save_image_with_correct_extension(img, bg_save_path)
			print("Saved background image to %s" % bg_save_path)
		elif removed_bg:
			if FileAccess.file_exists(bg_save_path):
				var err := DirAccess.remove_absolute(bg_save_path)
				if err == OK:
					print("Removed difficulty texture: %s" % bg_save_path)
				else:
					print("Failed to remove difficulty texture: %s (error %s, %s)" % [bg_save_path, err, error_string(err)])
	
	# Save difficulty texture
	if selected_diff_texture and selected_diff_texture is Texture2D:
		var img = selected_diff_texture.get_image()
		var diff_tex_save_path := folder_path + "/" + General._sanitize(selected_difficulty) + ".png"
		if img and not removed_diff_texture:
			General.save_image_with_correct_extension(img, diff_tex_save_path)
			print("Saved difficulty texture to %s" % diff_tex_save_path)
		elif removed_diff_texture:
			if FileAccess.file_exists(diff_tex_save_path):
				var err := DirAccess.remove_absolute(diff_tex_save_path)
				if err == OK:
					print("Removed difficulty texture: %s" % diff_tex_save_path)
				else:
					print("Failed to remove difficulty texture: %s (error %s, %s)" % [diff_tex_save_path, err, error_string(err)])
	
	# Save video background if one is set
	if background_vid_path != "" and FileAccess.file_exists(background_vid_path):
		print("Copying video to chart folder ", background_vid_path)
		var video_file_name := background_vid_path.get_file()
		var video_save_path := folder_path.path_join(video_file_name)
		
		# Copy video file into the chart folder using OS.execute wrapper
		General.copy_video(background_vid_path, video_save_path)
		
		# Store the filename in info.json
		info_dict["info"]["video"] = video_file_name
		print("Copied and saved background video to %s" % video_save_path)
	else:
		print("No background video set or file missing")
	
	var info_save_path := folder_path + "/info.json"
	var info_file := FileAccess.open(info_save_path, FileAccess.WRITE)
	if info_file:
		info_file.store_string(JSON.stringify(info_dict, "\t"))
		info_file.close()
		print("Saved info.json to %s" % info_save_path)
		save.emit()

func _on_saving_back_pressed() -> void:
	$Control/save_to_list/back.release_focus()
	restore_editor_mode()
	
	transition($Control/save_to_list, "scale", Vector2.ZERO, .2, true)

func _on_chart_name_edit_text_changed() -> void:
	print("na")
	if "chart_name" not in mandatory:
		mandatory.append("chart_name")
	_check_mandatory()

func _on_bpm_edit_text_changed(_new_text: String) -> void:
	if "bpm" not in mandatory:
		mandatory.append("bpm")
	_check_mandatory()

func _check_mandatory() -> void:
	var required = ["song_file", "chart_name", "bpm"]
	if required.all(func(x): return x in mandatory):
		$Control/create_map_panel/mandatory_notice.hide()
		$Control/create_map_panel/complete_setup_btn.disabled = false
		$Control/create_map_panel/complete_setup_btn.mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND
	else:
		print("no ", mandatory)

func _on_view_notes_array_pressed() -> void:
	$Control/editor_controls/view_notes_array.release_focus()
	save_editor_mode()
	transition($Control/note_array_panel, "scale", Vector2.ONE, 0.2, false)
	
	$Control/editor_title.text = "Edit Notes Array"
	$Control/editor_title.z_index = 50

	var filtered_notes: Array = General.filter_nulls(notes)
	var sorted_notes: Array = sort_by_timestamp(filtered_notes)

	$Control/note_array_panel/array.text = JSON.stringify(sorted_notes, "	")

func sort_by_timestamp(array: Array) -> Array:
	# Make a copy so we don't modify the original
	var sorted_array := array.duplicate()
	sorted_array.sort_custom(func(a, b):
		if a.has("timestamp") and b.has("timestamp"):
			return a["timestamp"] < b["timestamp"]
		return false
	)
	return sorted_array

func _on_n_array_submit() -> void:
	notes = JSON.parse_string($Control/note_array_panel/array.text)
	_on_reload_pressed()
	_on_n_array_back_pressed()
	$Control/note_array_panel/n_array_submit.release_focus()
	print("Internal Notes Array edited")

func _on_n_array_raw_pressed() -> void:
	if $Control/note_array_panel/n_array_view_raw.text == "View Raw":
		$Control/note_array_panel/n_array_view_raw.text = "View Filtered"
		$Control/note_array_panel/n_array_view_raw.tooltip_text = "View Notes array and filter null values"

		var sorted_notes: Array = sort_by_timestamp(notes)
		$Control/note_array_panel/array.text = JSON.stringify(sorted_notes, "	")
	else:
		$Control/note_array_panel/n_array_view_raw.text = "View Raw"
		$Control/note_array_panel/n_array_view_raw.tooltip_text = "View Notes array without filtering null values\n(Might cause significant fps drops)"
		
		var filtered_notes: Array = General.filter_nulls(notes)
		var sorted_notes: Array = sort_by_timestamp(filtered_notes)

		$Control/note_array_panel/array.text = JSON.stringify(sorted_notes, "	")

func _on_n_array_back_pressed() -> void:
	$Control/editor_title.z_index = 3
	$Control/editor_title.text = "Editor"
	restore_editor_mode()
	$Control/note_array_panel/array.text = "[]"
	transition($Control/note_array_panel, "scale", Vector2.ZERO, .2, true)
	$Control/note_array_panel/n_array_view_raw.text = "View Raw"
	$Control/note_array_panel/n_array_view_raw.tooltip_text = "View Notes array without filtering null values\n(Might cause significant fps drops)"

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
	$Control/editor_controls/tools.release_focus()
	save_editor_mode()
	$Control/tools/offset_lbl.text = "Offset all notes by specified time"
	$Control/tools/beat_offset_lbl.text = "Offset beatlines by specified time"
	
	$Control/tools/beat_offset.text = $Control/tools/beat_offset.text.strip_edges()
	$Control/tools/offset_all.text = $Control/tools/offset_all.text.strip_edges()
	transition($Control/tools, "scale", Vector2.ONE, .2, false)

func _on_tools_exit_pressed() -> void:
	restore_editor_mode()
	transition($Control/tools, "scale", Vector2.ZERO, .2, true)

func _on_offset_all_text_submitted(new_text: String) -> void:
	var text = General._num_eval(new_text)
	
	var value = float(text)
	
	for n in notes:
		n.timestamp += value
	_on_reload_pressed()
	$Control/tools/offset_all.text = ""
	$Control/tools/offset_lbl.text = "Notes set off by " + str(value) + " ms."
	
	saved = false
	$Control/chart_controls/save.text = "Save*"

func _on_beat_offset_text_submitted(new_text: String) -> void:
	var text = General._num_eval(new_text)
	
	var value = float(text)
	
	local_beat_offset = value
	_setup_beatlines()
	$Control/tools/beat_offset.text = ""
	$Control/tools/beat_offset_lbl.text = "Beatlines set off by " + str(value) + " ms."
	$Control/tools/beat_offset_value.text = "(Current offset: %s)" % [str(value)]
	
	saved = false
	$Control/chart_controls/save.text = "Save*"

func _on_offset_all_text_changed(_new_text: String) -> void:
	#if not new_text.is_valid_float():
	#	$Control/tools/offset_lbl.text = "Offset must be a number."
	#	return
	$Control/tools/offset_lbl.text = "Offset all notes by specified time"

func _on_beat_offset_text_changed(_new_text: String) -> void:
	#if not new_text.is_valid_float():
	#	$Control/tools/beat_offset_lbl.text = "Offset must be a number."
	#	return
	$Control/tools/beat_offset_lbl.text = "Offset beatlines by specified time"

func _on_save_to_list_mouse_entered() -> void:
	if $Control/save_to_list/saving_to_lbl.text != "Saved succesfully!": $Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(true))

func _on_save_copy_to_list_mouse_entered() -> void:
	if $Control/save_to_list/saving_to_lbl.text != "Saved succesfully!": $Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(false))

func _on_settings_btn_pressed() -> void:
	$Control/editor_controls/settings_btn.release_focus()
	if menu_open: return
	save_editor_mode()
	editor_mode =  "settings"
	$AnimationPlayer.play("go_to_settings")
	transition($Control/fps, "modulate", Color.WHITE, 0.0, false)

func _on_back_pressed() -> void:
	$back.release_focus()
	restore_editor_mode()
	$AnimationPlayer.play("back_to_edit")
	transition($Control/fps, "modulate", Color.WHITE, 0.0, true)

func _on_diff_texture_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_diff_texture_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("diff_texture", err, error_string(err))

var diff_texture_path: String
var removed_diff_texture: bool = false

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
		removed_diff_texture = false
	else:
		print("Failed to load image: ", diff_texture_path)

func _on_clear_diff_texture_pressed() -> void:
	$Control/edit_meta_cont/clear_diff.release_focus()
	$Control/create_map_panel/clear_diff.release_focus()
	removed_diff_texture = true
	diff_texture_path = ""
	$Control/edit_meta_cont/diff_texture_edit.icon = null
	$Control/create_map_panel/diff_texture_edit.icon = null

func _on_explorer_open_btn_pressed() -> void:
	General.explorer(ProjectSettings.globalize_path(selected_beatz_path.get_base_dir()))

func _on_help_btn_pressed() -> void:
	save_editor_mode()
	$Control/editor_controls/help_btn.release_focus()
	transition($Control/help, "scale", Vector2.ONE, 0.2, false)

func _on_help_exit_pressed() -> void:
	restore_editor_mode()
	transition($Control/help, "scale", Vector2.ZERO, 0.2, true)

func _on_settings_editor_brightness_changed(value: float) -> void:
	$Control/bg.self_modulate = Color(value, value, value)
	#$Control/VideoPlayback.self_modulate = Color(value, value, value)

func _on_settings_editor_note_backdrop_opacity_changed(opacity: float) -> void:
	$note_backdrop.self_modulate = Color(0.0, 0.0, 0.0, opacity)

func _on_bg_vid_edit_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Select a video file"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = General.VIDEO_FORMATS
	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.connect("file_selected", Callable(self, "_on_bg_vid_file_selected"))
	add_child(dialog)
	dialog.popup_centered()

var background_vid_path: String
var removed_bg_vid: bool = false

func _on_bg_vid_file_selected(path: String) -> void:
	background_vid_path = ProjectSettings.globalize_path(path)
	Settings.game.last_editor_path = background_vid_path.get_base_dir()

	print("Selected video: ", background_vid_path)
	
	if Settings.misc.editor_bg_videos:
		
	
		var video_node: VideoPlayback = $Control/VideoPlayback
		video_node.enable_audio = false
		video_node.enable_auto_play = false
		
		video_node.close()
		
		print("loading vid")
		video_node.set_video_path(background_vid_path)
		print("After load")
		
		# Wait until the GoZen video finishes loading
		video_node.video_loaded.connect(func():
			print("Video loaded, generating preview...")

			var total_frames = video_node.get_video_frame_count()
			var fps = video_node.get_video_framerate()
			var res = video_node.video.get_actual_resolution()

			# Calculate duration in seconds
			var duration_sec: float = 0.0
			if fps > 0:
				duration_sec = total_frames / fps

			# Format duration as mm:ss
			var minutes = int(duration_sec) / 60
			var seconds = int(duration_sec) % 60
			var duration_str = "%02d:%02d" % [minutes, seconds]

			# Seek middle frame for preview
			var mid_frame = int(total_frames / 2)
			video_node.seek_frame(mid_frame)
			await get_tree().process_frame

			# Capture current frame as preview image
			var img = video_node.video_texture.texture.get_image()
			var tex := ImageTexture.create_from_image(img)

			# Apply to icon
			$Control/edit_meta_cont/bg_vid_edit.icon = tex
			$Control/create_map_panel/bg_vid_edit.icon = tex

			# File size
			var file_size := FileAccess.get_size(path)
			var file_size_str := General.format_file_size(file_size)

			# Combine all details
			var details_text = (
				str(res.x) + "x" + str(res.y) + "\n" +
				str(round(fps)) + " FPS\n" +
				"Length: " + duration_str + "\n" +
				file_size_str + "\n" +
				path.get_file()
			)
			
			$Control/edit_meta_cont/bg_vid_details.text = details_text
			$Control/create_map_panel/bg_vid_details.text = details_text
		)
	else:
		var disabled_text: String = "Your video has been saved but\nyou have disabled BG Videos\nin the editor.\n(%s)" % background_vid_path.get_file() if background_vid_path != "" else ""
		$Control/edit_meta_cont/bg_vid_details.text = disabled_text
		$Control/create_map_panel/bg_vid_details.text = disabled_text

func _on_clear_bg_vid_pressed() -> void:
	$Control/edit_meta_cont/clear_bg_vid.release_focus()
	$Control/create_map_panel/clear_bg_vid.release_focus()
	
	removed_bg_vid = true
	background_vid_path = ""
	$Control/VideoPlayback.close()
	
	$Control/edit_meta_cont/bg_vid_details.text = "No Background"
	$Control/edit_meta_cont/bg_vid_edit.icon = null
	$Control/create_map_panel/bg_vid_details.text = "No Background"
	$Control/create_map_panel/bg_vid_edit.icon = null


func _on_settings_editor_bg_vids_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$Control/VideoPlayback.process_mode = Node.PROCESS_MODE_ALWAYS
		$Control/VideoPlayback.show()
		if background_vid_path:
			print("Setting bg vid as ", background_vid_path)
			_on_bg_vid_file_selected(background_vid_path)
	else:
		print("Closing bg vid ", background_vid_path)
		$Control/VideoPlayback.close()
		$Control/VideoPlayback.process_mode = Node.PROCESS_MODE_DISABLED
		$Control/VideoPlayback.hide()
		
		var disabled_text: String = "Your video has been saved but\nyou have disabled BG Videos\nin the editor.\n(%s)" % background_vid_path.get_file() if background_vid_path != "" else ""
		$Control/edit_meta_cont/bg_vid_details.text = disabled_text
		$Control/create_map_panel/bg_vid_details.text = disabled_text

func _on_import_from_beatz_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Select a .beatz file"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = [".beatz", ".chart", ".osu", ".qua", "*"]
	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.connect("file_selected", Callable(self, "_on_dotbeatz_file_selected"))
	add_child(dialog)
	dialog.popup_centered()

func _on_dotbeatz_file_selected(path: String):
	var file: String = ProjectSettings.globalize_path(path)
	var as_text = FileAccess.open(file, FileAccess.READ).get_as_text()
	var imported = General.import_beatz_file(as_text)
	notes = imported.notes as Array
	selected_bpm = imported.bpm
	selected_difficulty = imported.difficulty
	local_beat_offset = imported.local_beat_offset
	selected_charter = imported.charter
	selected_chart_name = imported.chart_name
	
	$Control/create_map_panel/diff_edit.text = imported.difficulty
	$Control/create_map_panel/chart_name_edit.text = imported.chart_name
	$Control/create_map_panel/charter_edit.text = imported.charter
	$Control/create_map_panel/bpm_edit.text = str(imported.bpm)
	
	var t: String = "Imported %s\nTotal notes: %d | BPM %0.2f" % [file.get_file(), imported.note_count, selected_bpm]
	$Control/create_map_panel/beatz_details.text = t
	$Control/tools/beatz_details.text = t

func _on_clear_imported_notes_pressed(reimported: bool = false) -> void:
	notes = []
	if not reimported: selected_bpm = 120.0
	if not reimported: selected_difficulty = "Hard"
	if not reimported: local_beat_offset = 0.0
	
	$Control/create_map_panel/beatz_details.text = "No Imported Notes"
