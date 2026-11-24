extends Node

var listening: bool = false # If true, a keybind is being edited, so any other key actions should be ignored

const INPUTS: Dictionary[Variant, Variant] = {
	"left": 0,
	"down": 1,
	"up": 2,
	"right": 3,
	"pause": 4,
}

const LEGACY_DEFAULT_KEYBINDS: Dictionary = {
	"noteLeft": [KEY_Q, KEY_Z, KEY_LEFT, KEY_3],
	"noteDown": [KEY_W],
	"noteUp": [KEY_O],
	"noteRight": [KEY_P],
	"pause-back": [KEY_ESCAPE],
}
const MAX_KEYBIND_EVENTS := 5

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
		"monitor_windows_media": false,
		"only_monitor_on_main_menu": false,
		"unpause_external_media_on_main_menu": false,
		"match_external_media_cover_loops": true,
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
		"custom_song_dirs": [
			"user://Custom"
		]
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
		"square_playing_bar_cover": false,
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
	"keybinds": {},
	"pause_back_bindings_migrated": false
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
	_apply_keybinds()
	_apply_display_settings()

func _save():
	print("Saving settings")
	var file: FileAccess = FileAccess.open(General.SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to open settings file for writing: %s (%s)" % [General.SETTINGS_PATH, error_string(FileAccess.get_open_error())])
		return

	file.store_string(JSON.stringify([settings], "\t", false))
	var write_error: int = file.get_error()
	file.close()
	if write_error != OK:
		push_error("Failed to write settings file: %s (%s)" % [General.SETTINGS_PATH, error_string(write_error)])

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
	var saved_keybinds: Variant = settings.get("keybinds", {})
	if typeof(saved_keybinds) != TYPE_DICTIONARY:
		push_warning("Ignoring invalid saved keybind data.")
		return

	if not bool(settings.get("pause_back_bindings_migrated", false)):
		if not _migrate_pause_back_keybinds(saved_keybinds):
			return
		settings["pause_back_bindings_migrated"] = true
		_save()

	for raw_action_name in saved_keybinds.keys():
		var action_name: StringName = StringName(raw_action_name)
		var raw_events: Variant = saved_keybinds[raw_action_name]
		if typeof(raw_events) != TYPE_ARRAY:
			push_warning("Ignoring invalid keybind list for '%s'." % action_name)
			continue
		var raw_events_array: Array = raw_events

		if _is_legacy_default_keybinds(str(action_name), raw_events_array):
			continue

		var loaded_events: Array[InputEvent] = []
		var valid_events: bool = true
		if raw_events_array.size() > MAX_KEYBIND_EVENTS:
			push_warning(
				"Keybind '%s' has more than %d inputs; ignoring extras."
				% [action_name, MAX_KEYBIND_EVENTS]
			)

		for event_index in mini(raw_events_array.size(), MAX_KEYBIND_EVENTS):
			var raw_event: Variant = raw_events_array[event_index]
			var input_event: InputEvent = _deserialize_keybind_event(raw_event)
			if input_event == null:
				valid_events = false
				break
			loaded_events.append(input_event)

		if not valid_events:
			push_warning("Ignoring invalid saved keybinds for '%s'." % action_name)
			continue

		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for input_event in loaded_events:
			InputMap.action_add_event(action_name, input_event)

func _migrate_pause_back_keybinds(saved_keybinds: Dictionary) -> bool:
	var pause_events: Array[InputEvent] = []
	if saved_keybinds.has("pause-back"):
		var raw_pause_events: Variant = saved_keybinds["pause-back"]
		if typeof(raw_pause_events) != TYPE_ARRAY:
			push_warning("Cannot migrate invalid saved 'pause-back' keybinds.")
			return false
		for raw_event in raw_pause_events:
			var input_event: InputEvent = _deserialize_keybind_event(raw_event)
			if input_event == null:
				push_warning("Cannot migrate invalid saved 'pause-back' keybinds.")
				return false
			pause_events.append(input_event)
	else:
		pause_events.assign(InputMap.action_get_events(&"pause-back"))

	for legacy_action in ["controller-pause", "controller-back"]:
		if not saved_keybinds.has(legacy_action):
			continue
		var raw_legacy_events: Variant = saved_keybinds[legacy_action]
		if typeof(raw_legacy_events) != TYPE_ARRAY:
			push_warning("Ignoring invalid saved keybind list for '%s'." % legacy_action)
			continue
		for raw_event in raw_legacy_events:
			var legacy_event: InputEvent = _deserialize_keybind_event(raw_event)
			if legacy_event == null:
				push_warning("Ignoring invalid saved keybind in '%s'." % legacy_action)
				continue
			if not _has_matching_keybind_event(pause_events, legacy_event):
				pause_events.append(legacy_event)

	for button_index in [JOY_BUTTON_START, JOY_BUTTON_B]:
		if _has_joypad_button_event(pause_events, button_index):
			continue
		while pause_events.size() >= MAX_KEYBIND_EVENTS:
			var removable_index: int = pause_events.size() - 1
			while removable_index >= 0:
				var existing_event: InputEvent = pause_events[removable_index]
				if not _is_pause_back_controller_button(existing_event):
					break
				removable_index -= 1
			if removable_index < 0:
				push_warning("Cannot migrate 'pause-back' keybinds within the input limit.")
				return false
			pause_events.remove_at(removable_index)

		var joypad_event: InputEventJoypadButton = InputEventJoypadButton.new()
		joypad_event.button_index = button_index as JoyButton
		pause_events.append(joypad_event)

	var serialized_events: Array[Dictionary] = []
	for input_event in pause_events:
		var serialized_event: Dictionary = _serialize_keybind_event(input_event)
		if serialized_event.is_empty():
			push_warning("Cannot migrate unsupported input event in 'pause-back'.")
			return false
		serialized_events.append(serialized_event)

	saved_keybinds["pause-back"] = serialized_events
	saved_keybinds.erase("controller-pause")
	saved_keybinds.erase("controller-back")
	return true

func _has_joypad_button_event(events: Array[InputEvent], button_index: int) -> bool:
	for input_event in events:
		if input_event is InputEventJoypadButton and input_event.button_index == button_index:
			return true
	return false

func _has_matching_keybind_event(events: Array[InputEvent], candidate: InputEvent) -> bool:
	for input_event in events:
		if input_event.is_match(candidate, true):
			return true
	return false

func _is_pause_back_controller_button(input_event: InputEvent) -> bool:
	return input_event is InputEventJoypadButton and input_event.button_index in [JOY_BUTTON_START, JOY_BUTTON_B]

func apply_keybind_event(action_name: StringName, event_index: int, new_event: InputEvent) -> bool:
	if not InputMap.has_action(action_name) or new_event == null:
		push_warning("Cannot update keybind for '%s'." % action_name)
		return false

	var saved_keybinds: Variant = settings.get("keybinds", {})
	if typeof(saved_keybinds) != TYPE_DICTIONARY:
		push_warning("Cannot update keybinds because saved keybind data is invalid.")
		return false

	var updated_events: Array[InputEvent] = []
	updated_events.assign(InputMap.action_get_events(action_name))
	if event_index == -1:
		if updated_events.size() >= MAX_KEYBIND_EVENTS:
			push_warning("Cannot add a sixth input to keybind '%s'." % action_name)
			return false
		updated_events.append(new_event)
	elif event_index >= 0 and event_index < updated_events.size():
		updated_events[event_index] = new_event
	else:
		push_warning("Cannot update keybind '%s': binding index is out of range." % action_name)
		return false

	var serialized_events: Array[Dictionary] = []
	for input_event in updated_events:
		var serialized_event: Dictionary = _serialize_keybind_event(input_event)
		if serialized_event.is_empty():
			push_warning("Cannot save unsupported input event for '%s'." % action_name)
			return false
		serialized_events.append(serialized_event)

	InputMap.action_erase_events(action_name)
	for input_event in updated_events:
		InputMap.action_add_event(action_name, input_event)
	saved_keybinds[str(action_name)] = serialized_events
	return true

func remove_keybind_event(action_name: StringName, event_index: int) -> bool:
	if not InputMap.has_action(action_name):
		push_warning("Cannot remove keybind for unknown action '%s'." % action_name)
		return false

	var events: Array[InputEvent] = []
	events.assign(InputMap.action_get_events(action_name))
	if event_index < 0 or event_index >= events.size():
		push_warning("Cannot remove keybind '%s': binding index is out of range." % action_name)
		return false
	events.remove_at(event_index)

	var serialized_events: Array[Dictionary] = []
	for input_event in events:
		var serialized_event: Dictionary = _serialize_keybind_event(input_event)
		if serialized_event.is_empty():
			push_warning("Cannot save unsupported input event for '%s'." % action_name)
			return false
		serialized_events.append(serialized_event)

	var saved_keybinds: Variant = settings.get("keybinds", {})
	if typeof(saved_keybinds) != TYPE_DICTIONARY:
		push_warning("Cannot update keybinds because saved keybind data is invalid.")
		return false

	InputMap.action_erase_events(action_name)
	for input_event in events:
		InputMap.action_add_event(action_name, input_event)
	saved_keybinds[str(action_name)] = serialized_events
	return true

func _is_legacy_default_keybinds(action_name: String, raw_events: Array) -> bool:
	if not LEGACY_DEFAULT_KEYBINDS.has(action_name):
		return false

	var legacy_defaults: Array = LEGACY_DEFAULT_KEYBINDS[action_name]
	if raw_events.size() != legacy_defaults.size():
		return false

	for index in range(raw_events.size()):
		if typeof(raw_events[index]) != TYPE_INT and typeof(raw_events[index]) != TYPE_FLOAT:
			return false
		if int(raw_events[index]) != legacy_defaults[index]:
			return false
	return true

func _deserialize_keybind_event(value: Variant) -> InputEvent:
	if value is Dictionary:
		var event_data: Dictionary = value
		var device: int = int(event_data.get("device", -1))
		match str(event_data.get("type", "")):
			"key":
				var key_event: InputEventKey = InputEventKey.new()
				key_event.device = device
				key_event.keycode = int(event_data.get("keycode", 0)) as Key
				key_event.physical_keycode = int(event_data.get("physical_keycode", 0)) as Key
				key_event.key_label = int(event_data.get("key_label", 0)) as Key
				key_event.unicode = int(event_data.get("unicode", 0))
				key_event.location = int(event_data.get("location", 0)) as KeyLocation
				key_event.alt_pressed = bool(event_data.get("alt", false))
				key_event.shift_pressed = bool(event_data.get("shift", false))
				key_event.ctrl_pressed = bool(event_data.get("ctrl", false))
				key_event.meta_pressed = bool(event_data.get("meta", false))
				return key_event
			"mouse_button":
				var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
				mouse_event.device = device
				mouse_event.button_index = int(event_data.get("button_index", 0)) as MouseButton
				mouse_event.alt_pressed = bool(event_data.get("alt", false))
				mouse_event.shift_pressed = bool(event_data.get("shift", false))
				mouse_event.ctrl_pressed = bool(event_data.get("ctrl", false))
				mouse_event.meta_pressed = bool(event_data.get("meta", false))
				return mouse_event
			"joypad_button":
				var joy_button_event: InputEventJoypadButton = InputEventJoypadButton.new()
				joy_button_event.device = device
				joy_button_event.button_index = int(event_data.get("button_index", 0)) as JoyButton
				joy_button_event.pressure = float(event_data.get("pressure", 0.0))
				joy_button_event.pressed = bool(event_data.get("pressed", false))
				return joy_button_event
			"joypad_motion":
				var joy_motion_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
				joy_motion_event.device = device
				joy_motion_event.axis = int(event_data.get("axis", 0)) as JoyAxis
				joy_motion_event.axis_value = float(event_data.get("axis_value", 1.0))
				return joy_motion_event
		return null

	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		var legacy_value: int = int(value)
		if legacy_value >= KEY_SPACE:
			var legacy_key_event: InputEventKey = InputEventKey.new()
			legacy_key_event.keycode = legacy_value as Key
			return legacy_key_event
		if legacy_value >= MOUSE_BUTTON_LEFT and legacy_value <= MOUSE_BUTTON_XBUTTON2:
			var legacy_mouse_event: InputEventMouseButton = InputEventMouseButton.new()
			legacy_mouse_event.button_index = legacy_value as MouseButton
			return legacy_mouse_event
		if legacy_value >= JOY_BUTTON_A and legacy_value <= JOY_BUTTON_RIGHT_SHOULDER:
			var legacy_joy_button_event: InputEventJoypadButton = InputEventJoypadButton.new()
			legacy_joy_button_event.button_index = legacy_value as JoyButton
			return legacy_joy_button_event
		if legacy_value >= JOY_AXIS_LEFT_X and legacy_value <= JOY_AXIS_TRIGGER_RIGHT:
			var legacy_joy_motion_event: InputEventJoypadMotion = InputEventJoypadMotion.new()
			legacy_joy_motion_event.axis = legacy_value as JoyAxis
			legacy_joy_motion_event.axis_value = 1.0
			return legacy_joy_motion_event

	return null

func _serialize_keybind_event(input_event: InputEvent) -> Dictionary:
	if input_event is InputEventKey:
		var key_event: InputEventKey = input_event as InputEventKey
		return {
			"type": "key",
			"device": key_event.device,
			"keycode": key_event.keycode,
			"physical_keycode": key_event.physical_keycode,
			"key_label": key_event.key_label,
			"unicode": key_event.unicode,
			"location": key_event.location,
			"alt": key_event.alt_pressed,
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"meta": key_event.meta_pressed
		}
	if input_event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
		return {
			"type": "mouse_button",
			"device": mouse_event.device,
			"button_index": mouse_event.button_index,
			"alt": mouse_event.alt_pressed,
			"shift": mouse_event.shift_pressed,
			"ctrl": mouse_event.ctrl_pressed,
			"meta": mouse_event.meta_pressed
		}
	if input_event is InputEventJoypadButton:
		var joy_button_event: InputEventJoypadButton = input_event as InputEventJoypadButton
		return {
			"type": "joypad_button",
			"device": joy_button_event.device,
			"button_index": joy_button_event.button_index,
			"pressure": joy_button_event.pressure,
			"pressed": joy_button_event.pressed
		}
	if input_event is InputEventJoypadMotion:
		var joy_motion_event: InputEventJoypadMotion = input_event as InputEventJoypadMotion
		return {
			"type": "joypad_motion",
			"device": joy_motion_event.device,
			"axis": joy_motion_event.axis,
			"axis_value": joy_motion_event.axis_value
		}
	return {}

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
