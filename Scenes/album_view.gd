extends Control

var selected_album: String
var selected_artist: String
var selected_year: int

var selected_cover: Image = Image.load_from_file("res://Resources/BeatzCoverX.png")

var song_number: int = 1  # Counter for songs

var streams := []  # Stores AudioStreamMP3 for each item

signal went_back
signal song_sel
signal item_context_menu(meta: String, pos: Vector2, idx: int)
signal item_context_menu_focus_released

signal item_play_as_bg(path)

signal loading_song(title: String)
signal loaded_song_meta(title: String)
signal loaded_song(title: String)

var add_queue := []
var processing_index := 0
var grouped_songs := {}

var song_info: Array = []
var difficulty_order := [
	"easy", "normal", "hard", "extreme", "insanity", "impossible"
]

var all_items: Array = []

signal loaded_charts

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	$bg.modulate = Color(Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness)
	
	if selected_album: load_album()
	
	if Settings.misc.menu_bg_img_path != "":
		var img := Image.load_from_file(Settings.misc.menu_bg_img_path)
		if img: # make sure it loaded
			var tex := ImageTexture.create_from_image(img)
			$TransitionRect.texture = tex
		else:
			print("Failed to load image at path:", Settings.misc.menu_bg_img_path)

func _process(_delta) -> void:
	if add_queue.is_empty():
		return
	
	var item = add_queue[processing_index]
	processing_index += 1
	
	if item["type"] == "entry":
		var entry = item["entry"]
		var idx = list.add_item(entry["text"], entry["cover"])
		list.set_item_metadata(idx, entry["metadata"])
		list.set_item_tooltip_enabled(idx, false)
		print("Added item ", idx)
	
	if processing_index >= add_queue.size():
		for i in range(list.get_item_count()):
			all_items.append({
				"text": list.get_item_text(i),
				"icon": list.get_item_icon(i),
				"metadata": list.get_item_metadata(i),
				"disabled": list.is_item_disabled(i),
			})
		print("Done")
		# Once done, stop processing
		set_process(false)

func load_album():
	print("Loading album charts")
	$album_side/names/album_name.text = selected_album
	$album_side/names/album_artist.text = selected_artist
	$album_side/names/album_year.text = str(selected_year)
	
	$album_side/cover_anim_cont/outline/mask/cover.texture = ImageTexture.create_from_image(selected_cover)
	$album_side/bg_cover_rotation_cont/bg_cover/mask/cover.texture = ImageTexture.create_from_image(selected_cover)
	
	var cols: Array[Color] = General.extract_dominant_colors(selected_cover)
	$album_side/cover_anim_cont/outline/Visualizer.colors = cols as Array[Color]
	
	if not cols.is_empty(): 
		$charts_side/Line2D.modulate = cols.pick_random()
		
		var brightest_color: Color = cols[0]
		var max_value = cols[0].r + cols[0].g + cols[0].b

		for color in cols:
			var value = color.r + color.g + color.b
			if value > max_value:
				max_value = value
				brightest_color = color
				print("new bright ", brightest_color)

		$bg.self_modulate = brightest_color
	else: 
		$charts_side/Line2D.modulate = Color.WHITE
		$bg.self_modulate = Color.WHITE
	
	set_process(true)
	_load_songs(selected_album)
	
	loaded_charts.emit()
	
	$init.play("init")

@onready var list = $charts_side/song_list

var scan_threads := []
var scan_results := []
var scan_mutex := Mutex.new()

func emit_loaded(type: int, title: String):
	match type:
		0: loading_song.emit(title)
		1: loaded_song_meta.emit(title)
		2: loaded_song.emit(title)

func _load_songs(album_filter: String):
	list.clear()
	add_queue.clear()
	processing_index = 0
	grouped_songs = {}

	print("Starting song scan", " for album: " + album_filter)

	# Scan user://Custom folders with info.json bundles
	var base_custom_dir: DirAccess
	if OS.get_name() == "Android":
		base_custom_dir = DirAccess.open("storage/emulated/0/Android/data/com.guayabr.beatzx/Custom")
	else:
		base_custom_dir = DirAccess.open("user://Custom")

	if base_custom_dir:
		base_custom_dir.list_dir_begin()
		var entry_name := base_custom_dir.get_next()
		while entry_name != "":
			if base_custom_dir.current_is_dir() and entry_name != "Charts":
				var folder_path = "user://Custom/" + entry_name if OS.get_name() == "Windows" else "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/" + entry_name

				# If album filter is active, check info.json first before starting a thread
				if album_filter != null:
					var info_path = folder_path + "/info.json"
					if FileAccess.file_exists(info_path):
						var file := FileAccess.open(info_path, FileAccess.READ)
						if file:
							var content := file.get_as_text()
							file.close()
							var parsed = JSON.parse_string(content)
							if parsed and parsed.has("info"):
								var album_name := str(parsed["info"].get("album", ""))
								if album_name == album_filter:
									_start_scan_thread(folder_path)
					else:
						# If info.json missing, skip
						pass
			entry_name = base_custom_dir.get_next()
		base_custom_dir.list_dir_end()
	else:
		print_debug("Failed to open custom songs directory.")

	# Wait for all scanning threads to finish
	for thread in scan_threads:
		thread.wait_to_finish()
	scan_threads.clear()

	# Finalize data
	for data in scan_results:
		_finalize_custom_folder_entry(data)
	scan_results.clear()

	# Merge and sort
	var all_entries: Array = []
	for diff_entries in grouped_songs.values():
		all_entries.append_array(diff_entries)
	all_entries.sort_custom(func(a, b):
		return a["metadata"]["song_name"].to_lower() < b["metadata"]["song_name"].to_lower()
	)

	# Add to queue
	for entry in all_entries:
		add_queue.append({"type": "entry", "entry": entry})

	print("Queued %d songs%s" % [
		add_queue.size(),
		( " (album: %s)" % album_filter if album_filter != "" else "")
	])

func _start_scan_thread(folder_path: String) -> void:
	var thread = Thread.new()
	scan_threads.append(thread)
	thread.start(Callable(self, "_thread_scan_folder").bind(folder_path), Thread.PRIORITY_LOW)

func _thread_scan_folder(folder_path: String) -> void:
	var data: Dictionary = _scan_custom_folder_data(folder_path)
	if not data.is_empty():
		scan_mutex.lock()
		scan_results.append(data)
		scan_mutex.unlock()

# THREAD-SAFE: Reads files and returns a data dictionary with pure data (no textures or streams)
func _scan_custom_folder_data(folder: String) -> Dictionary:
	print("Scanning ", folder)
	var _data: Dictionary[Variant, Variant] = {}

	var info_path := folder + "/info.json"
	if not FileAccess.file_exists(info_path):
		return {}

	var file_name := folder.get_file()
	
	call_deferred_thread_group("emit_loaded", 0, file_name)

	var id_file_path := folder + "/.songid"
	var id: String

	if FileAccess.file_exists(id_file_path):
		var id_file := FileAccess.open(id_file_path, FileAccess.READ)
		if id_file:
			id = id_file.get_as_text().strip_edges()
			id_file.close()
		else:
			print("Failed to read .songid file at: ", id_file_path)
			return {}
	else:
		id = "SONGID " + file_name + " " + str(Time.get_unix_time_from_system(), "_", randi())
		var id_file := FileAccess.open(id_file_path, FileAccess.WRITE)
		if id_file:
			id_file.store_line(id)
			id_file.close()
			print("Generated new .songid for folder: ", folder)
		else:
			print("Failed to create .songid file at: ", id_file_path)
			return {}

	var info_file := FileAccess.open(info_path, FileAccess.READ)
	if not info_file:
		return {}

	var info_text := info_file.get_as_text()
	info_file.close()

	var info_json = JSON.parse_string(info_text)
	if info_json == null or not info_json.has("info"):
		return {}

	# Make a deep copy so we can detect changes later
	var original_info = info_json["info"].duplicate(true)
	var info = original_info.duplicate(true)

	var song_title = info.get("title", "Unknown Title")
	var artist_name = info.get("artist", "Unknown Artist")
	var album_name = info.get("album", "Unknown Album")
	var year = info.get("year", 0)
	
	call_deferred_thread_group("emit_loaded", 1, file_name)
	
	var dir := DirAccess.open(folder)
	if dir == null:
		return {}
	
	var audio_path = info.get("audio", "")
	var image_path = info.get("cover", "")
	var beatz_path = info.get("chart", "")
	var background = folder + "/" + info.get("background", "")
	var diff_texture_path = info.get("diff_texture", "")
	
	var vid_path = info.get("video", "")
	
	var difficulty
	var nspeed
	var bpm
	var charter
	var chart_name
	var beat_offset
	
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".beatz"):
			beatz_path = folder + "/" + file
			if not info.has("chart"): info["chart"] = file
			
			var beatz_file = FileAccess.open(beatz_path, FileAccess.READ)
			if not beatz_file:
				print("Couldn't read beatz file in: %s" % folder)
				return {}

			var beatz_content := beatz_file.get_as_text()
			beatz_file.close()
			
			var beatz: Dictionary = General.import_beatz_file(beatz_content)
			
			difficulty = beatz["difficulty"]
			nspeed = beatz["note_speed"]
			bpm = beatz["bpm"]
			charter = beatz["charter"]
			chart_name = beatz["chart_name"]
			beat_offset = beatz["local_beat_offset"]
		elif file.ends_with(".mp3") or file.ends_with(".ogg") or file.ends_with(".wav"):
			audio_path = folder + "/" + file
			if not info.has("audio"): info["audio"] = file
		elif file.ends_with(".png") or file.ends_with(".jpg") or file.ends_with(".jpeg"):
			if file.get_basename() == General._sanitize(album_name): 
				image_path = folder + "/" + file
				if not info.has("cover"): info["cover"] = file
			if file.get_file().trim_suffix(".png") == difficulty: 
				diff_texture_path = folder + "/" + file
				if not info.has("difficulty_texture"): info["difficulty_texture"] = file
		file = dir.get_next()
	dir.list_dir_end()
	
	if info != original_info:
		info_json["info"] = info
		var save_file := FileAccess.open(info_path, FileAccess.WRITE)
		if save_file:
			save_file.store_string(JSON.stringify(info_json, "\t")) # pretty print
			save_file.close()
			print("✅ Updated info.json in: ", folder)
		else:
			print("❌ Failed to open info.json for writing in: ", folder)
		
	if beatz_path == "" or audio_path == "":
		print("Skipping folder: %s (missing required files)" % folder)
		return {}
	
	call_deferred_thread_group("emit_loaded", 2, file_name)
	
	return {
		"id": id,
		"song_title": song_title,
		"artist_name": artist_name,
		"album_name": album_name,
		"year": year,
		"bpm": bpm,
		"charter": charter,
		"chart_name": chart_name,
		"speed": nspeed,
		"audio_path": audio_path,
		"image_path": image_path,
		"beatz_path": beatz_path,
		"local_beat_offset": beat_offset,
		"difficulty": difficulty,
		"diff_texture_path": diff_texture_path,
		"background": background,
		"video": vid_path
	}

# MUST BE CALLED ON MAIN THREAD:
# Creates textures, loads audio stream, adds entry to grouped_songs
func _finalize_custom_folder_entry(data: Dictionary) -> void:
	if data.is_empty():
		return
	
	var audio_path = data["audio_path"]
	var image_path = data["image_path"]
	var beatz_path = data["beatz_path"]
	var difficulty = data["difficulty"]
	var diff_texture = data["diff_texture_path"]
	var song_title = data["song_title"]
	var artist_name = data["artist_name"]
	var album_name = data["album_name"]
	var year = data["year"]
	var id = data["id"]
	var bpm = data["bpm"]
	var charter = data["charter"]
	var chart_name = data["chart_name"]
	var speed = data["speed"]
	var beat_offset = data["local_beat_offset"]
	
	var background = data["background"]
	
	var video = data["video"]
	
	print("scanning ", beatz_path)
	
	var audio_ext = audio_path.get_extension().to_lower()
	
	#var stream
	#if audio_ext == "mp3":
		#stream = AudioStreamMP3.load_from_file(audio_path)
	#elif audio_ext == "ogg":
		#stream = AudioStreamOggVorbis.load_from_file(audio_path)
	#elif audio_ext == "wav":
		#stream = AudioStreamWAV.load_from_file(audio_path)
	
	if audio_ext not in  ["mp3", "ogg", "wav"]:
		print("Unsupported audio format in: %s" % audio_path)
	
	var cover_texture
	
	if image_path != "" and FileAccess.file_exists(image_path):
		var img := Image.new()
		var err := img.load(image_path)
		if err == OK:
			cover_texture = ImageTexture.create_from_image(img)
		else:
			print("Failed to load image at %s, using default cover." % image_path)
			cover_texture = load("res://Resources/Covers/noCover.png")
	else:
		print("No image found for %s, using default cover." % album_name)
		cover_texture = load("res://Resources/Covers/noCover.png")

	var text = "%s | %s, by %s | %d\n\nChart: %s | \"%s\" by %s | Custom" % [
		album_name,
		song_title,
		artist_name,
		year,
		difficulty.to_pascal_case(),
		chart_name,
		charter
	]

	var entry := {
		"text": text,
		"cover": cover_texture,
		"metadata": {
			"beatz_path": beatz_path,
			"id": id,
			"song_name": song_title,
			"album": album_name,
			"artist": artist_name,
			"year": year,
			"diff_texture_path": diff_texture,
			"bpm": bpm,
			"charter": charter,
			"speed": speed,
			"cover_texture": cover_texture,
			"stream": audio_path,
			"local_beat_offset": beat_offset,
			"selected_background": background,
			"background_vid": beatz_path.get_base_dir().path_join(video) if video != "" else ""
		}
	}
	
	add_queue.append({"type": "entry", "entry": entry})

var scroll_tween: Tween
var scroll_velocity := 0.0
var last_scroll_time := 0.0

func _on_song_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Settings.misc.smooth_scrolls:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var scroll_bar = $charts_side/song_list.get_v_scroll_bar()
			if not scroll_bar:
				return

			# Prevent default ItemList scroll behavior
			get_viewport().set_input_as_handled()

			var now := Time.get_ticks_msec() / 1000.0
			var delta_time := now - last_scroll_time
			last_scroll_time = now

			# Calculate base scroll strength
			var base_amount := 110.0
			var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			var mult := 0.8

			# Apply momentum: quick consecutive scrolls add up
			if delta_time < 0.07:
				scroll_velocity += base_amount * direction * mult
			else:
				scroll_velocity = base_amount * direction

			# Clamp velocity
			scroll_velocity = clampf(scroll_velocity, -5000.0, 5000.0)

			# Calculate target position
			var target_value := clampf(scroll_bar.value + scroll_velocity, scroll_bar.min_value, scroll_bar.max_value)

			# Restart tween but keep velocity-based duration
			if scroll_tween and scroll_tween.is_running():
				scroll_tween.kill()

			var duration := clampf(abs(scroll_velocity) / 1200.0, 0.3, 1.5)

			scroll_tween = create_tween()
			scroll_tween.tween_property(scroll_bar, "value", target_value, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

			# Slowly decay velocity over time
			scroll_tween.finished.connect(func():
				scroll_velocity *= 0.5
			)

func _on_song_selected(index: int) -> void:
	if !list.is_item_selectable(index) or list.is_item_disabled(index):
		return
	
	var lose_focus: bool = true
	
	if lose_focus: list.release_focus()
	
	if Settings.misc.reduce_motion:
		$".."/AnimationPlayer.play("go_to_selected", -1, 100.0)
	else:
		$".."/AnimationPlayer.play("go_to_selected")
	
	song_sel.emit()
	
	$".."/click_sfx.play()
	
	var metadata = list.get_item_metadata(index)
	
	print(metadata)
	
	var beatz_path = metadata["beatz_path"]
	var song_name = metadata["song_name"]
	var album = metadata["album"]
	var cover_texture = metadata["cover_texture"]
	var diff_texture_path = metadata["diff_texture_path"]
	var artist = metadata["artist"]
	var year = metadata["year"]
	var bpm = metadata["bpm"]
	var charter = metadata["charter"]
	var selected_stream = metadata["stream"]
	var selected_beat_offset = metadata["local_beat_offset"]
	
	var selected_background = metadata["selected_background"]
	
	var background_vid_path = metadata["background_vid"]
	
	#var speed = metadata["speed"]
	# Ignore separators (they have no metadata or missing stream)
	if metadata == null or !metadata.has("stream"):
		print("Selected item is a separator or missing data")
		return
	
	list.mouse_filter = MOUSE_FILTER_IGNORE
	
	if metadata:
		await get_tree().create_timer(1.4).timeout
		
		print("Selected song: %s by %s (%d) from album %s" % [song_name, artist, year, album])
		
		var beatz_file := FileAccess.open(beatz_path, FileAccess.READ)
		var content := beatz_file.get_as_text()
		var beatz_data := General.import_beatz_file(content)
		
		var main = load("res://Scenes/selected_song.tscn").instantiate() # Load selected song scene and set all of the song variables
		main.set("selected_stream_path", selected_stream)
		main.set("selected_title", song_name)
		main.set("selected_album", album)
		
		main.set("selected_cover", cover_texture.get_image())
		main.set("selected_artist", artist)
		main.set("selected_year", year)
		
		main.set("start_wait", beatz_data["start_wait"])
		main.set("preview_start", beatz_data["preview_start"])
		main.set("preview_end", beatz_data["preview_end"])
		
		main.set("selected_difficulty", beatz_data["difficulty"])
		main.set("selected_diff_texture", diff_texture_path)
		main.set("notes", beatz_data["notes"])
		main.set("selected_chart_name", beatz_data["chart_name"])
		
		main.set("selected_beatz_path", beatz_path)
		
		main.set("selected_beat_offset", selected_beat_offset)
		
		main.set("background_vid_path", background_vid_path)
		
		if selected_background:
			main.set("selected_background", Image.load_from_file(selected_background))
			main.set("selected_background_name", selected_background.get_file())
			print(selected_background.get_file())
			print(Image.load_from_file(selected_background))
		
		main.set("selected_bpm", bpm)
		main.set("selected_charter", charter)
		
		get_tree().root.add_child(main)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main

	else:
		print("No metadata found for song list item: ", index) # If no metadata found, return to main menu
		print(selected_stream)
		print(metadata)
		
		if !Settings.misc.reduce_motion: await get_tree().create_timer(1.4).timeout
		
		var main = load("res://Scenes/main_menu.tscn").instantiate()
		get_tree().root.add_child(main)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main

func _on_song_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		item_context_menu.emit($charts_side/song_list.get_item_metadata(index), at_position, index)
	elif mouse_button_index == MOUSE_BUTTON_MIDDLE:
		item_play_as_bg.emit($charts_side/song_list.get_item_metadata(index).stream)


func _on_song_list_item_selected(index: int) -> void:
	_on_song_selected(index)

func _on_song_list_item_activated(index: int) -> void:
	_on_song_selected(index)
