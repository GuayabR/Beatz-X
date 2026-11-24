extends Control

signal save

@onready var NoteContextSystem: Variant = $NoteContextSystem
@onready var ChartDisplaySystem: Variant = $ChartDisplaySystem
@onready var SaveSystem: Variant = $SaveSystem
@onready var MetadataSystem: Variant = $MetadataSystem
@onready var EditorRecordingSystem: Variant = $EditorRecordingSystem

var background_vid_path: String = ""
var cover_loop_vid_path: String = ""

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
	ChartDisplaySystem._setup_notes()

	set_save_warn()

	ChartDisplaySystem.calculate_difficulty_threaded()

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

		"record_section":
			notes.clear()
			for before_note in action["before"]:
				notes.append(before_note.duplicate(true))

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

		"record_section":
			notes.clear()
			for after_note in action["after"]:
				notes.append(after_note.duplicate(true))

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

	ChartDisplaySystem._setup_notes()

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
var selected_artists: Array[String] = []
var selected_artists_before_edit: Array[String] = []
var legacy_artist_needs_split_before_edit: bool = false
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
	selected_artist = ""
	selected_artists.clear()
	MetadataSystem.legacy_artist_needs_split = false
	$Control/create_map_panel/artist_edit.clear()
	MetadataSystem.refresh_all_artist_controls()
	await get_tree().process_frame
	transition($Control/create_map_panel, "scale", Vector2.ONE, .2, false)
	
	set_save_warn()
	
	DisplayServer.window_set_title("Creating new song... | Beatz! X")
	
	$Control/chart_controls/save.text = "Unsaved*"
	
	$Control/create_map_panel/cover_img_details.text = ""

func create_from_dropped_file(path):
	$Control/create_map_panel/metadata_use_check.button_pressed = true
	MetadataSystem._on_song_select_file_selected(true, [path], 0)
	
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
	_setup_editor_help_pages()
	
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
	
	menus = [$Control/edit_meta_cont, $Control/create_map_panel, $Control/save_to_list, $Control/exit_warn, $Control/note_array_panel, $Control/tools, $Control/help, $Control/playtest_panel, $Control/recording_panel]
	
	$Control/chart_details/note_speed.text = "Note speed: " + str(note_speed)
	
	$Control/bg.self_modulate = Color(Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness)
	$Control/VideoPlayback.self_modulate = Color(Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness, Settings.game.editor_bg_brightness)
	
	$note_backdrop.self_modulate = Color(0.0, 0.0, 0.0, Settings.misc.editor_notes_backdrop_opacity)
	
	$Control/edit_meta_cont/charter_edit.text = Settings.game.username
	$Control/create_map_panel/charter_edit.text = Settings.game.username
	$Control/chart_details/charter.text = Settings.game.username

	if not background_vid_path.is_empty():
		MetadataSystem.background_vid_path = background_vid_path
	if not cover_loop_vid_path.is_empty():
		MetadataSystem.cover_loop_vid_path = cover_loop_vid_path
	
	if new_beatzmap:
		await get_tree().process_frame
		create_beatzmap()
		return
	
	if not AchieveMan.is_unlocked("editing"): AchieveMan.unlock("editing")
	
	DisplayServer.window_set_title("Editing %s - %s | Beatz! X" % [selected_title, selected_artist])
	
	song_path = ProjectSettings.globalize_path(song_path)
	selected_beatz_path = ProjectSettings.globalize_path(selected_beatz_path)
	_load_selected_artists()
	
	$song.stream = selected_stream
	
	$Control/chart_details/bpm.text = "BPM: " + str(selected_bpm)
	$Control/chart_details/note_count.text = "Total notes: " + str(len(notes))
	
	$Control/song_details/song_title/Text.text = selected_title
	
	if selected_artist.to_upper() == "LINKIN PARK":
		$Control/song_details/song_artist/Text.text = "[b]" + selected_artist.to_upper() + "[/b]"
		$Control/song_details/song_artist.position.y = 56.0
	else:
		$Control/song_details/song_artist/Text.text = selected_artist
		#$Control/song_details/song_artist.position.y = 62.0
	
	$Control/song_details/album/Text.text = selected_album
	$Control/song_details/year.text = str(selected_year)
	
	$Control/chart_details/chart_name.text = "\"" + selected_chart_name + "\""
	$Control/chart_details/charter.text = selected_charter
	$Control/chart_details/diff.text = "Difficulty: " + selected_difficulty.to_pascal_case()
	if selected_diff_texture: $Control/chart_details/diff_tex.texture = selected_diff_texture
	else:
		var diff_img = Image.load_from_file(MetadataSystem.diff_texture_path)
		var diff_tex = ImageTexture.create_from_image(diff_img)
		$Control/chart_details/diff_tex.texture = diff_tex
		selected_diff_texture = diff_tex
		print("Created diff tex from path ", MetadataSystem.diff_texture_path)
	
	$Control/song_details/sha/cover_spin.texture = ImageTexture.create_from_image(selected_cover)
	
	if selected_background: 
		$Control/bg.texture = ImageTexture.create_from_image(selected_background)
	
	if MetadataSystem.background_vid_path:
		MetadataSystem.background_vid_path = ProjectSettings.globalize_path(MetadataSystem.background_vid_path)
		print("Setting bg vid as ", MetadataSystem.background_vid_path)
		MetadataSystem._on_bg_vid_file_selected(MetadataSystem.background_vid_path)
	
	if MetadataSystem.cover_loop_vid_path:
		MetadataSystem.cover_loop_vid_path = ProjectSettings.globalize_path(MetadataSystem.cover_loop_vid_path)
		print("Setting cover loop vid as ", MetadataSystem.cover_loop_vid_path)
		MetadataSystem._on_cover_loop_vid_file_selected(MetadataSystem.cover_loop_vid_path)
	
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
	
	$Control/song_details/song_path/Text.text = "Path: " + song_path
	$Control/song_details/song_title.refresh()
	$Control/song_details/song_artist.refresh()
	$Control/song_details/album.refresh()
	$Control/song_details/song_path.refresh()
	
	$Control/edit_meta_cont/explorer_open_btn.tooltip_text = "Open " + ProjectSettings.globalize_path(selected_beatz_path.get_base_dir()) + " in your explorer."
	
	if not saved:
		set_save_warn()
	
	print(selected_beatz_path)
	print(song_path)
	
	set_discord_rpc()
	
	apply_note_style()
	
	ChartDisplaySystem._setup_notes()
	
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
		
		NoteContextSystem.no_ctx_place_type = get_lane_type(pos - Vector2(15, 15))
		
		var idx = NoteContextSystem.type_map.find(NoteContextSystem.no_ctx_place_type)

		if idx != -1:
			$no_note_context/type_drop.select(idx)
		
		$no_note_context/place_details.text = "Of Type %s with Hold of %s ms" % [$no_note_context/type_drop.get_item_text(idx), $no_note_context/hold_edit.text]
		
		$no_note_context/btns_cont/paste.text = "Paste %s Notes" % NoteContextSystem.copied_notes.size()
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

		var type_index = NoteContextSystem.type_map.find(note.type)
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
	ChartDisplaySystem._setup_notes()

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
	ChartDisplaySystem._setup_notes()
	ChartDisplaySystem.calculate_difficulty_threaded()

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
	ChartDisplaySystem._update_visible_notes()
	ChartDisplaySystem._update_visible_beatlines()
	
	if ChartDisplaySystem.difficulty_calculating and ChartDisplaySystem.difficulty_thread and not ChartDisplaySystem.difficulty_thread.is_alive():
		ChartDisplaySystem.difficulty_result = ChartDisplaySystem.difficulty_thread.wait_to_finish()

		ChartDisplaySystem.update_difficulty_graph()
		ChartDisplaySystem.difficulty_calculating = false

		#print("finished calc", difficulty_result)

	# if notes changed while thread was running
	if ChartDisplaySystem.difficulty_dirty and not ChartDisplaySystem.difficulty_calculating:
		ChartDisplaySystem.calculate_difficulty_threaded()

	if ChartDisplaySystem.difficulty_result.is_empty():
		return

	$Control/chart_details/diff.text = "Difficulty: %s (%.2f)" % [
		selected_difficulty.to_pascal_case(),
		ChartDisplaySystem.difficulty_result["rating"]
	]

	$Control/chart_details/diff2.text = "Peak NPS: %.2f" % ChartDisplaySystem.difficulty_result["peak_nps"]

	$Control/chart_details/diff3.text = "Average NPS: %.2f" % ChartDisplaySystem.difficulty_result["average_nps"]
	
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
		if EditorRecordingSystem.recording:
			EditorRecordingSystem.toggle_pause()
			return
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
			
			preview_note.position.x = ChartDisplaySystem._get_note_x(type)
			
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
			if EditorRecordingSystem.range_preview_active:
				EditorRecordingSystem.refresh_note_range_visual(n)
	
	if not playing and editor_mode == "view":
		if dragging_selected_notes and dragged_note:
			var mouse_delta = (
				get_global_mouse_position() - drag_anchor_mouse
			)

			var lane_type = get_lane_type(
				get_viewport().get_mouse_position()
			)

			var target_x = ChartDisplaySystem._get_note_x(lane_type)

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
						if EditorRecordingSystem.range_preview_active:
							EditorRecordingSystem.refresh_note_range_visual(n)

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
			if menu.name == "recording_panel":
				EditorRecordingSystem.close_panel()
			else:
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
	if event.is_action_pressed("pause-back") and (
		not event is InputEventJoypadButton
		or (event as InputEventJoypadButton).button_index == JOY_BUTTON_B
	):
		if editor_mode == "settings": _on_back_pressed()
		close_panel_from_input()
	
	if Input.is_action_just_pressed("save_quit"):
		if editor_mode == "none":
			return
		SaveSystem._on_save_to_list_pressed()
		await save
		_on_exit_pressed()
		
	
	if Input.is_action_just_pressed("quit"):
		if editor_mode == "none":
			return
		_on_exit_warn_pressed()
	
	if Input.is_action_just_pressed("editor_save"):
		if editor_mode == "none":
			return
		SaveSystem._on_save_to_list_pressed()
	
	if Input.is_action_just_pressed("editor_save_copy"):
		if editor_mode == "none":
			return
		SaveSystem._on_save_copy_to_list_pressed()
	
	if Input.is_action_just_pressed("editor_share"):
		if editor_mode == "none":
			return
		SaveSystem._on_share_chart_pressed()
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
		NoteContextSystem.delete_notes(selected_notes)
	
	if Input.is_action_just_pressed("ui_copy"):
		NoteContextSystem.copy_selected_notes()
	
	if Input.is_action_just_pressed("ui_cut"):
		NoteContextSystem.cut_selected_notes()
	
	if Input.is_action_just_pressed("ui_paste"):
		NoteContextSystem.paste_copied_notes()
		
	
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
							if EditorRecordingSystem.range_preview_active:
								EditorRecordingSystem.refresh_note_range_visual(n)

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

						ChartDisplaySystem.calculate_difficulty_threaded()

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

				ChartDisplaySystem.calculate_difficulty_threaded()

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
	ChartDisplaySystem.calculate_difficulty_threaded()

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
	
	ChartDisplaySystem.calculate_difficulty_threaded()

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

func _on_chart_scroll_mouse_entered() -> void:
	$Control/chart_controls/scroll_time_hover.show()
	var t = create_tween()
	t.tween_property($Control/chart_controls/scroll_time_hover, "modulate", Color.WHITE, 0.15)

func _on_chart_scroll_mouse_exited() -> void:
	var t = create_tween()
	t.tween_property($Control/chart_controls/scroll_time_hover, "modulate", Color.TRANSPARENT, 0.15)

func _on_chart_scroll_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var chart_scroll: VSlider = $Control/chart_controls/chart_scroll
		var local_y: float = chart_scroll.get_local_mouse_position().y
		var height: float = max(chart_scroll.size.y, 1.0)
		var ratio: float = clamp(1.0 - (local_y / height), 0.0, 1.0)
		var hover_seconds: float = chart_scroll.min_value + (
			(chart_scroll.max_value - chart_scroll.min_value) * ratio
		)

		var total_milliseconds: int = int(round(clampf(hover_seconds, 0.0, song_len) * 1000.0))
		@warning_ignore("integer_division")
		var minutes: int = total_milliseconds / 60000
		@warning_ignore("integer_division")
		var seconds: int = (total_milliseconds % 60000) / 1000
		var milliseconds: int = total_milliseconds % 1000

		var hover_panel: Panel = $Control/chart_controls/scroll_time_hover
		hover_panel.get_node("time_lbl").text = "%d:%02d:%03d" % [minutes, seconds, milliseconds]

		hover_panel.position = Vector2(chart_scroll.position.x - 110.0, get_local_mouse_position().y - 550.0)

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
	if EditorRecordingSystem.recording:
		EditorRecordingSystem.toggle_pause()
		return
	
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



var highest_note_y := 0.0
var highest_timestamp: float = 0.0

var rendered_notes := {}



func _on_reload_pressed() -> void:
	for obj in $notes.get_children():
		if obj.name != "preview": obj.queue_free()
	
	ChartDisplaySystem._setup_notes()
	
	$waveform.regenerate()
	#$Control/chart_controls/waveform._draw_preview()
	
	$Control/editor_controls/reload.release_focus()

func _on_play_pressed() -> void:
	if EditorRecordingSystem.recording:
		EditorRecordingSystem.toggle_pause()
	elif playing:
		_pause()
	else:
		_play()
	
	$Control/chart_btns/btn_cont/play.release_focus()

func _on_song_finished() -> void:
	if EditorRecordingSystem.recording:
		EditorRecordingSystem._finish_recording()
	else:
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

func transition(panel: Object, property: String, to: Variant, time: float, close: bool, tween_playback_speed: bool = true): 
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
	if tween_playback_speed:
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
	var scene_request := SceneLoader.load_scene("res://Scenes/main_menu.tscn")
	_track_scene_loading(scene_request)

	$AnimationPlayer.play("exit", 0.5)
	transition($Control/exit_warn, "scale", Vector2.ZERO, .2, true)

	await $AnimationPlayer.animation_finished

	var packed_scene: PackedScene = await scene_request.wait()
	if packed_scene == null:
		return

	var main = packed_scene.instantiate()

	get_tree().root.add_child(main)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = main

func _load_selected_artists() -> void:
	var passed_artists := selected_artists.duplicate()
	selected_artists.clear()
	var has_artist_array := false
	var info_path := selected_beatz_path.get_base_dir().path_join("info.json")
	if FileAccess.file_exists(info_path):
		var info_json: Variant = JSON.parse_string(FileAccess.get_file_as_string(info_path))
		if typeof(info_json) == TYPE_DICTIONARY and typeof(info_json.get("info")) == TYPE_DICTIONARY:
			var info: Dictionary = info_json["info"]
			var artists_value: Variant = info.get("artists", null)
			if artists_value is Array and not artists_value.is_empty():
				selected_artists = General.artist_names_from_info(info)
				has_artist_array = not selected_artists.is_empty()

	if not has_artist_array and passed_artists.size() > 1:
		selected_artists = passed_artists
		has_artist_array = true

	MetadataSystem.legacy_artist_needs_split = false
	if not has_artist_array:
		var legacy_artist := str(selected_artist).strip_edges()
		if legacy_artist != "":
			selected_artists.append(legacy_artist)
		MetadataSystem.legacy_artist_needs_split = (
			selected_artists.is_empty()
			or legacy_artist.contains(",")
			or legacy_artist.contains("&")
			or legacy_artist.contains("/")
		)

	MetadataSystem.refresh_all_artist_controls()

func _on_cancel_exit_pressed() -> void:
	restore_editor_mode()
	transition($Control/exit_warn, "scale", Vector2.ZERO, .2, true)
	
	$Control/chart_controls/save.add_theme_color_override("font_color", Color.WHITE)
	
	$Control/chart_controls/exit.release_focus()

func _on_edit_meta_pressed() -> void:
	save_editor_mode()
	selected_artists_before_edit = selected_artists.duplicate()
	legacy_artist_needs_split_before_edit = MetadataSystem.legacy_artist_needs_split
	
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

	$Control/edit_meta_cont/artist_edit.clear()
	MetadataSystem.refresh_artist_added_label("edit_meta_cont")
	$Control/edit_meta_cont/album_edit.text = selected_album
	$Control/edit_meta_cont/year_edit.text = str(selected_year)
	$Control/edit_meta_cont/album_cover_edit.icon = ImageTexture.create_from_image(selected_cover)
	
	$Control/edit_meta_cont/bg_img_edit.icon = ImageTexture.create_from_image(selected_background)
	
	if selected_background: $Control/edit_meta_cont/bg_img_details.text = str(selected_background.get_width()) + "x" + str(selected_background.get_height()) + "\n" + selected_background_name + "\n" + General.format_file_size(selected_background.get_data_size())
	
	$Control/edit_meta_cont/bg_img_details.set_meta("background_name", selected_background_name)
	
	if selected_cover: $Control/edit_meta_cont/cover_img_details.text = str(selected_cover.get_width()) + "x" + str(selected_cover.get_height()) + "\n" + selected_album + "\n" + General.format_file_size(selected_cover.get_data_size())
	else: $Control/edit_meta_cont/cover_img_details.text = "No cover image."
	
	$Control/edit_meta_cont/metadata_use_check.set_pressed_no_signal(MetadataSystem.use_meta_check)
	
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

func _on_cancel_btn_pressed() -> void:
	restore_editor_mode()
	transition($Control/edit_meta_cont, "scale", Vector2.ZERO, .2, true)
	$Control/edit_meta_cont/save_btn.release_focus()
	selected_artists = selected_artists_before_edit.duplicate()
	MetadataSystem.legacy_artist_needs_split = legacy_artist_needs_split_before_edit
	MetadataSystem.refresh_all_artist_controls()

var playtest_playback_speed: float = 1.0
var playtest_start_pos: float = 0.0
const PLAYTEST_LEAD_IN_SECONDS: float = 4.0

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
@onready var loading_progress: ProgressBar = $loading_progress

func _track_scene_loading(request: Variant) -> void:
	loading_text.text = "Loading..."
	loading_progress.value = 0.0
	loading_progress.show()

	while not request.is_completed:
		loading_progress.value = request.progress * 100.0
		await get_tree().process_frame

	if request.scene != null:
		loading_progress.value = 100.0
	else:
		loading_text.text = "Loading failed."
		loading_progress.hide()

func _on_playtest_test_pressed() -> void:
	if setting_up:
		return

	transition($Control/playtest_panel, "scale", Vector2.ZERO, 0.2, true)

	$AnimationPlayer.play("exit", 0.5, 1.3)

	var scene_request := SceneLoader.load_scene(General.MAIN)
	_track_scene_loading(scene_request)

	await $AnimationPlayer.animation_finished

	var packed_scene: PackedScene = await scene_request.wait()
	if packed_scene == null:
		return
	var test = packed_scene.instantiate()

	test.set("chart_path", selected_beatz_path)
	test.set("song_path", song_path)
	test.set("song", selected_stream)
	test.set("song_title", selected_title)
	test.set("album", selected_album)
	test.set("artist", selected_artist)
	test.set("selected_artists", selected_artists.duplicate())
	test.set("year", selected_year)
	test.set("start_wait", start_wait)
	test.set("preview_start", preview_start)
	test.set("preview_end", preview_end)
	test.set("cover", selected_cover)
	test.set("customNotes", notes)
	test.set("difficulty", selected_difficulty)
	test.set("diff_texture_path", MetadataSystem.diff_texture_path)
	test.set("chart_name", selected_chart_name)
	test.set("charter", selected_charter)
	test.set("fade_in", fade_in)
	test.set("fade_out", fade_out)
	test.set("BPM", selected_bpm)
	test.set("local_beat_offset", local_beat_offset)
	test.set("selected_background", selected_background)
	test.set("selected_background_name", selected_background_name)
	test.set("colors", colors)
	test.set("background_vid_path", MetadataSystem.background_vid_path)
	test.set("cover_loop_vid_path", MetadataSystem.cover_loop_vid_path)

	test.set("editor_saved", saved)

	print("Giving main a speed ", playtest_playback_speed)
	test.set("playback_speed", playtest_playback_speed)

	var actual_start_pos: float = maxf(playtest_start_pos - PLAYTEST_LEAD_IN_SECONDS, 0.0)
	test.set("playtest_note_start_pos", playtest_start_pos)
	print("Giving main a start pos of ", actual_start_pos)
	test.set("start_pos", actual_start_pos)

	get_tree().root.add_child(test)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = test

func _on_playtest_cancel_pressed() -> void:
	transition($Control/playtest_panel, "scale", Vector2.ZERO, 0.2, true)

func _on_record_pressed() -> void:
	EditorRecordingSystem.open_panel()




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
	ChartDisplaySystem._update_visible_beatlines()
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


func _on_explorer_open_btn_pressed() -> void:
	General.explorer(ProjectSettings.globalize_path(selected_beatz_path.get_base_dir()))

func _setup_editor_help_pages() -> void:
	var rows: GridContainer = $Control/help/help_pages/Keybinds/keybind_rows
	for child in rows.get_children():
		child.queue_free()

	var keybind_pages: Array[Dictionary] = [
		{"action": "editor_save", "label": "Save", "resource": "UI_Save"},
		{"action": "editor_save_copy", "label": "Save Copy", "resource": "UI_EditorSaveCopy"},
		{"action": "editor_share", "label": "Share", "resource": "UI_EditorShare"},
		{"action": "editor_place", "label": "Place Notes", "resource": "UI_EditorPlace"},
		{"action": "editor_delete", "label": "Delete Notes", "resource": "UI_EditorDelete"},
		{"action": "editor_view", "label": "View Notes", "resource": "UI_EditorView"},
		{"action": "editor_playtest", "label": "Playtest", "resource": "UI_EditorPlaytest"},
		{"action": "record", "label": "Record", "resource": "UI_Record"},
		{"action": "quit", "label": "Quit (No Save)", "resource": "UI_Quit"},
		{"action": "save_quit", "label": "Save and Quit", "resource": "UI_SaveQuit"},
	]

	for entry in keybind_pages:
		var action_label: Label = Label.new()
		action_label.text = str(entry["label"])
		action_label.custom_minimum_size = Vector2(320.0, 45.0)
		action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		action_label.add_theme_font_size_override("font_size", 22)
		action_label.tooltip_text = str(entry["action"])
		rows.add_child(action_label)

		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(150.0, 45.0)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var resource_path: String = "res://Resources/KeybindResources/%s.tres" % entry["resource"]
		var icon_resource: Texture2D = load(resource_path) as Texture2D
		if icon_resource:
			icon_rect.texture = icon_resource
		else:
			push_error("Could not load keybind resource: %s" % resource_path)
		rows.add_child(icon_rect)

func _on_help_btn_pressed() -> void:
	save_editor_mode()
	$Control/editor_controls/help_btn.release_focus()
	$Control/help/help_pages.current_tab = 0
	transition($Control/help, "scale", Vector2.ONE, 0.2, false)

func _on_help_exit_pressed() -> void:
	restore_editor_mode()
	transition($Control/help, "scale", Vector2.ZERO, 0.2, true)

func _on_settings_editor_brightness_changed(value: float) -> void:
	$Control/bg.self_modulate = Color(value, value, value)
	$Control/VideoPlayback.self_modulate = Color(value, value, value)

func _on_settings_editor_note_backdrop_opacity_changed(opacity: float) -> void:
	$note_backdrop.self_modulate = Color(0.0, 0.0, 0.0, opacity)





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
	
	ChartDisplaySystem._setup_notes()


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
	SaveSystem._on_save_to_list_pressed()
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
	ChartDisplaySystem._setup_notes()

func _on_exit_to_menu_pressed() -> void:
	var scene_request := SceneLoader.load_scene("res://Scenes/main_menu.tscn")
	_track_scene_loading(scene_request)

	$AnimationPlayer.play("exit", 0.5)
	transition($Control/close_warn, "scale", Vector2.ZERO, .2, true)

	await $AnimationPlayer.animation_finished

	var packed_scene: PackedScene = await scene_request.wait()
	if packed_scene == null:
		return

	var main = packed_scene.instantiate()

	get_tree().root.add_child(main)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = main

func _on_save_and_menu_pressed() -> void:
	SaveSystem._on_save_to_list_pressed()
	await save
	_on_exit_to_menu_pressed()


func _on_edit_meta_artist_edit_text_submitted(new_text: String) -> void:
	pass # Replace with function body.


func _on_edit_meta_add_artist_pressed() -> void:
	pass # Replace with function body.
