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
		"speed": 1.0,
		"note_speed": 10.0,
		"theme": "Default", # 1.0 max 0.0 min
		"menu_bg_brightness": 1.0,
		"bg_brightness": 1.0,
		"editor_bg_brightness": 0.75,
		"version": "-1.0",
		"show_vpopup": true,
		"last_editor_path": ""
	},
	"misc_settings": {
		"bg_videos": true,
		"editor_bg_videos": true,
		"note_style": "dance", # dance / techno / para 
		"note_anims": true,
		"note_particle_fx": 1, # 0 none 1 splash 2 crash 3 splash and crash 4 orbit
		"menu_bg_pulse": true,
		"menu_bg_pulse_strength": 16.0,
		"menu_bg_img_path": "",
		"show_fps": true,
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
		"selected_eq_preset": "Flat"
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
	
	print(JSON.stringify(settings, "\t", false)) # Print out the settings for debug purposes

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
	
	# Window Mode
	match misc.window_mode:
		"exclusive_fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"maximized":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
		"minimized":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		"windowed":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Borderless
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, misc.borderless)

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
