extends Node

# This mostly stores settings, the settings json file is used for saving the settings, 
# When the game loads, it instantly refers back to the json file to update the settings dictionary below if any changes were made 

const VERSION: String = "1.5.2"
const NAME: String = "Beatz! X"
const SLOGAN: String = "FEEL. YOUR RHYTHM."
var port: String = "Desktop Port" if OS.get_name() == "Windows" else "%s Port" % OS.get_name()

var SONG_ID_ARR_PATH : String = "user://Custom/.songids" if OS.get_name() == "Windows" else "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/.songids"

const SETTINGS_PATH := "user://settings.json"

const MENU = preload("res://Scenes/main_menu.tscn")
const MAIN = preload("res://Scenes/main.tscn")
const EDITOR = preload("res://Scenes/editor.tscn")

var settings: Dictionary = {
	"game": {
		"mbl_btn_layout": 0, # 0 for 4 btn layout, 1 for 2 + 2 btn layout
		"song_vol": 80,
		"menu_song_vol": 75,
		"sfx_vol": 40,
		"speed": 1.0,
		"note_speed": 10.0,
		"theme": "Default"
	},
	"misc_settings": {
		"note_style": "dance", # dance / techno / para 
		"note_anims": true,
		"show_fps": true,
		"accurate_fps": false,
		"note_offset": 0.0,
		"fps": -1,
		"resolution": [1920, 1080],
		"window_mode": "windowed",
		"borderless": false,
		"reduce_motion": false
	}
}

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug_reload_scene"):
		print("------------------------------")
		print_rich("[color=orange]DEBUG: Reloading current scene[/color]")
		print("------------------------------")
		get_tree().reload_current_scene()

func _ready() -> void:
	if OS.get_name() == "Android":
		OS.request_permissions()
	
	ensure_songids_file_exists()
	_load_settings()
	_apply_display_settings()
	print(settings) # Print out the settings for debug purposes

func _load_settings():
	print("Loading settings")
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			var parsed = JSON.parse_string(text)
			if typeof(parsed) == TYPE_ARRAY and parsed.size() > 0:
				print("Merging loaded settings with defaults")
				_merge_dict(settings, parsed[0]) # Merge file settings into existing dictionary
			file.close()
	else:
		print("Settings file not found, creating new one with default settings")
		_save_settings()

func _merge_dict(base: Dictionary, updates: Dictionary) -> void:
	for key in updates.keys():
		if base.has(key):
			if typeof(base[key]) == TYPE_DICTIONARY and typeof(updates[key]) == TYPE_DICTIONARY:
				_merge_dict(base[key], updates[key]) # Recursively merge sub-dictionaries
			else:
				base[key] = updates[key]

func _save_settings():
	print("Saving settings")
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify([settings], "\t"))
		file.close()

func _apply_display_settings(): # On load, instantly apply any new display related settings like fps or window mode
	var misc = settings.misc_settings
	
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

		# Windowed-specific logic
	if misc.window_mode == "windowed":
		var screen_index = DisplayServer.window_get_current_screen()
		var screen_rect = DisplayServer.screen_get_usable_rect(screen_index)

		# Max 75% of screen size
		var max_size: Vector2 = screen_rect.size * 0.75

		# Force 16:9 aspect ratio
		var aspect := 16.0 / 9.0
		var target_width := max_size.x
		var target_height := target_width / aspect

		# If height is too tall, clamp by height instead
		if target_height > max_size.y:
			target_height = max_size.y
			target_width = target_height * aspect

		var target_size: Vector2i = Vector2i(target_width, target_height)

		# Apply size
		DisplayServer.window_set_size(target_size)

		# Center window
		var centered_pos = screen_rect.position + (screen_rect.size - target_size) / 2
		DisplayServer.window_set_position(centered_pos)

func ensure_songids_file_exists():
	if not FileAccess.file_exists(SONG_ID_ARR_PATH):
		var create_file = FileAccess.open(SONG_ID_ARR_PATH, FileAccess.WRITE)
		if create_file:
			create_file.close()
			print("Created missing .songids file.")
		else:
			print("Failed to create .songids file.")

func format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	var hrs = total_seconds / 3600
	var mins = (total_seconds % 3600) / 60
	var secs = total_seconds % 60
	var frac = int((seconds - total_seconds) * 100)  # hundredths of a second

	if hrs > 0:
		return "%d:%02d:%02d.%02d" % [hrs, mins, secs, frac]
	else:
		return "%02d:%02d.%02d" % [mins, secs, frac]

# Utility function to capitalize first letter
func _capitalize_first_letter(s: String) -> String:
	if s.length() == 0:
		return s
	return s.substr(0, 1).to_upper() + s.substr(1, s.length() - 1)

# Map direction abbreviation to full name
const REVERSE_NOTE_TYPE_MAP := {
	"U": "Up",
	"D": "Down",
	"L": "Left",
	"R": "Right",
	"UL": "Upleft",
	"DL": "Downleft",
	"UR": "Upright",
	"DR": "Downright"
}

const NOTE_TYPE_MAP := {
	"Up": "U",
	"Down": "D",
	"Left": "L",
	"Right": "R",
	"Upleft": "UL",
	"Downleft": "DL",
	"Upright": "UR",
	"Downright": "DR"
}

# Encode notes array into .beatz style string
func encode_notes(notes: Array) -> String:
	var encoded := []
	for note in notes:
		var type_str := _capitalize_first_letter(note.type)
		var type_char = NOTE_TYPE_MAP.get(type_str, "")
		var base := "%s/%d" % [type_char, note.timestamp]
		if note.has("hold") and note.hold != null:
			base += "!hold=%d" % note.hold
		encoded.append(base)
	return ",".join(encoded)

# Decode .beatz style string into notes array
func decode_notes(encoded_notes: String) -> Dictionary:
	var decoded := []
	for note_str in encoded_notes.split(","):
		var parts := note_str.split("/")
		if parts.size() < 2:
			continue
		var type_char := parts[0]
		var timestamp := int(parts[1])
		var note_type := _capitalize_first_letter(REVERSE_NOTE_TYPE_MAP.get(type_char, ""))
		var note_dict := {
			"type": note_type,
			"timestamp": timestamp
		}
		# Check for hold property
		if "!" in note_str:
			var hold_parts := note_str.split("!hold=")
			if hold_parts.size() > 1:
				note_dict.hold = int(hold_parts[1])
		decoded.append(note_dict)
	return {"notes": decoded}

func import_beatz_file(content: String) -> Dictionary:
	var sections := content.split("\\")
	if sections.size() == 1:
		sections = content.split("\\\\")
	
	var song := ""
	var charter := ""
	var chart_name := ""
	var decoded_bpm := 0
	var decoded_note_speed := 0.0
	var decoded_note_spawn_y := 0.0
	var decoded_start_wait := 0.0
	var decoded_prev_start := 0.0
	var decoded_prev_end := 30.0
	var decoded_difficulty := "hard"
	var notes_line := ""
	var decoded_notes := []
	
	for section in sections:
		if section.begins_with("Song:"):
			song = section.replace("Song:", "").strip_edges()
		elif section.begins_with("Charter:"):
			charter = section.replace("Charter:", "").strip_edges()
		elif section.begins_with("ChartName:"):
			chart_name = section.replace("ChartName:", "").strip_edges()
		elif section.begins_with("BPM:"):
			decoded_bpm = int(section.replace("BPM:", "").strip_edges())
		elif section.begins_with("noteSpeed:"):
			decoded_note_speed = float(section.replace("noteSpeed:", "").strip_edges())
		elif section.begins_with("noteSpawnY:"):
			decoded_note_spawn_y = int(section.replace("noteSpawnY:", "").strip_edges())
		elif section.begins_with("Difficulty:"):
			decoded_difficulty = section.replace("Difficulty:", "").strip_edges()
		elif section.begins_with("StartWait:"):
			decoded_start_wait = float(section.replace("StartWait:", "").strip_edges())
		elif section.begins_with("PrevStart:"):
			decoded_prev_start = float(section.replace("PrevStart:", "").strip_edges())
		elif section.begins_with("PrevEnd:"):
			decoded_prev_end = float(section.replace("PrevEnd:", "").strip_edges())
		elif section.begins_with("Notes:"):
			notes_line = section.replace("Notes:", "").strip_edges()
			
	if notes_line.find("/") != -1:
		for note_str in notes_line.split(","):
			var regex := RegEx.new()
			regex.compile(r"((?:S)?[LRUD]{1,2}|E|RND)/(-?\d+)(?:!([^,]+))?")
			var result := regex.search(note_str)
			if result == null:
				continue
				
			var type_char := result.get_string(1)
			var timestamp := float(result.get_string(2))
			var properties_str := result.get_string(3)
			
			var note_type := ""
			if type_char == "E":
				note_type = "Effect"
			elif type_char == "RND":
				note_type = "Random"
			else:
				note_type = _capitalize_first_letter(REVERSE_NOTE_TYPE_MAP.get(type_char, type_char))
				
			var note := {
				"type": note_type,
				"timestamp": timestamp,
				"newShake": null,
				"newBPM": null,
				"newSpeed": null,
				"newSpawnY": null,
				"FSinc": null,
				"smallFSinc": null,
				"bpmPulseInc": null,
				"ownSpeed": null,
				"ownSpawnY": null
			}
			
			if properties_str != "":
				for prop in properties_str.split(";"):
					var kv := prop.split("=")
					if kv.size() != 2:
						continue
					var key := kv[0].strip_edges().lstrip("!")
					var value := kv[1].strip_edges()
					
					match key:
						"ownSpeed":
							note["ownSpeed"] = float(value)
						"ownSpawnY":
							note["ownSpawnY"] = int(value)
						"shake":
							var parts := value.split(".")
							if parts.size() == 4:
								note["shake"] = {
									"strength": float(parts[0]),
									"speed": float(parts[1]),
									"duration": float(parts[2]),
									"fade": float(parts[3])
								}
						_:
							if value.is_valid_float():
								note[key] = float(value)
							else:
								note[key] = value
							
			decoded_notes.append(note)
			
	decoded_notes.sort_custom(func(a, b): return a["timestamp"] < b["timestamp"])
	
	return {
		"notes": decoded_notes,
		"note_count": decoded_notes.size(),
		"song": song,
		"chart_name": chart_name,
		"charter": charter,
		"bpm": decoded_bpm,
		"note_speed": decoded_note_speed,
		"note_spawn_y": decoded_note_spawn_y,
		"difficulty": decoded_difficulty,
		"start_wait": decoded_start_wait,
		"preview_start": decoded_prev_start,
		"preview_end": decoded_prev_end
	}
