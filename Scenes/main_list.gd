extends Control

@onready var list: ItemList = $center/song_list

signal went_back
signal song_sel
signal item_context_menu(meta: String, pos: Vector2, idx: int)
signal item_context_menu_focus_released

signal item_play_as_bg(path: String, index: int)

signal loading_song(title: String)
signal loaded_song_meta(title: String)
signal loaded_song(title: String)

signal error(title: String, code: Variant.Type)

var add_queue := []
var processing_index := 0
var grouped_songs := {}

var song_info: Array = []
var difficulty_order := [
	"easy", "normal", "hard", "extreme", "insanity", "impossible"
]

var all_items: Array = []

func load_song_info():
	var file := FileAccess.open("res://song_info.json", FileAccess.READ)
	if file == null:
		print("Failed to open song_info.json")
		error.emit("Failed to open song_info.json.", FileAccess.get_open_error())
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_text)
	if typeof(result) != TYPE_ARRAY:
		print("Invalid JSON structure in song_info.json")
		error.emit("Invalid JSON structure in song_info.json", result)
		return

	song_info = result

var start_time = Time.get_ticks_msec()

var total_songs: int = 0

func _ready() -> void:
	if OS.get_name() == "Android": 
		$center/song_list.select_mode = ItemList.SelectMode.SELECT_MULTI
	
	if Settings.game.keep_list_in_ram and Beatz.LIST.size() > 0:
		list.clear()
		print("Rebuilding list from mem")

		for id in Beatz.LIST.keys():
			var data = Beatz.LIST[id]

			var idx = list.add_item(data["text"], LOADING_COVER)
			list.set_item_metadata(idx, data["metadata"])
			list.set_item_disabled(idx, data["disabled"])
			list.set_item_tooltip_enabled(idx, false)

			all_items.append({
				"id": idx,
				"text": data["text"],
				"icon": LOADING_COVER,
				"metadata": data["metadata"],
				"disabled": data["disabled"],
			})

		list.get_v_scroll_bar().value_changed.connect(update_visible_covers)

		update_visible_covers(0)

		songs_built = true
		
		connect_popup()
		return
	
	if Settings.game.keep_list_in_ram and FileAccess.file_exists(Beatz.LIST_CACHE_PATH):
		var t := Time.get_ticks_msec()
		var file := FileAccess.open(Beatz.LIST_CACHE_PATH, FileAccess.READ)
		if file:
			var text := file.get_as_text()
			file.close()

			var parsed = JSON.parse_string(text)

			if typeof(parsed) == TYPE_DICTIONARY:
				print("Loaded song list from cache")

				Beatz.LIST.clear()
				list.clear()

				for id in parsed.keys():
					var data = parsed[id]

					Beatz.LIST[id] = data

					var idx = list.add_item(data["text"], LOADING_COVER)
					list.set_item_metadata(idx, data["metadata"])
					list.set_item_disabled(idx, data["disabled"])
					list.set_item_tooltip_enabled(idx, false)

					all_items.append({
						"id": idx,
						"text": data["text"],
						"icon": LOADING_COVER,
						"metadata": data["metadata"],
						"disabled": data["disabled"]
					})

				list.get_v_scroll_bar().value_changed.connect(update_visible_covers)
				update_visible_covers(0)

				songs_built = true
				connect_popup()
				
				print_rich(
					"[color=green]Loading from cache took [b]%d[/b] ms[/color]"
					% (Time.get_ticks_msec() - t)
				)
				return
	
	var t0 := Time.get_ticks_msec()
	total_songs = _count_songs()
	print("total songs ", total_songs)
	print("count_songs took ", Time.get_ticks_msec() - t0, " ms")

	var t1 := Time.get_ticks_msec()
	load_song_info()
	print("load_song_info took ", Time.get_ticks_msec() - t1, " ms")

	_load_songs()
	
	connect_popup()

func connect_popup():
	var popup: PopupMenu = $top_right/sort.get_popup()
	
	popup.about_to_popup.connect(func():
		General.is_popup_open = true
	)
	
	popup.popup_hide.connect(func():
		General.is_popup_open = false
	)

func _count_songs() -> int:
	var total := 0

	# 1. Count .beatz files directly inside res://Charts
	var charts_dir := DirAccess.open("res://Charts")
	if charts_dir:
		charts_dir.list_dir_begin()
		var file_name := charts_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".beatz"):
				total += 1
			file_name = charts_dir.get_next()
		charts_dir.list_dir_end()

	# 2. Count custom songs by scanning subfolders in Custom/
	var base_custom_path := ""
	if OS.get_name() == "Android":
		base_custom_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom"
	else:
		base_custom_path = "user://Custom"

	var custom_dir := DirAccess.open(base_custom_path)
	if custom_dir:
		custom_dir.list_dir_begin()
		var folder_name := custom_dir.get_next()
		while folder_name != "":
			if custom_dir.current_is_dir() and folder_name != "." and folder_name != ".." and folder_name != "Charts":
				var folder_path := base_custom_path + "/" + folder_name
				var sub_dir := DirAccess.open(folder_path)
				if sub_dir:
					sub_dir.list_dir_begin()
					var file_name := sub_dir.get_next()
					while file_name != "":
						if file_name.ends_with(".beatz"):
							total += 1
							break # Only count this folder once
						file_name = sub_dir.get_next()
					sub_dir.list_dir_end()
			folder_name = custom_dir.get_next()
		custom_dir.list_dir_end()

	return total

var background_cover_queue: Array[String] = []
var background_load_timer: float = 0.0
const BACKGROUND_LOAD_INTERVAL := 0.333 # 3 per second

var loading_covers := {}
var loaded_covers := {}
var cover_threads := {}
var cover_results := {}

func get_visible_item_range() -> Vector2i:
	var first_visible = list.get_v_scroll_bar().value / 124.0
	var visible_count = ceil(list.size.y / 124.0)
	#print("Visible range: " , first_visible, " to ", first_visible + visible_count)
	return Vector2i(int(first_visible), int(first_visible + visible_count))

var songs_built: bool = false

const DEFAULT_COVER := preload("res://Resources/misc/noCover.png")
const LOADING_COVER := preload("res://Resources/misc/loadingCover.png")

func _process(_delta):
	# add to list and all items array
	if not songs_built:
		if add_queue.is_empty():
			return

		for item in add_queue:
			if item["type"] == "entry":
				var entry = item["entry"]

				var idx = list.add_item(entry["text"], LOADING_COVER)
				list.set_item_metadata(idx, entry["metadata"])
				list.set_item_tooltip_enabled(idx, false)

		for i in range(list.get_item_count()):
			all_items.append({
				"id": i,
				"text": list.get_item_text(i),
				"icon": LOADING_COVER,
				"metadata": list.get_item_metadata(i),
				"disabled": list.is_item_disabled(i),
			})
		
		if Settings.game.keep_list_in_ram:
			print("adding list to mem")

			Beatz.LIST.clear()

			for item in all_items:
				Beatz.LIST[item["id"]] = {
					"text": item["text"],
					"metadata": item["metadata"],
					"disabled": item["disabled"]
				}

			# SAVE CACHE TO DISK
			var cache := {}

			for id in Beatz.LIST.keys():
				cache[id] = {
					"text": Beatz.LIST[id]["text"],
					"metadata": Beatz.LIST[id]["metadata"],
					"disabled": Beatz.LIST[id]["disabled"]
				}

			var file := FileAccess.open(Beatz.LIST_CACHE_PATH, FileAccess.WRITE)
			if file:
				print("Saved list to cache")
				file.store_string(JSON.stringify(cache))
				file.close()
			else:
				printerr("Failed to write list cache")

		list.get_v_scroll_bar().value_changed.connect(update_visible_covers)

		print("loading covers")
		update_visible_covers(0)

		songs_built = true
		# so next process loop skips over this part
	
	if _cover_update_pending:
		_cover_update_cooldown -= _delta

		if _cover_update_cooldown <= 0.0:
			_cover_update_pending = false
			_cover_update_cooldown = COVER_UPDATE_DELAY
			update_visible_covers(0)
	
	# create item list covers (lazy loading)
	for path in cover_results.keys():
		var img: Image = cover_results[path]
		var tex := ImageTexture.create_from_image(img)

		# Apply to ALL visible items using this cover
		for i in range(list.get_item_count()):
			var metadata = list.get_item_metadata(i)
			if metadata and metadata.get("cover_path", "") == path:
				list.set_item_icon(i, tex)

		# Update master cache
		for item in all_items:
			if item["metadata"].get("cover_path", "") == path:
				item["icon"] = tex

		loaded_covers[path] = tex

		if cover_threads.has(path):
			cover_threads[path].wait_to_finish()
			cover_threads.erase(path)

		loading_covers.erase(path)
		cover_results.erase(path)
		
		if background_cover_queue.has(path):
			background_cover_queue.erase(path)
	
	# Background loading (load all covers slowly)
	if Settings.game.load_all_covers and songs_built:
		background_load_timer += _delta

		if background_load_timer >= BACKGROUND_LOAD_INTERVAL:
			background_load_timer = 0.0

			if background_cover_queue.is_empty():
				_build_background_queue()
	
	_drain_cover_queue()

func _build_background_queue():
	background_cover_queue.clear()

	for item in all_items:
		var cover_path = item["metadata"].get("cover_path", "")
		if cover_path == "":
			cover_path = DEFAULT_COVER.resource_path

		if loaded_covers.has(cover_path):
			continue

		if loading_covers.has(cover_path):
			continue

		background_cover_queue.append(cover_path)
		#print("Added cover in background ", cover_path)

func _drain_cover_queue():
	var max_threads: int = Settings.game.max_threads_in_list
	if max_threads <= 0:
		max_threads = 1

	while cover_threads.size() < max_threads and not background_cover_queue.is_empty():
		var cover_path: String = background_cover_queue.pop_front()

		if loaded_covers.has(cover_path):
			continue
		if loading_covers.has(cover_path):
			continue

		_try_start_cover_thread(cover_path)

func _thread_load_image(path: String):
	var final_path := path

	if final_path == "res://Resources/misc/noCover.png" or final_path == "" or not FileAccess.file_exists(final_path):
		#print("283 ", DEFAULT_COVER.resource_path)
		final_path = DEFAULT_COVER.resource_path

	var img := Image.new()
	var err := img.load(final_path)

	if err != OK:
		return

	if img.get_width() > 420 or img.get_height() > 420:
		@warning_ignore("narrowing_conversion")
		img.resize(420, 420)

	cover_results[path] = img

func _try_start_cover_thread(cover_path: String):
	var max_threads: int = Settings.game.max_threads_in_list
	if max_threads <= 0:
		max_threads = 1

	if cover_threads.size() >= max_threads:
		return false

	loading_covers[cover_path] = true

	var thread := Thread.new()
	cover_threads[cover_path] = thread
	thread.start(_thread_load_image.bind(cover_path))

	return true

var all_covers_loaded: bool = false

var _cover_update_pending := false
var _cover_update_cooldown := 0.0
const COVER_UPDATE_DELAY := 0.1 # 100ms

@warning_ignore("unused_parameter")
func update_visible_covers(_arg):
	_cover_update_pending = true
	
	if not Settings.game.load_all_covers:
		_unload_invisible_covers()
	
	var visible_items = get_visible_item_range()
	
	
	for i in range(visible_items.x - 5, visible_items.y + 5):
		if i < 0 or i >= list.get_item_count():
			continue

		var metadata = list.get_item_metadata(i)
		if metadata == null:
			continue

		var cover_path = metadata.get("cover_path", "")
		if cover_path == "":
			#print("334 ", DEFAULT_COVER.resource_path)
			cover_path = DEFAULT_COVER.resource_path

		if loaded_covers.has(cover_path):
			continue

		if loading_covers.has(cover_path):
			continue

		if not _try_start_cover_thread(cover_path):
			if not background_cover_queue.has(cover_path):
				background_cover_queue.push_front(cover_path)

func _unload_invisible_covers():
	var visible_items = get_visible_item_range()
	var keep_paths := {}

	# Determine which cover paths should stay loaded
	for i in range(visible_items.x - 5, visible_items.y + 5):
		if i < 0 or i >= list.get_item_count():
			continue

		var metadata = list.get_item_metadata(i)
		if metadata == null:
			continue

		var cover_path = metadata.get("cover_path", "")
		if cover_path == "":
			#print("362 ", DEFAULT_COVER.resource_path)
			cover_path = DEFAULT_COVER.resource_path

		keep_paths[cover_path] = true

	# Unload covers not in visible range
	for path in loaded_covers.keys():
		if keep_paths.has(path):
			continue

		# Reset icons in list
		for i in range(list.get_item_count()):
			var metadata = list.get_item_metadata(i)
			if metadata and metadata.get("cover_path", "") == path:
				list.set_item_icon(i, LOADING_COVER)

		# Reset cached icon
		for item in all_items:
			if item["metadata"].get("cover_path", "") == path:
				item["icon"] = LOADING_COVER

		loaded_covers.erase(path)

var touch_start := Vector2.ZERO
var dragging := false
var drag_threshold := 20.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			dragging = false

	elif event is InputEventScreenDrag:
		if event.position.distance_to(touch_start) > drag_threshold:
			dragging = true
	if Input.is_action_just_pressed("fast_restart"):
		_on_reload_pressed()

	if Input.is_action_pressed("ui_accept"):
		# Ignore if it's the Space key
		if event is InputEventKey and event.keycode == KEY_SPACE:
			return

		if event is InputEventKey and event.keycode not in [KEY_ENTER, KEY_KP_ENTER]:
			return

		var selected = list.get_selected_items()
		if not selected.is_empty():
			var idx = selected[0]
			list.ensure_current_is_visible()
			_on_song_selected(idx)
			get_parent().can_random = true
			$top_right/search.release_focus()
		else:
			print("No song is selected.")
		

	if Input.is_action_just_pressed("ui_up"):
		_on_scrl_up_pressed()
	elif Input.is_action_just_pressed("ui_down"):
		_on_scrl_down_pressed()

func _parse_beatz_file(beatz_path: String, grouped: Dictionary):
	var beatz_file = FileAccess.open(beatz_path, FileAccess.READ)
	if not beatz_file:
		return

	var content := beatz_file.get_as_text()
	beatz_file.close()

	# Use import_beatz_file() to avoid duplicate parsing logic
	var parsed := General.import_beatz_file(content)

	var _song_name = parsed["song"]
	var _file_chart_name = parsed["chart_name"]
	var _file_charter = parsed["charter"]
	var _file_bpm = parsed["bpm"]
	var _file_note_speed = parsed["note_speed"]
	var _file_note_spawn_y = parsed["note_spawn_y"]
	var _file_start_wait = parsed["start_wait"]
	var _file_p_start = parsed["preview_start"]
	var _file_p_end = parsed["preview_end"]
	var _file_b_offset = parsed["local_beat_offset"]
	var _file_difficulty = parsed["difficulty"]
	var _decoded_notes = parsed["notes"]

	var song_index = -1
	for i in range(song_info.size()):
		if song_info[i]["file_name"] == _song_name:
			song_index = i
			break

	if song_index != -1:
		var song_title = song_info[song_index]["song_name"]
		var artist_name = song_info[song_index]["artist"]
		var album_name: String = song_info[song_index]["album"]
		var year = song_info[song_index]["year"]
		var file = song_info[song_index]["file_name"]

		var mp3_path = "res://Resources/Songs/" + file
		var cover_texture: CompressedTexture2D

		if FileAccess.file_exists(mp3_path):
			#var new_stream = load(mp3_path) as AudioStreamMP3

			var sanitized_album_name = album_name.replace("/", "_").replace("\\", "_").replace(":", "_")
			var cover_path = "res://Resources/Covers/" + sanitized_album_name + ".png"

			if FileAccess.file_exists(cover_path):
				cover_texture = load(cover_path)
			else:
				cover_texture = load("res://Resources/misc/noCover.png")

			var text: String
			var show_chart_name = _file_chart_name.to_lower() != song_title.to_lower()
			var show_album_name = album_name.to_lower() != song_title.to_lower()

			if not show_album_name and not show_chart_name:
				text = "%s | %s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					song_title,
					artist_name,
					year
				]
			elif not show_album_name and show_chart_name:
				text = "%s | '%s' | %s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					_file_chart_name,
					song_title,
					artist_name,
					year
				]
			elif show_album_name and not show_chart_name:
				text = "%s | %s | %s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					album_name,
					song_title,
					artist_name,
					year
				]
			else:
				text = "%s | '%s' | %s | %s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					_file_chart_name,
					album_name,
					song_title,
					artist_name,
					year
				]

			var entry := {
				"text": text,
				"cover": cover_texture,
				"metadata": {
					"beatz_path": beatz_path,
					"song_name": song_title,
					"album": album_name,
					"artist": artist_name,
					"year": year,
					"bpm": _file_bpm,
					"charter": _file_charter,
					"speed": _file_note_speed,
					"start_wait": _file_start_wait,
					"local_beat_offset": 0.0,
					"diff_texture_path": "res://Resources/misc/" + _file_difficulty + "_label.png",
					"selected_background": "",
					"background_vid": "",
					"stream": mp3_path,
					"note_count": _decoded_notes.size()
				}
			}

			if not grouped.has(_file_difficulty):
				grouped_songs[_file_difficulty] = []
			grouped_songs[_file_difficulty].append(entry)
		else:
			print("MP3 file not found for: %s" % _song_name)
	else:
		print("Song not found in predefined list: %s" % _song_name)

		var album_name: String = "Unknown Album"
		var artist_name: String = "Unknown Artist"
		var year = 0

		var mp3_path = "res://Resources/Songs/" + _song_name + ".mp3"
		var cover_texture: CompressedTexture2D
		var new_stream
		if FileAccess.file_exists(mp3_path):
			new_stream = mp3_path #load(mp3_path) as AudioStreamMP3
			print("MP3 file actually found for: %s" % _song_name)
		else:
			#new_stream = null
			print("MP3 file not found for: %s" % _song_name)

		cover_texture = load("res://Resources/misc/noCover.png")

		var text = "%s | (Not in song_info.json) %s, by %s | %d  " % [
			_file_difficulty.to_pascal_case(), _song_name, artist_name, year
		]

		var entry := {
			"text": text,
			"cover": cover_texture,
			"metadata": {
				"beatz_path": beatz_path,
				"song_name": _song_name,
				"album": album_name,
				"artist": artist_name,
				"year": year,
				"bpm": _file_bpm,
				"charter": _file_charter,
				"speed": _file_note_speed,
				"start_wait": _file_start_wait,
				"stream": new_stream,
				"selected_background": "",
				"background_vid": "",
				"note_count": _decoded_notes.size()
			}
		}

		if not grouped.has(_file_difficulty):
			grouped_songs[_file_difficulty] = []
		grouped_songs[_file_difficulty].append(entry)

var scan_threads := []
var scan_results := []
var scan_mutex := Mutex.new()

var scan_finished := false
var remaining_scan_threads := 0

func _load_songs():
	var t_start := Time.get_ticks_msec()

	list.clear()
	add_queue.clear()
	processing_index = 0
	grouped_songs = {}

	scan_results.clear()
	scan_threads.clear()
	scan_finished = false
	remaining_scan_threads = 0

	# Scan Charts folder next to the exe (exported-friendly)
	var t_charts := Time.get_ticks_msec()

	var exe_dir := OS.get_executable_path().get_base_dir()
	var charts_path := exe_dir.path_join("Charts")

	var charts_dir := DirAccess.open(charts_path)

	if charts_dir:
		charts_dir.list_dir_begin()

		var file_name = charts_dir.get_next()

		while file_name != "":
			if not charts_dir.current_is_dir() and file_name.ends_with(".beatz"):
				_parse_beatz_file(
					charts_path.path_join(file_name),
					grouped_songs
				)

			file_name = charts_dir.get_next()

		charts_dir.list_dir_end()

	else:
		printerr(
			"Failed to open Charts directory at: ",
			charts_path,
			". Err ",
			DirAccess.get_open_error(),
			" ",
			error_string(DirAccess.get_open_error())
		)

		error.emit(
			"Failed to open Charts directory at: %s" % charts_path,
			DirAccess.get_open_error()
		)

	print("exe Charts scan took ", Time.get_ticks_msec() - t_charts, " ms")

	# Scan user://Custom/Charts
	var t_custom_charts := Time.get_ticks_msec()

	var custom_dir

	if OS.get_name() == "Android":
		custom_dir = DirAccess.open(
			"storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/Charts"
		)
	else:
		custom_dir = DirAccess.open("user://Custom/Charts")

	if custom_dir:
		custom_dir.list_dir_begin()

		var file_name = custom_dir.get_next()

		while file_name != "":
			if file_name.ends_with(".beatz"):
				if OS.get_name() == "Windows":
					_parse_beatz_file(
						"user://Custom/Charts/" + file_name,
						grouped_songs
					)
				else:
					_parse_beatz_file(
						"storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/Charts/" + file_name,
						grouped_songs
					)

			file_name = custom_dir.get_next()

		custom_dir.list_dir_end()

	else:
		printerr(
			"Failed to open Custom Charts directory. Err ",
			DirAccess.get_open_error(),
			" ",
			error_string(DirAccess.get_open_error())
		)

		error.emit(
			"Failed to open Custom Charts directory at: %s" % custom_dir,
			DirAccess.get_open_error()
		)

	print("Custom/Charts scan took ", Time.get_ticks_msec() - t_custom_charts, " ms")

	# Scan user://Custom folders with info.json bundles
	var t_thread_start := Time.get_ticks_msec()

	var base_custom_dir: DirAccess

	if OS.get_name() == "Android":
		base_custom_dir = DirAccess.open(
			"storage/emulated/0/Android/data/com.guayabr.beatzx/Custom"
		)
	else:
		base_custom_dir = DirAccess.open("user://Custom")

	if base_custom_dir:
		base_custom_dir.list_dir_begin()

		var entry_name := base_custom_dir.get_next()

		while entry_name != "":
			if base_custom_dir.current_is_dir() and entry_name != "Charts":
				var folder_path

				if OS.get_name() == "Windows":
					folder_path = "user://Custom/" + entry_name
				else:
					folder_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/" + entry_name

				remaining_scan_threads += 1
				_start_scan_thread(folder_path)

			entry_name = base_custom_dir.get_next()

		base_custom_dir.list_dir_end()

	else:
		printerr(
			"Failed to open Custom Songs directory. Err ",
			DirAccess.get_open_error(),
			" ",
			error_string(DirAccess.get_open_error())
		)

		error.emit(
			"Failed to open Custom Songs directory at: %s" % base_custom_dir,
			DirAccess.get_open_error()
		)

	print(
		"Thread spawn + folder scan kickoff took ",
		Time.get_ticks_msec() - t_thread_start,
		" ms"
	)

	if remaining_scan_threads <= 0:
		_finish_song_loading(t_start)

func _start_scan_thread(folder_path: String) -> void:
	var thread = Thread.new()
	scan_threads.append(thread)
	thread.start(Callable(self, "_thread_scan_folder").bind(folder_path), Thread.PRIORITY_LOW)

func _thread_scan_folder(folder_path: String) -> void:
	var data = _scan_custom_folder_data(folder_path)

	if not data.is_empty():
		scan_mutex.lock()
		scan_results.append(data)
		scan_mutex.unlock()

	call_deferred("_on_scan_thread_finished")

func _on_scan_thread_finished() -> void:
	remaining_scan_threads -= 1

	if remaining_scan_threads <= 0 and not scan_finished:
		scan_finished = true
		_finish_song_loading(start_time)


func _finish_song_loading(t_start: int) -> void:
	var t_finalize := Time.get_ticks_msec()

	for thread in scan_threads:
		thread.wait_to_finish()

	scan_threads.clear()

	for data in scan_results:
		_finalize_custom_folder_entry(data, grouped_songs)

	scan_results.clear()

	print(
		"Finalize custom folder entries took ",
		Time.get_ticks_msec() - t_finalize,
		" ms"
	)

	var t_merge := Time.get_ticks_msec()

	var all_entries: Array = []

	for diff_entries in grouped_songs.values():
		all_entries.append_array(diff_entries)

	all_entries.sort_custom(func(a, b):
		return (
			a["metadata"]["song_name"].to_lower()
			< b["metadata"]["song_name"].to_lower()
		)
	)

	print("Merge + sort took ", Time.get_ticks_msec() - t_merge, " ms")

	for entry in all_entries:
		add_queue.append({
			"type": "entry",
			"entry": entry
		})

	print("Queued %d songs" % add_queue.size())

	print(
		"TOTAL _load_songs took ",
		Time.get_ticks_msec() - t_start,
		" ms"
	)
	
	if reload_loading_active:
		reload_loading_active = false

		$center/loading_charts_panel/ProgressBar.value = 100.0

		$center/loading_charts_panel/progress.text = "%s/%s" % [
			total_songs,
			total_songs
		]

		$center/loading_charts_panel/details.text = (
			"Finished loading all songs."
		)

		var t := create_tween()

		t.tween_property(
			$center/loading_charts_panel,
			"scale",
			Vector2.ZERO,
			0.25
		).set_trans(Tween.TRANS_CIRC)

	update_visible_covers(2)

	$top_left/reload.release_focus()

func emit_loaded(type: int, title: String):
	match type:
		0:
			loading_song.emit(title)

			if reload_loading_active:
				$center/loading_charts_panel/details.text = (
					"Loading song folder:\n%s" % title
				)

		1:
			loaded_song_meta.emit(title)

			if reload_loading_active:
				$center/loading_charts_panel/details.text = (
					"Reading metadata:\n%s" % title
				)

		2:
			loaded_song.emit(title)

			if reload_loading_active:
				reload_loaded_songs += 1

				var progress := (
					float(reload_loaded_songs)
					/ float(max(total_songs, 1))
				) * 100.0

				$center/loading_charts_panel/ProgressBar.value = progress

				$center/loading_charts_panel/progress.text = "%s/%s" % [
					reload_loaded_songs,
					total_songs
				]

				$center/loading_charts_panel/details.text = (
					"Finished loading:\n%s" % title
				)

# THREAD-SAFE: Reads files and returns a data dictionary with pure data (no textures or streams)
func _scan_custom_folder_data(folder: String) -> Dictionary:
	var _data = {}

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

	General.save_or_replace_song_id(id)

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
	var background = info.get("background", "")
	var diff_texture_path = info.get("diff_texture", "")
	
	var vid_path = info.get("video", "")
	var cover_loop_vid_path = info.get("cover_loop", "")
	
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
			
			var beatz = General.import_beatz_file(beatz_content)
			
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
		else:
			print("Failed to open info.json in: ", folder)
		
	if beatz_path == "" or audio_path == "":
		print("Skipping folder: %s (missing files)" % folder)
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
		"selected_background": background,
		"background_vid": vid_path,
		"cover_loop_vid": cover_loop_vid_path
	}

# MUST BE CALLED ON MAIN THREAD:
# Creates textures, loads audio stream, adds entry to grouped_songs
func _finalize_custom_folder_entry(data: Dictionary, grouped: Dictionary) -> void:
	if data.is_empty():
		return
	
	var audio_path = ProjectSettings.globalize_path(data["audio_path"])
	var cover_path = data["image_path"]
	var beatz_path: String = data["beatz_path"]
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
	
	var background = data["selected_background"]
	
	var video = data["background_vid"]
	var cover_loop = data["cover_loop_vid"]
	
	#print("scanning ", beatz_path)
	
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
	
	var entry := {
		"text": text,
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
			"difficulty": difficulty,
			"speed": speed,
			"cover_path": cover_path,
			"stream": audio_path,
			"date_modified": FileAccess.get_modified_time(beatz_path),
			"local_beat_offset": beat_offset,
			"selected_background": beatz_path.get_base_dir().path_join(background) if background != "" else "",
			"background_vid": beatz_path.get_base_dir().path_join(video) if video != "" else "",
			"cover_loop": beatz_path.get_base_dir().path_join(cover_loop) if cover_loop != "" else ""
		}
	}
	
	processing_index += 1
	
	var tb = null

	if OS.get_name() == "Windows" and Engine.has_singleton("TBProgress"):
		tb = Engine.get_singleton("TBProgress")

	if tb:
		tb.set_progress(processing_index, total_songs)

	if not grouped.has(difficulty):
		grouped_songs[difficulty] = []
	grouped_songs[difficulty].append(entry)

var _img_thread: Thread
var _loaded_cover: Image
var _loaded_bg: Image
var _img_done := false

func _load_images_thread(cover_path: String, bg_path: String):
	if cover_path != "":
		_loaded_cover = Image.load_from_file(cover_path)
	
	if bg_path != "":
		_loaded_bg = Image.load_from_file(bg_path)
	
	call_deferred("_on_images_loaded")

func _on_images_loaded():
	if _img_thread:
		_img_thread.wait_to_finish()
		_img_thread = null
	
	_img_done = true

@onready var loading_text: RichTextLabel = $center_bottom/loading_text

func _on_song_selected(index: int, from_all_items: bool = false) -> void:
	if dragging:
		return

	if !list.is_item_selectable(index) or list.is_item_disabled(index):
		return

	var lose_focus := true

	if edit_mode:
		var item_text = list.get_item_text(index)
		pending_delete_index = index
		lose_focus = false

		if item_text.contains("\n"):
			$center/del_custom_panel/del_yes.show()
			$center/del_custom_panel/title_del_custom_s.text = "Are you sure you want to delete\nthis custom song? (This cannot be undone.)"
		else:
			$center/del_custom_panel/del_yes.hide()
			$center/del_custom_panel/title_del_custom_s.text = "This is not a custom song."

		$del_custom_anim.play("popup_panel")
		return

	if lose_focus:
		list.release_focus()

	if Settings.misc.reduce_motion:
		$AnimationPlayer.play("go_to_selected", -1, 100.0)
	else:
		$AnimationPlayer.play("go_to_selected")

	song_sel.emit()
	item_context_menu_focus_released.emit()
	$click_sfx.play()

	var metadata

	if from_all_items:
		metadata = all_items.get(index).metadata
	else:
		metadata = list.get_item_metadata(index)

	if metadata == null or !metadata.has("stream"):
		print("Selected item is a separator or missing data")
		return

	var beatz_path = metadata["beatz_path"]
	var song_name = metadata["song_name"]
	var album = metadata["album"]
	var cover_texture_path = metadata["cover_path"]

	var selected_background = metadata["selected_background"]

	_img_done = false

	if _img_thread and _img_thread.is_started():
		_img_thread.wait_to_finish()

	_img_thread = Thread.new()
	_img_thread.start(Callable(self, "_load_images_thread").bind(
		cover_texture_path,
		selected_background
	))

	var diff_texture_path = metadata["diff_texture_path"]
	var artist = metadata["artist"]
	var year = metadata["year"]
	var bpm = metadata["bpm"]
	var charter = metadata["charter"]
	var selected_stream = metadata["stream"]
	var selected_beat_offset = metadata["local_beat_offset"]

	var selected_video = metadata["background_vid"]
	var selected_cover_loop_video = metadata["cover_loop"]

	SceneLoader.load_scene("res://Scenes/selected_song.tscn")

	var progress_update := func():
		while SceneLoader.is_loading():
			loading_text.text = "Loading... (%d%)" % int(SceneLoader.get_progress() * 100.0)
			await get_tree().process_frame
		loading_text.text = "Loading... 100%"

	progress_update.call()

	await $AnimationPlayer.animation_finished
	await get_tree().create_timer(1.0).timeout

	var game = SceneLoader.loaded_scene.instantiate()

	var beatz_file := FileAccess.open(beatz_path, FileAccess.READ)
	var content := beatz_file.get_as_text()
	var beatz_data := General.import_beatz_file(content)

	game.set("selected_stream_path", selected_stream)
	game.set("selected_title", song_name)
	game.set("selected_album", album)

	game.set("selected_cover", Image.load_from_file(cover_texture_path))

	game.set("selected_artist", artist)
	game.set("selected_year", year)

	game.set("start_wait", beatz_data["start_wait"])
	game.set("preview_start", beatz_data["preview_start"])
	game.set("preview_end", beatz_data["preview_end"])

	game.set("selected_difficulty", beatz_data["difficulty"])
	game.set("selected_diff_texture", diff_texture_path)
	game.set("notes", beatz_data["notes"])
	game.set("selected_chart_name", beatz_data["chart_name"])

	game.set("selected_beatz_path", beatz_path)
	game.set("selected_beat_offset", selected_beat_offset)

	if selected_background:
		game.set("selected_background", Image.load_from_file(selected_background))
		game.set("selected_background_name", selected_background.get_file())

	game.set("background_vid_path", selected_video)
	game.set("cover_loop_vid_path", selected_cover_loop_video)

	game.set("selected_bpm", bpm)
	game.set("selected_charter", charter)

	get_tree().root.add_child(game)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game


func go_to_album(album_name: String, album_artist: String, album_year: int, album_cover: Image):
	$AnimationPlayer.play("go_to_album")
	$album_view.selected_album = album_name
	$album_view.selected_artist = album_artist
	$album_view.selected_year = album_year
	$album_view.selected_cover = album_cover
	await get_tree().create_timer(0.5).timeout
	$album_view.load_album()


func _on_back_button_up() -> void:
	General.set_presence(
		"Main Menu",
		EOS.Presence.Status.Online
	)
	
	$top_left/back.release_focus()
	_on_background_focus_entered()
	if Settings.misc.reduce_motion:
		$AnimationPlayer.play("back", -1, 250.0)
	else:
		$AnimationPlayer.play("back")
		await get_tree().create_timer(0.7).timeout
	went_back.emit()

var reload_loading_active := false
var reload_loaded_songs := 0

func _on_reload_pressed() -> void:
	start_time = Time.get_ticks_msec()

	songs_built = false

	list.clear()
	all_items.clear()
	Beatz.LIST.clear()
	
	total_songs = _count_songs()

	set_process(true)

	reload_loading_active = true
	reload_loaded_songs = 0

	$center/loading_charts_panel/loading_lbl.text = "Loading %s chart(s)..." % total_songs

	$center/loading_charts_panel/progress.text = "0/%s" % total_songs

	$center/loading_charts_panel/details.text = "Loading..."

	$center/loading_charts_panel/ProgressBar.value = 0.0

	var t := create_tween()

	t.tween_property(
		$center/loading_charts_panel,
		"scale",
		Vector2.ONE,
		0.25
	).set_trans(Tween.TRANS_CIRC)

	load_song_info()
	_load_songs()

	print_rich(
		"[color=green]Song reloading took [b]%d[/b] ms[/color]"
		% (Time.get_ticks_msec() - start_time)
	)

var import_thread: Thread

var import_progress := 0.0
var import_current_file := 0
var import_total_files := 0


func _on_open_beatz_bxzip_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .bx or .beatz files.",
		"",
		"",
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILES,
		["*.bx", "*.beatz", "*"],
		Callable(self, "_on_file_dialog_files_selected")
	)

	if err != OK:
		print("Failed to show native file dialog.")


func _on_file_dialog_files_selected(status, paths: PackedStringArray, _filter_idx: int) -> void:
	if status != true or paths.is_empty():
		print("User cancelled or error occurred.")
		return

	start_time = Time.get_ticks_msec()

	if import_thread and import_thread.is_started():
		print("Import thread already running.")
		return

	import_total_files = paths.size()
	import_current_file = 0
	import_progress = 0.0

	$center/loading_charts_panel/loading_lbl.text = "Loading %s chart(s)..." % paths.size()
	$center/loading_charts_panel/progress.text = "0/%s" % paths.size()
	$center/loading_charts_panel/details.text = "Preparing import..."
	$center/loading_charts_panel/ProgressBar.value = 0.0

	var t := create_tween()
	t.tween_property(
		$center/loading_charts_panel,
		"scale",
		Vector2.ONE,
		0.25
	).set_trans(Tween.TRANS_CIRC)
	
	await get_tree().create_timer(0.4).timeout

	import_thread = Thread.new()
	import_thread.start(_thread_import_files.bind(paths))


func _thread_import_files(paths: PackedStringArray) -> void:
	var reload_needed := false

	for i in paths.size():
		var path := paths[i]

		call_deferred(
			"_update_import_status",
			float(i) / float(paths.size()) * 100.0,
			i,
			"Preparing %s..." % path.get_file()
		)

		var extension := path.get_extension().to_lower()
		var success := false

		if extension in ["bx", "zip"]:
			var file_name := path.get_file().get_basename()
			var output_path := "user://Custom/%s" % file_name

			if DirAccess.dir_exists_absolute(output_path):
				print("Output path for file already exists")

				var time = Time.get_datetime_dict_from_system()

				output_path = "user://Custom/%s-%s-%s-%s" % [
					file_name,
					str(time.hour),
					str(time.day),
					str(time.month)
				]

			if OS.get_name() == "Android":
				output_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/%s" % file_name

			call_deferred(
				"_update_import_status",
				float(i) / float(paths.size()) * 100.0,
				i,
				"Opening ZIP\n%s..." % path.get_file()
			)

			var zip := ZIPReader.new()
			var err := zip.open(path)

			if err != OK:
				printerr("Failed to open ZIP file:\n", path)
				continue

			DirAccess.make_dir_recursive_absolute(output_path)

			var files := zip.get_files()
			var total_inner_files = max(files.size(), 1)

			for inner_index in files.size():
				var inner_path := files[inner_index]
				var full_output_path = output_path.path_join(inner_path)

				var per_file_progress := float(inner_index) / float(total_inner_files)
				var global_progress := (
					(float(i) + per_file_progress)
					/ float(paths.size())
				) * 100.0

				call_deferred(
					"_update_import_status",
					global_progress,
					i,
					"Unzipping to\n%s" % full_output_path
				)

				if inner_path.ends_with("/"):
					DirAccess.make_dir_recursive_absolute(full_output_path)

				else:
					DirAccess.make_dir_recursive_absolute(full_output_path.get_base_dir())

					var file = FileAccess.open(full_output_path, FileAccess.WRITE)

					if file:
						var data := zip.read_file(inner_path)

						file.store_buffer(data)
						file.close()

					else:
						printerr("Failed to write zip file: ", full_output_path)

			zip.close()

			call_deferred(
				"_update_import_status",
				((float(i) + 0.95) / float(paths.size())) * 100.0,
				i,
				"Making SONGID file..."
			)

			print("Unpacked zip to: ", output_path)

			var song_id := "SONGID " + file_name + " " + str(Time.get_unix_time_from_system(), "_", randi())

			var id_file := FileAccess.open(
				output_path.path_join(".songid"),
				FileAccess.WRITE
			)

			if id_file:
				id_file.store_string(song_id)
				id_file.close()

			call_deferred(
				"_update_import_status",
				((float(i) + 0.98) / float(paths.size())) * 100.0,
				i,
				"Saving song ID..."
			)

			General.save_or_replace_song_id(song_id)

			print("Made unique ID: ", song_id)

			success = true

		elif extension == "beatz":
			var charts_path := "user://Custom/Charts"

			if OS.get_name() == "Android":
				charts_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/Charts"

			call_deferred(
				"_update_import_status",
				float(i) / float(paths.size()) * 100.0,
				i,
				"Copying .beatz file..."
			)

			DirAccess.make_dir_recursive_absolute(charts_path)

			var file_data := FileAccess.open(path, FileAccess.READ)

			if file_data:
				var target_path := charts_path.path_join(path.get_file())

				var target_file := FileAccess.open(
					target_path,
					FileAccess.WRITE
				)

				if target_file:
					target_file.store_buffer(
						file_data.get_buffer(file_data.get_length())
					)

					target_file.close()

					print("Copied .beatz to: ", target_path)

					success = true

				else:
					printerr(
						"Failed to open target file for writing: ",
						target_path
					)

				file_data.close()

			else:
				printerr("Failed to open source .beatz file: ", path)

		else:
			print("Unsupported file type: ", extension)

		if success:
			reload_needed = true

		call_deferred(
			"_update_import_status",
			(float(i + 1) / float(paths.size())) * 100.0,
			i + 1,
			"Finished %s" % path.get_file()
		)

	call_deferred("_finish_import_thread", reload_needed, paths.size())


func _update_import_status(progress_value: float, completed_files: int, details_text: String) -> void:
	import_progress = progress_value

	$center/loading_charts_panel/ProgressBar.value = progress_value

	$center/loading_charts_panel/progress.text = "%s/%s" % [
		completed_files,
		import_total_files
	]

	$center/loading_charts_panel/details.text = details_text


func _finish_import_thread(reload_needed: bool, file_count: int) -> void:
	if import_thread:
		import_thread.wait_to_finish()
	
	await get_tree().process_frame
	
	$center/loading_charts_panel/ProgressBar.value = 100.0
	$center/loading_charts_panel/progress.text = "%s/%s" % [
		file_count,
		file_count
	]

	$center/loading_charts_panel/details.text = "Finished importing charts."

	var t := create_tween()

	t.tween_property(
		$center/loading_charts_panel,
		"scale",
		Vector2.ZERO,
		0.25
	).set_trans(Tween.TRANS_CIRC)
	
	await get_tree().create_timer(0.3).timeout

	if reload_needed:
		var elapsed = Time.get_ticks_msec() - start_time

		print_rich(
			"[color=green]Song importing took [b]%d[/b] ms for %d file(s)[/color]"
			% [elapsed, file_count]
		)

		_on_reload_pressed()

var edit_mode := false
var pending_delete_index := -1

var delete_from_context := false

func _on_edit_pressed() -> void:
	print("Editing")
	edit_mode = !edit_mode
	
	var btn := $top_left/edit
	if edit_mode:
		btn.add_theme_color_override("font_color", Color.GREEN)
		btn.add_theme_constant_override("outline_size", 12)
		btn.add_theme_color_override("font_outline_color", Color.DARK_GREEN)
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_constant_override("outline_size")
		btn.remove_theme_color_override("font_outline_color")
	btn.release_focus()

func _on_scrl_up_pressed() -> void:
	var count = list.get_item_count()
	if count == 0:
		return

	var current = list.get_selected_items()
	var start_index = current[0] if current.size() > 0 else get_visible_center_item_index(list)

	for offset in range(1, count + 1):
		var i = (start_index - offset + count) % count
		if list.is_item_selectable(i) and !list.is_item_disabled(i):
			list.select(i)
			list.ensure_current_is_visible()
			$center_right/scrl_up.release_focus()
			break

func _on_scrl_down_pressed() -> void:
	var count = list.get_item_count()
	if count == 0:
		return

	var current = list.get_selected_items()
	var start_index = current[0] if current.size() > 0 else get_visible_center_item_index(list)

	for offset in range(1, count + 1):
		var i = (start_index + offset) % count
		if list.is_item_selectable(i) and !list.is_item_disabled(i):
			list.select(i)
			list.ensure_current_is_visible()
			$center_right/scrl_down.release_focus()
			break

func get_visible_center_item_index(itemList: ItemList) -> int:
	# Get the vertical scroll and visible region
	var scroll := itemList.get_v_scroll_bar()
	if scroll == null:
		return 0

	var scroll_value := scroll.value
	var visible_height := itemList.size.y
	var total_height = itemList.get_item_count() * 126.0

	# Estimate which item is centered
	var item_height = total_height / itemList.get_item_count()
	var center_position := scroll_value + (visible_height / 2.0)
	var index := int(center_position / item_height)
	return clamp(index, 0, itemList.get_item_count() - 1)

func _on_edit_cancel_pressed() -> void:
	if delete_from_context:
		edit_mode = false
		pending_delete_index = -1
		delete_from_context = false
	$del_custom_anim.play("cancel_panel")
	await $del_custom_anim.animation_finished
	$center/del_custom_panel/del_yes.show()
	$center/del_custom_panel/title_del_custom_s.text = "Are you sure you want to delete\nthis custom song? (This cannot be undone.)"
	$center/del_custom_panel/del_no.disabled = false
	$center/del_custom_panel/del_yes.disabled = false

func try_delete_folder(folder_path: String, target_id: String) -> bool:
	var id_path = folder_path.path_join(".songid")
	if FileAccess.file_exists(id_path):
		print("Found .songid file at: ", id_path)
		var file = FileAccess.open(id_path, FileAccess.READ)
		if file:
			var content = file.get_as_text().strip_edges()
			file.close()
			print("Song ID: ", content)
			if content == target_id:
				print("Match found, deleting folder: ", folder_path)
				
				var sub_dir = DirAccess.open(folder_path)
				if sub_dir:
					sub_dir.list_dir_begin()
					var sub_file = sub_dir.get_next()
					while sub_file != "":
						if sub_dir.current_is_dir():
							print("Deleting subfolder (not recursing): ", sub_file)
							DirAccess.remove_absolute(folder_path.path_join(sub_file))
						else:
							print("Deleting file: ", sub_file)
							sub_dir.remove(folder_path.path_join(sub_file))
						sub_file = sub_dir.get_next()
					sub_dir.list_dir_end()
					DirAccess.remove_absolute(folder_path)
					print("Deleted folder: ", folder_path)

					# Read existing lines first
					var lines := []
					var id_file = FileAccess.open(General.SONG_ID_ARR_PATH, FileAccess.READ)
					if id_file:
						lines = id_file.get_as_text().split("\n")
						id_file.close()

					var updated_lines := []
					for line in lines:
						if line.strip_edges() != content and line.strip_edges() != "":
							updated_lines.append(line)
						else:
							print("Removed song ID from SONG_ID_ARR_PATH: ", line)

					# Always WRITE mode after reading to safely truncate
					var out_file = FileAccess.open(General.SONG_ID_ARR_PATH, FileAccess.WRITE)
					if out_file:
						out_file.store_string("\n".join(updated_lines) + "\n")
						out_file.close()
					else:
						print("Failed to open SONG_ID_ARR_PATH for overwriting")

					return true
				else:
					print("Failed to open folder for deletion: ", folder_path)
		else:
			print("Failed to open .songid file: ", id_path)
	else:
		print("No .songid found in folder: ", folder_path)
	return false

func _on_edit_confirm_pressed() -> void:
	if pending_delete_index < 0:
		print("No pending delete index.")
		return

	var meta = list.get_item_metadata(pending_delete_index)
	if not meta.has("id"):
		print("No song ID in metadata. Metadata contents:", meta)
		return

	var target_id = meta["id"]
	var song_name = meta["song_name"]
	print("Attempting to delete song with ID: ", target_id, " and name: ", song_name)

	var base_path = "user://Custom/" if OS.get_name() == "Windows" else "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/"
	print("Using base path: ", base_path)

	# First Attempt: Exact match with folder named after song_name
	var exact_folder_path = base_path.path_join(song_name)
	if DirAccess.dir_exists_absolute(exact_folder_path):
		print("Trying exact folder name first: ", exact_folder_path)
		if try_delete_folder(exact_folder_path, target_id):
			$center/del_custom_panel/del_yes.release_focus()
			$del_custom_anim.play("confirm_panel")
			await $del_custom_anim.animation_finished
			_on_reload_pressed()
			return

	# Second Attempt: Find a folder starting with song_name (closest match)
	var dir = DirAccess.open(base_path)
	if not dir:
		print("Failed to open custom folder: ", base_path)
		return

	dir.list_dir_begin()
	var closest_match_path := ""
	var folder = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "Charts":
			if folder.begins_with(song_name):
				closest_match_path = base_path.path_join(folder)
				print("Trying closest matching folder: ", closest_match_path)
				if try_delete_folder(closest_match_path, target_id):
					dir.list_dir_end()
					$center/del_custom_panel/del_yes.release_focus()
					$del_custom_anim.play("confirm_panel")
					await $del_custom_anim.animation_finished
					_on_reload_pressed()
					return
		folder = dir.get_next()
	dir.list_dir_end()

	# Third Attempt: Full iteration after showing warning and disabling buttons
	print("Exact and closest folder didn't match, showing warning and iterating all folders...")
	$center/del_custom_panel/title_del_custom_s.text = "Folders with name \"" + song_name + "\" did not\nmatch song ID. Iterating through all folders..."
	$center/del_custom_panel/del_no.disabled = true
	$center/del_custom_panel/del_yes.disabled = true
	await get_tree().process_frame

	dir = DirAccess.open(base_path)
	if not dir:
		print("Failed to reopen custom folder for full iteration.")
		return

	var found = false
	dir.list_dir_begin()
	folder = dir.get_next()
	while folder != "":
		if dir.current_is_dir() and folder != "Charts":
			var folder_path = base_path.path_join(folder)
			if try_delete_folder(folder_path, target_id):
				found = true
				break
		folder = dir.get_next()
	dir.list_dir_end()

	if not found:
		print("Error: No Song IDs match ", song_name)
		$center/del_custom_panel/title_del_custom_s.text = "ERROR: No folder matched Song ID:\n" + target_id
		$center/del_custom_panel/del_no.disabled = false
		$center/del_custom_panel/del_yes.disabled = true
		return

	$center/del_custom_panel/del_yes.release_focus()
	$del_custom_anim.play("confirm_panel")
	await $del_custom_anim.animation_finished
	$center/del_custom_panel/del_no.disabled = false
	$center/del_custom_panel/del_yes.disabled = false
	_on_reload_pressed()

func _on_create_req() -> void:
	var t = create_tween() 
	
	t.tween_property($center/create_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_CIRC)
	$top_left/create.release_focus()

func _on_create_pressed() -> void:
	var edit = load(General.EDITOR).instantiate()
	
	get_tree().root.add_child(edit)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = edit

func _on_create_cancel() -> void:
	var t = create_tween() 
	
	t.tween_property($center/create_panel, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_CIRC)
	$center/create_panel/HBoxContainer/create_cancel.release_focus()

func _on_record_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .mp3, .ogg or .wav files.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILES,    # Mode: open multiple files
		["*.mp3", "*.ogg", "*.wav", "*"],   # File filters
		Callable(self, "_on_song_select_file_selected")
	)
	if err != OK:
		print("Failed to show native file dialog.")
	
	$center/create_panel/HBoxContainer/record.release_focus()

func _on_song_select_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("list song select file status", status)
	print("list song select paths ", paths)
	print("list song select filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	if paths[0].get_extension() not in ["mp3", "ogg", "wav"]:
		$Control/create_map_panel/song_file_label.text = "Song has to be an mp3, ogg or wav file."
		return
	
	var song_path = paths[0]
	
	var stream
	
	var song_didnt_fail := true
	if song_path.ends_with(".mp3") or song_path.ends_with(".ogg") or song_path.ends_with(".wav"):
		if song_path.ends_with(".mp3"):
			stream = AudioStreamMP3.load_from_file(song_path)
			print("Song created as mp3 ", stream)
		elif song_path.ends_with(".ogg"):
			stream = AudioStreamOggVorbis.load_from_file(song_path)
			print("Song created as ogg ", stream)
		elif song_path.ends_with(".wav"):
			stream = AudioStreamWAV.load_from_file(song_path)
			print("Song created as wav ", stream)
		else:
			song_didnt_fail = false
			print("Unsupported audio format in: %s" % song_path)
			stream = null
			
	if song_didnt_fail: 
		
		print("Song success ", stream)
		
		# Parse ID3 from file
		var metaRead := MP3ID3Tag.new()
		var loaded_ok := metaRead.load_file(song_path)
		if not loaded_ok:
			print("Failed to load ID3 tags for ", song_path)
			return
		
		# Track name
		var track := metaRead.getTrackName()
		if track and track.strip_edges() != "":
			print(track)
		else:
			print("Track name not in metadata")
		
		# Artist
		var artist := metaRead.getArtist()
		if artist and artist.strip_edges() != "":
			print(artist)
		else:
			print("Artist not in metadata")
		
		# Album
		var album := metaRead.getAlbum()
		if album and album.strip_edges() != "":
			print(album)
		else:
			print("Album not in metadata")
		
		# Year
		var year := metaRead.getYear()
		if year and year.strip_edges() != "":
			print(year)
		else:
			print("Year not in metadata")
		
		# Cover (first attached picture)
		var response: Array = metaRead.getAttachedPictureAndMime(0)
		if not response.is_empty() and response[0]:
			print("Got cover")
		else:
			print("Cover image not in metadata")
		
		var main = load("res://Scenes/main.tscn").instantiate()
		main.set("song", stream)
		main.set("song_path", song_path)
		main.set("song_title", track)
		main.set("album", album)
		
		if not response.is_empty() and response.get(0): main.set("cover", response[0])
		
		main.set("artist", artist)
		main.set("year", year)
		
		#main.set("start_wait", 0.0)
		#main.set("preview_start", beatz_data["preview_start"])
		#main.set("preview_end", beatz_data["preview_end"])
		
		main.set("difficulty", "easy")
		main.set("chart_name", track)
		
		main.set("charter", Settings.game.username)
		
		if not response.is_empty() and response.get(0): main.set("colors", General.extract_dominant_colors(response[0]))
		
		main.set("init_recording", true) # Initialize main with recording
		
		get_tree().root.add_child(main)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main

func entered_mp3_on_window(file):
	var edit = load(General.EDITOR).instantiate()
	
	edit.create_from_dropped_file(file)
	
	get_tree().root.add_child(edit)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = edit

func _on_dlt_all_pressed() -> void:
	$center/del_custom_panel/title_del_custom_s.text = "Are you sure you want\nto delete ALL custom songs?\n(This CANNOT be undone!)\n(Scores will save)"
	$center/del_custom_panel/title_del_custom_s.position.y -= 15
	$del_custom_anim.play("popup_panel")
	$center/del_custom_panel/del_yes.disconnect("pressed", Callable(self, "_on_edit_confirm_pressed"))
	$center/del_custom_panel/del_yes.connect("pressed", Callable(self, "_on_edit_dlt_all_confirm"))
	$center/del_custom_panel/del_no.disconnect("pressed", Callable(self, "_on_edit_cancel_pressed"))
	$center/del_custom_panel/del_no.connect("pressed", Callable(self, "_on_edit_dlt_all_cancel"))

func _on_edit_dlt_all_cancel() -> void:
	$center/del_custom_panel/del_no.disabled = true
	$center/del_custom_panel/del_yes.disabled = true
	$del_custom_anim.play("cancel_panel")
	
	await $del_custom_anim.animation_finished
	$center/del_custom_panel/del_yes.show()
	$center/del_custom_panel/title_del_custom_s.text = "Are you sure you want to delete\nthis custom song? (This cannot be undone.)"
	$center/del_custom_panel/del_no.disabled = false
	$center/del_custom_panel/del_yes.disabled = false
	
	$center/del_custom_panel/del_yes.disconnect("pressed", Callable(self, "_on_edit_dlt_all_confirm"))
	$center/del_custom_panel/del_yes.connect("pressed", Callable(self, "_on_edit_confirm_pressed"))
	$center/del_custom_panel/del_no.disconnect("pressed", Callable(self, "_on_edit_dlt_all_cancel"))
	$center/del_custom_panel/del_no.connect("pressed", Callable(self, "_on_edit_cancel_pressed"))

func _on_edit_dlt_all_confirm() -> void:
	$center/del_custom_panel/del_no.disabled = true
	$center/del_custom_panel/del_yes.disabled = true
	$center/del_custom_panel/title_del_custom_s.text = "Deleting..."
	
	var base_path := "user://Custom"
	var dir := DirAccess.open(base_path)
	
	if not dir:
		print("Failed to open Custom folder for deletion.")
		return
	
	dir.list_dir_begin()
	var folder := dir.get_next()
	
	while folder != "":
		if dir.current_is_dir() and folder != "Charts":
			var folder_path := base_path.path_join(folder)
			$center/del_custom_panel/title_del_custom_s.text = "Deleting " + folder + "..."
			_delete_folder_contents(folder_path)
		folder = dir.get_next()
	
	dir.list_dir_end()
	
	$center/del_custom_panel/title_del_custom_s.text = "All custom songs deleted."
	print("All custom subfolders deleted.")
	
	$center/del_custom_panel/del_yes.disconnect("pressed", Callable(self, "_on_edit_dlt_all_confirm"))
	$center/del_custom_panel/del_yes.connect("pressed", Callable(self, "_on_edit_confirm_pressed"))
	
	_on_reload_pressed()
	await get_tree().create_timer(2.5).timeout
	$del_custom_anim.play("confirm_panel")
	await $del_custom_anim.animation_finished
	$center/del_custom_panel/del_no.disabled = false
	$center/del_custom_panel/del_yes.disabled = false
	$center/del_custom_panel/title_del_custom_s.position.y += 15

# Helper function that manually clears a folder’s contents and then deletes it
func _delete_folder_contents(folder_path: String) -> void:
	var sub_dir := DirAccess.open(folder_path)
	if not sub_dir:
		print("Failed to open:", folder_path)
		return
	
	sub_dir.list_dir_begin()
	var sub_item := sub_dir.get_next()
	
	while sub_item != "":
		if sub_item in [".", ".."]:
			sub_item = sub_dir.get_next()
			continue
		
		var full_path := folder_path.path_join(sub_item)
		if sub_dir.current_is_dir():
			print("Deleting subfolder:", full_path)
			_delete_folder_contents(full_path) # recurse deeper
			DirAccess.remove_absolute(full_path)
		else:
			print("Deleting file:", full_path)
			var e := DirAccess.remove_absolute(full_path)
			if e != OK:
				print("Failed to delete file:", full_path, "Error:", e, error_string(e))
		
		sub_item = sub_dir.get_next()
	
	sub_dir.list_dir_end()
	
	# Now remove the empty parent folder itself
	var err := DirAccess.remove_absolute(folder_path)
	if err == OK:
		print("Deleted folder:", folder_path)
	else:
		print("Failed to delete folder:", folder_path, "Error:", err, error_string(err))

func _on_background_focus_entered() -> void:
	$background.release_focus()
	$song_list_sprite.release_focus()
	$center/song_list.deselect_all()
	item_context_menu_focus_released.emit()

func _on_song_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_RIGHT:
		item_context_menu.emit($center/song_list.get_item_metadata(index), at_position, index)
	elif mouse_button_index == MOUSE_BUTTON_MIDDLE:
		item_play_as_bg.emit($center/song_list.get_item_metadata(index).stream, index)

var scroll_tween: Tween
var scroll_velocity := 0.0
var last_scroll_time := 0.0

func _on_song_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Settings.misc.smooth_scrolls:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var scroll_bar = $center/song_list.get_v_scroll_bar()
			if not scroll_bar:
				return

			# Prevent default ItemList scroll behavior
			get_viewport().set_input_as_handled()

			var now := Time.get_ticks_msec() / 1000.0
			var delta_time := now - last_scroll_time
			last_scroll_time = now

			# Calculate base scroll strength
			var base_amount := 150.0
			var direction := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1
			var mult := 0.95

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

			var duration := clampf(abs(scroll_velocity) / 1200.0, 0.2, 1.0)

			scroll_tween = create_tween()
			scroll_tween.tween_property(scroll_bar, "value", target_value, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

			# Slowly decay velocity over time
			scroll_tween.finished.connect(func():
				scroll_velocity *= 0.5
			)

func _on_random_pressed() -> void:
	$top_left/random.release_focus()
	$center/song_list.deselect_all()
	_on_song_selected(randi_range(0, $center/song_list.item_count))


func _on_album_view_loaded_charts() -> void:
	$AnimationPlayer.play("loaded_album")

func _on_search_focus_entered() -> void:
	get_parent().can_random = false

func _on_search_focus_exited() -> void:
	get_parent().can_random = true

func _on_search_bar_text_changed(new_text: String):
	current_search_query = new_text
	filter_items(new_text)

func filter_items(query: String):
	current_search_query = query

	var items := _get_filtered_items(query)

	if items.size() > 1:
		items.sort_custom(func(a, b):
			return _sort_compare(a, b)
		)

		if reverse_order:
			items.reverse()

	_rebuild_list_from_items(items)

	if list.get_item_count() > 0:
		list.select(0)
		list.ensure_current_is_visible()

func _difficulty_rank(diff: String) -> int:
	diff = diff.to_lower()

	match diff:
		"easy":
			return 0
		"normal":
			return 1
		"hard":
			return 2
		"extreme":
			return 3
		"insanity":
			return 4
		"impossible":
			return 5
		"deathly":
			return 6
		_:
			return 7 # non-matching difficulties go last

var current_sort_mode := 0
var reverse_order := false
var current_search_query := ""

func _on_sort_item_selected(index: int) -> void:
	current_sort_mode = index
	_apply_sort()
	
	$top_right/sort.release_focus()

func _on_reverse_order_toggled(toggled_on: bool) -> void:
	reverse_order = toggled_on
	_apply_sort()
	$top_right/reverse_order.release_focus()

func _apply_sort():
	var items_to_sort: Array

	if current_search_query.strip_edges() == "":
		items_to_sort = all_items.duplicate(true)
	else:
		items_to_sort = _get_filtered_items(current_search_query)

	if items_to_sort.size() <= 1:
		return

	items_to_sort.sort_custom(func(a, b):
		return _sort_compare(a, b)
	)

	if reverse_order:
		items_to_sort.reverse()
		update_visible_covers(1)

	_rebuild_list_from_items(items_to_sort)

func _sort_compare(a: Dictionary, b: Dictionary) -> bool:
	var ma = a["metadata"]
	var mb = b["metadata"]

	match current_sort_mode:
		0: # Title A-Z
			return ma["song_name"].to_lower() < mb["song_name"].to_lower()

		1: # Artist A-Z
			return ma["artist"].to_lower() < mb["artist"].to_lower()

		2: # Album (Year desc, then Album A-Z)
			return ma["album"].to_lower() < mb["album"].to_lower()

		3: # Year (Newest -> Oldest)
			return ma["year"] > mb["year"]

		4: # Difficulty (custom order, then A-Z for unknown)
			var da = _difficulty_rank(ma.get("difficulty", ""))
			var db = _difficulty_rank(mb.get("difficulty", ""))

			if da != db:
				return da < db

			return ma.get("difficulty", "").to_lower() < mb.get("difficulty", "").to_lower()

		5: # Charter A-Z
			return ma["charter"].to_lower() < mb["charter"].to_lower()
		
		6: # Chart Date Modified
			return ma["date_modified"] > mb["date_modified"]

		_:
			return a["id"] < b["id"]

func _rebuild_list_from_items(items: Array):
	list.clear()

	for item in items:
		var idx = list.add_item(item["text"], item["icon"])
		list.set_item_metadata(idx, item["metadata"])
		list.set_item_tooltip_enabled(idx, false)

		if item["disabled"]:
			list.set_item_disabled(idx, true)
			list.set_item_selectable(idx, false)
	
	update_visible_covers(1)

func _get_filtered_items(query: String) -> Array:
	var results: Array = []

	query = query.strip_edges()

	var exact_match := false
	if query.begins_with('"'):
		exact_match = true
		query = query.substr(1)

	var q := query.to_lower()

	for item in all_items:
		var text = item["text"].to_lower()
		var ma := false

		if query == "":
			ma = true
		elif exact_match:
			var regex := RegEx.new()
			var escaped_query = General._escape_regex(q)
			regex.compile("\\b" + escaped_query + "\\b")
			ma = regex.search(text) != null
		else:
			ma = q in text

		if ma:
			results.append(item)

	return results
