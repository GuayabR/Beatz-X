extends Node

# This mostly stores settings, the settings json file is used for saving the settings, 
# When the game loads, it instantly refers back to the json file to update the settings dictionary below if any changes were made 

const VERSION: String = "1.5.0"
const NAME: String = "Beatz! X"
const SLOGAN: String = "VISUALIZE YOUR RHYTHM."

const MESSAGES: Array = [
	"SENSE. YOUR RHYTHM.",
	"SEE. YOUR RHYTHM.",
	"FEEL. YOUR RHYTHM.",
	SLOGAN,
	VERSION,
	"CREATE. YOUR RHYTHM.",
	"Let the music imagine",
	"\"IS MUSIC THE GREATEST THING EVER CREATED?\"",
	"Yes I do really like that guy Linkin",
	"Includes Creo's Rhythm!",
	"AS^",
	"The Unforgettable",
	"AA",
	"AM",
	"am",
	"AR",
	"AJ",
	"aa",
	"AS",
	"aE",
	"AL",
	"AT",
	"AF",
	"AS^ AA AM am AR AJ aa AS aE AL AT AF",
	"Hybrid Theory 25"
]

const MAIN_MENU_MSGS: Array = [
	"SENSE. YOUR RHYTHM.",
	"SEE. YOUR RHYTHM.",
	"FEEL. YOUR RHYTHM.",
	SLOGAN,
	"CREATE. YOUR RHYTHM.",
	"CREATE. YOUR JITHOO.",
	"Let the music imagine",
	"\"IS MUSIC THE GREATEST THING EVER CREATED?\"",
	"Yes I do really like that guy Linkin",
	"Top 20 Singer",
	"Includes Creo's Rhythm!",
	"AS^ AA AM am AR\nAJ aa AS aE AL AT AF",
	"THAT MEANS YOU",
	"Hybrid Theory 25",
	"Thanks for Playing!",
	"SING YOUR MIND AWAY",
	"\"This is going on my playlist\" 🙏",
	"ADD YOUR MEANING TO IT",
	"AMIGA QUIERO QUE SEPAS LA IMPRESION QUE TU PRESENCIA HA CAUSADO EN MI",
	"\"MAKE NIELSEN PROUD!\""
]

var port: String = "Desktop Port" if OS.get_name() == "Windows" else "%s Port" % OS.get_name()

const GITHUB_REL_URL: String = "https://api.github.com/repos/GuayabR/Beatz-X/releases/latest"

var SONG_ID_ARR_PATH : String = "user://Custom/.songids" if OS.get_name() == "Windows" else "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/.songids"

const SETTINGS_PATH := "user://settings.json"

const POINTS_PATH := "user://.points"

const DISCORD_APP_ID: int = 1426499873607520306

var play_start_time: int

const MENU: PackedScene = preload("res://Scenes/main_menu.tscn")
const MAIN: PackedScene = preload("res://Scenes/main.tscn")
const EDITOR: PackedScene = preload("res://Scenes/editor.tscn")

const IMG_FORMATS: Array[Variant] = ["*.png, *.jpg, *.webp, *.svg, *.tga, *.dds. *.ktx, *.exr, *.hdr", "*.png", "*.jpg", "*.webp", "*.svg", "*.tga", "*.dds", "*.ktx", "*.exr", "*.hdr", "*"]
const AUDIO_FORMATS: Array[Variant] = ["*.mp3, *.ogg, *.wav"]
const VIDEO_FORMATS: PackedStringArray = ["*.mp4", "*.mov", "*.mkv", "*.avi", "*.webm"]

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug_reload_scene"):
		print("------------------------------")
		print_rich("[color=orange]DEBUG: Reloading current scene[/color]")
		print("------------------------------")
		get_tree().reload_current_scene()

func _on_focus_in():
	#print("focused back in")
	if bg_was_pulsing: Settings.misc.menu_bg_pulse = true
	if Settings.misc.advanced_fps:
		if get_tree().current_scene.name.to_lower().contains("main_menu"):
			apply_fps_limit("main_menu")
		else:
			apply_fps_limit("main")
	else:
		apply_fps_limit("main_menu")

func _on_focus_out() -> void:
	if is_popup_open: return
	bg_was_pulsing = Settings.misc.menu_bg_pulse
	if Settings.misc.advanced_fps:
		apply_fps_limit("unfocused")
		if bg_was_pulsing: Settings.misc.menu_bg_pulse = false

var bg_was_pulsing: bool = false

func _ready() -> void:
	print()
	print("General Global node loaded")
	
	get_viewport().connect("focus_entered", Callable(self, "_on_focus_in"))
	get_viewport().connect("focus_exited", Callable(self, "_on_focus_out"))
	
	if OS.get_name() == "Android":
		OS.request_permissions()
	
	var icon: CompressedTexture2D = preload("res://Resources/favicon.png")
	DisplayServer.set_icon(icon.get_image())
	
	ensure_songids_file_exists()
	
	play_start_time = int(Time.get_unix_time_from_system())
	
	if is_process_running("Discord.exe") and Settings.misc.drc:
		# this is boolean if everything worked
		DiscordRPC.app_id = DISCORD_APP_ID
		print("Discord working: " + str(DiscordRPC.get_is_discord_working()))
		# Set the first custom text row of the activity here
		DiscordRPC.details = "A rhythm game by GuayabR"
		# Set the second custom text row of the activity here
		DiscordRPC.state = "Main Menu"
		# Image key for small image from "Art Assets" from the Discord Developer website
		DiscordRPC.large_image = "beatzroundcover"
		# Tooltip text for the large image
		DiscordRPC.large_image_text = "Beatz! X - Download at beatzx.com!"
		# Image key for large image from "Art Assets" from the Discord Developer website
		DiscordRPC.small_image = "beatzroundcover"
		# Tooltip text for the small image
		DiscordRPC.small_image_text = "FEEL. YOUR RHYTHM."
		# "02:41 elapsed" timestamp for the activity
		DiscordRPC.start_timestamp = play_start_time
		# Always refresh after changing the values!
		DiscordRPC.refresh()
	else:
		print("Either discord is not running or user toggled off drc")
		DiscordRPC.clear(true)
		DiscordRPC.free()

func _set_rpc(details: String, state: String, large_img: String, large_img_text: String, small_img: String, small_img_text: String, start: int, end: int):
	if not Settings.misc.drc or not DiscordRPC: return
	# Set the first custom text row of the activity here
	DiscordRPC.details = details
	# Set the second custom text row of the activity here
	DiscordRPC.state = state
	# Image key for small image from "Art Assets" from the Discord Developer website
	DiscordRPC.large_image = large_img
	# Tooltip text for the large image
	DiscordRPC.large_image_text = large_img_text
	# Image key for large image from "Art Assets" from the Discord Developer website
	DiscordRPC.small_image = small_img
	# Tooltip text for the small image
	DiscordRPC.small_image_text = small_img_text
	# "02:41 elapsed" timestamp for the activity
	DiscordRPC.start_timestamp = start
	# "59:59 remaining" timestamp for the activity
	if end != 0: DiscordRPC.end_timestamp = end
	# Always refresh after changing the values!
	DiscordRPC.refresh()

var is_popup_open: bool = false

func apply_fps_limit(context: String) -> void:
	# Never switch to unfocused FPS if a settings popup is open
	if is_popup_open:
		print("popupped")
		return
	
	match context:
		"main_menu":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Settings.misc.fps_main_menu
		"main":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Settings.misc.fps_main
		"unfocused":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Settings.misc.fps_unfocused
		_:
			Engine.max_fps = 120 # fallback
			print("Fallbacked to 120 fps cuz ", context, " was not recognized as a menu")
	#print("Max fps applied from ", context, " to ", Engine.max_fps)

func _set_file_hidden(path: String) -> void:
	if OS.get_name() == "Windows":
		var abs_path := ProjectSettings.globalize_path(path)
		abs_path = abs_path.replace("/", "\\")
		var out := []
		var err := OS.execute("cmd.exe", ["/C", "attrib +H \"" + abs_path + "\""], out, false)
		print("Hidden: ", abs_path)
		print("Result: ", err, " (", error_string(err), ") ", "Output: ", out)

func _merge_dict(base: Dictionary, updates: Dictionary) -> void:
	for key in updates.keys():
		if typeof(updates[key]) == TYPE_DICTIONARY:
			# If base doesn't have the sub-dict, create it
			if not base.has(key):
				base[key] = {}
			elif typeof(base[key]) != TYPE_DICTIONARY:
				base[key] = {}
			_merge_dict(base[key], updates[key])
		else:
			# Always add or replace
			base[key] = updates[key]

func is_process_running(process_name: String) -> bool:
	if OS.get_name() != "Windows":
		return false

	var output := []
	var exit_code := OS.execute("cmd.exe", ["/C", "tasklist"], output, true)
	if exit_code != 0:
		print("Failed to run tasklist: ", exit_code)
		return false

	for line in output:
		if process_name.to_lower() in line.to_lower():
			print_rich("[color=green]" + process_name + " Is running[/color]")
			return true
	print_rich("[color=red]" + process_name + " Is not running[/color]")
	return false

func ensure_songids_file_exists():
	if not FileAccess.file_exists(SONG_ID_ARR_PATH):
		var create_file = FileAccess.open(SONG_ID_ARR_PATH, FileAccess.WRITE)
		if create_file:
			create_file.close()
			print("Created missing .songids file.")
		else:
			print("Failed to create .songids file.")

var _color_from_string_map: Dictionary = {}

func extract_dominant_colors(texture: Image) -> Array[Color]:
	#print("Extracting dominant colors...")
	var to_scan = Image.create_from_data(texture.get_width(), texture.get_height(), false, texture.get_format(), texture.get_data())
	if to_scan.is_compressed():
		print("Image is compressed. Decompressing...")
		to_scan.decompress()
	to_scan.resize(64, 1, Image.INTERPOLATE_TRILINEAR)
	#print("Image resized to 64x1")
	
	var color_counts: Dictionary = _scan_colors(to_scan, false)
	#print("Scanned normal colors. Found:", color_counts.size(), "distinct colors")
	
	var dark_count: int = 0
	var total_count: int = 0
	for c in color_counts.keys():
		var color = _color_from_string_map.get(c, Color(0, 0, 0))
		total_count += color_counts[c]
		if color.r < 0.314 or color.g < 0.314 or color.b < 0.314:
			dark_count += color_counts[c]
	#print("Total color samples:", total_count)
	#print("Dark color samples:", dark_count)
	
	if total_count > 0 and float(dark_count) / float(total_count) > 0.6:
		#print("Too many dark colors. Trying to scan for brighter colors...")
		var bright_counts: Dictionary = _scan_colors(to_scan, true)
		#print("Scanned bright colors. Found:", bright_counts.size(), "distinct colors")
		if bright_counts.size() > 0:
			color_counts = bright_counts
		else:
			#print("No brighter colors found. Brightening existing dark colors...")
			var new_counts: Dictionary[Variant, Variant] = {}
			for c in color_counts.keys():
				var original_color = _color_from_string_map.get(c, Color(0, 0, 0))
				var brighter := Color(
					clamp(original_color.r + 0.3, 0, 1),
					clamp(original_color.g + 0.3, 0, 1),
					clamp(original_color.b + 0.3, 0, 1),
					1.0
				)
				var key_str := str(brighter)
				new_counts[key_str] = color_counts[c]
				_color_from_string_map[key_str] = brighter
			color_counts = new_counts
			_latest_color_counts = color_counts
			
	var sorted_colors = color_counts.keys()
	sorted_colors.sort_custom(Callable(self, "_compare_colors_by_frequency"))
	#print("Sorted colors by frequency")
	
	var result: Array[Color] = []
	for i in range(min(6, sorted_colors.size())):
		var col_str = sorted_colors[i]
		result.append(_color_from_string_map.get(col_str, Color(0, 0, 0)))
		
	#print("Final extracted colors:", result)
	return result

var _latest_color_counts: Dictionary

func _scan_colors(image: Image, only_bright: bool) -> Dictionary:
	var counts := {}
	for x in range(image.get_width()):
		var c: Color = image.get_pixel(x, 0)
		if only_bright:
			if c.r < 0.314 and c.g < 0.314 and c.b < 0.314:
				continue
		else:
			if c.r < 0.05 and c.g < 0.05 and c.b < 0.05:
				continue
		var key_color := Color(
			round(c.r * 10.0) / 10.0,
			round(c.g * 10.0) / 10.0,
			round(c.b * 10.0) / 10.0,
			1.0
		)
		var key_str := str(key_color)
		counts[key_str] = counts.get(key_str, 0) + 1
		_color_from_string_map[key_str] = key_color

	#print("Scan complete. only_bright =", only_bright, " Unique entries:", counts.size())
	_latest_color_counts = counts
	return counts

func _compare_colors_by_frequency(a: String, b: String) -> int:
	if not _latest_color_counts.has(a) or not _latest_color_counts.has(b):
		print("Missing color count for", a, "or", b)
		return 0
	var result = _latest_color_counts[b] - _latest_color_counts[a]
	#print("Comparing ", a, " vs ", b, " -> ", result)
	return result

func _yuv_to_image(y_data: PackedByteArray, u_data: PackedByteArray, v_data: PackedByteArray, res: Vector2i) -> Image:
	var w := res.x
	var h := res.y
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)

	# Very simplified YUV420p → RGB conversion (approximation)
	# Works fine for preview thumbnails
	for y in range(h):
		for x in range(w):
			var Y = y_data[y * w + x]
			var U = u_data[(y / 2) * (w / 2) + (x / 2)] - 128
			var V = v_data[(y / 2) * (w / 2) + (x / 2)] - 128
			var r = clamp(Y + 1.402 * V, 0, 255)
			var g = clamp(Y - 0.344136 * U - 0.714136 * V, 0, 255)
			var b = clamp(Y + 1.772 * U, 0, 255)
			img.set_pixel(x, y, Color8(r, g, b))

	return img

func save_image_with_correct_extension(image: Image, save_path: String) -> int:
	var ext := save_path.get_extension().to_lower()

	match ext:
		"png":
			return image.save_png(save_path)
		"jpg", "jpeg":
			return image.save_jpg(save_path, 1.0)
		"webp":
			return image.save_webp(save_path, false, 1.0)
		"exr":
			return image.save_exr(save_path)
		"hdr":
			return image.save_hdr(save_path)
		_: # unsupported for saving — fallback
			push_warning("Unsupported or unknown extension '%s', saving as PNG instead." % ext)
			save_path = save_path.get_basename() + ".png"
			return image.save_png(save_path)

func format_time(seconds: float) -> String:
	var total_seconds = int(seconds)
	@warning_ignore("integer_division")
	var hrs = total_seconds / 3600
	var mins = (total_seconds % 3600) / 60.0
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

# Function to safely escape regex special chars
func _escape_regex(text: String) -> String:
	var specials: Array[Variant] = ['\\', '.', '+', '*', '?', '^', '$', '(', ')', '[', ']', '{', '}', '|']
	for s in specials:
		text = text.replace(s, '\\' + s)
	return text

func format_file_size(bytes: int) -> String:
	var units: Array[Variant] = ["B", "KB", "MB", "GB", "TB"]
	var size = float(bytes)
	var i: int = 0

	while size >= 1024.0 and i < units.size() - 1:
		size /= 1024.0
		i += 1

	return "%0.2f %s" % [size, units[i]]

func _sanitize(what: String, is_path: bool = false) -> String:
	var invalid_chars := [ "<", ">", ":", "\"", "/", "\\", "|", "?", "*" ]
	var sanitized := what
	for c in invalid_chars:
		sanitized = sanitized.replace(c, "_")
	sanitized = sanitized.strip_edges()
	if is_path: 
		while sanitized.ends_with(".") or sanitized.ends_with(" "):
			sanitized = sanitized.substr(0, sanitized.length() - 1)

	return sanitized

func format_number_with_commas(num: float) -> String:
	var int_part := int(num)
	var str_num := str(int_part)
	var result := ""
	while str_num.length() > 3:
		result = "," + str_num.substr(str_num.length() - 3) + result
		str_num = str_num.substr(0, str_num.length() - 3)
	result = str_num + result
	return result

# Open folder in Explorer
func explorer(path: String) -> void:
	# Make sure path is absolute and valid
	if not DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path):
		print("Path does not exist: ", path)
		return
	OS.shell_open(path)
	print("Opening ", path)

func filter_nulls(array) -> Array:
	var filtered_nulls: Array = []
	for value in array:
		var filtered_value: Dictionary = {}
		for key in value.keys():
			if value[key] != null:
				filtered_value[key] = value[key]
		filtered_nulls.append(filtered_value)
	return filtered_nulls

func copy_video(src_path: String, dst_path: String) -> void:
	var platform := OS.get_name()
	var abs_src_path := ProjectSettings.globalize_path(src_path)
	var abs_dst_path := ProjectSettings.globalize_path(dst_path)

	if platform == "Windows":
		var output := []
		print("Starting OS file copy for Windows...")
		print("Source: ", abs_src_path)
		print("Destination: ", abs_dst_path)

		# Quote both paths so spaces are preserved
		var quoted_src := '"' + abs_src_path + '"'
		var quoted_dst := '"' + abs_dst_path + '"'
		var args := ["/c", "copy", "/Y", quoted_src, quoted_dst]

		print("Doing ", "cmd", " ".join(args))
		var result := OS.execute("cmd", args, output, true)
		print("Result ", result)
		print("Out ", output)

		if result == OK:
			print("Successfully copied video using OS command.")
		else:
			push_warning("OS copy failed, falling back.")
			print("Falling back to manual copy.")
			_copy_fallback(abs_src_path, abs_dst_path)

	elif platform == "Linux" or platform == "FreeBSD" or platform == "macOS":
		var output := []
		print("Starting OS file copy for Unix-like system...")
		print("Source:", abs_src_path)
		print("Destination:", abs_dst_path)

		var args := ["-f", abs_src_path, abs_dst_path]
		print("Doing ", "cp", " ".join(args))
		var result := OS.execute("cp", args, output, true)
		print("Result", result)
		print("Out", output)

		if result == OK:
			print("✅ Successfully copied video using OS cp.")
		else:
			push_warning("❌ OS cp failed, falling back.")
			_copy_fallback(abs_src_path, abs_dst_path)
	else:
		print("Non-desktop platform (%s), using fallback copy method." % platform)
		_copy_fallback(abs_src_path, abs_dst_path)


func _copy_fallback(src: String, dst: String) -> void:
	print("Starting fallback copy...")
	print("Source: ", src)
	print("Destination: ", dst)

	var src_file := FileAccess.open(src, FileAccess.READ)
	if not src_file:
		push_error("Could not open source file: %s" % src)
		return

	var dst_file := FileAccess.open(dst, FileAccess.WRITE)
	if not dst_file:
		push_error("Could not open destination file: %s" % dst)
		src_file.close()
		return

	var buffer_size := 65536 # 64KB chunks
	var total_bytes := 0
	while not src_file.eof_reached():
		var chunk := src_file.get_buffer(buffer_size)
		total_bytes += chunk.size()
		dst_file.store_buffer(chunk)

	src_file.close()
	dst_file.close()
	print("Copied %d bytes from %s to %s (fallback)" % [total_bytes, src, dst])

func _num_eval(input: String) -> float:
	input = input.strip_edges()
	
	# Reject anything that isn't a number or safe math symbol
	if not RegEx.create_from_string("^[0-9+\\-*/().\\s]+$").search(input):
		return input.to_float()  # fallback, invalid expression
	
	var expr := Expression.new()
	var parse_err = expr.parse(input)
	if parse_err == OK:
		var result = expr.execute()
		if typeof(result) in [TYPE_INT, TYPE_FLOAT]:
			return float(result)
	return input.to_float()

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
		var base: String = type_char + "/" + str(note.timestamp)
		if note.has("hold") and note.hold != null:
			base += "!hold=" + str(note.hold)
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
		var timestamp := float(parts[1])
		var note_type := _capitalize_first_letter(REVERSE_NOTE_TYPE_MAP.get(type_char, ""))
		var note_dict := {
			"type": note_type,
			"timestamp": timestamp
		}
		# Check for hold property
		if "!" in note_str:
			var hold_parts := note_str.split("!hold=")
			if hold_parts.size() > 1:
				note_dict.hold = float(hold_parts[1])
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
	var decoded_local_beat_offset := 0.0
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
		elif section.begins_with("BeatOffset:"):
			decoded_local_beat_offset = float(section.replace("BeatOffset:", "").strip_edges())
		elif section.begins_with("Notes:"):
			notes_line = section.replace("Notes:", "").strip_edges()
			
	if notes_line.find("/") != -1:
		for note_str in notes_line.split(","):
			var regex := RegEx.new()
			regex.compile(r"((?:S)?[LRUD]{1,2}|E|RND)/(-?\d*\.?\d+)(?:!([^,]+))?")
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
		"preview_end": decoded_prev_end,
		"local_beat_offset": decoded_local_beat_offset
	}
