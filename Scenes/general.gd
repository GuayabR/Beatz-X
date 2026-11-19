extends Node

# This mostly stores settings, the settings json file is used for saving the settings, 
# When the game loads, it instantly refers back to the json file to update the settings dictionary below if any changes were made 

signal epic_logged_in(user_info: Dictionary, product_info: Dictionary)

const VERSION: String = "1.6.0"
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
	"The Unforgettable",
	"Includes Creo's Rhythm!",
	"AK",
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
	"AK AA AM am AR AJ aa AS aE AL AT AF",
	"@mihirswrld Today 1:06 AM: Oriental Bay Drink Ups",
	"@mihirswrld Today 1:06 AM: Oriental diddy activities"
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
	"AK AA AM am AR\nAJ aa AS aE AL AT AF",
	"THAT MEANS YOU",
	"Hybrid Theory 25",
	"Thanks for Playing!",
	"SING YOUR MIND AWAY",
	"\"This is going on my playlist\" 🙏",
	"ADD YOUR MEANING TO IT",
	"AMIGA QUIERO QUE SEPAS LA IMPRESION QUE TU PRESENCIA HA CAUSADO EN MI",
	"\"MAKE NIELSEN PROUD!\""
]

var window_focused = true

var port: String = "Desktop Port" if OS.get_name() == "Windows" else "%s Port" % OS.get_name()

const GITHUB_REL_URL: String = "https://api.github.com/repos/GuayabR/Beatz-X/releases/latest"

var SONG_ID_ARR_PATH : String = "user://Custom/.songids" if OS.get_name() == "Windows" else "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/.songids"

const SETTINGS_PATH := "user://settings.json"

const POINTS_PATH := "user://.points"

const DISCORD_APP_ID: int = 1426499873607520306

var play_start_time: int

const MENU: String = "res://Scenes/main_menu.tscn"
const MAIN: String = "res://Scenes/main.tscn"
const EDITOR: String = "res://Scenes/editor.tscn"

const IMG_FORMATS: Array[Variant] = ["*.png, *.jpg, *.webp, *.svg, *.tga, *.dds. *.ktx, *.exr, *.hdr", "*.png", "*.jpg", "*.webp", "*.svg", "*.tga", "*.dds", "*.ktx", "*.exr", "*.hdr", "*"]
const AUDIO_FORMATS: Array[Variant] = ["*.mp3, *.ogg, *.wav"]
const VIDEO_FORMATS: PackedStringArray = ["*.mp4", "*.mov", "*.mkv", "*.avi", "*.webm"]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if get_tree().is_auto_accept_quit():
			EpicUserDataStore.save_file(General.SETTINGS_PATH.get_file(), JSON.stringify([Settings.settings], "\t", false))

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug_reload_scene"):
		print("------------------------------")
		print_rich("[color=orange]DEBUG: Reloading current scene[/color]")
		print("------------------------------")
		get_tree().reload_current_scene()

func _on_focus_in():
	window_focused = true
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
	
	window_focused = false
	
	bg_was_pulsing = Settings.misc.menu_bg_pulse
	if Settings.misc.advanced_fps:
		apply_fps_limit("unfocused")
		if bg_was_pulsing: Settings.misc.menu_bg_pulse = false

var bg_was_pulsing: bool = false

func _on_logged_in():
	print("Logged in successfully: product_user_id=%s" % HAuth.product_user_id)
	
	var options := EOS.Stats.IngestStatOptions.new()

	options.local_user_id = EOSGRuntime.local_product_user_id
	options.target_user_id = EOSGRuntime.local_product_user_id

	options.stats = [
		{
			"stat_name": "lifetime_points",
			"ingest_amount": Beatz.lifetime_points
		}
	]

	EOS.Stats.StatsInterface.ingest_stat(options)
	
	epic_user_info = await HAuth.get_user_info_async()
	epic_product_info = {
		"puid": EOSGRuntime.local_product_user_id,
		"epic_acc_id": EOSGRuntime.local_epic_account_id,
	}
	
	set_presence(
		"Main Menu",
		EOS.Presence.Status.Online
	)
	
	epic_logged_in.emit(epic_user_info, epic_product_info)

var epic_user_info: Dictionary
var epic_product_info: Dictionary

func _on_eos_log_msg(msg: EOS.Logging.LogMessage) -> void:
	print("SDK at %s: %s | %s" % [Time.get_unix_time_from_system(), msg.category, msg.message])

func _ready() -> void:
	print()
	print("General Global node loaded")
	
	get_viewport().connect("focus_entered", Callable(self, "_on_focus_in"))
	get_viewport().connect("focus_exited", Callable(self, "_on_focus_out"))
	
	AudioServer.set_output_device(Settings.game.output_device)
	AudioServer.set_input_device(Settings.game.input_device)
	print("Autoload setting input device to: ", Settings.game.input_device)
	
	if OS.get_name() == "Android":
		OS.request_permissions()
	
	var icon: CompressedTexture2D = preload("res://Resources/favicon.png")
	DisplayServer.set_icon(icon.get_image())
	
	ensure_songids_file_exists()
	
	### Epic Online Services Code ---------------------------------------------
	
	# Setup HEOS Logs
	HLog.log_level = HLog.LogLevel.OFF

	var credentials = HCredentials.new()
	credentials.product_name = "Beatz! X"
	credentials.product_version = "1.6.0"
	credentials.product_id = "4c3c468fe60549bb8605b19d588564cb"
	credentials.sandbox_id = "787e7aa662b0415da408b19fb43cc0b7"
	credentials.deployment_id = "5b5d344c233d4babbf91eea01e0ad575"
	credentials.client_id = "xyza78917SegqcdfrpchUl7lEFVsTckC"
	credentials.client_secret = "lJad6NZf91pF/10YbqBOQOG0N6ydnBvuGBEu0WI9X4A"
	#credentials.encryption_key = "ENCRYPTION_KEY_HERE"

	var setup_success := await HPlatform.setup_eos_async(credentials)
	if not setup_success:
		printerr("Failed to setup EOS. See logs for more details")
		return

	# Setup Logs from EOS
	HPlatform.log_msg.connect(_on_eos_log_msg)
	var log_res := HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Error)
	if not EOS.is_success(log_res):
		printerr("Failed to set logging level")
		return

	HAuth.logged_in.connect(_on_logged_in)
	
	### Rest of ready func ---------------------------------------------
	
	#"localhost:4545", "BeatzTestEOS")
	if not await HAuth.login_persistent_auth_async():
		HAuth.login_account_portal_async()

	# Or login without any credentials
	#await HAuth.login_anonymous_async(Settings.game.username)
	
	play_start_time = int(Time.get_unix_time_from_system())
	
	var drpc = null
	if OS.get_name() != "Android" and Engine.has_singleton("Discorddrpc"):
		drpc = Engine.get_singleton("Discorddrpc")
	
	if is_process_running("Discord.exe") and Settings.misc.drc and drpc:
		# this is boolean if everything worked
		drpc.app_id = DISCORD_APP_ID
		print("Discord working: " + str(drpc.get_is_discord_working()))
		# Set the first custom text row of the activity here
		drpc.details = "A rhythm game by GuayabR"
		# Set the second custom text row of the activity here
		drpc.state = "Main Menu"
		# Image key for small image from "Art Assets" from the Discord Developer website
		drpc.large_image = "beatzroundcover"
		# Tooltip text for the large image
		drpc.large_image_text = "Beatz! X - Download at beatzx.com!"
		# Image key for large image from "Art Assets" from the Discord Developer website
		drpc.small_image = "beatzroundcover"
		# Tooltip text for the small image
		drpc.small_image_text = "FEEL. YOUR RHYTHM."
		# "02:41 elapsed" timestamp for the activity
		drpc.start_timestamp = play_start_time
		# Always refresh after changing the values!
		drpc.refresh()
	else:
		print("Either discord is not running or user toggled off drc")
		if drpc:
			drpc.clear(true)
			drpc.free()

func set_presence(
	rich_text: String,
	status: int = EOS.Presence.Status.Online,
	join_info: String = "",
	data: Dictionary = {}
) -> void:
	if not EOSGRuntime.local_product_user_id: return
	
	var create_opts = EOS.Presence.CreatePresenceModificationOptions.new()

	var result = EOS.Presence.PresenceInterface.create_presence_modification(create_opts)

	if not result.has("presence_modification"):
		print("SDK Presence at %s: Failed creating presence modification" % Time.get_unix_time_from_system())
		return

	var modification: EOSGPresenceModification = result.presence_modification

	if rich_text != "":
		modification.set_raw_rich_text(rich_text)

	if join_info != "":
		modification.set_join_info(join_info)

	if not data.is_empty():
		modification.set_data(data)

	modification.set_status(status)

	var set_opts = EOS.Presence.SetPresenceOptions.new()
	set_opts.presence_modification = modification

	EOS.Presence.PresenceInterface.set_presence(set_opts)

	print(
		"SDK Presence at %s: Presence updated (%s)"
		% [Time.get_unix_time_from_system(), rich_text]
	)

func _set_rpc(details: String, state: String, large_img: String, large_img_text: String, small_img: String, small_img_text: String, start: int, end: int):
	if not Settings.misc.drc: return
	
	var drpc = null
	if OS.get_name() != "Android" and Engine.has_singleton("Discorddrpc"):
		drpc = Engine.get_singleton("Discorddrpc")
	
	if drpc == null:
		return
	
	# Set the first custom text row of the activity here
	drpc.details = details
	# Set the second custom text row of the activity here
	drpc.state = state
	# Image key for small image from "Art Assets" from the Discord Developer website
	drpc.large_image = large_img
	# Tooltip text for the large image
	drpc.large_image_text = large_img_text
	# Image key for large image from "Art Assets" from the Discord Developer website
	drpc.small_image = small_img
	# Tooltip text for the small image
	drpc.small_image_text = small_img_text
	# "02:41 elapsed" timestamp for the activity
	drpc.start_timestamp = start
	# "59:59 remaining" timestamp for the activity
	if end != 0: drpc.end_timestamp = end
	# Always refresh after changing the values!
	drpc.refresh()
	

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
		"editor":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Settings.misc.fps_main
		"unfocused":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Settings.misc.fps_unfocused
		_:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			print("Fallbacked to vsync cuz ", context, " was not recognized as a menu")
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

func rgb_to_hsv(c: Color) -> Vector3:
	var r := c.r
	var g := c.g
	var b := c.b

	var max_c = max(r, max(g, b))
	var min_c = min(r, min(g, b))
	var delta = max_c - min_c

	var h := 0.0
	var s := 0.0
	var v = max_c

	if max_c != 0.0:
		s = delta / max_c

	if delta == 0.0:
		h = 0.0
	else:
		if max_c == r:
			h = (g - b) / delta
			if g < b:
				h += 6.0
		elif max_c == g:
			h = (b - r) / delta + 2.0
		else:
			h = (r - g) / delta + 4.0

		h /= 6.0

	return Vector3(h, s, v)

func get_average_color(image_source: Variant, sample_step: int = 4) -> Color:
	var image: Image = null

	if image_source is Image:
		image = image_source

	elif image_source is Texture2D:
		image = image_source.get_image()

	else:
		push_error("Unsupported image type: %s" % [typeof(image_source)])
		return Color.BLACK

	if image == null:
		return Color.BLACK

	if image.is_empty():
		return Color.BLACK

	image.decompress()

	var width := image.get_width()
	var height := image.get_height()

	var total_r := 0.0
	var total_g := 0.0
	var total_b := 0.0
	var total_a := 0.0

	var pixel_count := 0

	for y in range(0, height, sample_step):
		for x in range(0, width, sample_step):
			var color := image.get_pixel(x, y)

			# Ignore nearly transparent pixels
			if color.a < 0.05:
				continue

			total_r += color.r
			total_g += color.g
			total_b += color.b
			total_a += color.a

			pixel_count += 1

	if pixel_count == 0:
		return Color.BLACK

	var result := Color(
		total_r / pixel_count,
		total_g / pixel_count,
		total_b / pixel_count,
		total_a / pixel_count
	)

	var hsv := rgb_to_hsv(result)

	# Increase saturation by 35%
	hsv.y = clamp(hsv.y * 1.35, 0.0, 1.0)

	# If the colour is very dark, brighten it
	if hsv.z < 0.2:
		hsv.z = lerp(hsv.z, 0.35, 0.8)

	result = hsv_to_rgb(hsv.x, hsv.y, hsv.z)
	result.a = total_a / pixel_count

	# Pure black fallback
	if result.r < 0.02 and result.g < 0.02 and result.b < 0.02:
		return Color.WHITE

	return result

func get_dominant_color(image_source: Variant, sample_step: int = 4, quantize: int = 32) -> Color:
	var image: Image = null

	if image_source is Image:
		image = image_source

	elif image_source is Texture2D:
		image = image_source.get_image()

	else:
		push_error("Unsupported image type: %s" % [typeof(image_source)])
		return Color.BLACK

	if image == null:
		return Color.WHITE

	if image.is_empty():
		return Color.WHITE

	image.decompress()

	var width := image.get_width()
	var height := image.get_height()

	var color_buckets := {}

	for y in range(0, height, sample_step):
		for x in range(0, width, sample_step):
			var color := image.get_pixel(x, y)

			# Ignore transparent pixels
			if color.a < 0.05:
				continue

			var hsv := rgb_to_hsv(color)

			# Ignore nearly grayscale/dull colors
			if hsv.y < 0.15:
				continue

			# Quantize color space
			var r := int(color.r * 255.0 / quantize) * quantize
			var g := int(color.g * 255.0 / quantize) * quantize
			var b := int(color.b * 255.0 / quantize) * quantize

			r = clamp(r, 0, 255)
			g = clamp(g, 0, 255)
			b = clamp(b, 0, 255)

			var key := "%s_%s_%s" % [r, g, b]

			if not color_buckets.has(key):
				color_buckets[key] = {
					"count": 0,
					"color": Color8(r, g, b)
				}

			# Boost vibrant colors slightly
			var weight := 1.0 + (hsv.y * 1.5) + (hsv.z * 0.5)

			color_buckets[key]["count"] += weight

	if color_buckets.is_empty():
		print("No colours getting average as fallback")
		return get_average_color(image_source, sample_step)

	var best_bucket = null
	var best_score := -1.0

	for bucket in color_buckets.values():
		if bucket["count"] > best_score:
			best_score = bucket["count"]
			best_bucket = bucket

	var result: Color = best_bucket["color"]

	var hsv := rgb_to_hsv(result)

	# Make dominant colours pop more
	hsv.y = clamp(hsv.y * 1.4, 0.0, 1.0)

	# Avoid extremely dark colours
	if hsv.z < 0.2:
		hsv.z = lerp(hsv.z, 0.4, 0.8)

	result = hsv_to_rgb(hsv.x, hsv.y, hsv.z)

	# Pure black fallback
	if result.r < 0.02 and result.g < 0.02 and result.b < 0.02:
		return Color.WHITE

	return result


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

func hsv_to_rgb(h, s, v, a = 1):
	#based on code at
	#http://stackoverflow.com/questions/51203917/math-behind-hsv-to-rgb-conversion-of-colors
	var r
	var g
	var b

	var i = floor(h * 6)
	var f = h * 6 - i
	var p = v * (1 - s)
	var q = v * (1 - f * s)
	var t = v * (1 - (1 - f) * s)

	match (int(i) % 6):
		0:
			r = v
			g = t
			b = p
		1:
			r = q
			g = v
			b = p
		2:
			r = p
			g = v
			b = t
		3:
			r = p
			g = q
			b = v
		4:
			r = t
			g = p
			b = v
		5:
			r = v
			g = p
			b = q
	return Color(r, g, b, a)

func _yuv_to_image(y_data: PackedByteArray, u_data: PackedByteArray, v_data: PackedByteArray, res: Vector2i) -> Image:
	var w := res.x
	var h := res.y
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)

	# Very simplified YUV420p → RGB conversion (approximation)
	# Works fine for preview thumbnails
	for y in range(h):
		for x in range(w):
			var Y = y_data[y * w + x]
			@warning_ignore("integer_division")
			var U = u_data[(y / 2) * (w / 2) + (x / 2)] - 128
			@warning_ignore("integer_division")
			var V = v_data[(y / 2) * (w / 2) + (x / 2)] - 128
			var r = clamp(Y + 1.402 * V, 0, 255)
			var g = clamp(Y - 0.344136 * U - 0.714136 * V, 0, 255)
			var b = clamp(Y + 1.772 * U, 0, 255)
			img.set_pixel(x, y, Color8(r, g, b))

	return img

func delete_folder_recursive(path: String) -> void:
	var dir := DirAccess.open(path)

	if dir == null:
		return

	dir.list_dir_begin()

	var file_name = dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path.path_join(file_name)

			if dir.current_is_dir():
				delete_folder_recursive(full_path)
				DirAccess.remove_absolute(full_path)
			else:
				DirAccess.remove_absolute(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()

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

		if abs_src_path == abs_dst_path:
			push_warning("Source and destination are the same file, skipping copy.")
			return
		
		var dst_dir := abs_dst_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dst_dir):
			DirAccess.make_dir_recursive_absolute(dst_dir)
		
		var cmd := 'copy /Y "%s" "%s"' % [abs_src_path, abs_dst_path]
		var args := ["/c", cmd]

		print("Doing cmd ", cmd)
		var result := OS.execute("cmd", args, output, true)
		print("Result ", result)
		print("Out ", output)

		if result == 0:
			print("Successfully copied video using OS command.")
		else:
			push_warning("OS copy failed, falling back.")
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
	if src == dst:
		push_warning("Source and destination are the same file so no copy needed")
		return

	
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

func save_or_replace_song_id(new_id_line: String) -> void:
	var file_name_part = new_id_line.trim_prefix("SONGID ").split(" ")[0]

	var file = FileAccess.open(General.SONG_ID_ARR_PATH, FileAccess.READ)
	var lines := []
	if file:
		var text := ""
		if file.get_length() > 0:
			text = file.get_as_text()
		lines = text.split("\n")

	var updated_lines := []
	var replaced := false

	for line in lines:
		if line.begins_with("SONGID "):
			var existing_file_name = line.trim_prefix("SONGID ").split(" ")[0]
			if existing_file_name == file_name_part:
				#print("Replacing existing song ID: ", line)
				updated_lines.append(new_id_line)
				replaced = true
			else:
				updated_lines.append(line)
		elif line.strip_edges() != "":
			updated_lines.append(line)

	if not replaced:
		updated_lines.append(new_id_line)

	var out_file = FileAccess.open(General.SONG_ID_ARR_PATH, FileAccess.WRITE)
	if out_file:
		out_file.store_string("\n".join(updated_lines) + "\n")
		out_file.close()
	else:
		print("Failed to open SONG_ID_ARR_PATH for writing")

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
			regex.compile(r"((?:S)?[LRUD]{1,2}|E||S|RND)/(-?\d*\.?\d+)(?:!([^,]+))?")
			var result := regex.search(note_str)
			if result == null:
				continue
				
			var type_char := result.get_string(1)
			var timestamp := float(result.get_string(2))
			var properties_str := result.get_string(3)
			
			var note_type := ""
			if type_char == "E":
				note_type = "Effect"
			elif type_char == "S":
				note_type = "Section"
			elif type_char == "RND":
				note_type = "Random"
			else:
				note_type = _capitalize_first_letter(REVERSE_NOTE_TYPE_MAP.get(type_char, type_char))
				
			var note := {
				"id": generate_note_id(),
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

func generate_note_id() -> String:
	var id = str(Time.get_ticks_usec()) + "_" + str(randi())
	return id
