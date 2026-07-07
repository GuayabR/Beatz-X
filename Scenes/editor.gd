extends Control

signal save

const BASE_TIME: float = 360.0

var edit_start_time

var selected_difficulty_rating: float = 0.0

var history: Array = []
var redo_stack: Array = []

var move_undo_before := []
var hold_undo_before := []

func push_history(action: Dictionary) -> void:
	history.append(action)

	_update_undo_redo_buttons()


func remove_note_by_id(id: String) -> void:
	print("removing note of id ", id)
	for i in range(notes.size()):
		if notes[i]["id"] == id:
			notes.remove_at(i)
			print("removed ", i)
			break


func restore_note(note_properties: Dictionary) -> void:
	print("restoring note ", note_properties)
	notes.append(note_properties.duplicate(true))


func refresh_notes_after_history() -> void:
	_setup_notes()

	set_save_warn()

	calculate_difficulty_threaded()

func undo() -> void:
	$Control/editor_controls/undo_btn.release_focus()
	if history.is_empty():
		return

	var action: Dictionary = history.pop_back()
	redo_stack.append(action)
	
	print(action)

	match action["mode"]:
		"place":
			remove_note_by_id(action["note"]["id"])

		"delete":
			restore_note(action["note"])
		
		"multi_delete":
			for n in action["before"]:
				restore_note(n)

		"move":
			_apply_note_state_array(action["before"])

		"hold":
			_apply_note_state_array(action["before"])

	apply_scroll(action.get("scroll", $Control/chart_controls/chart_scroll.value))

	refresh_notes_after_history()
	_update_undo_redo_buttons()

func redo() -> void:
	$Control/editor_controls/redo_btn.release_focus()
	if redo_stack.is_empty():
		return

	var action: Dictionary = redo_stack.pop_back()
	history.append(action)
	
	print(action)

	match action["mode"]:
		"place":
			restore_note(action["note"])

		"delete":
			remove_note_by_id(action["note"]["id"])
		
		"multi_delete":
			for n in action["before"]:
				remove_note_by_id(n["id"])

		"move":
			_apply_note_state_array(action["after"])

		"hold":
			_apply_note_state_array(action["after"])

	apply_scroll(action.get("scroll", $Control/chart_controls/chart_scroll.value))

	refresh_notes_after_history()
	_update_undo_redo_buttons()

func apply_scroll(value: float) -> void:
	$Control/chart_controls/chart_scroll.value = value


func _apply_note_state_array(state: Array) -> void:
	for changed_note in state:
		for i in range(notes.size()):
			var n = notes[i]

			if n["id"] == changed_note["id"]:
				notes[i] = changed_note.duplicate(true)
				break

	_setup_notes()

func _update_undo_redo_buttons() -> void:
	var undo_btn = $Control/editor_controls/undo_btn
	var redo_btn = $Control/editor_controls/redo_btn

	undo_btn.disabled = history.is_empty()
	redo_btn.disabled = redo_stack.is_empty()

var new_beatzmap := true

var selected_stream: AudioStream

var song_len: float:
	get():
		return $song.stream.get_length() if $song.stream else 0.0
var song_len_ms: float:
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

@export_enum("1/2", "1/4", "1/8", "1/16", "1/32", "1/64") var snap_division: String = "1/8"

func _on_grid_snap_switch_pressed() -> void:
	$Control/editor_controls/grid_snap_switch.release_focus()
	var options = ["Free", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64"]
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
		"1/4": return quads
		"1/8": return eights
		"1/16": return sixteenths
		"1/32": return thirtyseconds
		"1/64": return sixtyfourths
		_: return 0.0 # Free mode disables snapping

func snap_timestamp(timestamp: float) -> float:
	var interval := get_snap_interval()

	# free placement
	if interval <= 0.0:
		return timestamp + (OFFSET * 2)

	return snapped(timestamp, interval) + (OFFSET * 2)

var selected_bpm: float

var beattime: float: # Time in seconds between beats (1/4 notes)
	get():
		return 60.0 / selected_bpm

var beattime_ms: float: # Time in seconds between beats (1/4 notes)
	get():
		return (60.0 / selected_bpm) * 1000.0

var doubles: float: # 1/2 note
	get():
		return beattime_ms / 2

var quads: float: # Whole note
	get():
		return beattime_ms / 4

var eights: float: # 1/8 note
	get():
		return beattime_ms / 8

var sixteenths: float: # 1/16 note
	get():
		return beattime_ms / 16

var thirtyseconds: float: # 1/32 note
	get():
		return beattime_ms / 32

var sixtyfourths: float: # 1/64 note
	get():
		return beattime_ms / 64

var note_speed : float = 15.0 # Settings.game.note_speed

var zoom: float = 10.0

var notes: Array = []

var local_beat_offset: float = 0

var NOTE := preload("res://Scenes/note.tscn")
var BEAT := preload("res://Scenes/beat_line.tscn")

var preview_note: Node2D = null

var hovered_note: Node2D = null

var dragged_note: Node2D = null

var dragged_note_index := -1

var resizing_hold_note: Node2D = null

var right_click_note: Node = null
var right_click_start_pos: Vector2 = Vector2.ZERO

var right_click_dragging := false
var right_click_pending := false

const RIGHT_CLICK_DRAG_THRESHOLD := 6.0

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
		General.set_presence(
			"Editing " + selected_title + " - " + selected_artist,
			EOS.Presence.Status.Online
		)
		General._set_rpc(selected_title + " - " + selected_artist, "Editing a Song!", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(edit_start_time), 0)
	else:
		General.set_presence(
			"Creating a Beatzmap...",
			EOS.Presence.Status.Online
		)
		General._set_rpc("No Song Set.", "Creating a Beatzmap...", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(edit_start_time), 0)

func create_beatzmap():
	save_editor_mode()
	setting_up = true
	await get_tree().process_frame
	transition($Control/create_map_panel, "scale", Vector2.ONE, .2, false)
	
	set_save_warn()
	
	DisplayServer.window_set_title("Creating new song... | Beatz! X")
	
	$Control/chart_controls/save.text = "Unsaved*"
	
	$Control/create_map_panel/cover_img_details.text = ""

func create_from_dropped_file(path):
	$Control/create_map_panel/metadata_use_check.button_pressed = true
	_on_song_select_file_selected(true, [path], 0)
	
	$Control/create_map_panel/cover_img_details.text = ""
	
	set_save_warn()
	
	$Control/chart_controls/save.text = "Unsaved*"

func time_to_y(time: float) -> float:
	#return (timestamp * zoom * note_speed / 100.0) # * -1.0
	var timestamp = time
	return (timestamp * note_speed / 10.0) * -1

func y_to_time(y: float) -> float:
	return ((-y) * zoom / note_speed)

func _init() -> void:
	edit_start_time = Time.get_unix_time_from_system()

var note_data: Dictionary

func apply_note_style() -> void:
	match Settings.misc.note_style:
		"dance": 
			note_data = {
				"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "NoteUpleftPress.png", "idle": "NoteUpleft.png"},
				"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "NoteDownleftpress.png", "idle": "NoteDownleft.png"},
				"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "NoteLeft.png", "idle": "NoteLeft.png"},
				"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "NoteDown.png", "idle": "NoteDown.png"},
				"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "NoteUp.png", "idle": "NoteUp.png"},
				"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "NoteRight.png", "idle": "NoteRight.png"},
				"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "NoteDownrightPress.png", "idle": "NoteDownright.png"},
				"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "NoteUprightPress.png", "idle": "NoteUpright.png"}
			}
		"techno": 
			note_data = {
				"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "NoteUpleftPress.png", "idle": "NoteUpleft.png"},
				"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "NoteDownleftpress.png", "idle": "NoteDownleft.png"},
				"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "techno/technoNoteLeft.png", "idle": "techno/technoNoteLeft.png"},
				"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "techno/technoNoteDown.png", "idle": "techno/technoNoteDown.png"},
				"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "techno/technoNoteUp.png", "idle": "techno/technoNoteUp.png"},
				"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "techno/technoNoteRight.png", "idle": "techno/technoNoteRight.png"},
				"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "NoteDownrightPress.png", "idle": "NoteDownright.png"},
				"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "NoteUprightPress.png", "idle": "NoteUpright.png"}
			}
		"para": 
			note_data = {
				"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "para/paraNoteUpleftPress.png", "idle": "para/paraNoteUpleft.png"},
				"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "para/paraNoteDownleftPress.png", "idle": "para/paraNoteDownleft.png"},
				"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "para/paraNoteLeftPress.png", "idle": "para/paraNoteLeft.png"},
				"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "para/paraNoteDownPress.png", "idle": "para/paraNoteDown.png"},
				"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "para/paraNoteUpPress.png", "idle": "para/paraNoteUp.png"},
				"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "para/paraNoteRightPress.png", "idle": "para/paraNoteRight.png"},
				"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "para/paraNoteDownrightPress.png", "idle": "para/paraNoteDownright.png"},
				"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "para/paraNoteUprightPress.png", "idle": "para/paraNoteUpright.png"}
			}
		"circles":
			note_data = {
				"noteUpleft": {
					"key": "Upleft",
					"sprite": "noteUpleftSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteDownleft": {
					"key": "Downleft",
					"sprite": "noteDownleftSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteLeft": {
					"key": "Left",
					"sprite": "noteLeftSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteDown": {
					"key": "Down",
					"sprite": "noteDownSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteUp": {
					"key": "Up",
					"sprite": "noteUpSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteRight": {
					"key": "Right",
					"sprite": "noteRightSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteDownright": {
					"key": "Downright",
					"sprite": "noteDownrightSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteUpright": {
					"key": "Upright",
					"sprite": "noteUprightSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				}
			}
	
	for action in note_data.keys():
		var sprite_path: String = note_data[action]["sprite"]
		var idle_texture: String = note_data[action]["idle"]

		var sprite_node: Sprite2D = $stationary_notes.get_node(sprite_path)

		if not sprite_node:
			continue

		sprite_node.texture = load("res://Resources/Arrows/" + idle_texture)

		if Settings.misc.note_style == "circles":
			var key: String = note_data[action]["key"]

			sprite_node.self_modulate = Settings.parse_any_color(
				Settings.circles.get(key, "ffffff")
			)
		else:
			sprite_node.self_modulate = Color.WHITE

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close_requested()

func _on_close_requested() -> void:
	if get_tree().is_auto_accept_quit():
		return
	
	if saved: 
		$Control/chart_controls/save.add_theme_color_override("font_color", Color.GREEN)
	else:
		$Control/chart_controls/save.add_theme_color_override("font_color", Color.RED)
	
	save_editor_mode()
	transition($Control/close_warn, "scale", Vector2.ONE, .2, false)

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	
	General.apply_fps_limit(name) # editor
	
	if Settings.misc.hq_selection_box: selection_box = $selection_box_hq
	else: selection_box = $selection_box
	
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
		$Control/chart_btns/btn_cont/playtest,
		$Control/chart_controls/chart_scroll,
		$Control/editor_controls/view_btn,
		$Control/editor_controls/view_notes_array,
		$Control/editor_controls/tools
	]
	
	buttons = [$Control/editor_controls/tools, $Control/editor_controls/view_notes_array, $Control/editor_controls/view_btn, $Control/zoom_scroll, $Control/editor_controls/place_btn, $Control/editor_controls/reload, $Control/editor_controls/dlt_btn, $Control/chart_btns/btn_cont/play, $Control/chart_btns/btn_cont/playtest, $Control/chart_controls/chart_scroll, $Control/chart_controls/exit, $Control/chart_controls/save]
	
	menus = [$Control/edit_meta_cont, $Control/create_map_panel, $Control/save_to_list, $Control/exit_warn, $Control/note_array_panel, $Control/tools, $Control/help, $Control/playtest_panel]
	
	$Control/chart_details/note_speed.text = "Note speed: " + str(note_speed)
	
	$Control/bg.self_modulate = Color(Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness)
	$Control/VideoPlayback.self_modulate = Color(Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness)
	
	$note_backdrop.self_modulate = Color(0.0, 0.0, 0.0, Settings.misc.editor_notes_backdrop_opacity)
	
	$Control/edit_meta_cont/charter_edit.text = Settings.game.username
	$Control/create_map_panel/charter_edit.text = Settings.game.username
	$Control/chart_details/charter.text = Settings.game.username
	
	if new_beatzmap:
		await get_tree().process_frame
		create_beatzmap()
		return
	
	if not AchieveMan.is_unlocked("editing"): AchieveMan.unlock("editing")
	
	DisplayServer.window_set_title("Editing %s - %s | Beatz! X" % [selected_title, selected_artist])
	
	song_path = ProjectSettings.globalize_path(song_path)
	selected_beatz_path = ProjectSettings.globalize_path(selected_beatz_path)
	
	$song.stream = selected_stream
	
	$Control/chart_details/bpm.text = "BPM: " + str(selected_bpm)
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
	
	$Control/song_details/song_title.text = selected_title
	
	if selected_artist.to_upper() == "LINKIN PARK":
		$Control/song_details/song_artist.text = "[b]" + selected_artist.to_upper() + "[/b]"
		$Control/song_details/song_artist.position.y = 56.0
	else:
		$Control/song_details/song_artist.text = selected_artist
		#$Control/song_details/song_artist.position.y = 62.0
	
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
	
	if cover_loop_vid_path: 
		cover_loop_vid_path = ProjectSettings.globalize_path(cover_loop_vid_path)
		print("Setting cover loop vid as ", cover_loop_vid_path)
		_on_cover_loop_vid_file_selected(cover_loop_vid_path)
	
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
	
	if not saved:
		set_save_warn()
	
	print(selected_beatz_path)
	print(song_path)
	
	set_discord_rpc()
	
	apply_note_style()
	
	_setup_notes()
	
	$waveform.use_chunks = true
	$waveform.setup(selected_stream)
	
	$Control/chart_controls/waveform.use_chunks = false
	$Control/chart_controls/waveform.setup(selected_stream)
	
	#$waveform._draw_preview()
	
	if playtest_start_pos > 1.0: $Control/chart_controls/chart_scroll.value = playtest_start_pos
	
	_connect_popup($note_context/type_drop)
	_connect_popup($no_note_context/type_drop)
	
func _connect_popup(btn: OptionButton) -> void:
	var popup: PopupMenu = btn.get_popup()

	popup.about_to_popup.connect(func():
		General.is_popup_open = true
	)

	popup.popup_hide.connect(func():
		General.is_popup_open = false
	)


var playing := false

var video_seek_timer: float = 0.0
const VIDEO_UPDATE_INTERVAL: float = 0.125 # 8 fps, FPS = 1 / interval s | Interval = 1 / FPS


var selected_notes: Array = []

var selection_dragging := false
var selection_start := Vector2.ZERO
var selection_end := Vector2.ZERO

var dragging_selected_notes := false

var drag_anchor_mouse := Vector2.ZERO
var selected_note_offsets := {}

var selection_box

var ctx_note: Node = null
var ctx_note_index: int = -1

var ctx_multiple_notes: Array = []

var ctx_menu_anchor_pos: Vector2 = Vector2.ZERO

func _open_note_context_menu(note, pos: Vector2, multiple: bool = false) -> void:
	hide_all_note_context_menus()

	ctx_menu_anchor_pos = pos

	if note == null:
		$no_note_context.global_position = _fit_menu_to_screen($no_note_context, pos)
		$no_note_context.show()

		ctx_multiple_notes.clear()
		ctx_note = null
		
		$no_note_context/title.text = "No note"
		
		no_ctx_place_type = get_lane_type(pos - Vector2(15, 15))
		
		var idx = type_map.find(no_ctx_place_type)

		if idx != -1:
			$no_note_context/type_drop.select(idx)
		
		$no_note_context/place_details.text = "Of Type %s with Hold of %s ms" % [$no_note_context/type_drop.get_item_text(idx), $no_note_context/hold_edit.text]
		
		$no_note_context/btns_cont/paste.text = "Paste %s Notes" % copied_notes.size()
		return
		
	if multiple:
		$multiple_note_context.global_position = _fit_menu_to_screen($multiple_note_context, pos)
		$multiple_note_context.show()

		ctx_multiple_notes = selected_notes.duplicate()
		
		$multiple_note_context/timestamp_edit.text = str(selected_notes[0].timestamp)

		$multiple_note_context/title.text = "%d Selected Notes" % [
			ctx_multiple_notes.size()
		]
	else:
		$note_context.global_position = _fit_menu_to_screen($note_context, pos)
		$note_context.show()

		ctx_note = note
		ctx_note_index = note.note_index
		
		$note_context/title.text = "Note %s | Index %d\nID: %s" % [
			note.type,
			ctx_note_index,
			note.note_id
		]
		
		$note_context/hold_edit.text = str(note.hold_ms)
		$note_context/timestamp_edit.text = str(note.timestamp)

		var type_index = type_map.find(note.type)
		$note_context/type_drop.select(type_index)

func _fit_menu_to_screen(menu: Control, pos: Vector2) -> Vector2:
	var screen_size := get_viewport().get_visible_rect().size
	
	menu.global_position = pos
	
	var menu_size = menu.size
	var corrected := pos

	if corrected.x + menu_size.x > screen_size.x - 35.0:
		corrected.x = screen_size.x - menu_size.x - 35.0
	
	if corrected.y + menu_size.y > screen_size.y - 35.0:
		corrected.y = screen_size.y - menu_size.y - 35.0

	if corrected.x < 15:
		corrected.x = 15.0
	
	if corrected.y < 15:
		corrected.y = 15.0

	return corrected

func _apply_note_changes():
	if ctx_note_index < 0 or ctx_note_index >= notes.size():
		return

	var data = notes[ctx_note_index]

	data.timestamp = ctx_note.timestamp
	data.type = ctx_note.type

	if ctx_note.hold_ms > 0.0:
		data.hold = ctx_note.hold_ms
	else:
		data.erase("hold")

	notes[ctx_note_index] = data

	set_save_warn()
	_setup_notes()

func _apply_multiple_note_changes():
	for n in ctx_multiple_notes:
		if not is_instance_valid(n):
			continue

		var idx = n.note_index

		if idx < 0 or idx >= notes.size():
			continue

		var data = notes[idx]

		data.timestamp = n.timestamp
		data.type = n.type

		if n.hold_ms > 0.0:
			data.hold = n.hold_ms
		elif data.has("hold"):
			data.erase("hold")

		notes[idx] = data

	set_save_warn()
	_setup_notes()
	calculate_difficulty_threaded()

func hide_all_note_context_menus():
	$note_context.hide()
	$multiple_note_context.hide()
	$no_note_context.hide()
	
	$note_context.global_position = Vector2(-328, 252)
	$multiple_note_context.global_position = Vector2(-328, 482)
	$no_note_context.global_position = Vector2(-385, 694)

var right_click_hold_armed := false
var hold_original_value := 0.0
var hold_changed := false

func _process(delta: float) -> void:
	_update_visible_notes()
	_update_visible_beatlines()
	
	if difficulty_calculating and difficulty_thread and not difficulty_thread.is_alive():
		difficulty_result = difficulty_thread.wait_to_finish()

		update_difficulty_graph()
		difficulty_calculating = false

		#print("finished calc", difficulty_result)

	# if notes changed while thread was running
	if difficulty_dirty and not difficulty_calculating:
		calculate_difficulty_threaded()

	if difficulty_result.is_empty():
		return

	$Control/chart_details/diff.text = "Difficulty: %s (%.2f)" % [
		selected_difficulty.to_pascal_case(),
		difficulty_result["rating"]
	]

	$Control/chart_details/diff2.text = "Peak NPS: %.2f" % difficulty_result["peak_nps"]

	$Control/chart_details/diff3.text = "Average NPS: %.2f" % difficulty_result["average_nps"]
	
	if chart_scroll_tween and chart_scroll_tween.is_running():
		video_seek_timer += delta
		if video_seek_timer >= VIDEO_UPDATE_INTERVAL:
			video_seek_timer = 0.0
			_update_video_frame()
	
	if not playing:
		if editor_mode == "none": return
		var speed := 10.0
		if Input.is_key_pressed(KEY_SHIFT):
			speed *= 3.0
		if Input.is_key_pressed(KEY_CTRL):
			speed *= 0.4
		
		if Input.is_action_pressed("noteUp") and not Input.is_action_pressed("editor_save"):
			move(speed)
			_update_scroll_from_notes_position()
		if Input.is_action_pressed("noteDown") and not Input.is_action_pressed("editor_save"):
			move(-speed)
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
		if right_click_pending and not right_click_dragging:
			if get_global_mouse_position().distance_to(right_click_start_pos) > RIGHT_CLICK_DRAG_THRESHOLD:
				
				right_click_dragging = true
				resizing_hold_note = right_click_note
				
				# NEW
				right_click_hold_armed = true
				hold_changed = false
				
				if resizing_hold_note:
					hold_original_value = resizing_hold_note.hold_ms
					
					hold_undo_before.clear()

					if (
						resizing_hold_note.note_index >= 0
						and resizing_hold_note.note_index < notes.size()
					):
						hold_undo_before.append(
							notes[resizing_hold_note.note_index].duplicate(true)
						)
				
				hide_all_note_context_menus()
		
		if resizing_hold_note and right_click_hold_armed:
			var bar = resizing_hold_note.get_node("HoldBar2D")
			var bar2 = resizing_hold_note.get_node("HoldBar")
			var end = resizing_hold_note.get_node("note_hold_end")
			var hit = resizing_hold_note.get_node("editor_hitbox")

			var local_y: float = -bar.to_local(get_global_mouse_position()).y

			var hold_visual_y = max(local_y * -1.0, 0.0)

			bar.points[1].y = hold_visual_y
			bar.points[2].y = hold_visual_y + 20
			bar2.size.y = hold_visual_y

			if bar2.size.y > Beatz.time_to_y(Settings.misc.hold_thresh_to_rm_edit, true):
				hit.size.y = min(local_y - 82, 0.0) * -1.0
				hit.position.y = min(local_y, 0.0)
			else:
				hit.size.y = 164.0
				hit.position.y = -82

			if not end.visible and Settings.misc.editor_show_note_hold_ends:
				end.show()

			end.position.y = min(local_y, 0.0)

			if bar2.size.y < Beatz.time_to_y(Settings.misc.hold_thresh_to_rm_edit, true):
				bar2.size.y = 0.0
				bar.points[1].y = 0.0
				bar.points[2].y = 20.0
				end.position.y = 0.0

				resizing_hold_note.hold_ms = 0.0

				if end.visible and Settings.misc.editor_show_note_hold_ends:
					end.hide()

			else:
				var note_y: float = local_y / Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER

				resizing_hold_note.hold_ms = max(
					Beatz.y_to_time(note_y, true),
					0.0
				)

			var i = resizing_hold_note.note_index

			if i >= 0 and i < notes.size():
				var note_properties = notes[i]

				if resizing_hold_note.hold_ms <= 0.0:
					if note_properties.has("hold"):
						note_properties.erase("hold")
				else:
					note_properties.hold = resizing_hold_note.hold_ms

				notes[i] = note_properties
				
				var new_hold = resizing_hold_note.hold_ms
				
				if abs(new_hold - hold_original_value) > 0.001:
					hold_changed = true

		if hold_changed:
			set_save_warn()
		
	
	if not playing and editor_mode == "place":
		if preview_note:
			var raw_y: float = get_global_mouse_position().y - $notes.position.y

			var timestamp = (
				((-raw_y) * zoom / note_speed)
				- BASE_TIME
			)

			timestamp = snap_timestamp(timestamp)

			preview_note.position.y = (
				(timestamp + BASE_TIME)
				* note_speed
				/ zoom
			) * -1.0
			
			var type: String = get_lane_type(get_global_mouse_position())
			if type == "out": preview_note.hide()
			else: preview_note.show()
			
			preview_note.position.x = _get_note_x(type)
			
			if preview_note.type != type: preview_note.set_type(type)
			
			preview_note.modulate = Color(1.0, 1.0, 1.0, 0.5)
	
	
	if selection_dragging and not playing:
		selection_end = $notes.get_local_mouse_position()

		var rect := Rect2(
			selection_start,
			selection_end - selection_start
		).abs()

		# convert local chart-space rect to global UI position
		selection_box.global_position = (
			$notes.global_position + rect.position
		)

		selection_box.size = rect.size

		var new_selection := []

		if Input.is_key_pressed(KEY_CTRL):
			new_selection = selected_notes.duplicate()

		for n in rendered_notes.values():
			var hitbox: Control = n.get_node("editor_hitbox")

			# convert hitbox rect into $notes local space
			var hb_global_pos: Vector2 = hitbox.global_position
			var hb_size: Vector2 = hitbox.size - Vector2(15, 15)

			var local_rect := Rect2(
				$notes.to_local(hb_global_pos) + Vector2(4, -7),
				hb_size / 1.5
			)

			if rect.intersects(local_rect):
				if not new_selection.has(n):
					new_selection.append(n)
					

		selected_notes = new_selection
		
		for n in rendered_notes.values():
			n.selected = selected_notes.has(n)

			if n.selected:
				n.modulate = Color.CYAN
			else:
				n.modulate = Color.WHITE
	
	if not playing and editor_mode == "view":
		if dragging_selected_notes and dragged_note:
			var mouse_delta = (
				get_global_mouse_position() - drag_anchor_mouse
			)

			var lane_type = get_lane_type(
				get_viewport().get_mouse_position()
			)

			var target_x = _get_note_x(lane_type)

			# ORIGINAL dragged note position
			var dragged_data = selected_note_offsets[dragged_note]
			var dragged_raw_pos = dragged_data["pos"] + mouse_delta

			# RAW timestamp before snapping
			var dragged_raw_timestamp = (
				((-dragged_raw_pos.y) * zoom / note_speed)
				- BASE_TIME
			)

			# ONLY snap the dragged note
			var snapped_timestamp = snap_timestamp(dragged_raw_timestamp)

			# delta caused by snapping
			var snap_offset = snapped_timestamp - dragged_raw_timestamp

			for n in selected_notes:
				if not is_instance_valid(n):
					continue

				var data = selected_note_offsets[n]

				var new_pos = data["pos"] + mouse_delta

				# base timestamp (NO snapping)
				var timestamp = (
					((-new_pos.y) * zoom / note_speed)
					- BASE_TIME
				)

				# apply dragged-note snap offset
				timestamp += snap_offset

				n.timestamp = timestamp

				# re-sync visual position
				n.position.y = (
					(timestamp + BASE_TIME)
					* note_speed
					/ zoom
				) * -1.0

				# only dragged note changes lane
				if n == dragged_note:
					n.position.x = target_x

					if n.type != lane_type:
						n.set_type(lane_type)

				var idx = n.note_index

				if idx >= 0 and idx < notes.size():
					var note_properties = notes[idx]

					note_properties.timestamp = timestamp - (OFFSET * 2)

					if n == dragged_note:
						note_properties.type = lane_type

					notes[idx] = note_properties
	
	$Control/chart_controls/pos_label.text = "D Y Pos: " + str(snapped(get_y(), 0.01))
	if not setting_up: $Control/chart_controls/scroll_lbl.text = "D Song time: " + str(snapped($song.get_playback_position(), 0.01))
	$Control/chart_controls/scroll_val.text = "Time: " +  General.format_time($Control/chart_controls/chart_scroll.value) + " / " + General.format_time(song_len)

func move(amnt: float = 0.0, use_old_logic: bool = true) -> void:
	if use_old_logic:
		$notes.position.y += amnt
		$beatlines.position.y += amnt
		$waveform.position.y += amnt# + 1080.0
		return
	$cam.global_position.y -= amnt
	$Control.global_position.y -= amnt
	$stationary_notes.global_position.y -= amnt
	$lanes.global_position.y -= amnt
	$lanes2.global_position.y -= amnt

func set_y(value: float = 0.0, use_old_logic: bool = true) -> void:
	if use_old_logic:
		$notes.position.y = value
		$beatlines.position.y = value
		$waveform.position.y = value + 989.0
		return
	$cam.global_position.y = value + 540.0
	$Control.global_position.y = value
	$stationary_notes.global_position.y = value
	$lanes.global_position.y = value
	$lanes2.global_position.y = value

func get_y(use_old_logic: bool = true) -> float:
	if use_old_logic: return $notes.global_position.y 
	else: return -$cam.global_position.y

func close_panel_from_input():
	for menu in menus:
		if menu.name == "note_array_panel":
			_on_n_array_back_pressed()
			continue
		
		if menu.scale > Vector2.ZERO:
			transition(menu, "scale", Vector2.ZERO, 0.2, true)

func set_save_warn():
	saved = false
	$Control/chart_controls/save.text = "Save*"

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
	
	if Input.is_action_just_pressed("save_quit"):
		if editor_mode == "none":
			return
		_on_save_to_list_pressed()
		await save
		_on_exit_pressed()
		
	
	if Input.is_action_just_pressed("quit"):
		if editor_mode == "none":
			return
		_on_exit_warn_pressed()
	
	if Input.is_action_just_pressed("editor_save"):
		if editor_mode == "none":
			return
		_on_save_to_list_pressed()
	
	if Input.is_action_just_pressed("editor_save_copy"):
		if editor_mode == "none":
			return
		_on_save_copy_to_list_pressed()
	
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
	
	if Input.is_action_just_pressed("ui_undo"):
		undo()
	
	if Input.is_action_just_pressed("ui_redo"):
		redo()
	
	if Input.is_action_just_pressed("ui_text_delete"):
		delete_notes(selected_notes)
	
	if Input.is_action_just_pressed("ui_copy"):
		copy_selected_notes()
	
	if Input.is_action_just_pressed("ui_cut"):
		cut_selected_notes()
	
	if Input.is_action_just_pressed("ui_paste"):
		paste_copied_notes()
		
	
	var mouse_pos := get_viewport().get_mouse_position()

	var over_single_menu = $note_context.get_global_rect().has_point(mouse_pos)
	var over_multi_menu = $multiple_note_context.get_global_rect().has_point(mouse_pos)
	var over_none_menu = $no_note_context.get_global_rect().has_point(mouse_pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		match editor_mode:
			"view":
				if setting_up or playing:
					return
				
				var ctrl_held := Input.is_key_pressed(KEY_CTRL)
				
				if event.pressed:
					if (over_single_menu or over_multi_menu or over_none_menu) or menu_open:
						return
					
					if hovered_note:
						# clicked a note

						# if note not already selected,
						# make it the only selected note
						if ctrl_held:
							if selected_notes.has(hovered_note):
								selected_notes.erase(hovered_note)
							else:
								selected_notes.append(hovered_note)
						else:
							if not selected_notes.has(hovered_note):
								selected_notes.clear()
								selected_notes.append(hovered_note)
						
						for n in rendered_notes.values():
							n.selected = selected_notes.has(n)

							if n.selected:
								n.modulate = Color.CYAN
							else:
								n.modulate = Color.WHITE

						dragged_note = hovered_note
						dragged_note_index = hovered_note.note_index

						dragging_selected_notes = true
						drag_anchor_mouse = get_global_mouse_position()

						selected_note_offsets.clear()
						
						move_undo_before.clear()

						for n in selected_notes:
							if n.note_index >= 0 and n.note_index < notes.size():
								move_undo_before.append(
									notes[n.note_index].duplicate(true)
								)

						for n in selected_notes:
							selected_note_offsets[n] = {
								"pos": n.position,
								"timestamp": n.timestamp
							}

						set_save_warn()

					else:
						# clicked empty space -> begin box selection
						if not ctrl_held:
							selected_notes.clear()

						selection_start = $notes.get_local_mouse_position()
						
						if selection_start.x > 380.0 and selection_start.x < 1420 and not over_single_menu and not over_multi_menu and not over_none_menu and not menu_open:
							selection_dragging = true
							
							selection_end = selection_start

							selection_box.visible = true
						else:
							selection_start = Vector2.ZERO
				else:
					if dragging_selected_notes:
						var move_after := []

						for n in selected_notes:
							if n.note_index >= 0 and n.note_index < notes.size():
								move_after.append(
									notes[n.note_index].duplicate(true)
								)

						if not move_undo_before.is_empty():
							push_history({
								"mode": "move",
								"before": move_undo_before.duplicate(true),
								"after": move_after.duplicate(true)
							})

						calculate_difficulty_threaded()

					dragging_selected_notes = false

					dragged_note = null
					dragged_note_index = -1

					if selection_dragging:
						selection_dragging = false

						selection_box.visible = false

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
					if hovered_note:
						delete_note(hovered_note)

			"select":
				if setting_up: return
				if event.pressed:
					get_note_under_mouse()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not over_single_menu and not over_multi_menu and not over_none_menu:
			hide_all_note_context_menus()
	
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragged_note = null

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if hovered_note:
				right_click_note = hovered_note
				right_click_start_pos = get_global_mouse_position()
				right_click_pending = true
				right_click_dragging = false
			else:
				right_click_note = null
				right_click_pending = false
				right_click_dragging = false
				hide_all_note_context_menus()
		
		else:
			# RELEASE
			
			var note := right_click_note
			var was_dragging := right_click_dragging
			
			var open_multi := false
			
			if note:
				open_multi = (
					selected_notes.size() > 1
					and selected_notes.has(note)
				)
			
			if note and not was_dragging:
				if open_multi:
					_open_note_context_menu(
						note,
						get_global_mouse_position() + Vector2(15, 15),
						true
					)
				else:
					_open_note_context_menu(
						note,
						get_global_mouse_position() + Vector2(15, 15),
						false
					)
			elif note == null and not was_dragging:
				_open_note_context_menu(
					note,
					get_global_mouse_position() + Vector2(15, 15),
					false
				)
			
			if was_dragging:
				if hold_changed:
					var hold_after := []

					if (
						note.note_index >= 0
						and note.note_index < notes.size()
					):
						hold_after.append(
							notes[note.note_index].duplicate(true)
						)

					push_history({
						"mode": "hold",
						"before": hold_undo_before.duplicate(true),
						"after": hold_after.duplicate(true),
						"scroll": $Control/chart_controls/chart_scroll.value
					})

				calculate_difficulty_threaded()

				right_click_hold_armed = false
				hold_changed = false
				hold_original_value = 0.0
			
			right_click_note = null
			right_click_pending = false
			right_click_dragging = false
			resizing_hold_note = null
	
	if event is InputEventMouseButton:
		if playing or setting_up or editor_mode == "none" or editor_mode == "settings":
			return

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

func _on_note_hovered(note: Node2D) -> void:
	if hovered_note == note:
		return

	if hovered_note:
		var t = create_tween()
		t.tween_property(hovered_note.get_node("noteImg"), "scale", Vector2.ONE, 0.15)
		t.parallel().tween_property(hovered_note.get_node("noteImg"), "modulate", Color(1,1,1,1), 0.2)

	hovered_note = note

	if editor_mode == "view":
		var t = create_tween()
		t.tween_property(note.get_node("noteImg"), "scale", Vector2(1.05, 1.05), 0.1)
		t.parallel().tween_property(note.get_node("noteImg"), "modulate", Color(0.607, 1.0, 0.577, 1.0), 0.2)

	elif editor_mode == "delete":
		var t = create_tween()
		t.tween_property(note.get_node("noteImg"), "scale", Vector2(0.95, 0.95), 0.1)
		t.parallel().tween_property(note.get_node("noteImg"), "modulate", Color(1,1,1,0.6), 0.15)

func _on_note_unhovered(note: Node2D) -> void:
	if hovered_note != note:
		return

	var t = create_tween()
	t.tween_property(note.get_node("noteImg"), "scale", Vector2.ONE, 0.15)
	t.parallel().tween_property(note.get_node("noteImg"), "modulate", Color(1,1,1,1), 0.2)

	hovered_note = null

func _on_note_pressed(note: Node2D, event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if editor_mode == "view":
			dragged_note = note

		elif editor_mode == "delete":
			delete_note(note)

	if event.button_index == MOUSE_BUTTON_RIGHT:
		if editor_mode in ["view"]:
			resizing_hold_note = note

			# if note has no hold yet, create a temporary one so visuals appear
			if resizing_hold_note.hold_ms < 0.0:
				resizing_hold_note.hold_ms = 0.0

				var bar = resizing_hold_note.get_node("HoldBar2D")
				var bar2 = resizing_hold_note.get_node("HoldBar")
				var end = resizing_hold_note.get_node("note_hold_end")

				bar.visible = true
				bar2.visible = true
				if Settings.misc.editor_show_note_hold_ends: end.visible = true

				bar.points[1].y = 0.0
				bar.points[2].y = 20.0
				bar2.size.y = 0.0
				end.position.y = 0.0


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
	if $Control/note_effect_lane.get_rect().has_point(mouse_pos):
		return "Effect"
	elif $Control/note_ul_lane.get_rect().has_point(mouse_pos):
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

	var note_id := ""

	if typeof(note_to_delete) == TYPE_DICTIONARY:
		note_id = note_to_delete.get("id", "")
	else:
		note_id = note_to_delete.note_id

	var deleted_snapshot := {}

	for i in range(notes.size()):
		var n = notes[i]

		if n.get("id", "") == note_id:
			deleted_snapshot = n.duplicate(true)

			notes.remove_at(i)
			$Control/chart_details/note_count.text = "Total notes: " + str(notes.size())
			break

	# UI object side delete
	if typeof(note_to_delete) != TYPE_DICTIONARY:
		if note_to_delete.editor_deleted or note_to_delete.faded:
			return

		note_to_delete.editor_deleted = true
		note_to_delete.z_index -= 1
		note_to_delete.hit()

	set_save_warn()
	calculate_difficulty_threaded()

	if not deleted_snapshot.is_empty():
		push_history({
			"mode": "delete",
			"note": deleted_snapshot.duplicate(true),
			"scroll": $Control/chart_controls/chart_scroll.value
		})

# Spawns a new NOTE at the correct lane x and given y
func place_note_at(y_pos: float, note_type: String, timestamp_override: float = -1.0, record_history: bool = true):
	if setting_up or editor_mode == "settings":
		return

	var timestamp: float
	if timestamp_override != -1.0:
		timestamp = timestamp_override + (OFFSET * 2)
	else:
		timestamp = (((-y_pos) * zoom / note_speed)) - BASE_TIME

	timestamp = snap_timestamp(timestamp)

	print("appending new NOTE at timestamp ", timestamp)
	var note_properties := {
		"id": General.generate_note_id(),
		"timestamp": timestamp - (OFFSET * 2),
		"type": note_type,
	}

	notes.append(note_properties)
	
	set_save_warn()
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
	
	#print("appended: ", note_type)
	
	calculate_difficulty_threaded()

	# Add to undo history (only if not from undo/redo)
	if record_history:
		push_history({
			"mode": "place",
			"note": note_properties.duplicate(true),
			"scroll": $Control/chart_controls/chart_scroll.value
		})

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
		if Settings.misc.editor_seek_vid_along_scroll: _update_video_frame()

	# Update UI labels
	$Control/chart_controls/pos_label.text = "D Y Pos: " + str(snapped(get_y(), 0.01))
	$Control/chart_controls/scroll_lbl.text = "D Song time: " + str(snapped($song.get_playback_position(), 0.01))
	$Control/chart_controls/scroll_val.text = "Time: " +  General.format_time($Control/chart_controls/chart_scroll.value) + " / " + General.format_time(song_len)

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

func _on_chart_scroll_drag_ended(value_changed: bool) -> void:
	if value_changed: _update_video_frame()

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
	
	selection_dragging = false
	
	selection_start = Vector2.ZERO
	selection_end = Vector2.ZERO
	
	selection_box.size = Vector2.ZERO
	
	save_editor_mode()
	if preview_note: preview_note.hide()
	
	$Control/chart_btns/btn_cont/play.text = "Pause"
	playing = true
	
	for btn in buttons_to_disable_on_play:
		if btn == null:
			continue
		if btn is Button:
			btn.disabled = true
		else:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
			
			if $Control/VideoPlayback.current_frame == target_frame: 
				$Control/VideoPlayback.play()
				return
			
			var total_frames = $Control/VideoPlayback.get_video_frame_count()
			target_frame = clampi(target_frame, 0, total_frames - 1)

			$Control/VideoPlayback.seek_frame(target_frame)
			$Control/VideoPlayback.play()

func _pause() -> void:
	if setting_up: return
	
	restore_editor_mode()
	if preview_note: preview_note.show()
	
	$Control/chart_btns/btn_cont/play.text = "Play"
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

var difficulty_thread: Thread
var difficulty_result: Dictionary = {}
var difficulty_calculating := false
var difficulty_dirty := false

var difficulty_graph_data := {}

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
	if notes.is_empty():
		return {
			"rating": 0.0,
			"peak_nps": 0.0,
			"average_nps": 0.0
		}

	var sorted_notes := notes.duplicate()

	sorted_notes.sort_custom(func(a, b):
		return a.timestamp < b.timestamp
	)

	var note_counts := {}
	var graph_data := {}

	var total_notes := sorted_notes.size()
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

	var scroll := $Control/chart_controls/chart_scroll

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
	var max_second = max(int(song_len), 1)

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

var highest_note_y := 0.0
var highest_timestamp: float = 0.0

var rendered_notes := {}

const NOTE_RENDER_DISTANCE: float = 986.0

func _setup_notes():
	if setting_up:
		return

	for child in $notes.get_children():
		child.queue_free()

	rendered_notes.clear()

	var highest_y: float = ((song_len_ms) * note_speed / zoom)
	#var highest_time: float = song_len

	for n: Dictionary in notes:
		var timestamp = n.timestamp + OFFSET + BASE_TIME
		var y = (timestamp * note_speed / 10.0) * -1

		if -y > highest_y:
			highest_y = -y

		#if (n.timestamp + 1080.0) / 1000.0 > highest_time:
			#highest_time = (n.timestamp + 1080.0) / 1000.0

	highest_note_y = highest_y
	highest_timestamp = song_len

	$Control/chart_controls/chart_scroll.min_value = 0
	$Control/chart_controls/chart_scroll.max_value = highest_timestamp

	$Control/chart_details/note_count.text = "Total notes: " + str(notes.size())

	_update_visible_notes()

	calculate_difficulty_threaded()
	
	_update_visible_beatlines()

func _update_visible_notes():
	var min_y = -1 * get_y() - NOTE_RENDER_DISTANCE
	var max_y = -1 * get_y() + NOTE_RENDER_DISTANCE

	var visible_notes := {}

	for i in range(notes.size()):
		var n = notes.get(i)
		
		if n == null:
			print("Note not found in index ", i)
			continue

		var timestamp = n.timestamp + (OFFSET * 2) + BASE_TIME
		var y = (timestamp * note_speed / 10.0) * -1

		var hold_ms: float = 0.0
		if n.has("hold"):
			hold_ms = n.hold

		var tail_y = y
		if hold_ms > 0.0:
			var hold_pixels := (hold_ms * note_speed / 10.0)
			tail_y = y + -hold_pixels  # downward extension (because y is inverted)

		var on_screen = not (
			(max(y, tail_y) < min_y) or
			(min(y, tail_y) > max_y)
		)

		if not on_screen:
			continue
		
		visible_notes[i] = true

		if rendered_notes.has(i):
			var existing = rendered_notes[i]

			if is_instance_valid(existing):
				continue

			rendered_notes.erase(i)

		var obj := NOTE.instantiate()
		
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

		obj.editor_hovered.connect(_on_note_hovered)
		obj.editor_unhovered.connect(_on_note_unhovered)
		obj.editor_pressed.connect(_on_note_pressed)
		
		if menu_open: obj.get_node("editor_hitbox").mouse_filter = MOUSE_FILTER_IGNORE

		$notes.add_child(obj)

		rendered_notes[i] = obj

	var to_remove := []

	for i in rendered_notes.keys():
		if visible_notes.has(i):
			continue

		var obj = rendered_notes[i]

		# keep selected notes alive even offscreen
		if selected_notes.has(obj):
			continue

		if is_instance_valid(obj):
			obj.queue_free()

		to_remove.append(i)

	for i in to_remove:
		rendered_notes.erase(i)

func _get_note_x(type: String) -> float:
	match type:
		"Effect",  "Section":
			return $stationary_notes/noteEffectSprite.position.x

		"Upleft":
			return $stationary_notes/noteUpleftSprite.position.x

		"Downleft":
			return $stationary_notes/noteDownleftSprite.position.x

		"Left":
			return $stationary_notes/noteLeftSprite.position.x

		"Down":
			return $stationary_notes/noteDownSprite.position.x

		"Up":
			return $stationary_notes/noteUpSprite.position.x

		"Right":
			return $stationary_notes/noteRightSprite.position.x

		"Downright":
			return $stationary_notes/noteDownrightSprite.position.x

		"Upright":
			return $stationary_notes/noteUprightSprite.position.x
	
	if type != "out": print("Unrecognized note type: ", type)
	return $stationary_notes/noteEffectSprite.position.x

var rendered_beatlines := {}
const BEAT_RENDER_DISTANCE := 1000.0

func y_to_timestamp(y: float) -> float:
	return (-y * zoom / note_speed) - BASE_TIME - (OFFSET * 2.0)
	
func timestamp_to_y(t: float) -> float:
	return ((t + BASE_TIME + (OFFSET * 2.0)) * note_speed / zoom) * -1.0

func _update_visible_beatlines():
	var min_y = -1 * get_y() - BEAT_RENDER_DISTANCE
	var max_y = -1 * get_y() + BEAT_RENDER_DISTANCE

	var min_time = y_to_timestamp(max_y)
	var max_time = y_to_timestamp(min_y)

	var interval := beattime_ms
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

			var line := BEAT.instantiate()
			line.position = Vector2(960, y)
			line.process_mode = Node.PROCESS_MODE_DISABLED
			$beatlines.add_child(line)

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

				var sub := BEAT.instantiate()
				sub.position = Vector2(960, y)
				sub.scale = Vector2(2.6, 0.3)
				sub.modulate = Color(0.5, 0.5, 0.5, 1.0)
				sub.process_mode = Node.PROCESS_MODE_DISABLED

				$beatlines.add_child(sub)
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
	for line in $beatlines.get_children():
		line.queue_free()

	var t := 0.0 - beattime * 16
	var times := local_beat_offset

	while t <= song_len:
		# MAIN BEAT
		var main_timestamp := t + times

		var y = (
			((main_timestamp * 1000.0) + BASE_TIME - OFFSET)
			* note_speed
			/ zoom
		) * -1.0

		var main_line := BEAT.instantiate()

		main_line.position = Vector2(960, y)
		main_line.process_mode = Node.PROCESS_MODE_DISABLED

		$beatlines.add_child(main_line)
		
		# SUBDIVISIONS
		for i in range(1, 4):
			var sub_t := t + (beattime / 4.0) * i

			if sub_t > song_len:
				break

			var sub_timestamp := sub_t + times

			var sub_y = (
				((sub_timestamp * 1000.0) + BASE_TIME - OFFSET)
				* note_speed
				/ zoom
			) * -1.0

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
	
	$waveform.regenerate()
	#$Control/chart_controls/waveform._draw_preview()
	
	$Control/editor_controls/reload.release_focus()

func _on_play_pressed() -> void:
	if playing:
		_pause()
	else:
		_play()
	
	$Control/chart_btns/btn_cont/play.release_focus()

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
	elif preview_note and is_instance_valid(preview_note): preview_note.show()
	
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
		call_deferred("enable_editor_notes")
		
		if $Control/edit_meta_cont/bg_vid_edit/VideoPlayback.is_open() and panel.name == "edit_meta_cont":
			$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.pause()
			$Control/create_map_panel/bg_vid_edit/VideoPlayback.pause()
		
		if $Control/edit_meta_cont/cover_loop_edit/VideoPlayback.is_open() and panel.name == "edit_meta_cont":
			$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.pause()
			$Control/create_map_panel/cover_loop_edit/VideoPlayback.pause()
	else:
		menu_open = true
		call_deferred("disable_editor_notes")
			
		if $Control/edit_meta_cont/bg_vid_edit/VideoPlayback.is_open() and panel.name == "edit_meta_cont":
			$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.play()
			$Control/create_map_panel/bg_vid_edit/VideoPlayback.play()
		
		if $Control/edit_meta_cont/cover_loop_edit/VideoPlayback.is_open() and panel.name == "edit_meta_cont":
			$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.play()
			$Control/create_map_panel/cover_loop_edit/VideoPlayback.play()
	
	var t = create_tween() 
	
	t.tween_property(panel, property, to, time).set_trans(Tween.TRANS_CIRC) 
	t.parallel().tween_property($overlay, "modulate", Color(0, 0, 0, 0.5) if not close else Color(0, 0, 0, 0.0), 0.2).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property($song, "pitch_scale", 0.85 if not close else 1.0, 0.2)
	t.parallel().tween_property($Control/VideoPlayback, "playback_speed", 0.85 if not close else 1.0, 0.2)

func disable_editor_notes():
	if $notes.get_child_count() == 0: return
	for n in $notes.get_children():
		var hit: Control = n.get_node("editor_hitbox")
		if not hit: continue
		hit.mouse_default_cursor_shape = Control.CURSOR_ARROW
		hit.mouse_filter = Control.MOUSE_FILTER_IGNORE

func enable_editor_notes():
	if $notes.get_child_count() == 0: return
	for n in $notes.get_children():
		var hit: Control = n.get_node("editor_hitbox")
		if not hit: continue
		
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.mouse_filter = Control.MOUSE_FILTER_STOP

func _on_exit_warn_pressed() -> void:
	save_editor_mode()
	$Control/exit_warn/warn_lbl.text = "Are you sure you want to exit editing \"%s\"\n\nUnsaved edits will be lost." % selected_chart_name
	
	transition($Control/exit_warn, "scale", Vector2.ONE, .2, false)
	$Control/chart_controls/exit.release_focus()
	
	if saved: 
		$Control/chart_controls/save.add_theme_color_override("font_color", Color.GREEN)
	else:
		$Control/chart_controls/save.add_theme_color_override("font_color", Color.RED)

func _on_exit_pressed() -> void:
	SceneLoader.load_scene("res://Scenes/main_menu.tscn")

	var progress_update := func():
		while SceneLoader.is_loading():
			loading_text.text = "Loading... (" + str(int(SceneLoader.get_progress() * 100.0)) + "%"
			await get_tree().process_frame
		loading_text.text = "Loading... 100%"

	progress_update.call()

	$AnimationPlayer.play("exit", 0.5)
	transition($Control/exit_warn, "scale", Vector2.ZERO, .2, true)

	await $AnimationPlayer.animation_finished

	if SceneLoader.is_loading():
		await SceneLoader.scene_loaded

	var main = SceneLoader.loaded_scene.instantiate()

	get_tree().root.add_child(main)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = main

func _on_cancel_exit_pressed() -> void:
	restore_editor_mode()
	transition($Control/exit_warn, "scale", Vector2.ZERO, .2, true)
	
	$Control/chart_controls/save.add_theme_color_override("font_color", Color.WHITE)
	
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
	
	if selected_cover: $Control/edit_meta_cont/cover_img_details.text = str(selected_cover.get_width()) + "x" + str(selected_cover.get_height()) + "\n" + selected_album + "\n" + General.format_file_size(selected_cover.get_data_size())
	else: $Control/edit_meta_cont/cover_img_details.text = "No cover image."
	
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
	
	_update_visible_beatlines()
	
	$Control/song_details/song_artist.text = $Control/edit_meta_cont/artist_edit.text
	selected_artist = $Control/edit_meta_cont/artist_edit.text
	
	if selected_artist.to_upper() == "LINKIN PARK":
		$Control/song_details/song_artist.text = "[b]" + selected_artist.to_upper() + "[/b]"
		$Control/song_details/song_artist.position.y = 56.0
	else:
		$Control/song_details/song_artist.text = selected_artist
		#$Control/song_details/song_artist.position.y = 62.0
	
	$Control/song_details/album.text = $Control/edit_meta_cont/album_edit.text
	selected_album = $Control/edit_meta_cont/album_edit.text
	
	var cov: ImageTexture = $Control/edit_meta_cont/album_cover_edit.icon
	if cov: 
		selected_cover = cov.get_image()
		$Control/song_details/sha.show()
	else: 
		selected_cover = preload("res://Resources/misc/noCover.png").get_image()
		$Control/song_details/sha.hide()
	
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
	
	DisplayServer.window_set_title("Editing %s - %s | Beatz! X" % [selected_title, selected_artist])
	
	set_save_warn()
	
	set_discord_rpc()

func _on_cancel_btn_pressed() -> void:
	restore_editor_mode()
	transition($Control/edit_meta_cont, "scale", Vector2.ZERO, .2, true)
	$Control/edit_meta_cont/save_btn.release_focus()

var playtest_playback_speed: float = 1.0
var playtest_start_pos: float = 0.0

func _on_playtest_pressed() -> void:
	if setting_up: return
	
	transition($Control/playtest_panel, "scale", Vector2.ONE, 0.2, false)
	
	$Control/playtest_panel/use_current.text = "Use Current Position (%s)" % General.format_time($Control/chart_controls/chart_scroll.value)
	
	$Control/playtest_panel/at_pos_slider.max_value = song_len

func _on_playtest_rate_value_changed(value: float) -> void:
	$Control/playtest_panel/playback_lbl.text = "Playback Speed: %s" % str(value)
	playtest_playback_speed = value

func _on_playtest_start_pos_value_changed(value: float) -> void:
	$Control/playtest_panel/at_pos_lbl.text = "Start from minute: %s" % General.format_time(value)
	playtest_start_pos = value

func _on_playtest_use_current_pressed() -> void:
	$Control/playtest_panel/at_pos_lbl.text = "Start from minute: %s" % General.format_time($Control/chart_controls/chart_scroll.value)
	$Control/playtest_panel/at_pos_slider.value = $Control/chart_controls/chart_scroll.value
	playtest_start_pos = $Control/chart_controls/chart_scroll.value

@onready var loading_text: RichTextLabel = $loading_text

func _on_playtest_test_pressed() -> void:
	if setting_up:
		return

	transition($Control/playtest_panel, "scale", Vector2.ZERO, 0.2, true)

	$AnimationPlayer.play("exit", 0.5, 1.3)

	SceneLoader.load_scene(General.MAIN)

	var progress_update := func():
		while SceneLoader.is_loading():
			loading_text.text = "Loading... (" + str(int(SceneLoader.get_progress() * 100.0)) + "%"
			await get_tree().process_frame
		loading_text.text = "Loading... 100%"

	progress_update.call()

	await $AnimationPlayer.animation_finished

	var test = SceneLoader.loaded_scene.instantiate()

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
	test.set("cover_loop_vid_path", cover_loop_vid_path)

	test.set("editor_saved", saved)

	print("Giving main a speed ", playtest_playback_speed)
	test.set("playback_speed", playtest_playback_speed)

	print("Giving main a start pos of ", $Control/chart_controls/chart_scroll.value)
	test.set("start_pos", playtest_start_pos - Beatz.BASE_REC_TIME / 1.5)

	get_tree().root.add_child(test)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = test

func _on_playtest_cancel_pressed() -> void:
	transition($Control/playtest_panel, "scale", Vector2.ZERO, 0.2, true)
	$Control/playtest_panel/cancel.release_focus()

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
	
	if selected_artist.to_upper() == "LINKIN PARK":
		$Control/song_details/song_artist.text = "[b]" + selected_artist.to_upper() + "[/b]"
		$Control/song_details/song_artist.position.y = 56.0
	else:
		$Control/song_details/song_artist.text = selected_artist
		#$Control/song_details/song_artist.position.y = 62.0
	
	$Control/song_details/album.text = $Control/create_map_panel/album_edit.text
	selected_album = $Control/create_map_panel/album_edit.text
	
	var cov: ImageTexture = $Control/create_map_panel/album_cover_edit.icon
	if cov:
		selected_cover = cov.get_image()
		
		$Control/song_details/sha/cover_spin.texture = cov
		
		$Control/song_details/sha.show()
	else:
		selected_cover = preload("res://Resources/misc/noCover.png").get_image()
	
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
	
	DisplayServer.window_set_title("Editing %s - %s | Beatz! X" % [selected_title, selected_artist])
	
	transition($Control/create_map_panel, "scale", Vector2.ZERO, .2, true)
	
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
	
	if not toggled_on or not song_path:
		return
	
	# Make sure it's an MP3
	if song_path.get_extension().to_lower() != "mp3":
		$Control/create_map_panel/metadata_use_check.button_pressed = false
		$Control/create_map_panel/metadata_use_check.text = "File is not an mp3."
		$Control/create_map_panel/metadata_use_check.release_focus()
		return
	
	# Parse ID3 from file
	var metaRead := MP3ID3Tag.new()
	var loaded_ok := metaRead.load_file(song_path)
	if not loaded_ok:
		print("Failed to load ID3 tags for ", song_path)
		return
	
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
	
	# Cover (first attached picture)
	var response: Array = metaRead.getAttachedPictureAndMime(0)
	if not response.is_empty() and response[0]:
		var tex: ImageTexture
		if response[0] is Image: tex = ImageTexture.create_from_image(response[0])
		album_cover_mime = response[1]
		if tex:
			$Control/create_map_panel/album_cover_edit.icon = tex
			$Control/create_map_panel/cover_img_details.text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + "Attached Album Cover " + response[1] + "\n" + General.format_file_size(response[0].get_data_size())
	else:
		$Control/create_map_panel/album_cover_edit.icon = null
		$Control/create_map_panel/cover_img_details.text = "No Cover Found"
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
var album_cover_mime: String

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

func _on_remove_album_pressed():
	album_cover_path = ""
	
	$Control/edit_meta_cont/album_cover_edit.icon = null
	$Control/create_map_panel/album_cover_edit.icon = null
	$Control/edit_meta_cont/cover_img_details.text = ""
	$Control/create_map_panel/cover_img_details.text = ""

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
		if OS.get_name() == "Windows":
			folder_path = "user://Custom/" + base_title + "/"
			if only_file: save_path = base_filename + ".beatz"
			else: save_path = folder_path + base_filename + ".beatz"
		elif OS.get_name() == "Android":
			folder_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/" + base_title + "/"
			if only_file: save_path = base_filename + ".beatz"
			else: save_path = folder_path + base_filename + ".beatz"
	else: save_path = selected_beatz_path
	
	# Song (1), Song (2), ...
	if not overwrite:
		var i := 0
		@warning_ignore("unused_variable")
		var copy_folder := base_title + "/"

		while true:
			var test_name: String
			if i == 0:
				test_name = base_title
			else:
				test_name = "%s (%d)" % [base_title, i]

			var test_path: String

			if OS.get_name() == "Windows":
				test_path = "user://Custom/" + test_name + "/"
			elif OS.get_name() == "Android":
				test_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/" + test_name + "/"
			else:
				test_path = "user://Custom/" + test_name + "/"

			if not DirAccess.dir_exists_absolute(test_path):
				folder_path = test_path
				copy_folder = test_name + "/"
				break

			i += 1

		if only_file:
			save_path = base_filename + ".beatz"
		else:
			save_path = folder_path + base_filename + ".beatz"
	
	return save_path

func _on_save_pressed() -> void:
	var save_path := _get_save_path()
	$Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(save_path)
	
	save_editor_mode()

	transition($Control/save_to_list, "scale", Vector2.ONE, .2, false)
	$Control/chart_controls/save.release_focus()

func _on_save_to_list_pressed() -> void:
	$Control/save_to_list/save_to_list.release_focus()
	_start_encode_thread(notes, song_path)
	
	$Control/chart_controls/save.add_theme_color_override("font_color", Color.GRAY)
	
	$Control/chart_controls/saved_to_popup.text = "Saving..."
	$Control/chart_controls/saved_to_popup.size = Vector2(121.0, 40.0)
	$popups.stop()
	$popups.play("saved_popup")

func _on_save_copy_to_list_pressed() -> void:
	$Control/save_to_list/save_copy_to_list.release_focus()
	_start_encode_thread(notes, song_path, false)
	
	$Control/chart_controls/saved_to_popup.text = "Saving\ncopy..."
	$Control/chart_controls/saved_to_popup.size = Vector2(121.0, 40.0)
	$popups.stop()
	$popups.play("saved_popup")

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

	_start_encode_thread(notes, song_path, true, true, save_path)

var _encode_thread: Thread

func _start_encode_thread(decoded_notes, current_song_path: String, overwrite: bool = true, share_mode: bool = false, share_save_path: String = "") -> void:
	if _encode_thread and _encode_thread.is_started():
		print("Encode already running")
		return
	
	_encode_thread = Thread.new()
	_encode_thread.start(Callable(self, "_encode_beatz_file_threaded").bind(
		decoded_notes,
		current_song_path,
		overwrite,
		share_mode,
		share_save_path
	))

func _encode_beatz_file_threaded(decoded_notes, current_song_path: String, overwrite: bool, share_mode: bool, share_save_path: String) -> void:
	_encode_beatz_file(decoded_notes, current_song_path, overwrite, share_mode, share_save_path)
	
	call_deferred("_on_encode_finished")

func _on_encode_finished():
	if _encode_thread:
		_encode_thread.wait_to_finish()
		_encode_thread = null

func _encode_beatz_file(decoded_notes, current_song_path: String, overwrite: bool = true, share_mode: bool = false, share_save_path: String = "") -> void:
	_thread_report("progress", 0)
	# Make sure we have notes
	if decoded_notes.is_empty():
		_thread_report("status_text", "No custom notes found. Record some!")
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
	content += "BPM: %f.3\\" % selected_bpm
	content += "noteSpeed: %d\\" % 5
	content += "noteSpawnY: %d\\" % 360
	content += "Difficulty: %s\\" % selected_difficulty
	content += "StartWait: %f.2\\" % start_wait
	content += "PrevStart: 0.0\\PrevEnd: 99999.0\\"
	content += "BeatOffset: %f.4\\" % local_beat_offset
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
			"background": background_img_path.get_file(),
			"video": background_vid_path.get_file(),
			"cover_loop": cover_loop_vid_path.get_file(),
			"difficulty_texture": General._sanitize(selected_difficulty) + ".png"
		}
	}
	
	_thread_report("progress", 10)
	
	# ----- SHARE MODE (no saving to disk) -----
	if share_mode:
		_thread_report("status_text", "Sharing...")
		
		var zip_path = share_save_path
		var zipper := ZIPPacker.new()
		if zipper.open(zip_path) != OK:
			push_error("Could not create zip: %s" % zip_path)
			_thread_report("error", "Could not create zip at %s" % zip_path)
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
				
				if ext == "":
					if album_cover_mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
						buffer = img.save_jpg_to_buffer(1.0)
					elif album_cover_mime == "image/png":
						buffer = img.save_png_to_buffer()
					else: # save as png if mime from attached cover is not recognized
						buffer = img.save_png_to_buffer()

				
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
		
		# Add cover loop video if one is set
		if cover_loop_vid_path != "" and FileAccess.file_exists(cover_loop_vid_path):
			var video_file_name := cover_loop_vid_path.get_file()
			info_dict["info"]["cover_loop"] = video_file_name

			var video_bytes := FileAccess.get_file_as_bytes(cover_loop_vid_path)
			if not video_bytes.is_empty():
				print("Adding cover loop video to .bx:", video_file_name)
				zipper.start_file(video_file_name)
				zipper.write_file(video_bytes)
				zipper.close_file()
			else:
				push_warning("Video file could not be read or is empty: %s" % cover_loop_vid_path)
		else:
			print("No cover loop video set or file missing skipping video")
		
		
		zipper.close()

		# Rename zip to .bx
		if not zip_path.ends_with(".bx"):
			var final_path = zip_path.get_basename() + ".bx"
			DirAccess.rename_absolute(zip_path, final_path)
			print("Shared chart packaged to %s" % final_path)
		else:
			print("Shared chart packaged to %s" % zip_path)
		
		_thread_report("status_text", "Shared succesfully!")
		_thread_report("done", true)
		return
	
	# Build base save path and folder
	var save_path := _get_save_path(overwrite)
	var folder_path := save_path.get_base_dir()
	
	var already_exists := FileAccess.file_exists(save_path)

	# Make sure folder exists
	DirAccess.make_dir_recursive_absolute(folder_path)
	
	# Save the .beatz file
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("Notes exported to %s successfully." % save_path)
		saved = true
		_thread_report("save_text", "Saved")
		_thread_report("song_path", "Path: " + ProjectSettings.globalize_path(folder_path).path_join(song_path.get_file()))
		
		_thread_report("progress", 20)
		
		_thread_report("tooltip", "Open " + ProjectSettings.globalize_path(selected_beatz_path.get_base_dir()) + " in your explorer.")
	else:
		push_error("Failed to save file: %s, due to %s" % [save_path, error_string(FileAccess.get_open_error())] )
		_thread_report("error", "Failed to save.")
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
				_thread_report("progress", 30)
			elif "data" in selected_stream: 
				audio_file.store_buffer(selected_stream.data)
				_thread_report("progress", 30)
				audio_file.close()
			print("Saved audio to %s" % audio_save_path)

	# Save cover image
	if selected_cover and selected_cover is Image:
		var img = selected_cover
		var ext = album_cover_path.get_extension()
		
		if ext == "":
			if album_cover_mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
				ext = "jpg"
			elif album_cover_mime == "image/png":
				ext = "png"
			else: # save as png if mime from attached cover is not recognized
				ext = "png"
		
		if img:
			var cover_save_path: String = folder_path + "/" + General._sanitize(selected_album) + "." + ext
			General.save_image_with_correct_extension(img, cover_save_path)
			_thread_report("progress", 40)
			print("Saved cover image to %s" % cover_save_path)
	
	# Save background image
	if selected_background and selected_background is Image:
		var img = selected_background
		var bg_save_path := folder_path + "/" + background_img_path.get_file()
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
		
		_thread_report("progress", 50)
	
	
	# Save difficulty texture
	if selected_diff_texture and selected_diff_texture is Texture2D:
		var img = selected_diff_texture.get_image()
		var ext = diff_texture_path.get_extension()
		var diff_tex_save_path: String = folder_path + "/" + General._sanitize(selected_difficulty) + "." + ext
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
		
		_thread_report("progress", 60)
	
	
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
	
	_thread_report("progress", 70)
	
	# Save cover loop background if one is set
	if cover_loop_vid_path != "" and FileAccess.file_exists(cover_loop_vid_path):
		print("Copying cover loop video to chart folder ", cover_loop_vid_path)
		var video_file_name := cover_loop_vid_path.get_file()
		var video_save_path := folder_path.path_join(video_file_name)
		
		# Copy video file into the chart folder using OS.execute wrapper
		General.copy_video(cover_loop_vid_path, video_save_path)
		
		# Store the filename in info.json
		info_dict["info"]["cover_loop"] = video_file_name
		print("Copied and saved cover loop video to %s" % video_save_path)
	else:
		print("No cover loop video set or file missing")
	
	_thread_report("progress", 80)
	
	var info_save_path := folder_path + "/info.json"
	var info_file := FileAccess.open(info_save_path, FileAccess.WRITE)
	if info_file:
		info_file.store_string(JSON.stringify(info_dict, "\t"))
		info_file.close()
		print("Saved info.json to %s" % info_save_path)
		
		var song_id := "SONGID " + selected_title + " " + str(Time.get_unix_time_from_system(), "_", randi())
		var id_file := FileAccess.open(folder_path.path_join(".songid"), FileAccess.WRITE)
		id_file.store_string(song_id)
		id_file.close()

		General.save_or_replace_song_id(song_id)
		print("Made unique ID: ", song_id)
		
		var text = "%s | %s, by %s | %d\n\nChart: %s | \"%s\" by %s | Custom" % [
			selected_album,
			selected_title,
			selected_artist,
			selected_year,
			selected_difficulty.to_pascal_case(),
			selected_chart_name,
			selected_charter
		]
		
		var ext = album_cover_path.get_extension()
		if ext == "":
			if album_cover_mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
				ext = "jpg"
			elif album_cover_mime == "image/png":
				ext = "png"
			else: # save as png if mime from attached cover is not recognized
				ext = "png"
		
		var list_entry: Dictionary = {
			"text": text,
			"disabled": false,
			"metadata": {
				"beatz_path": ProjectSettings.globalize_path(save_path),
				"id": song_id,
				"song_name": selected_title if selected_title != null and selected_title != "" else "",
				"album": selected_album if selected_album != null and selected_album != "" else "",
				"artist": selected_artist if selected_artist != null and selected_artist != "" else "",
				"year": selected_year if selected_year != null else 1980,
				"diff_texture": selected_diff_texture,
				"diff_texture_path": diff_texture_path if diff_texture_path != null and diff_texture_path != "" else "",
				"bpm": selected_bpm if selected_bpm != null else 120.0,
				"charter": selected_charter if selected_charter != null and selected_charter != "" else "",
				"difficulty": selected_difficulty if selected_difficulty != null and selected_difficulty != "" else "",
				"speed": note_speed,
				"cover_path": ProjectSettings.globalize_path(folder_path + "/" + General._sanitize(selected_album) + "." + ext),
				"stream": ProjectSettings.globalize_path(folder_path + "/" + General._sanitize(song_name)),
				"date_modified": Time.get_unix_time_from_system(),
				"local_beat_offset": local_beat_offset if local_beat_offset != null else 0.0,
				"selected_background": selected_background,
				"background_vid": background_vid_path if background_vid_path != null and background_vid_path != "" else "",
				"cover_loop": cover_loop_vid_path if cover_loop_vid_path != null and cover_loop_vid_path != "" else ""
			}
		}
		
		selected_beatz_path = ProjectSettings.globalize_path(save_path)
		current_song_path = folder_path + "/" + General._sanitize(song_name)
		
		if album_cover_path: album_cover_path = folder_path + "/" + General._sanitize(selected_album) + "." + ext
		
		if diff_texture_path: diff_texture_path = folder_path + "/" + General._sanitize(selected_difficulty) + "." + diff_texture_path.get_extension()
		
		if background_img_path: background_img_path = folder_path + "/" + General._sanitize(background_img_path.get_file())
		if background_vid_path: background_vid_path = folder_path.path_join(background_vid_path.get_file())
		if cover_loop_vid_path: cover_loop_vid_path = folder_path.path_join(cover_loop_vid_path.get_file())
		
		if (
			not (overwrite and already_exists)
			and Settings.game.keep_list_in_ram
		):
			print("Adding to list as")
			print(JSON.stringify(list_entry, "\t", false))

			var inserted := false
			var new_title := selected_title.to_lower()

			var keys := Beatz.LIST.keys()
			keys.sort()

			for key in keys:
				var existing = Beatz.LIST[key]

				if not existing.has("metadata"):
					continue

				var existing_title := str(
					existing["metadata"].get("song_name", "")
				).to_lower()

				if new_title < existing_title:
					var rebuilt := {}
					var inserted_index := false

					for rebuild_key in keys:
						if rebuild_key == key and not inserted_index:
							rebuilt[rebuilt.size() + 1] = list_entry
							inserted_index = true

						rebuilt[rebuilt.size() + 1] = Beatz.LIST[rebuild_key]

					Beatz.LIST = rebuilt
					inserted = true
					break

			if not inserted:
				Beatz.LIST[Beatz.LIST.size() + 1] = list_entry
		
		General.delete_folder_recursive("user://Temp/Covers")
		
		_thread_report("done", true)
		_thread_report("status_text", "Saved succesfully!")

var _encode_result := {}

func _thread_report(key: String, value):
	_encode_result[key] = value
	call_deferred("_apply_encode_update", key, value)


func _apply_encode_update(key: String, value):
	var tb = null
	if OS.get_name() == "Windows" and Engine.has_singleton("TBProgress"):
		tb = Engine.get_singleton("TBProgress")
	
	match key:
		"progress":
			if tb: tb.set_progress(value, 90)
			$Control/chart_controls/save.text = str(value) + "%"
			
			$Control/chart_controls/exit.disabled = true
			$Control/exit_warn/exit.disabled = true
			
			$Control/save_to_list/save_to_list.disabled = true
			$Control/save_to_list/save_copy_to_list.disabled = true
			$Control/save_to_list/share_to_bx.disabled = true
			
		"status_text":
			$Control/save_to_list/saving_to_lbl.text = value
		
		"save_text":
			$Control/chart_controls/save.text = value
		
		"song_path":
			$Control/song_details/song_path.text = value
		
		"tooltip":
			$Control/edit_meta_cont/explorer_open_btn.tooltip_text = value
		
		"error":
			if tb: tb.set_error()
			$Control/save_to_list/saving_to_lbl.text = value
			
			set_save_warn()
			
			$Control/chart_controls/saved_to_popup.text = "Error!"
			$Control/chart_controls/saved_to_popup.size = Vector2(121.0, 40.0)
			$popups.stop()
			$popups.play("saved_popup")
			
			$Control/chart_controls/exit.disabled = false
			$Control/exit_warn/exit.disabled = false
			
			$Control/save_to_list/save_to_list.disabled = false
			$Control/save_to_list/save_copy_to_list.disabled = false
			$Control/save_to_list/share_to_bx.disabled = false
		
		"done":
			if tb: tb.clear()
			saved = true
			save.emit()
			$Control/chart_controls/save.text = "Saved"
			
			if menu_open: $Control/chart_controls/save.add_theme_color_override("font_color", Color.GREEN)
			else:  $Control/chart_controls/save.add_theme_color_override("font_color", Color.WHITE)
			
			$Control/chart_controls/saved_to_popup.text = "Saved!"
			$Control/chart_controls/saved_to_popup.size = Vector2(121.0, 40.0)
			$popups.stop()
			$popups.play("saved_popup")
			
			$Control/chart_controls/exit.disabled = false
			$Control/exit_warn/exit.disabled = false
			
			$Control/save_to_list/save_to_list.disabled = false
			$Control/save_to_list/save_copy_to_list.disabled = false
			$Control/save_to_list/share_to_bx.disabled = false


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
	
	if preview_note and is_instance_valid(preview_note):
		preview_note.hide()
	
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
	
	$Control/tools/rm_align_info.text = "No notes removed/aligned."
	
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
	
	set_save_warn()

func _on_beat_offset_text_submitted(new_text: String) -> void:
	var text = General._num_eval(new_text)
	
	var value = float(text)
	
	local_beat_offset = value
	_update_visible_beatlines()
	$Control/tools/beat_offset.text = ""
	$Control/tools/beat_offset_lbl.text = "Beatlines set off by " + str(value) + " ms."
	$Control/tools/beat_offset_value.text = "(Current offset: %s)" % [str(value)]
	
	set_save_warn()

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
	$Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(true))

func _on_save_copy_to_list_mouse_entered() -> void:
	$Control/save_to_list/saving_to_lbl.text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(false))

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
	$Control/VideoPlayback.self_modulate = Color(value, value, value)

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
		$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.set_video_path(background_vid_path)
		$Control/create_map_panel/bg_vid_edit/VideoPlayback.set_video_path(background_vid_path)
		print("After load")
		
		video_node.show()
		
		$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.show()
		$Control/create_map_panel/bg_vid_edit/VideoPlayback.show()
		
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
			@warning_ignore("integer_division")
			var minutes = int(duration_sec) / 60
			var seconds = int(duration_sec) % 60
			var duration_str = "%02d:%02d" % [minutes, seconds]

			# Seek middle frame for preview
			@warning_ignore("integer_division")
			var mid_frame = int(total_frames / 2)
			video_node.seek_frame(mid_frame)

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
	
	$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.close()
	$Control/create_map_panel/bg_vid_edit/VideoPlayback.close()
	
	$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.hide()
	$Control/create_map_panel/bg_vid_edit/VideoPlayback.hide()
	
	$Control/VideoPlayback.hide()
	
	$Control/edit_meta_cont/bg_vid_details.text = "No Background"
	$Control/edit_meta_cont/bg_vid_edit.icon = null
	$Control/create_map_panel/bg_vid_details.text = "No Background"
	$Control/create_map_panel/bg_vid_edit.icon = null

func _on_settings_editor_bg_vids_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$Control/VideoPlayback.process_mode = Node.PROCESS_MODE_ALWAYS
		$Control/VideoPlayback.show()
		
		$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.process_mode = Node.PROCESS_MODE_ALWAYS
		$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.show()
		
		if background_vid_path:
			print("Setting bg vid as ", background_vid_path)
			_on_bg_vid_file_selected(background_vid_path)
	else:
		print("Closing bg vid ", background_vid_path)
		$Control/VideoPlayback.close()
		$Control/VideoPlayback.process_mode = Node.PROCESS_MODE_DISABLED
		$Control/VideoPlayback.hide()
		
		$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.close()
		$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.process_mode = Node.PROCESS_MODE_DISABLED
		$Control/edit_meta_cont/bg_vid_edit/VideoPlayback.hide()
		
		var disabled_text: String = "Your video has been saved but\nyou have disabled BG Videos\nin the editor.\n(%s)" % background_vid_path.get_file() if background_vid_path != "" else ""
		$Control/edit_meta_cont/bg_vid_details.text = disabled_text
		$Control/create_map_panel/bg_vid_details.text = disabled_text

func _on_settings_editor_cover_loops_toggled(toggled_on: bool) -> void:
	if toggled_on and cover_loop_vid_path:
		$Control/song_details/sha/cover_loop.process_mode = Node.PROCESS_MODE_ALWAYS
		$Control/song_details/sha/cover_loop.show()
		
		$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.process_mode = Node.PROCESS_MODE_ALWAYS
		$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.show()
		
		$Control/song_details/sha/cover_spin.hide()
		
		print("Setting cover loop as ", cover_loop_vid_path)
		_on_cover_loop_vid_file_selected(cover_loop_vid_path)
	else:
		print("Closing bg vid ", cover_loop_vid_path)
		$Control/song_details/sha/cover_loop.close()
		$Control/song_details/sha/cover_loop.process_mode = Node.PROCESS_MODE_DISABLED
		$Control/song_details/sha/cover_loop.hide()
		
		$Control/song_details/sha/cover_spin.show()
		
		$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.close()
		$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.process_mode = Node.PROCESS_MODE_DISABLED
		$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.hide()
		
		
		var disabled_text: String = "Your video has been saved but\nyou have disabled Cover Loop Videos\nin the editor.\n(%s)" % cover_loop_vid_path.get_file() if cover_loop_vid_path != "" else ""
		$Control/edit_meta_cont/cover_loop_details.text = disabled_text
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

var cover_loop_vid_path: String
var removed_cover_loop_vid: bool = false

func _on_cover_loop_edit_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Select a video file"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = General.VIDEO_FORMATS
	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.connect("file_selected", Callable(self, "_on_cover_loop_vid_file_selected"))
	add_child(dialog)
	dialog.popup_centered()

func _on_cover_loop_vid_file_selected(path: String) -> void:
	cover_loop_vid_path = ProjectSettings.globalize_path(path)
	Settings.game.last_editor_path = cover_loop_vid_path.get_base_dir()

	print("Selected cover loop video: ", cover_loop_vid_path)
	
	if Settings.misc.editor_cover_loops:
		var video_node: VideoPlayback = $Control/song_details/sha/cover_loop
		video_node.enable_audio = false
		
		video_node.close()
		
		print("loading vid")
		video_node.set_video_path(cover_loop_vid_path)
		$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.set_video_path(cover_loop_vid_path)
		$Control/create_map_panel/cover_loop_edit/VideoPlayback.set_video_path(cover_loop_vid_path)
		print("After load")
		
		video_node.show()
		$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.show()
		$Control/create_map_panel/cover_loop_edit/VideoPlayback.show()
		
		$Control/song_details/sha/cover_spin.hide()
		
		## Wait until the GoZen video finishes loading
		video_node.video_loaded.connect(func():
			print("Video loaded, generating preview...")
#
			var total_frames: int = video_node.get_video_frame_count()
			var fps: float  = video_node.get_video_framerate()
			var res = video_node.video.get_actual_resolution()
#
			# Calculate duration in seconds
			var duration_sec: float = 0.0
			if fps > 0:
				duration_sec = total_frames / fps
#
			# Format duration as mm:ss
			@warning_ignore("integer_division")
			var minutes = int(duration_sec) / 60
			var seconds = int(duration_sec) % 60
			var duration_str = "%02d:%02d" % [minutes, seconds]
#
			# Seek middle frame for preview
			@warning_ignore("integer_division")
			var mid_frame = int(total_frames / 2)
			video_node.seek_frame(mid_frame)

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
			
			$Control/edit_meta_cont/cover_loop_details.text = details_text
			$Control/create_map_panel/cover_loop_details.text = details_text
		)
	else:
		var disabled_text: String = "Your video has been saved but\nyou have disabled Cover Loop Videos\nin the editor.\n(%s)" % cover_loop_vid_path.get_file() if cover_loop_vid_path != "" else ""
		$Control/edit_meta_cont/cover_loop_details.text = disabled_text
		$Control/create_map_panel/cover_loop_details.text = disabled_text

func _on_clear_loop_pressed() -> void:
	$Control/edit_meta_cont/clear_loop.release_focus()
	$Control/create_map_panel/clear_loop.release_focus()
	
	removed_cover_loop_vid = true
	cover_loop_vid_path = ""
	$Control/song_details/sha/cover_loop.close()
	$Control/song_details/sha/cover_loop.hide()
	
	$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.close()
	$Control/create_map_panel/cover_loop_edit/VideoPlayback.close()
	
	$Control/edit_meta_cont/cover_loop_edit/VideoPlayback.hide()
	$Control/create_map_panel/cover_loop_edit/VideoPlayback.hide()
	
	$Control/song_details/sha/cover_spin.show()
	
	$Control/edit_meta_cont/cover_loop_details.text = "No Cover Loop Video"
	$Control/edit_meta_cont/cover_loop_edit.icon = null
	$Control/create_map_panel/cover_loop_details.text = "No Cover Loop Video"
	$Control/create_map_panel/cover_loop_edit.icon = null


func _on_fetch_cover_pressed() -> void:
	print("Fetch cover pressed")
	
	var exe_path = "res://covit.exe"
	print("Executable path:", exe_path)
	
	var temp_dir = "user://Temp/Covers"
	print("Temp directory:", temp_dir)
	
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))
	print("Temp directory ensured:", ProjectSettings.globalize_path(temp_dir))
	
	var args = [
		"--address", "https://covers.musichoarders.xyz/",
		"--input", song_path,
		"--query-sources", "applemusic",
		"--primary-output", ProjectSettings.globalize_path(temp_dir + "/cover"),
		"--secondary-output", ProjectSettings.globalize_path(temp_dir + "/cover.mp4"),
		"--primary-overwrite",
		"--secondary-overwrite",
		"--remote-agent", "BeatzX 1.6.0",
		"--remote-text", "Beatz X uses covers.musichoarders.xyz to fetch artwork."
	]
	
	print("Arguments:", args)
	
	var pid = OS.create_process(ProjectSettings.globalize_path(exe_path), args)
	print("Process started with PID:", pid)
	
	await _wait_for_process(pid)
	print("Process finished")
	
	await get_tree().create_timer(2.0).timeout
	_load_temp_cover(temp_dir)


func _wait_for_process(pid: int) -> void:
	print("Waiting for process:", pid)
	
	while OS.is_process_running(pid):
		await get_tree().process_frame
	
	print("Process is no longer running:", pid)


func _load_temp_cover(temp_dir: String) -> void:
	print("Loading temp cover from:", temp_dir)
	
	var jpg_path = temp_dir + "/cover.jpg"
	var png_path = temp_dir + "/cover.png"
	var mp4_path = temp_dir + "/cover.mp4"
	
	print("Checking JPG path:", jpg_path)
	print("Checking PNG path:", png_path)
	print("Checking MP4 path:", mp4_path)
	
	var image_path := ""
	
	if FileAccess.file_exists(jpg_path):
		print("JPG cover found")
		image_path = jpg_path
	elif FileAccess.file_exists(png_path):
		print("PNG cover found")
		image_path = png_path
	else:
		print("No JPG or PNG cover found")
	
	if image_path != "":
		var img = Image.new()
		var err = img.load(image_path)
		print("Image load result:", err)
		
		var tex = ImageTexture.create_from_image(img)
		print("Texture created from image")
		
		if err == OK:
			$Control/edit_meta_cont/album_cover_edit.icon = tex
			$Control/create_map_panel/album_cover_edit.icon = tex
			var text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + image_path.get_file() + "\n" + General.format_file_size(FileAccess.get_size(image_path))
			$Control/edit_meta_cont/cover_img_details.text = text
			$Control/create_map_panel/cover_img_details.text = text
		print("Assigned texture to album_cover_edit")
		
		var remove_err = DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
		print("Removed image file, result:", remove_err)
	
	if FileAccess.file_exists(mp4_path):
		print("MP4 cover found")
		
		cover_loop_vid_path = ProjectSettings.globalize_path(mp4_path)
		
		print("Selected cover loop video: ", mp4_path)
	
		if Settings.misc.editor_cover_loops:
			var video_node: VideoPlayback = $Control/song_details/sha/cover_loop
			video_node.enable_audio = false
			
			video_node.close()
			
			print("loading vid")
			video_node.set_video_path(mp4_path)
			print("After load")
			
			video_node.show()
			
			## Wait until the GoZen video finishes loading
			video_node.video_loaded.connect(func():
				print("Video loaded, generating preview...")
	#
				var total_frames: int = video_node.get_video_frame_count()
				var fps: float  = video_node.get_video_framerate()
				var res = video_node.video.get_actual_resolution()
	#
				# Calculate duration in seconds
				var duration_sec: float = 0.0
				if fps > 0:
					duration_sec = total_frames / fps
	#
				# Format duration as mm:ss
				@warning_ignore("integer_division")
				var minutes = int(duration_sec) / 60
				var seconds = int(duration_sec) % 60
				var duration_str = "%02d:%02d" % [minutes, seconds]

				# Seek middle frame for preview
				@warning_ignore("integer_division")
				var mid_frame = int(total_frames / 2)
				video_node.seek_frame(mid_frame)
				await get_tree().process_frame

				# Capture current frame as preview image
				var tex = video_node.video_texture.get_texture()

				# Apply to icon
				$Control/edit_meta_cont/cover_loop_edit.icon = tex
				$Control/create_map_panel/cover_loop_edit.icon = tex

				# File size
				var file_size := FileAccess.get_size(mp4_path)
				var file_size_str := General.format_file_size(file_size)

				# Combine all details
				var details_text = (
					str(res.x) + "x" + str(res.y) + "\n" +
					str(round(fps)) + " FPS\n" +
					"Length: " + duration_str + "\n" +
					file_size_str + "\n" +
					mp4_path.get_file()
				)
				
				$Control/edit_meta_cont/cover_loop_details.text = details_text
				$Control/create_map_panel/cover_loop_details.text = details_text
			)
		else:
			var disabled_text: String = "Your Cover Loop Video has been saved but\nyou have disabled Cover Loop Videos\nin the editor.\n(%s)" % cover_loop_vid_path.get_file() if cover_loop_vid_path != "" else ""
			$Control/edit_meta_cont/cover_loop_details.text = disabled_text
			$Control/create_map_panel/cover_loop_details.text = disabled_text
	else:
		print("No MP4 cover found")

func _on_search_bg_vid_pressed() -> void:
	var query = $Control/edit_meta_cont/artist_edit.text.replace(" ", "+") + "+" + $Control/edit_meta_cont/song_name_edit.text.replace(" ", "+")
	
	OS.shell_open("https://cobalt.meowing.de")
	await get_tree().process_frame
	OS.shell_open("https://youtube.com/results?search_query=" + query)

var songbpm_url: String = ""
var songbpm_url_exists: bool = true

var _request_cooldown := false
var _pending_request_url := ""

func clean_song_title(song: String) -> String:
	# remove anything in parentheses first
	song = song.replace(".", "")
	song = song.replace("(", "").replace(")", "")
	return song.strip_edges()

func _on_search_bpm_pressed() -> void:
	if songbpm_url_exists:
		OS.shell_open(songbpm_url)
	else:
		var query = (
			$Control/edit_meta_cont/song_name_edit.text + " " +
			$Control/edit_meta_cont/artist_edit.text + " bpm"
		).uri_encode()

		OS.shell_open("https://www.google.com/search?q=" + query)

func _on_search_bpm_mouse_entered() -> void:
	var artist: String = $Control/edit_meta_cont/artist_edit.text
	var song: String = clean_song_title($Control/edit_meta_cont/song_name_edit.text)

	var artist_slug: String = artist.replace(" ", "-").to_lower()
	var song_slug: String = song.replace(" ", "-").to_lower()

	if song.strip_edges().is_empty():
		songbpm_url = "https://songbpm.com/@%s" % artist_slug
	else:
		songbpm_url = "https://songbpm.com/@%s/%s" % [artist_slug, song_slug]

	if song.strip_edges().is_empty():
		$Control/edit_meta_cont/search_bpm.tooltip_text = 'This will open SongBPM.com and search for "%s" as "%s"' % [artist, songbpm_url]
	else:
		$Control/edit_meta_cont/search_bpm.tooltip_text = 'This will open SongBPM.com and search for "%s %s" as "%s"' % [artist, song, songbpm_url]

	# debounce logic
	_pending_request_url = songbpm_url

	if _request_cooldown:
		return

	_request_cooldown = true
	$HTTPRequest.cancel_request()
	$HTTPRequest.request(songbpm_url, [], HTTPClient.METHOD_HEAD)

	await get_tree().create_timer(0.75).timeout
	_request_cooldown = false

	# if user hovered again during cooldown, re-request latest URL once
	if _pending_request_url != songbpm_url:
		_on_search_bpm_mouse_entered()

func _on_search_bpm_focus_entered() -> void:
	_on_search_bpm_mouse_entered()

func _on_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	print(response_code)

	songbpm_url_exists = (
		result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 400
	)

	if songbpm_url_exists:
		print("%s Exists" % songbpm_url)
	else:
		print("%s Not found" % songbpm_url)

var tool_thread: Thread
var tool_running: bool = false


func _tool_notify(text: String) -> void:
	if not Settings.misc.edit_tools_notify_modified_notes:
		return

	call_deferred("_tool_notify_deferred", text)


func _tool_notify_deferred(text: String) -> void:
	$Control/tools/rm_align_info.text = text


func _tool_finish(text: String, modified: bool) -> void:
	call_deferred("_tool_finish_deferred", text, modified)


func _tool_finish_deferred(text: String, modified: bool) -> void:
	$Control/tools/rm_align_info.text = text

	if modified:
		set_save_warn()

	tool_running = false

	if tool_thread:
		tool_thread.wait_to_finish()
	
	_setup_notes()


func _start_tool_thread(method: Callable) -> void:
	if tool_running:
		return

	tool_running = true

	if tool_thread:
		tool_thread.wait_to_finish()

	tool_thread = Thread.new()
	tool_thread.start(method)

func _on_align_dbl_notes_pressed() -> void:
	_start_tool_thread(_align_dbl_notes_thread)

func _on_align_hold_ends_pressed() -> void:
	_start_tool_thread(_align_hold_ends_thread)

func _on_rm_duplicate_notes_pressed() -> void:
	_start_tool_thread(_rm_duplicate_notes_thread)

func _align_dbl_notes_thread() -> void:
	var threshold: float = 35.0
	var aligned_count: int = 0

	notes.sort_custom(func(a, b):
		return a.timestamp < b.timestamp
	)

	var i: int = 0

	while i < notes.size():
		var group := [notes[i]]
		var base_time: float = notes[i].timestamp

		var j := i + 1

		while j < notes.size():
			if notes[j].timestamp - base_time <= threshold:
				group.append(notes[j])
				j += 1
			else:
				break

		var types: Dictionary = {}

		for note in group:
			types[note.type] = true

		if types.size() > 1:
			for note in group:
				if note.timestamp != base_time:
					_tool_notify(
						"Aligned %s at %s -> %s" % [
							note.type,
							General.format_time(note.timestamp),
							General.format_time(base_time)
						]
					)

					note.timestamp = base_time
					aligned_count += 1

		i = j

	_tool_finish(
		"Aligned %d notes" % aligned_count,
		aligned_count > 0
	)


func _align_hold_ends_thread() -> void:
	var threshold: float = 35.0
	var aligned_count: int = 0

	notes.sort_custom(func(a, b):
		var hold_a: float = a.get("hold", 0.0)
		var hold_b: float = b.get("hold", 0.0)

		return (a.timestamp + hold_a) < (b.timestamp + hold_b)
	)

	var i: int = 0

	while i < notes.size():
		var hold_i: float = notes[i].get("hold", 0.0)

		var group := [notes[i]]
		var base_end: float = notes[i].timestamp + hold_i

		var j := i + 1

		while j < notes.size():
			var hold_j: float = notes[j].get("hold", 0.0)
			var end_j: float = notes[j].timestamp + hold_j

			if end_j - base_end <= threshold:
				group.append(notes[j])
				j += 1
			else:
				break

		if group.size() > 1:
			for note in group:
				var hold_val: float = note.get("hold", 0.0)
				var current_end: float = note.timestamp + hold_val

				if current_end != base_end:
					_tool_notify(
						"Aligned hold end %s at %s" % [
							note.type,
							General.format_time(note.timestamp)
						]
					)

					note.hold = base_end - note.timestamp
					aligned_count += 1

		i = j

	_tool_finish(
		"Aligned %d hold ends" % aligned_count,
		aligned_count > 0
	)


func _rm_duplicate_notes_thread() -> void:
	
	var threshold: float = 35.0

	notes.sort_custom(func(a, b):
		return a.timestamp < b.timestamp
	)

	var to_remove: Array = []

	for i in range(notes.size()):
		var note_a = notes[i]

		for j in range(i + 1, notes.size()):
			var note_b = notes[j]

			if note_b.timestamp - note_a.timestamp > threshold:
				break

			if note_a.type == note_b.type:
				_tool_notify(
					"Removed duplicate %s at %s" % [
						note_b.type,
						General.format_time(note_b.timestamp)
					]
				)

				to_remove.append(note_b)

	var removed_count: int = to_remove.size()

	for note in to_remove:
		notes.erase(note)

	_tool_finish(
		"Removed %d duplicate notes" % removed_count,
		removed_count > 0
	)

func _on_settings_note_style_changed(_style: int) -> void:
	apply_note_style()

	for n in $notes.get_children():
		if not n.has_node("noteImg"):
			continue

		var sprite_node: Sprite2D = n.get_node("noteImg")

		if not sprite_node:
			continue

		var note_type := ""

		if n.has_method("get_type"):
			note_type = n.get_type()
		elif "type" in n:
			note_type = n.type

		var matching_data = null

		for action in note_data.keys():
			if note_data[action]["key"] == note_type:
				matching_data = note_data[action]
				break

		if matching_data == null:
			continue

		var idle_texture: String = matching_data["idle"]

		sprite_node.texture = load("res://Resources/Arrows/" + idle_texture)

		if Settings.misc.note_style == "circles":
			sprite_node.self_modulate = Settings.parse_any_color(
				Settings.circles.get(note_type, "ffffff")
			)
		else:
			sprite_node.self_modulate = Color.WHITE

func _on_settings_edit_show_hold_ends_toggled(toggled_on: bool) -> void:
	for n in $notes.get_children():
		var hold_end = n.get_node("note_hold_end")
		if hold_end and !hold_end.visible and toggled_on and n.hold_ms > 0: hold_end.show()
		elif hold_end and hold_end.visible and not toggled_on: hold_end.hide()

func _on_settings_note_offset_changed(new_offset: float) -> void:
	OFFSET = new_offset
	_on_reload_pressed()

func _on_save_and_quit_btn_pressed() -> void:
	_on_save_to_list_pressed()
	await save
	print("Closing after saving")
	transition($Control/close_warn, "scale", Vector2.ZERO, .2, true)
	get_tree().quit()

func _on_quit_btn_pressed() -> void:
	transition($Control/close_warn, "scale", Vector2.ZERO, .2, true)
	get_tree().quit()

func _on_cancel_quit_btn_pressed() -> void:
	transition($Control/close_warn, "scale", Vector2.ZERO, .2, true)
	restore_editor_mode()
	$Control/chart_controls/save.add_theme_color_override("font_color", Color.WHITE)

func _on_settings_show_error_notes_toggled(_toggled_on: bool) -> void:
	_setup_notes()

func _on_exit_to_menu_pressed() -> void:
	SceneLoader.load_scene("res://Scenes/main_menu.tscn")

	var progress_update := func():
		while SceneLoader.is_loading():
			loading_text.text = "Loading... (" + str(int(SceneLoader.get_progress() * 100.0)) + "%"
			await get_tree().process_frame
		loading_text.text = "Loading... 100%"

	progress_update.call()

	$AnimationPlayer.play("exit", 0.5)
	transition($Control/close_warn, "scale", Vector2.ZERO, .2, true)

	await $AnimationPlayer.animation_finished

	if SceneLoader.is_loading():
		await SceneLoader.scene_loaded

	var main = SceneLoader.loaded_scene.instantiate()

	get_tree().root.add_child(main)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = main

func _on_save_and_menu_pressed() -> void:
	_on_save_to_list_pressed()
	await save
	_on_exit_to_menu_pressed()

var type_map = [
	"Effect",
	"Upleft",
	"Downleft",
	"Left",
	"Down",
	"Up",
	"Right",
	"Downright",
	"Upright"
]

func get_note_by_id(id: String) -> Dictionary:
	for n in notes:
		if n.get("id", "") == id:
			return n
	return {}

func _on_singular_ctx_hold_edit_text_submitted(new_text: String) -> void:
	if ctx_note == null:
		return

	var before := get_note_by_id(ctx_note.note_id)

	var value := float(new_text)
	var idx = ctx_note.note_index

	if idx < 0 or idx >= notes.size():
		return

	notes[idx]["hold"] = max(value, 0.0)
	ctx_note.hold_ms = max(value, 0.0)

	_apply_note_changes()

	push_history({
		"mode": "hold",
		"before": [before.duplicate(true)],
		"after": [notes[idx].duplicate(true)],
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	hide_all_note_context_menus()
	$note_context/hold_edit.release_focus()

func _on_singular_ctx_timestamp_edit_text_submitted(new_text: String) -> void:
	if ctx_note == null:
		return

	var before := get_note_by_id(ctx_note.note_id)

	var value := float(new_text)
	var idx = ctx_note.note_index

	if idx < 0 or idx >= notes.size():
		return

	notes[idx]["timestamp"] = value
	ctx_note.timestamp = value

	_apply_note_changes()

	var after = notes[idx].duplicate(true)

	push_history({
		"mode": "move",
		"before": [before.duplicate(true)],
		"after": [after],
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	calculate_difficulty_threaded()
	hide_all_note_context_menus()
	$note_context/timestamp_edit.release_focus()


func _on_singular_ctx_type_drop_item_selected(index: int) -> void:
	if ctx_note == null:
		return

	var before := get_note_by_id(ctx_note.note_id)

	var idx = ctx_note.note_index
	if idx < 0 or idx >= notes.size():
		return

	notes[idx]["type"] = type_map[index]
	ctx_note.type = type_map[index]
	ctx_note.set_type(ctx_note.type)

	_apply_note_changes()

	var after = notes[idx].duplicate(true)

	push_history({
		"mode": "move",
		"before": [before.duplicate(true)],
		"after": [after],
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	calculate_difficulty_threaded()
	hide_all_note_context_menus()
	$note_context/type_drop.release_focus()


func _on_singular_ctx_delete_pressed() -> void:
	if ctx_note == null:
		return

	delete_notes([ctx_note])

	ctx_note = null
	ctx_note_index = -1

	_reindex_notes()

	$note_context/btns_cont/delete.release_focus()
	$note_context.hide()

func _on_singular_ctx_to_grid_pressed() -> void:
	$note_context/btns_cont/to_grid_cont/to_grid.release_focus()

	align_notes_to_grid([ctx_note])
	
	hide_all_note_context_menus()

func _on_singular_ctx_snap_pressed() -> void:
	var btn = $note_context/btns_cont/to_grid_cont/snap

	btn.release_focus()

	cycle_context_snap(btn)

func _reindex_notes():
	for i in range(notes.size()):
		var node = rendered_notes.get(i)
		if node:
			node.note_index = i

func _on_multiple_ctx_timestamp_edit_text_submitted(new_text: String) -> void:
	if ctx_multiple_notes.is_empty():
		return

	_sort_ctx_multiple_notes()

	var target_timestamp := float(new_text)
	var first_note = ctx_multiple_notes[0]
	var delta = target_timestamp - first_note.timestamp

	var before := []

	for n in ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for n in ctx_multiple_notes:
		n.timestamp += delta

		var y = (
			(n.timestamp + OFFSET + BASE_TIME)
			* note_speed / 10.0
		) * -1

		n.position.y = y

	var after := []

	for n in ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	_apply_multiple_note_changes()
	hide_all_note_context_menus()
	_setup_notes()
	$multiple_note_context/timestamp_edit.release_focus()


func _on_multiple_ctx_align_pressed() -> void:
	if ctx_multiple_notes.is_empty():
		return

	_sort_ctx_multiple_notes()

	var target_timestamp = ctx_multiple_notes[0].timestamp

	var before := []

	for n in ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for n in ctx_multiple_notes:
		n.timestamp = target_timestamp

		var y = (
			(n.timestamp + OFFSET + BASE_TIME)
			* note_speed / 10.0
		) * -1

		n.position.y = y

	var after := []

	for n in ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	_apply_multiple_note_changes()
	hide_all_note_context_menus()
	_setup_notes()
	$multiple_note_context/btns_cont/align.release_focus()


func _on_multiple_ctx_stream_pressed() -> void:
	if ctx_multiple_notes.size() < 3:
		return

	_sort_ctx_multiple_notes()

	var first = ctx_multiple_notes[0]
	var last = ctx_multiple_notes[-1]

	var start_time = first.timestamp
	var end_time = last.timestamp
	var count := ctx_multiple_notes.size()

	var spacing = (end_time - start_time) / float(count - 1)

	var before := []

	for n in ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for i in range(count):
		var n = ctx_multiple_notes[i]

		n.timestamp = start_time + (spacing * i)

		var y = (
			(n.timestamp + OFFSET + BASE_TIME)
			* note_speed / 10.0
		) * -1

		n.position.y = y

	var after := []

	for n in ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	_apply_multiple_note_changes()
	hide_all_note_context_menus()
	_setup_notes()
	$multiple_note_context/btns_cont/stream.release_focus()

func _sort_ctx_multiple_notes():
	ctx_multiple_notes.sort_custom(func(a, b):
		return a.timestamp < b.timestamp
	)

func _on_multiple_ctx_delete_pressed() -> void:
	$multiple_note_context/btns_cont/delete.release_focus()
	
	delete_notes(ctx_multiple_notes)

func delete_notes(targets: Array) -> void:
	if targets.is_empty():
		return

	var before := []
	var indices := []

	for n in targets:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

		indices.append(n.note_index)

	indices.sort()
	indices.reverse()

	for idx in indices:
		if idx >= 0 and idx < notes.size():
			notes.remove_at(idx)

		if rendered_notes.has(idx):
			var obj = rendered_notes[idx]
			if is_instance_valid(obj):
				obj.queue_free()
			rendered_notes.erase(idx)

	selected_notes.clear()
	ctx_multiple_notes.clear()

	_setup_notes()
	set_save_warn()
	calculate_difficulty_threaded()

	push_history({
		"mode": "multi_delete",
		"before": before,
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	hide_all_note_context_menus()

var context_snap_division := "1/4"

func cycle_context_snap(button: Button) -> void:
	var options = ["1/2", "1/4", "1/8", "1/16", "1/32", "1/64"]

	var current_index = options.find(context_snap_division)

	if current_index == -1:
		current_index = 0

	current_index = (current_index + 1) % options.size()

	context_snap_division = options[current_index]

	button.text = context_snap_division

func get_snap_interval_from_division(div: String) -> float:
	match div:
		"1/2":
			return doubles

		"1/4":
			return quads

		"1/8":
			return eights

		"1/16":
			return sixteenths

		"1/32":
			return thirtyseconds

		"1/64":
			return sixtyfourths

	return 0.0

func snap_timestamp_to_division(timestamp: float, div: String) -> float:
	var interval := get_snap_interval_from_division(div)

	if interval <= 0.0:
		return timestamp

	var snapped_value = snapped(timestamp, interval)

	return snapped_value

func align_notes_to_grid(target_notes: Array):
	var before := []

	for n in target_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for n in target_notes:
		if not is_instance_valid(n):
			continue

		var snapped_timestamp = snap_timestamp_to_division(
			n.timestamp,
			context_snap_division
		)

		# visual node
		n.timestamp = snapped_timestamp

		# actual chart data
		if n.note_index >= 0 and n.note_index < notes.size():
			notes[n.note_index]["timestamp"] = snapped_timestamp

		var new_y = (
			(snapped_timestamp + BASE_TIME - OFFSET)
			* note_speed
			/ zoom
		) * -1.0

		n.position.y = new_y

	var after := []

	for n in target_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	set_save_warn()
	calculate_difficulty_threaded()

func _on_multiple_ctx_to_grid_pressed() -> void:
	$multiple_note_context/btns_cont/to_grid_cont/to_grid.release_focus()

	align_notes_to_grid(selected_notes)
	hide_all_note_context_menus()

func _on_multiple_ctx_snap_pressed() -> void:
	$multiple_note_context/btns_cont/to_grid_cont/snap.release_focus()

	cycle_context_snap($multiple_note_context/btns_cont/to_grid_cont/snap)


func _on_settings_editor_diff_graph_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		for color in $Control/chart_controls/chart_scroll.get_children():
			color.queue_free()
	else:
		update_difficulty_graph()


func _on_settings_selection_box_quality_changed(toggled_on: bool) -> void:
	if toggled_on: selection_box = $selection_box_hq
	else: selection_box = $selection_box

var copied_notes: Array = []

var flip_note_map := {
	"Left": "Right",
	"Right": "Left",

	"Upleft": "Upright",
	"Upright": "Upleft",

	"Downleft": "Downright",
	"Downright": "Downleft",

	"Up": "Down",
	"Down": "Up",
	"Effect": "Effect"
}

func _on_multiple_ctx_copy_pressed() -> void:
	copy_selected_notes()

	hide_all_note_context_menus()

	$note_context/btns_cont/copycutpaste/copy.release_focus()


func _on_multiple_ctx_cut_pressed() -> void:
	cut_selected_notes()

	hide_all_note_context_menus()

	$multiple_note_context/btns_cont/copycutpaste/cut.release_focus()

func _on_multiple_ctx_mirror_pressed() -> void:
	if ctx_multiple_notes.is_empty():
		return

	var before := []

	for n in ctx_multiple_notes:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)

		if snap.is_empty():
			continue

		before.append(snap.duplicate(true))

	for n in ctx_multiple_notes:
		if not is_instance_valid(n):
			continue

		var idx = n.note_index

		if idx < 0 or idx >= notes.size():
			continue

		var old_type: String = notes[idx]["type"]

		if not flip_note_map.has(old_type):
			continue

		var new_type: String = flip_note_map[old_type]

		notes[idx]["type"] = new_type

		n.type = new_type
		n.set_type(new_type)

	var after := []

	for n in ctx_multiple_notes:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)

		if snap.is_empty():
			continue

		after.append(snap.duplicate(true))

	push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	_apply_multiple_note_changes()

	set_save_warn()
	calculate_difficulty_threaded()

	hide_all_note_context_menus()
	$multiple_note_context/btns_cont/mirror.release_focus()

func _on_singular_ctx_copy_pressed() -> void:
	copy_selected_notes()

	hide_all_note_context_menus()
	$note_context/btns_cont/copycutpaste/copy.release_focus()


func _on_singular_ctx_cut_pressed() -> void:
	cut_selected_notes()

	hide_all_note_context_menus()
	$note_context/btns_cont/copycutpaste/cut/cut.release_focus()

func _on_singular_ctx_flip_pressed() -> void:
	if ctx_note == null:
		return

	var idx = ctx_note.note_index

	if idx < 0 or idx >= notes.size():
		return

	var before = notes[idx].duplicate(true)

	var old_type: String = notes[idx]["type"]

	if not flip_note_map.has(old_type):
		return

	var new_type: String = flip_note_map[old_type]

	notes[idx]["type"] = new_type

	ctx_note.type = new_type
	ctx_note.set_type(new_type)

	var after = notes[idx].duplicate(true)

	push_history({
		"mode": "move",
		"before": [before],
		"after": [after],
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	_apply_note_changes()

	set_save_warn()
	calculate_difficulty_threaded()

	hide_all_note_context_menus()
	$note_context/btns_cont/flip.release_focus()





var no_ctx_place_hold := 0.0
var no_ctx_place_type := "Left"

func _on_no_ctx_hold_edit_text_changed(new_text: String) -> void:
	no_ctx_place_hold = max(float(new_text), 0.0)


func _on_no_ctx_type_drop_item_selected(index: int) -> void:
	if index < 0 or index >= type_map.size():
		return

	no_ctx_place_type = type_map[index]


func _on_no_ctx_place_pressed() -> void:
	var local_pos = $notes.to_local(ctx_menu_anchor_pos - Vector2(15, 15))

	var timestamp = (
		((local_pos.y * -1.0) * zoom / note_speed)
		- BASE_TIME
		- OFFSET * 2
	)

	var new_note := {
		"id": str(Time.get_ticks_usec()),
		"type": no_ctx_place_type,
		"timestamp": snappedf(timestamp, 0.01),
		"hold": no_ctx_place_hold
	}

	notes.append(new_note)

	push_history({
		"mode": "place",
		"note": new_note.duplicate(true),
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	hide_all_note_context_menus()

	_setup_notes()

	set_save_warn()
	calculate_difficulty_threaded()

	$no_note_context/place.release_focus()


func _on_no_ctx_paste_pressed() -> void:
	paste_copied_notes(true)

	$no_note_context/btns_cont/paste.release_focus()

func copy_selected_notes():
	if selected_notes.is_empty():
		return

	copied_notes.clear()

	for n in selected_notes:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)

		if snap.is_empty():
			continue

		copied_notes.append(snap.duplicate(true))


func cut_selected_notes():
	if selected_notes.is_empty():
		return

	copy_selected_notes()
	delete_notes(selected_notes)


func paste_copied_notes(use_context_menu_position := false):
	if copied_notes.is_empty():
		return

	var paste_pos: Vector2

	if use_context_menu_position:
		paste_pos = ctx_menu_anchor_pos - Vector2(15, 15)
	else:
		paste_pos = get_global_mouse_position()

	var local_pos = $notes.to_local(paste_pos)

	var target_timestamp = (
		((local_pos.y * -1.0) * zoom / note_speed)
		- BASE_TIME
		- OFFSET * 2
	)

	var pasted_notes := []

	var first_timestamp = copied_notes[0]["timestamp"]

	for note in copied_notes:
		first_timestamp = min(
			first_timestamp,
			note["timestamp"]
		)

	for note in copied_notes:
		var new_note = note.duplicate(true)

		var relative_offset = (
			note["timestamp"] - first_timestamp
		)

		new_note["id"] = General.generate_note_id()

		new_note["timestamp"] = snappedf(
			target_timestamp + relative_offset,
			0.01
		)

		notes.append(new_note)

		pasted_notes.append(
			new_note.duplicate(true)
		)

	push_history({
		"mode": "multi_place",
		"notes": pasted_notes,
		"scroll": $Control/chart_controls/chart_scroll.value
	})

	hide_all_note_context_menus()

	_setup_notes()

	set_save_warn()
	calculate_difficulty_threaded()

func _on_no_ctx_create_stream_pressed() -> void:
	pass # Replace with function body.


func _on_no_ctx_space_pressed() -> void:
	pass # Replace with function body.


func _on_no_ctx_place_jack_pressed() -> void:
	pass # Replace with function body.


func _on_no_ctx_jack_quantity_pressed() -> void:
	pass # Replace with function body.
