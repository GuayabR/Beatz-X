extends Control

var Stream: AudioStreamMP3
var song_number = 1  # Counter for songs

var streams := []  # Stores AudioStreamMP3 for each item

signal went_back
signal song_sel

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
		return
	
	var json_text := file.get_as_text()
	file.close()
	
	var result = JSON.parse_string(json_text)
	if typeof(result) != TYPE_ARRAY:
		print("Invalid JSON structure in song_info.json")
		return

	song_info = result

func _ready() -> void:
	load_song_info()
	_load_songs()

func _process(delta):
	if add_queue.is_empty():
		return
	
	var item = add_queue[processing_index]
	processing_index += 1
	
	if item["type"] == "separator":
		var sep_idx = $song_list.add_item("------------ %s ------------" % item["difficulty"].capitalize())
		$song_list.set_item_disabled(sep_idx, true)
		$song_list.set_item_selectable(sep_idx, false)
		$song_list.set_item_custom_fg_color(sep_idx, Color.WHITE)
	
	elif item["type"] == "entry":
		var entry = item["entry"]
		var idx = $song_list.add_item(entry["text"], entry["cover"])
		$song_list.set_item_metadata(idx, entry["metadata"])
		#print("Added item ", idx)
	
	if processing_index >= add_queue.size():
		for i in range($song_list.get_item_count()):
			all_items.append({
				"text": $song_list.get_item_text(i),
				"icon": $song_list.get_item_icon(i),
				"metadata": $song_list.get_item_metadata(i),
				"disabled": $song_list.is_item_disabled(i),
			})
		print("Done")
		# Once done, stop processing
		set_process(false)

func _parse_beatz_file(beatz_path: String, grouped_songs: Dictionary):
	var beatz_file = FileAccess.open(beatz_path, FileAccess.READ)
	if not beatz_file:
		return

	var content := beatz_file.get_as_text()
	beatz_file.close()

	# Use import_beatz_file() to avoid duplicate parsing logic
	var parsed := Globals.import_beatz_file(content)

	var _song_name = parsed["song"]
	var _file_chart_name = parsed["chart_name"]
	var _file_charter = parsed["charter"]
	var _file_bpm = parsed["bpm"]
	var _file_note_speed = parsed["note_speed"]
	var _file_note_spawn_y = parsed["note_spawn_y"]
	var _file_start_wait = parsed["start_wait"]
	var _file_p_start = parsed["preview_start"]
	var _file_p_end = parsed["preview_end"]
	var _file_difficulty = parsed["difficulty"]
	var _decoded_notes = parsed["notes"]

	var song_index = -1
	for i in range(song_info.size()):
		if song_info[i]["file_name"].get_basename() == _song_name:
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
			var new_stream = load(mp3_path) as AudioStreamMP3

			var sanitized_album_name = album_name.replace("/", "_").replace("\\", "_").replace(":", "_")
			var cover_path = "res://Resources/Covers/" + sanitized_album_name + ".png"

			if FileAccess.file_exists(cover_path):
				cover_texture = load(cover_path)
			else:
				cover_texture = load("res://Resources/Covers/noCover.png")

			var text: String
			var show_chart_name = _file_chart_name.to_lower() != song_title.to_lower()
			var show_album_name = album_name.to_lower() != song_title.to_lower()

			if "deltarune chapter 1" in album_name.to_lower():
				text = "  %s%s%s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					" | Chapter 1" if show_chart_name else "",
					" | %s" % song_title,
					artist_name,
					year
				]
			elif "deltarune chapter 2" in album_name.to_lower():
				text = "  %s%s%s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					" | Chapter 2" if show_chart_name else "",
					" | %s" % song_title,
					artist_name,
					year
				]
			elif "deltarune chapter 3+4" in album_name.to_lower():
				text = "  %s%s%s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					" | Chapters 3+4" if show_chart_name else "",
					" | %s" % song_title,
					artist_name,
					year
				]
			elif not show_album_name and not show_chart_name:
				text = "  %s | %s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					song_title,
					artist_name,
					year
				]
			elif not show_album_name and show_chart_name:
				text = "  %s | '%s' | %s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					_file_chart_name,
					song_title,
					artist_name,
					year
				]
			elif show_album_name and not show_chart_name:
				text = "  %s | %s | %s, by %s | %d  " % [
					_file_difficulty.to_pascal_case(),
					album_name,
					song_title,
					artist_name,
					year
				]
			else:
				text = "  %s | '%s' | %s | %s, by %s | %d  " % [
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
					"cover_texture": cover_texture,
					"stream": new_stream,
					"notes": _decoded_notes,
					"note_count": _decoded_notes.size()
				}
			}

			if not grouped_songs.has(_file_difficulty):
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
			new_stream = load(mp3_path) as AudioStreamMP3
		else:
			new_stream = null
			print("MP3 file not found for: %s" % _song_name)

		cover_texture = load("res://Resources/Covers/noCover.png")

		var text = "  %s | (Not in song_info.json) %s, by %s | %d  " % [
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
				"cover_texture": cover_texture,
				"stream": new_stream,
				"notes": _decoded_notes,
				"note_count": _decoded_notes.size()
			}
		}

		if not grouped_songs.has(_file_difficulty):
			grouped_songs[_file_difficulty] = []
		grouped_songs[_file_difficulty].append(entry)


var scan_threads := []
var scan_results := []
var scan_mutex := Mutex.new()

func _load_songs():
	$song_list.clear()
	add_queue.clear()
	processing_index = 0
	grouped_songs = {}  # We'll still fill this but ignore difficulty in the end

	# Scan res://Charts
	var charts_dir = DirAccess.open("res://Charts")
	if charts_dir:
		charts_dir.list_dir_begin()
		var file_name = charts_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".beatz"):
				_parse_beatz_file("res://Charts/" + file_name, grouped_songs)
			file_name = charts_dir.get_next()
		charts_dir.list_dir_end()
	else:
		print("Failed to open Charts directory.")

	# Scan user://Custom/Charts
	var custom_dir
	if OS.get_name() == "Android":
		custom_dir = DirAccess.open("storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/Charts")
	else:
		custom_dir = DirAccess.open("user://Custom/Charts")
	if custom_dir:
		custom_dir.list_dir_begin()
		var file_name = custom_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".beatz"):
				if OS.get_name() == "Windows":
					_parse_beatz_file("user://Custom/Charts/" + file_name, grouped_songs)
				else:
					_parse_beatz_file("storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/Charts/" + file_name, grouped_songs)
			file_name = custom_dir.get_next()
		custom_dir.list_dir_end()
	else:
		print("Failed to open Custom Charts directory.")

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
				_start_scan_thread(folder_path)
			entry_name = base_custom_dir.get_next()
		base_custom_dir.list_dir_end()
	else:
		printerr("Failed to open custom songs directory.")

	# Wait for threads
	for thread in scan_threads:
		thread.wait_to_finish()
	scan_threads.clear()

	# Finalize all custom folder entries into grouped_songs
	for data in scan_results:
		_finalize_custom_folder_entry(data, grouped_songs)
	scan_results.clear()

	# Merge all songs into one flat list and sort alphabetically
	var all_entries: Array = []
	for diff_entries in grouped_songs.values():
		all_entries.append_array(diff_entries)
	all_entries.sort_custom(func(a, b):
		return a["metadata"]["song_name"].to_lower() < b["metadata"]["song_name"].to_lower()
	)

	# Add to queue without separators
	for entry in all_entries:
		add_queue.append({"type": "entry", "entry": entry})

	print("Queued %d songs" % add_queue.size())

func _start_scan_thread(folder_path: String) -> void:
	var thread = Thread.new()
	scan_threads.append(thread)
	thread.start(Callable(self, "_thread_scan_folder").bind(folder_path), Thread.PRIORITY_NORMAL)

func _thread_scan_folder(folder_path: String) -> void:
	var data = _scan_custom_folder_data(folder_path)
	if not data.is_empty():
		scan_mutex.lock()
		scan_results.append(data)
		scan_mutex.unlock()

# THREAD-SAFE: Reads files and returns a data dictionary with pure data (no textures or streams)
func _scan_custom_folder_data(folder: String) -> Dictionary:
	var data = {}

	var info_path := folder + "/info.json"
	if not FileAccess.file_exists(info_path):
		return {}

	var file_name := folder.get_file()

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

	save_or_replace_song_id(id)

	var info_file := FileAccess.open(info_path, FileAccess.READ)
	if not info_file:
		return {}

	var info_text := info_file.get_as_text()
	info_file.close()

	var info_json = JSON.parse_string(info_text)
	if info_json == null or not info_json.has("info"):
		return {}

	var info = info_json["info"]
	var song_title = info.get("title", "Unknown Title")
	var artist_name = info.get("artist", "Unknown Artist")
	var album_name = info.get("album", "Unknown Album")
	var year = info.get("year", 0)

	var dir := DirAccess.open(folder)
	if dir == null:
		return {}

	var audio_path := ""
	var image_path := ""
	var beatz_path := ""

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".beatz"):
			beatz_path = folder + "/" + file
		elif file.ends_with(".mp3") or file.ends_with(".ogg") or file.ends_with(".wav"):
			audio_path = folder + "/" + file
		elif file.ends_with(".png") or file.ends_with(".jpg") or file.ends_with(".jpeg"):
			image_path = folder + "/" + file
		file = dir.get_next()
	dir.list_dir_end()

	if beatz_path == "" or audio_path == "":
		print("Skipping folder: %s (missing required files)" % folder)
		return {}

	var beatz_file = FileAccess.open(beatz_path, FileAccess.READ)
	if not beatz_file:
		print("Couldn't read beatz file in: %s" % folder)
		return {}

	var beatz_content := beatz_file.get_as_text()
	beatz_file.close()
	
	var beatz = Globals.import_beatz_file(beatz_content)
	
	var difficulty = beatz["difficulty"]
	var nspeed = beatz["note_speed"]
	var bpm = beatz["bpm"]
	var charter = beatz["charter"]

	return {
		"id": id,
		"song_title": song_title,
		"artist_name": artist_name,
		"album_name": album_name,
		"year": year,
		"bpm": bpm,
		"charter": charter,
		"speed": nspeed,
		"audio_path": audio_path,
		"image_path": image_path,
		"beatz_path": beatz_path,
		"difficulty": difficulty
	}

# MUST BE CALLED ON MAIN THREAD:
# Creates textures, loads audio stream, adds entry to grouped_songs
func _finalize_custom_folder_entry(data: Dictionary, grouped_songs: Dictionary) -> void:
	if data.is_empty():
		return
		
	print("Doing")
	print("dsa")
	
	var audio_path = data["audio_path"]
	var image_path = data["image_path"]
	var beatz_path = data["beatz_path"]
	var difficulty = data["difficulty"]
	var song_title = data["song_title"]
	var artist_name = data["artist_name"]
	var album_name = data["album_name"]
	var year = data["year"]
	var id = data["id"]
	var bpm = data["bpm"]
	var charter = data["charter"]
	var speed = data["speed"]
	
	print("scanning ", beatz_path)
	
	var audio_ext = audio_path.get_extension().to_lower()
	
	var stream
	if audio_ext == "mp3":
		stream = AudioStreamMP3.load_from_file(audio_path)
	elif audio_ext == "ogg":
		stream = AudioStreamOggVorbis.load_from_file(audio_path)
	elif audio_ext == "wav":
		stream = AudioStreamWAV.load_from_file(audio_path)
	else:
		print("Unsupported audio format in: %s" % audio_path)
		stream = null
	
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

	var text = "  %s | %s | %s, by %s | %d | Custom" % [
		difficulty.to_pascal_case(),
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
			"id": id,
			"song_name": song_title,
			"album": album_name,
			"artist": artist_name,
			"year": year,
			"bpm": bpm,
			"charter": charter,
			"speed": speed,
			"cover_texture": cover_texture,
			"stream": stream
		}
	}

	if not grouped_songs.has(difficulty):
		grouped_songs[difficulty] = []
	grouped_songs[difficulty].append(entry)

func _on_song_selected(index: int) -> void:
	if !$song_list.is_item_selectable(index) or $song_list.is_item_disabled(index):
		return
	
	var lose_focus = true
	
	if edit_mode:
		var item_text = $song_list.get_item_text(index)
		pending_delete_index = index
		lose_focus = false
		
		
		if item_text.ends_with("| Custom"):
			$del_custom_panel/del_yes.show()
			$del_custom_panel/title_del_custom_s.text = "Are you sure you want to delete\nthis custom song? (This cannot be undone.)"
		else:
			$del_custom_panel/del_yes.hide()
			$del_custom_panel/title_del_custom_s.text = "This is not a custom song."
			
		$del_custom_anim.play("popup_panel")
		return
	
	if lose_focus: $song_list.release_focus()
	
	if Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("go_to_selected", -1, 100.0)
	else:
		$AnimationPlayer.play("go_to_selected")
	
	song_sel.emit()
	
	$click_sfx.play()
	
	var metadata = $song_list.get_item_metadata(index)
	
	print(metadata)
	
	var beatz_path = metadata["beatz_path"]
	var song_name = metadata["song_name"]
	var album = metadata["album"]
	var cover_texture = metadata["cover_texture"]
	var artist = metadata["artist"]
	var year = metadata["year"]
	var bpm = metadata["bpm"]
	var charter = metadata["charter"]
	var selected_stream = metadata["stream"]
	var speed = metadata["speed"]
	
	# Ignore separators (they have no metadata or missing stream)
	if metadata == null or !metadata.has("stream"):
		print("Selected item is a separator or missing data")
		return
	
	$cover_sel.texture = $song_list.get_item_icon(index)
	
	$song_list.mouse_filter = MOUSE_FILTER_IGNORE
	
	if metadata:
		await get_tree().create_timer(1.4).timeout
		
		print("Selected song: %s by %s (%d) from album %s" % [song_name, artist, year, album])
		
		var beatz_file := FileAccess.open(beatz_path, FileAccess.READ)
		var content := beatz_file.get_as_text()
		var beatz_data := Globals.import_beatz_file(content)
		
		var main = load("res://Scenes/selected_song.tscn").instantiate() # Load selected song scene and set all of the song variables
		main.set("selected_stream", selected_stream)
		main.set("selected_title", song_name)
		main.set("selected_album", album)
		
		main.set("selected_cover", cover_texture)
		main.set("selected_artist", artist)
		main.set("selected_year", year)
		
		main.set("start_wait", beatz_data["start_wait"])
		main.set("preview_start", beatz_data["preview_start"])
		main.set("preview_end", beatz_data["preview_end"])
		
		main.set("selected_difficulty", beatz_data["difficulty"])
		main.set("notes", beatz_data["notes"])
		main.set("selected_chart_name", beatz_data["chart_name"])
		
		main.set("selected_beatz_path", beatz_path)
		
		main.set("selected_bpm", bpm)
		main.set("selected_charter", charter)
		
		get_tree().root.add_child(main)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main

	else:
		print("No metadata found for song list item: ", index) # If no metadata found, return to main menu
		print(selected_stream)
		print(metadata)
		
		if !Globals.settings.misc_settings.reduce_motion: await get_tree().create_timer(1.4).timeout
		
		var main = load("res://Scenes/main_menu.tscn").instantiate()
		get_tree().root.add_child(main)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main

func _on_back_button_up() -> void:
	$back.release_focus()
	if Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("back", -1, 250.0)
	else:
		$AnimationPlayer.play("back")
		await get_tree().create_timer(0.7).timeout
	went_back.emit()

func _on_search_focus_entered() -> void:
	get_parent().can_random = false

func _on_search_focus_exited() -> void:
	get_parent().can_random = true

func _on_search_bar_text_changed(new_text: String):
	filter_items(new_text)

func filter_items(query: String):
	$song_list.clear()
	var first_match_highlighted := false

	for item in all_items:
		if query == "" or query.to_lower() in item["text"].to_lower():
			var idx = $song_list.add_item(item["text"], item["icon"])
			$song_list.set_item_metadata(idx, item["metadata"])
			if item["disabled"]:
				$song_list.set_item_disabled(idx, true)
				$song_list.set_item_selectable(idx, false)
			elif not first_match_highlighted:
				# highlight the first non-disabled match
				$song_list.select(idx)
				$song_list.ensure_current_is_visible()
				first_match_highlighted = true


func search_item(query: String):
	var match_found := false
	for i in $song_list.get_item_count():
		var item_text = $song_list.get_item_text(i)
		if query.to_lower() in item_text.to_lower():
			$song_list.select(i)
			$song_list.ensure_current_is_visible()
			print("Found match: ", item_text, i)
			match_found = true
			break
	if not match_found:
		for j in $song_list.get_item_count():
			$song_list.deselect(j)
		print("No match found.")
	
func _on_search_bar_text_submitted(new_text: String) -> void:
	var match_found := false
	for i in $song_list.get_item_count():
		var item_text = $song_list.get_item_text(i)
		if new_text.to_lower() in item_text.to_lower():
			$song_list.select(i)
			$song_list.ensure_current_is_visible()
			_on_song_selected(i)
			match_found = true
			get_parent().can_random = true
			break
	if not match_found:
		for j in $song_list.get_item_count():
			$song_list.deselect(j)
		print("No match found to play.")
	$search.release_focus()

func _on_reload_pressed() -> void:
	set_process(true)
	
	$song_list.clear()
	all_items.clear()
	load_song_info()
	_load_songs()
	$reload.release_focus()

func _on_open_beatz_bxzip_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .beatz, .bx or .zip file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILES,    # Mode: open multiple files
		["*.bx", "*.beatz", "*.zip", "*"],   # File filters
		Callable(self, "_on_file_dialog_files_selected")
	)
	if err != OK:
		print("Failed to show native file dialog.")
		
func _on_file_dialog_file_selected(path: String) -> void:
	var extension := path.get_extension().to_lower()
	if extension in ["bx", "zip"]:
		var file_name := path.get_file().get_basename()
		var output_path := "user://Custom/%s" % file_name
		if OS.get_name() == "Android":
			output_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/%s" % file_name

		var zip := ZIPReader.new()
		var err := zip.open(path)
		if err != OK:
			printerr("Failed to open ZIP file: ", path)
			return

		DirAccess.make_dir_recursive_absolute(output_path)

		for inner_path in zip.get_files():
			var full_output_path = output_path.path_join(inner_path)

			if inner_path.ends_with("/"):
				DirAccess.make_dir_recursive_absolute(full_output_path)
			else:
				DirAccess.make_dir_recursive_absolute(full_output_path.get_base_dir())
				var file = FileAccess.open(full_output_path, FileAccess.WRITE)
				if file:
					file.store_buffer(zip.read_file(inner_path))
					file.close()
				else:
					printerr("Failed to write zip file: ", full_output_path)
					
		zip.close()
		print("Unpacked zip to: ", output_path)
		
		var song_id := "SONGID " + file_name + " " + str(Time.get_unix_time_from_system(), "_", randi())
		var id_file := FileAccess.open(output_path.path_join(".songid"), FileAccess.WRITE)
		id_file.store_line(song_id)
		id_file.close()
		
		save_or_replace_song_id(song_id)
		
		print("Made unique ID: ", song_id)
		
		_on_reload_pressed()
		
	elif extension == "beatz":
		var charts_path := "user://Custom/Charts"
		if OS.get_name() == "Android":
			charts_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/Charts"
		DirAccess.make_dir_recursive_absolute(charts_path)
		
		var file_data := FileAccess.open(path, FileAccess.READ)
		if file_data:
			var target_path := charts_path.path_join(path.get_file())
			var target_file := FileAccess.open(target_path, FileAccess.WRITE)
			if target_file:
				target_file.store_buffer(file_data.get_buffer(file_data.get_length()))
				target_file.close()
				
				print("Copied .beatz to: ", target_path)
				_on_reload_pressed()
			else:
				printerr("Failed to open target file for writing: ", target_path)
			file_data.close()
		else:
			printerr("Failed to open source .beatz file: ", path)
	else:
		print("Unsupported file type: ", extension)

func _on_file_dialog_files_selected(status, paths: PackedStringArray, _filter_idx: int) -> void:
	
	if status != true:
		print("User cancelled or error occurred.")
		return
	
	var reload_needed := false

	for path in paths:
		var extension := path.get_extension().to_lower()

		if extension in ["bx", "zip"]:
			var file_name := path.get_file().get_basename()
			var output_path := "user://Custom/%s" % file_name
			if OS.get_name() == "Android":
				output_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/%s" % file_name

			var zip := ZIPReader.new()
			var err := zip.open(path)
			if err != OK:
				printerr("Failed to open ZIP file: ", path)
				continue

			DirAccess.make_dir_recursive_absolute(output_path)

			for inner_path in zip.get_files():
				var full_output_path = output_path.path_join(inner_path)

				if inner_path.ends_with("/"):
					DirAccess.make_dir_recursive_absolute(full_output_path)
				else:
					DirAccess.make_dir_recursive_absolute(full_output_path.get_base_dir())
					var file = FileAccess.open(full_output_path, FileAccess.WRITE)
					if file:
						file.store_buffer(zip.read_file(inner_path))
						file.close()
					else:
						printerr("Failed to write zip file: ", full_output_path)

			zip.close()
			print("Unpacked zip to: ", output_path)
			
			var song_id := "SONGID " + file_name + " " + str(Time.get_unix_time_from_system(), "_", randi())
			var id_file := FileAccess.open(output_path.path_join(".songid"), FileAccess.WRITE)
			id_file.store_string(song_id)
			id_file.close()
			
			save_or_replace_song_id(song_id)
			
			print("Made unique ID: ", song_id)
			
			reload_needed = true

		elif extension == "beatz":
			var charts_path := "user://Custom/Charts"
			if OS.get_name() == "Android":
				charts_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/Charts"
			DirAccess.make_dir_recursive_absolute(charts_path)

			var file_data := FileAccess.open(path, FileAccess.READ)
			if file_data:
				var target_path := charts_path.path_join(path.get_file())
				var target_file := FileAccess.open(target_path, FileAccess.WRITE)
				if target_file:
					target_file.store_buffer(file_data.get_buffer(file_data.get_length()))
					target_file.close()
					
					print("Copied .beatz to: ", target_path)
					reload_needed = true
				else:
					printerr("Failed to open target file for writing: ", target_path)
				file_data.close()
			else:
				printerr("Failed to open source .beatz file: ", path)
		else:
			print("Unsupported file type: ", extension)
			
	if reload_needed:
		_on_reload_pressed()

var edit_mode := false
var pending_delete_index := -1

func _on_edit_pressed() -> void:
	print("Editing")
	edit_mode = !edit_mode
	
	var btn := $edit
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
	var count = $song_list.get_item_count()
	if count == 0:
		return

	var current = $song_list.get_selected_items()
	var start_index = current[0] if current.size() > 0 else 0

	for offset in range(1, count + 1):
		var i = (start_index - offset + count) % count
		if $song_list.is_item_selectable(i) and !$song_list.is_item_disabled(i):
			$song_list.select(i)
			$song_list.ensure_current_is_visible()
			$scrl_up.release_focus()
			break

func _on_scrl_down_pressed() -> void:
	var count = $song_list.get_item_count()
	if count == 0:
		return

	var current = $song_list.get_selected_items()
	var start_index = current[0] if current.size() > 0 else -1

	for offset in range(1, count + 1):
		var i = (start_index + offset) % count
		if $song_list.is_item_selectable(i) and !$song_list.is_item_disabled(i):
			$song_list.select(i)
			$song_list.ensure_current_is_visible()
			$scrl_down.release_focus()
			break

func _on_edit_cancel_pressed() -> void:
	$del_custom_anim.play("cancel_panel")
	await $del_custom_anim.animation_finished
	$del_custom_panel/del_yes.show()
	$del_custom_panel/title_del_custom_s.text = "Are you sure you want to delete\nthis custom song? (This cannot be undone.)"
	$del_custom_panel/del_no.disabled = false
	$del_custom_panel/del_yes.disabled = false

func save_or_replace_song_id(new_id_line: String) -> void:
	var file_name_part = new_id_line.trim_prefix("SONGID ").split(" ")[0]

	var file = FileAccess.open(Globals.SONG_ID_ARR_PATH, FileAccess.READ)
	var lines := []
	if file:
		if file.get_length() > 0:
			lines = file.get_as_text().split("\n")
		file.close()

	var updated_lines := []
	var replaced := false

	for line in lines:
		if line.begins_with("SONGID "):
			var existing_file_name = line.trim_prefix("SONGID ").split(" ")[0]
			if existing_file_name == file_name_part:
				print("Replacing existing song ID: ", line)
				updated_lines.append(new_id_line)
				replaced = true
			else:
				updated_lines.append(line)
		elif line.strip_edges() != "":
			updated_lines.append(line)

	if not replaced:
		print("Appending new song ID: ", new_id_line)
		updated_lines.append(new_id_line)

	var out_file = FileAccess.open(Globals.SONG_ID_ARR_PATH, FileAccess.WRITE)
	if out_file:
		out_file.store_string("\n".join(updated_lines) + "\n")
		out_file.close()
	else:
		print("Failed to open SONG_ID_ARR_PATH for writing")

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
					var id_file = FileAccess.open(Globals.SONG_ID_ARR_PATH, FileAccess.READ)
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
					var out_file = FileAccess.open(Globals.SONG_ID_ARR_PATH, FileAccess.WRITE)
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

	var meta = $song_list.get_item_metadata(pending_delete_index)
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
			$del_custom_panel/del_yes.release_focus()
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
					$del_custom_panel/del_yes.release_focus()
					$del_custom_anim.play("confirm_panel")
					await $del_custom_anim.animation_finished
					_on_reload_pressed()
					return
		folder = dir.get_next()
	dir.list_dir_end()

	# Third Attempt: Full iteration after showing warning and disabling buttons
	print("Exact and closest folder didn't match, showing warning and iterating all folders...")
	$del_custom_panel/title_del_custom_s.text = "Folders with name \"" + song_name + "\" did not match song ID. Iterating through all folders..."
	$del_custom_panel/del_no.disabled = true
	$del_custom_panel/del_yes.disabled = true
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
		$del_custom_panel/title_del_custom_s.text = "ERROR: No folder matched Song ID: " + target_id
		$del_custom_panel/del_no.disabled = false
		$del_custom_panel/del_yes.disabled = true
		return

	$del_custom_panel/del_yes.release_focus()
	$del_custom_anim.play("confirm_panel")
	await $del_custom_anim.animation_finished
	_on_reload_pressed()

func _on_create_pressed() -> void:
	var edit = Globals.EDITOR.instantiate()
	
	get_tree().root.add_child(edit)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = edit
