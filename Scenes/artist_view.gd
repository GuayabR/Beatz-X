extends Control

var selected_artist: String

var streams := []  # Stores AudioStreamMP3 for each item

signal went_back
signal song_sel
signal item_context_menu(meta: Dictionary, pos: Vector2, idx: int)
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
	"easy", "normal", "hard", "extreme", "insanity", "impossible", "deathly"
]

var all_items: Array = []

signal loaded_charts

func _ready():
	$bg.modulate = Color(Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness)
	
	if selected_artist: load_artist()
	
	if Settings.misc.menu_bg_img_path != "":
		var img := Image.load_from_file(Settings.misc.menu_bg_img_path)
		if img: # make sure it loaded
			var tex := ImageTexture.create_from_image(img)
			if has_node("TransitionRect"):
				$TransitionRect.texture = tex
		else:
			print("Failed to load image at path:", Settings.misc.menu_bg_img_path)

func _process(_delta) -> void:
	if not scan_finished:
		return

	if processing_index < pending_scan_results.size():
		var data: Dictionary = pending_scan_results[processing_index]
		_finalize_custom_folder_entry(data)
		var entry_data: Dictionary = add_queue[add_queue_index]["entry"]
		var item_index: int = list.add_item(entry_data["text"], entry_data["cover"])
		list.set_item_metadata(item_index, entry_data["metadata"])
		list.set_item_tooltip_enabled(item_index, false)
		all_items.append({
			"text": entry_data["text"],
			"icon": entry_data["cover"],
			"metadata": entry_data["metadata"],
			"disabled": false,
		})
		processing_index += 1
		add_queue_index += 1
		_update_song_loading_progress()
		return

	_finish_artist_loading()

func load_artist():
	print("Loading artist's charts")
	if not loading_screen_active:
		prepare_artist_loading(selected_artist)
	$top_intro/artist_name.text = selected_artist
	
	#var cols: Array[Color] = General.extract_dominant_colors(selected_cover)
	#$album_side/cover_anim_cont/outline/Visualizer.colors = cols as Array[Color]
	#
	#if not cols.is_empty(): 
		#$charts_side/Line2D.modulate = cols.pick_random()
		#
		#var brightest_color: Color = cols[0]
		#var max_value = cols[0].r + cols[0].g + cols[0].b
#
		#for color in cols:
			#var value = color.r + color.g + color.b
			#if value > max_value:
				#max_value = value
				#brightest_color = color
				#print("new bright ", brightest_color)
#
		#$bg.self_modulate = brightest_color
	#else: 
		#$charts_side/Line2D.modulate = Color.WHITE
		#$bg.self_modulate = Color.WHITE
	
	set_process(true)
	_load_songs(selected_artist.to_lower())
	
	loaded_charts.emit()

@onready var list = $song_list

var scan_threads := []
var scan_results := []
var scan_mutex := Mutex.new()
var pending_scan_results: Array[Dictionary] = []
var remaining_scan_threads: int = 0
var scan_finished: bool = false
var loading_complete: bool = false
var add_queue_index: int = 0
var loading_screen_active: bool = false
var loading_screen_tween: Tween

func prepare_artist_loading(artist_name: String) -> void:
	selected_artist = artist_name
	loading_screen_active = true
	$top_intro/artist_name.text = artist_name
	$TransitionRect.show()
	$TransitionRect.modulate = Color.TRANSPARENT
	$center_bottom/loading_text.text = "Searching for songs by artist..."
	$center_bottom/loading_text.show()
	$center_bottom/loading_text.modulate = Color.TRANSPARENT
	$center_bottom/loading_progress.indeterminate = true
	$center_bottom/loading_progress.value = 0.0
	$center_bottom/loading_progress.show()
	$center_bottom/loading_progress.modulate = Color.TRANSPARENT
	if loading_screen_tween and loading_screen_tween.is_running():
		loading_screen_tween.kill()
	loading_screen_tween = create_tween().set_parallel()
	loading_screen_tween.tween_property($TransitionRect, "modulate", Color.WHITE, 0.5)
	loading_screen_tween.tween_property($center_bottom/loading_text, "modulate", Color.WHITE, 0.5)
	loading_screen_tween.tween_property($center_bottom/loading_progress, "modulate", Color.WHITE, 0.5)

func _finish_loading_screen_fade() -> void:
	if not loading_complete:
		return
	$center_bottom/loading_text.hide()
	$center_bottom/loading_progress.hide()
	$TransitionRect.hide()
	loading_screen_active = false

func emit_loaded(type: int, title: String):
	match type:
		0:
			loading_song.emit(title)
			$center_bottom/loading_text.text = "Searching artist folder:\n%s" % title
		1:
			loaded_song_meta.emit(title)
			$center_bottom/loading_text.text = "Reading song metadata:\n%s" % title
		2:
			loaded_song.emit(title)

var cover_loop_sources: Dictionary = {}
var cover_loop_values: Array[String] = []
var average_cover_loop: String = ""

func _load_songs(artist: String):
	list.clear()
	add_queue.clear()
	all_items.clear()
	scan_threads.clear()
	scan_results.clear()
	pending_scan_results.clear()
	processing_index = 0
	add_queue_index = 0
	remaining_scan_threads = 0
	scan_finished = false
	loading_complete = false
	grouped_songs.clear()
	cover_loop_values.clear()
	cover_loop_sources.clear()
	average_cover_loop = ""

	$center_bottom/loading_text.text = "Searching for songs by artist..."
	$center_bottom/loading_progress.indeterminate = true
	print("Starting threaded song scan for artist: ", artist)

	var custom_path: String
	if OS.get_name() == "Android":
		custom_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom"
	else:
		custom_path = "user://Custom"

	var base_custom_dir: DirAccess = DirAccess.open(custom_path)
	if base_custom_dir == null:
		push_error("Failed to open custom songs directory at '%s': %s" % [
			custom_path,
			error_string(DirAccess.get_open_error())
		])
		_finish_song_scan()
		return

	base_custom_dir.list_dir_begin()
	var entry_name: String = base_custom_dir.get_next()
	while entry_name != "":
		if base_custom_dir.current_is_dir() and entry_name != "Charts":
			_start_scan_thread(custom_path.path_join(entry_name), artist)
		entry_name = base_custom_dir.get_next()
	base_custom_dir.list_dir_end()

	if remaining_scan_threads == 0:
		_finish_song_scan()


func _start_scan_thread(folder_path: String, artist_filter: String) -> void:
	var thread: Thread = Thread.new()
	var error: Error = thread.start(
		Callable(self, "_thread_scan_folder").bind(folder_path, artist_filter),
		Thread.PRIORITY_LOW
	)
	if error != OK:
		push_error("Failed to start artist song scan for '%s': %s" % [
			folder_path,
			error_string(error)
		])
		return
	scan_threads.append(thread)
	remaining_scan_threads += 1


func _thread_scan_folder(folder_path: String, artist_filter: String) -> void:
	var data: Dictionary = _scan_custom_folder_data(folder_path, artist_filter)
	if not data.is_empty():
		scan_mutex.lock()
		scan_results.append(data)
		scan_mutex.unlock()
	call_deferred("_on_scan_thread_finished", not data.is_empty())


func _on_scan_thread_finished(song_found: bool) -> void:
	remaining_scan_threads -= 1
	if song_found:
		scan_mutex.lock()
		var found_count: int = scan_results.size()
		scan_mutex.unlock()
		$center_bottom/loading_text.text = "Found %d matching song(s)..." % found_count
	if remaining_scan_threads <= 0:
		_finish_song_scan()


func _finish_song_scan() -> void:
	if scan_finished:
		return
	scan_finished = true

	for thread: Thread in scan_threads:
		thread.wait_to_finish()
	scan_threads.clear()

	scan_mutex.lock()
	pending_scan_results.clear()
	for scan_data in scan_results:
		pending_scan_results.append(scan_data)
	scan_results.clear()
	scan_mutex.unlock()

	pending_scan_results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("song_title", "")).to_lower() < str(b.get("song_title", "")).to_lower()
	)

	$center_bottom/loading_progress.indeterminate = false
	$center_bottom/loading_progress.max_value = maxf(float(pending_scan_results.size()), 1.0)
	$center_bottom/loading_progress.value = 0.0
	if pending_scan_results.is_empty():
		$center_bottom/loading_text.text = "No songs found for this artist."
	else:
		$center_bottom/loading_text.text = "Loading 0/%d songs..." % pending_scan_results.size()

	print("Artist scan complete: %d song(s) for '%s'" % [
		pending_scan_results.size(),
		selected_artist
	])
	set_process(true)


func _update_song_loading_progress() -> void:
	$center_bottom/loading_progress.value = processing_index
	$center_bottom/loading_text.text = "Loaded %d/%d songs..." % [
		processing_index,
		pending_scan_results.size()
	]


func _finish_artist_loading() -> void:
	if loading_complete:
		return
	loading_complete = true
	$center_bottom/loading_progress.value = $center_bottom/loading_progress.max_value
	if processing_index > 0:
		$center_bottom/loading_text.text = "Loaded %d song(s)." % processing_index
	else:
		$center_bottom/loading_text.text = "No songs found for this artist."
	print("Loaded %d songs for artist '%s'" % [processing_index, selected_artist])
	set_process(false)
	loaded_charts.emit()
	if loading_screen_tween and loading_screen_tween.is_running():
		loading_screen_tween.kill()
	loading_screen_tween = create_tween().set_parallel()
	loading_screen_tween.tween_property($TransitionRect, "modulate", Color.TRANSPARENT, 0.5)
	loading_screen_tween.tween_property($center_bottom/loading_text, "modulate", Color.TRANSPARENT, 0.5)
	loading_screen_tween.tween_property($center_bottom/loading_progress, "modulate", Color.TRANSPARENT, 0.5)
	loading_screen_tween.finished.connect(_finish_loading_screen_fade)

# THREAD-SAFE: Reads files and returns a data dictionary with pure data (no textures or streams)
func _scan_custom_folder_data(folder: String, artist_filter: String) -> Dictionary:
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

	var filter_info: Variant = info_json["info"]
	if typeof(filter_info) != TYPE_DICTIONARY:
		return {}
	var matching_artists: Array[String] = General.artist_names_from_info(filter_info)
	var requested_artist := artist_filter.strip_edges().to_lower()
	var artist_matches := false
	for artist_name: String in matching_artists:
		if artist_name.to_lower() == requested_artist:
			artist_matches = true
			break
	if not artist_matches:
		return {}

	# Make a deep copy so we can detect changes later
	var original_info = info_json["info"].duplicate(true)
	var info = original_info.duplicate(true)

	var song_title = info.get("title", "Unknown Title")
	var artists: Array[String] = General.artist_names_from_info(info)
	var artist_name := str(info.get("artist", ""))
	if artist_name.strip_edges() == "":
		artist_name = General.artist_credit_from_names(artists)
	if artist_name == "":
		artist_name = "Unknown Artist"
	var album_name = info.get("album", "Unknown Album")
	var year = info.get("year", 0)
	
	call_deferred_thread_group("emit_loaded", 1, file_name)
	
	var dir := DirAccess.open(folder)
	if dir == null:
		return {}
	
	var audio_path = info.get("audio", "")
	var image_path = info.get("cover", "")
	var beatz_path = info.get("chart", "")
	var background_name = str(info.get("background", ""))
	var background = folder.path_join(background_name) if background_name != "" else ""
	var diff_texture_path = info.get("diff_texture", "")
	
	var vid_path = info.get("video", "")
	
	var cover_loop = info.get("cover_loop", "")

	if audio_path != "" and not FileAccess.file_exists(audio_path):
		var resolved_audio := folder.path_join(audio_path)
		if FileAccess.file_exists(resolved_audio):
			audio_path = resolved_audio
	if beatz_path != "" and not FileAccess.file_exists(beatz_path):
		var resolved_chart := folder.path_join(beatz_path)
		if FileAccess.file_exists(resolved_chart):
			beatz_path = resolved_chart
	if image_path != "" and not FileAccess.file_exists(image_path):
		var resolved_cover := folder.path_join(image_path)
		if FileAccess.file_exists(resolved_cover):
			image_path = resolved_cover
	if diff_texture_path != "":
		var resolved_diff := folder.path_join(diff_texture_path)
		if FileAccess.file_exists(resolved_diff):
			diff_texture_path = resolved_diff
	
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
		"artists": artists,
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
		"video": vid_path,
		"cover_loop": cover_loop
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
	
	var cover_loop = data["cover_loop"]
	if cover_loop != "":
		cover_loop_values.append(cover_loop)
		if not cover_loop_sources.has(cover_loop):
			cover_loop_sources[cover_loop] = []
		cover_loop_sources[cover_loop].append(beatz_path.get_base_dir())
	
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

	var text = "%s | %s, by %s | %d\n\nChart: %s | \"%s\" by %s | Custom" % [
		album_name,
		song_title,
		artist_name,
		year,
		difficulty.to_pascal_case(),
		chart_name,
		charter
	]

	var cover_texture: Texture2D = preload("res://Resources/misc/noCover.png")
	if image_path != "" and FileAccess.file_exists(image_path):
		var cover_image := Image.load_from_file(image_path)
		if cover_image:
			cover_texture = ImageTexture.create_from_image(cover_image)

	var entry := {
		"text": text,
		"cover": cover_texture,
		"metadata": {
			"beatz_path": beatz_path,
			"id": id,
			"song_name": song_title,
			"album": album_name,
			"artist": artist_name,
			"artists": data.get("artists", []),
			"year": year,
			"diff_texture_path": diff_texture,
			"bpm": bpm,
			"charter": charter,
			"speed": speed,
			"cover_path": image_path,
			"stream": audio_path,
			"date_modified": FileAccess.get_modified_time(beatz_path),
			"local_beat_offset": beat_offset,
			"selected_background": background,
			"background_vid": beatz_path.get_base_dir().path_join(video) if video != "" else "",
			"cover_loop": beatz_path.get_base_dir().path_join(cover_loop) if cover_loop != "" else ""
		}
	}
	
	add_queue.append({"type": "entry", "entry": entry})

var scroll_tween: Tween
var scroll_velocity := 0.0
var last_scroll_time := 0.0

func _on_song_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Settings.misc.smooth_scrolls:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var scroll_bar = $song_list.get_v_scroll_bar()
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

	var parent_node := get_parent()
	if parent_node and parent_node.has_node("AnimationPlayer"):
		var parent_animator: AnimationPlayer = parent_node.get_node("AnimationPlayer")
		if Settings.misc.reduce_motion:
			parent_animator.play("go_to_selected", -1, 100.0)
		else:
			parent_animator.play("go_to_selected")
	
	song_sel.emit()
	
	var metadata = list.get_item_metadata(index)
	
	print(metadata)
	if typeof(metadata) != TYPE_DICTIONARY:
		print("No metadata to select a song. index ", index)
		return

	var beatz_path = metadata["beatz_path"]
	var song_name = metadata["song_name"]
	var album = metadata["album"]
	var diff_texture_path = metadata["diff_texture_path"]
	var artist = metadata["artist"]
	var year = metadata["year"]
	var bpm = metadata["bpm"]
	var charter = metadata["charter"]
	var selected_stream = metadata["stream"]
	var selected_beat_offset = metadata["local_beat_offset"]
	
	var selected_background = metadata["selected_background"]
	
	var background_vid_path = metadata["background_vid"]
	
	var cover_loop_vid_path: String = str(metadata.get("cover_loop", ""))
	var cover_path = str(metadata.get("cover_path", ""))
	var cover_texture: Image = null
	if cover_path != "" and FileAccess.file_exists(cover_path):
		cover_texture = Image.load_from_file(cover_path)
	
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
		if beatz_file == null:
			push_error("Failed to open chart file: %s" % beatz_path)
			return
		var content := beatz_file.get_as_text()
		beatz_file.close()
		var beatz_data := General.import_beatz_file(content)
		
		var main = load("res://Scenes/selected_song.tscn").instantiate() # Load selected song scene and set all of the song variables
		main.set("selected_stream_path", selected_stream)
		main.set("selected_title", song_name)
		main.set("selected_album", album)
		
		if cover_texture:
			main.set("selected_cover", cover_texture)
		main.set("selected_artist", artist)
		main.set("selected_artists", General.artist_names_from_info(metadata))
		main.set("selected_year", year)
		
		main.set("start_wait", beatz_data["start_wait"])
		main.set("preview_start", beatz_data["preview_start"])
		main.set("preview_end", beatz_data["preview_end"])
		main.set("fade_in", beatz_data.get("fade_in", false))
		main.set("fade_out", beatz_data.get("fade_out", false))
		
		main.set("selected_difficulty", beatz_data["difficulty"])
		main.set("selected_diff_texture", diff_texture_path)
		main.set("notes", beatz_data["notes"])
		main.set("selected_chart_name", beatz_data["chart_name"])
		
		main.set("selected_beatz_path", beatz_path)
		
		main.set("selected_beat_offset", selected_beat_offset)
		
		main.set("background_vid_path", background_vid_path)
		main.set("cover_loop_vid_path", cover_loop_vid_path)
		
		if selected_background != "" and FileAccess.file_exists(selected_background):
			var background_image := Image.load_from_file(selected_background)
			if background_image:
				main.set("selected_background", background_image)
				main.set("selected_background_name", selected_background.get_file())
		
		main.set("selected_bpm", bpm)
		main.set("selected_charter", charter)
		if cover_texture and not cover_texture.is_empty():
			main.set("colors", General.extract_dominant_colors(cover_texture))
		
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
		item_context_menu.emit($song_list.get_item_metadata(index), at_position, index)
	elif mouse_button_index == MOUSE_BUTTON_MIDDLE:
		var metadata = $song_list.get_item_metadata(index)
		if typeof(metadata) == TYPE_DICTIONARY:
			item_play_as_bg.emit(metadata.get("stream", ""))


func _on_song_list_item_selected(index: int) -> void:
	_on_song_selected(index)

func _on_song_list_item_activated(index: int) -> void:
	_on_song_selected(index)
