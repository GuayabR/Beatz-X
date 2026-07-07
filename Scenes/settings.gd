extends Node

var listening: bool = false # If true, a keybind is being edited, so any other key actions should be ignored

const INPUTS: Dictionary[Variant, Variant] = {
	"left": 0,
	"down": 1,
	"up": 2,
	"right": 3,
	"pause": 4,
}

var settings: Dictionary[String, Variant] = {
	"game": {
		"username": "",
		"title": "",
		"clan": "",
		"profile_path": "",
		"banner_path": "",
		"mbl_btn_layout": 0, # 0 for 4 btn layout, 1 for 2 + 2 btn layout
		"master_vol": 100.0,
		"song_vol": 80.0,
		"menu_song_vol": 75.0,
		"sfx_vol": 40.0,
		"output_device": "Default",
		"input_device": "Default",
		"speed": 1.0,
		"note_speed": 10.0,
		"pause_audio_fx": true, # If true, audio will slow down on pause and speed up on unpause
		"pause_resume_time": 1.0, # Time in seconds to give the player after unpausing
		"theme": "Default",
		"menu_bg_brightness": 1.0,
		"bg_brightness": 1.0,
		"editor_bg_brightness": 0.75,
		"version": "-1.0",
		"show_vpopup": true,
		"last_editor_path": "",
		"joy_sens": 800.0,
		"brightness": 1.0,
		"contrast": 1.0,
		"gamma": 1.0,
		"colourblind_mode": 0,
		"colourblind_strength": 1.0,
		"load_all_covers": false, # if false, only the covers that are currently visible are actually loaded in ram, if a cover is now not visible it will be unloaded
		# if true, covers will be naturally loaded either until you scroll to the bottom of the list, or if you wait long enough
		"keep_list_in_ram": false, # if true, the list will always stay loaded (except covers), instead of always reloading it from your file system
		# if you create a new song, or import a new song, the new song entry will just be added onto the already loaded list.
		# list only gets recreated when the game starts or when you press the reload list button
		"max_threads_in_list": 2,
		"menu_song_dirs": [
			"user://Custom"
		],
	},
	"misc_settings": {
		"hq_background": true,
		"bg_parallax": true,
		"bg_matches_cover": true,
		"bg_effect": 1,
		"bg_fx_random_multi_min": 5,
		"bg_fx_random_multi_max": 15,
		"bg_multi_min": 5,
		"bg_multi_max": 15,
		"bg_tween_time_sec": 0.5,
		"bg_time_interval_sec": 1.0,
		"bg_parallax_speed": 1.0,
		"bg_videos": true,
		"editor_bg_videos": true,
		"cover_loops": true,
		"cover_loops_selected_song": true,
		"editor_cover_loops": true,
		"cover_loops_playing_bar": true,
		"editor_seek_vid_along_scroll": true,
		"editor_show_note_hold_ends": true,
		"editor_waveform_color": Color(1.0, 1.0, 1.0, 0.25),
		"show_error_notes": false,
		"editor_show_diff_graph": true,
		"hq_selection_box": true,
		"note_style": "dance", # dance / techno / para 
		"note_anims": true,
		"note_particle_fx": 1.0, # 0 none 1 splash 2 crash 3 splash and crash 4 orbit
		"hold_bar_keep_position": true,
		"hold_bar_no_end_fade": false,
		"hold_bar_solid": false,
		"hold_thresh_to_rm_edit": 25.0,
		"menu_bg_pulse": true,
		"bg_vid_pulse": true,
		"menu_bg_pulse_strength": 16.0,
		"bg_vid_pulse_strength": 8.0,
		"menu_bg_img_path": "",
		"show_fps": true,
		"show_frame_time": false,
		"show_ram": false,
		"show_more_ram": false,
		"show_draw_calls": false,
		"show_vram": false,
		"show_audio_latency": false,
		"show_mix_rate": false,
		"accurate_fps": false,
		"drc": true,
		"vis": true,
		"note_offset": 0.0,
		"advanced_fps": false,
		"fps": -1,
		"fps_main_menu": 120,
		"fps_main": 240,
		"fps_unfocused": 15,
		"resolution": [1920, 1080],
		"window_mode": "windowed",
		"borderless": false,
		"reduce_motion": false,
		"smooth_scrolls": true,
		"colour_bg_with_cover": true,
		"notes_backdrop_opacity": 0.35,
		"editor_notes_backdrop_opacity": 0.0,
		"eq_applies_to_menu_song": false,
		"selected_eq_preset": "Flat",
		"edit_tools_notify_modified_notes": true
	},
	"circle_notes": {
		"Upleft": Color(1.0, 0.0, 1.0, 1.0),
		"Downleft": Color(0.0, 0.0, 1.0, 1.0),
		"Left": Color(1.0, 0.0, 0.0, 1.0),
		"Down": Color(1.0, 1.0, 0.0, 1.0),
		"Up": Color(0.0, 1.0, 0.0, 1.0),
		"Right": Color(0.0, 1.0, 0.9, 1.0),
		"Downright": Color(0.627451, 0.1254902, 0.9411765, 1),
		"Upright": Color(1.0, 0.0, 0.0, 1.0),
		"pressed_uses_idle_colors": true,
		"UpleftPress": Color(1.0, 0.0, 1.0, 1.0),
		"DownleftPress": Color(0.0, 0.0, 1.0, 1.0),
		"LeftPress": Color(1.0, 0.0, 0.0, 1.0),
		"DownPress": Color(1.0, 1.0, 0.0, 1.0),
		"UpPress": Color(0.0, 1.0, 0.0, 1.0),
		"RightPress": Color(0.0, 1.0, 0.9, 1.0),
		"DownrightPress": Color(0.627451, 0.1254902, 0.9411765, 1),
		"UprightPress": Color(1.0, 0.0, 0.0, 1.0),
		"chart_notes_use_idle_colors": true,
		"UpleftChart": Color(1.0, 0.0, 1.0, 1.0),
		"DownleftChart": Color(0.0, 0.0, 1.0, 1.0),
		"LeftChart": Color(1.0, 0.0, 0.0, 1.0),
		"DownChart": Color(1.0, 1.0, 0.0, 1.0),
		"UpChart": Color(0.0, 1.0, 0.0, 1.0),
		"RightChart": Color(0.0, 1.0, 0.9, 1.0),
		"DownrightChart": Color(0.627451, 0.1254902, 0.9411765, 1),
		"UprightChart": Color(1.0, 0.0, 0.0, 1.0),
		"size": 1.0
	},
	"other": {
		"show_chart_alignment": false
	},
	"eq": {
		"31": 0.0,
		"62": 0.0,
		"125": 0.0,
		"250": 0.0,
		"500": 0.0,
		"1000": 0.0,
		"2000": 0.0,
		"4000": 0.0,
		"8000": 0.0,
		"16000": 0.0,
	},
	"eq_presets": {
		"Flat": {
			"31": 0.0,
			"62": 0.0,
			"125": 0.0,
			"250": 0.0,
			"500": 0.0,
			"1000": 0.0,
			"2000": 0.0,
			"4000": 0.0,
			"8000": 0.0,
			"16000": 0.0,
		},
		"Bass": {
			"31": 5.0,
			"62": 6.0,
			"125": 2.0,
			"250": 0.0,
			"500": -4.0,
			"1000": -4.0,
			"2000": 0.0,
			"4000": 0.0,
			"8000": 1.0,
			"16000": 2.0,
		},
		"Bass Compensate": {
			"31": 4.0,
			"62": 6.0,
			"125": 2.0,
			"250": -2.0,
			"500": -4.0,
			"1000": -4.0,
			"2000": 0.0,
			"4000": 2.0,
			"8000": 5.0,
			"16000": 8.0,
		},
	},
	"keybinds": {
		"noteLeft": [KEY_Q, KEY_Z, KEY_LEFT, KEY_3],
		"noteDown": [KEY_W],
		"noteUp": [KEY_O],
		"noteRight": [KEY_P],
		"pause-back": [KEY_ESCAPE]
	}
}

# Aliases
var game: Dictionary:
	get: return settings.game
var misc: Dictionary:
	get: return settings.misc_settings
var circles: Dictionary:
	get: return settings.circle_notes
var other: Dictionary:
	get: return settings.other
var eq: Dictionary:
	get: return settings.eq
var eq_presets: Dictionary:
	get: return settings.eq_presets
var keybinds: Dictionary:
	get: return settings.keybinds

func _ready() -> void:
	print("Settings Global node loaded")
	_load()
	#_apply_keybinds()
	_apply_display_settings()

func _save():
	print("Saving settings")
	var file = FileAccess.open(General.SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify([settings], "\t", false))
		file.close()

func _apply_display_settings(): # On load, instantly apply any new display related settings like fps or window mode
	# Fps mode
	if misc.fps == -1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = misc.fps

	var args = {}

	for arg in OS.get_cmdline_args():
		if arg.contains("="):
			var key_val = arg.split("=", false, 1)
			args[key_val[0].trim_prefix("--").to_lower()] = key_val[1]
		else:
			args[arg.trim_prefix("--").to_lower()] = ""

	print("Raw cmdline args: ", OS.get_cmdline_args())
	print("Parsed cmdline args: ", args)

	# Window Mode
	var window_mode = misc.window_mode
	if args.has("window_mode"):
		window_mode = args["window_mode"]

	match window_mode:
		"exclusive_fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"maximized":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Resolution
	var resolution = misc.resolution

	if args.has("resolution"):
		var split := str(args["resolution"]).split("x")

		if split.size() == 2 and split[0].is_valid_int() and split[1].is_valid_int():
			resolution = [
				int(split[0]),
				int(split[1])
			]

	elif args.has("width") and args.has("height"):
		if str(args["width"]).is_valid_int() and str(args["height"]).is_valid_int():
			resolution = [
				int(args["width"]),
				int(args["height"])
			]

	if resolution.size() >= 2:
		var res := Vector2i(resolution[0], resolution[1])
		DisplayServer.window_set_size(res)

	# Borderless
	var borderless = misc.borderless

	if args.has("borderless"):
		borderless = str(args["borderless"]).to_lower() in ["true", "1", "yes"]

	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, borderless)

func _load():
	print("Loading settings")
	if FileAccess.file_exists(General.SETTINGS_PATH):
		var file = FileAccess.open(General.SETTINGS_PATH, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_ARRAY and parsed.size() > 0:
				print("Merging loaded settings with defaults")
				General._merge_dict(settings, parsed[0]) # Merge file settings into existing dictionary
			file.close()
	else:
		print("Settings file not found, creating new one with default settings")
		_save()

func _apply_keybinds() -> void:
	for action_name in settings["keybinds"].keys():
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
			print("Erased ", action_name)
		else:
			InputMap.add_action(action_name)
			print("Not found, added ", action_name)

		for raw_val in settings["keybinds"][action_name]:
			var val: int = int(raw_val) # Convert from float to int
			var ev: InputEvent = null

			# Detect input type
			if val >= KEY_SPACE: # Assume keyboard key
				var key_event := InputEventKey.new()
				key_event.keycode = key_event.val
				ev = key_event
			elif val >= MOUSE_BUTTON_LEFT and val <= MOUSE_BUTTON_XBUTTON2:
				var mouse_event := InputEventMouseButton.new()
				mouse_event.button_index = mouse_event.val
				ev = mouse_event
			elif val >= JOY_BUTTON_A and val <= JOY_BUTTON_RIGHT_SHOULDER:
				var joy_event := InputEventJoypadButton.new()
				joy_event.button_index = joy_event.val
				ev = joy_event
			elif val >= JOY_AXIS_LEFT_X and val <= JOY_AXIS_TRIGGER_RIGHT:
				var axis_event := InputEventJoypadMotion.new()
				axis_event.axis = axis_event.val
				axis_event.axis_value = 1.0
				ev = axis_event

			if ev:
				print("Created ", action_name, " with ", ev.as_text())
				InputMap.action_add_event(action_name, ev)

func parse_any_color(value) -> Color:
	if typeof(value) == TYPE_COLOR:
		return value

	if typeof(value) == TYPE_STRING:
		var v: String = value.strip_edges()

		if v.begins_with("(") and v.ends_with(")"):
			var inner = v.trim_prefix("(").trim_suffix(")")
			var parts = inner.split(",")
			if parts.size() == 4:
				return Color(
					parts[0].to_float(),
					parts[1].to_float(),
					parts[2].to_float(),
					parts[3].to_float()
				)

		return Color(v)

	return Color.WHITE
