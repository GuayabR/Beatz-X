extends Control

var bgsong: AudioStream # randomly selected stream

var current_menu: String = "main" # main / list / settings / loading | loading is selected when an animation is playing so you dont press buttons that trigger other animations

var spectrum: AudioEffectSpectrumAnalyzerInstance

var can_random := true

func _on_files_dropped(files: PackedStringArray) -> void:
	_process_files(files)


func _handle_file_args(args: PackedStringArray) -> void:
	_process_files(args)


func _process_files(files: PackedStringArray) -> void:
	if files.is_empty():
		return

	var beatzmaps: PackedStringArray = []
	var charts: PackedStringArray = []
	var songs: PackedStringArray = []
	var unsupported: PackedStringArray = []

	for path in files:
		if path.begins_with("--") or path.begins_with("uid://"):
			continue

		var lower_ext := path.get_extension().to_lower()
		match lower_ext:
			"bx":
				beatzmaps.append(path)
			"beatz":
				charts.append(path)
			"mp3", "ogg", "wav":
				songs.append(path)
			_:
				unsupported.append(path)

	# --- Process all at once ---
	if beatzmaps.size() > 0:
		print("Uploading beatzmaps:", beatzmaps)
		$main_list._on_file_dialog_files_selected(true, beatzmaps, 0)

	if charts.size() > 0:
		print("Uploading beatz charts:", charts)
		$main_list._on_file_dialog_files_selected(true, charts, 0)

	if songs.size() > 0:
		print("Passing songs to editor:", songs)
		for s in songs:
			$main_list.entered_mp3_on_window(s)

	if unsupported.size() > 0:
		for s in unsupported:
			print("Unsupported file dropped:", s)

func _ready() -> void:
	General.apply_fps_limit(name) # main_menu
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	var args = OS.get_cmdline_args()
	if args.size() > 0:
		_handle_file_args(args)
	
	get_window().files_dropped.connect(_on_files_dropped)
	
	if OS.get_name() in ["Android", "iOS", "Web"]:
		$exit_text.hide()
		$exit_game.hide()
	
	get_tree().quit_on_go_back = false
	spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Menu Song"), 0) as AudioEffectSpectrumAnalyzerInstance
	
	$bg_main_menu.modulate = Color(Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness)
	$main_list/background.self_modulate = Color(Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness, Settings.game.menu_bg_brightness)
	
	if Settings.misc.menu_bg_img_path != "":
		var img := Image.load_from_file(Settings.misc.menu_bg_img_path)
		if img: # make sure it loaded
			var tex := ImageTexture.create_from_image(img)
			$bg_main_menu.texture = tex
			$TransitionRect.texture = tex
			$main_list/background.texture = tex
			$main_list/TransitionRect.texture = tex
		else:
			print("Failed to load image at path:", Settings.misc.menu_bg_img_path)
	
	if not Settings.misc.vis: $Visualizer.hide()
	
	if current_menu == "list":
		$AnimationPlayer.pause()
		if !Settings.misc.reduce_motion:
			$AnimationPlayer.play("scene_finish_load", -1, 0.75)
		else:
			$AnimationPlayer.play("scene_finish_load", -1, 250.0) # if reduce motion is turned on, play the animation at a very high speed so items still end up where they should be
		
		# all code below also happens after clicking the play button, changed it a bit so it also plays after clicking back on the selected song scene
		$settings_button.position = Vector2(780.0, -200.0)
		$settings_button.disabled = false
		$settings_text.modulate = Color("ffffff00")
		
		$playing_bar.position.y = 1005.0
		$Visualizer.position.y = -75.0
		
		$playing_bar.show_cover()
		
		$logo_sprite.hide()
		$bg_main_menu.hide()
		$exit_game.hide()
		$exit_text.hide()
		
		$Visualizer.show()
		$Visualizer.self_modulate = Color(1.0, 1.0, 1.0, 0.388)
		
		$play_sprite.scale = Vector2.ZERO
		$main_list.show()
		play_random_song()
		await get_tree().create_timer(0.5, true, true, true).timeout
		current_menu = "list"
	else:
		if Settings.misc.reduce_motion:
			$AnimationPlayer.play("init", -1, 150.0)
	
	$logo_sprite/message.text = General.MAIN_MENU_MSGS.pick_random()
	
	await get_tree().process_frame
	
	$logo_sprite/message.pivot_offset = $logo_sprite/message.size / 2

var small_cover_pulse: bool = true

var weight = Settings.misc.menu_bg_pulse_strength

# Clamp scale safely between 1.0 and 20.0
func safe_scale(current: Vector2, target_scale: float, wght: float, delta: float) -> Vector2:
	var next = current.lerp(Vector2.ONE * target_scale, wght * delta)
	next.x = clampf(next.x, 1.0, 20.0)
	next.y = clampf(next.y, 1.0, 20.0)
	return next

func _process(delta: float) -> void:
	if $bg_song.is_playing():
		$playing_bar.set_time($bg_song.get_playback_position())
	
	if spectrum and Settings.misc.menu_bg_pulse:
		if $bg_song.is_playing():
			var overall_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 11050.0).length()
			var overall_loudness: float = clampf((111 + linear_to_db(overall_energy)) / 111.0, 0.0, 1.0)

			var bass_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 250.0).length()
			var bass_loudness: float = clampf((111 + linear_to_db(bass_energy)) / 111.0, 0.0, 1.0)

			var treble_energy: float = spectrum.get_magnitude_for_frequency_range(5000.0, 11050.0).length()
			var treble_loudness: float = clampf((111 + linear_to_db(treble_energy)) / 111.0, 0.0, 1.0)

			var exp_treble := pow(treble_loudness, 1.5)
			var exp_overall := pow(overall_loudness, 3.0)
			var exp_bass := pow(bass_loudness, 2.5)
			var exp_bg := clampf(exp_bass * 0.8 + exp_overall * 0.1, 0.0, 1.0)

			var base_scale := 1.0
			var max_title := 1.5
			var max_bg := 1.3

			var title_target = lerp(base_scale, max_title, exp_treble)
			var bg_target = lerp(base_scale, max_bg, exp_bg)
			
			$bg_main_menu.scale = safe_scale($bg_main_menu.scale, bg_target, weight, delta)
			$TransitionRect.scale = safe_scale($TransitionRect.scale, bg_target, weight, delta)
			$main_list/background.scale = safe_scale($main_list/background.scale, bg_target, weight, delta)
			$main_list/TransitionRect.scale = safe_scale($main_list/TransitionRect.scale, bg_target, weight, delta)
			
			$main_list/album_view/album_side/bg_cover_rotation_cont/bg_cover.scale = safe_scale($main_list/album_view/album_side/bg_cover_rotation_cont/bg_cover.scale, 3.622 * bg_target, weight, delta)
			
			$main_list/album_view/bg.scale = safe_scale($main_list/album_view/bg.scale, bg_target, weight, delta)
			$main_list/album_view/TransitionRect.scale = safe_scale($main_list/album_view/TransitionRect.scale, bg_target, weight, delta)
			
			$logo_sprite/message.scale = safe_scale($logo_sprite/message.scale, bg_target, weight * 1.4, delta)

			if $playing_bar.showing:
				if small_cover_pulse:
					$playing_bar/cover_mask.scale = safe_scale($playing_bar/cover_mask.scale, 2.202 * title_target, weight, delta)
				else:
					$playing_bar/cover_mask.scale = safe_scale($playing_bar/cover_mask.scale, 2.202, weight / 1.4, delta)
		else:
			$bg_main_menu.scale = safe_scale($bg_main_menu.scale, 1.0, weight / 2.5, delta)
			$TransitionRect.scale = safe_scale($TransitionRect.scale, 1.0, weight / 2.5, delta)
			$main_list/background.scale = safe_scale($main_list/background.scale, 1.0, weight / 2.5, delta)
			$main_list/TransitionRect.scale = safe_scale($main_list/TransitionRect.scale, 1.0, weight / 2.5, delta)
			
			$main_list/album_view/album_side/bg_cover_rotation_cont/bg_cover.scale = safe_scale($main_list/album_view/album_side/bg_cover_rotation_cont/bg_cover.scale, 3.622, weight / 2.5, delta)
			
			$main_list/album_view/bg.scale = safe_scale($main_list/album_view/bg.scale, 1.0, weight / 2.5, delta)
			$main_list/album_view/TransitionRect.scale = safe_scale($main_list/album_view/TransitionRect.scale, 1.0, weight / 2.5, delta)
			
			$logo_sprite/message.scale = safe_scale($logo_sprite/message.scale, 1.0, weight / 3.0, delta)
			
			$playing_bar/cover_mask.scale = safe_scale($playing_bar/cover_mask.scale, 2.202, weight / 3.0, delta)
	else:
		$bg_main_menu.scale = Vector2.ONE
		$TransitionRect.scale = Vector2.ONE
		$main_list/background.scale = Vector2.ONE
		$main_list/TransitionRect.scale = Vector2.ONE
		$playing_bar/cover_mask.scale = Vector2(2.202, 2.202)

var _song_thread: Thread

func play_random_song() -> void:
	if _song_thread:
		_song_thread.wait_to_finish()
		_song_thread = Thread.new()
		_song_thread.start(Callable(self, "_thread_play_random_song"))
	else:
		_song_thread = Thread.new()
		_song_thread.start(Callable(self, "_thread_play_random_song"))

func _thread_play_random_song() -> void:
	if not can_random: return
	can_random = false
	
	var data := {}

	# Copy your file scanning and loading logic here, but don't touch UI yet.
	# We'll just collect everything in `data`.

	var song_files := []
	var dir = DirAccess.open("res://Resources/Songs/")
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if not dir.current_is_dir() and f.ends_with(".mp3"):
				song_files.append("res://Resources/Songs/" + f)
			f = dir.get_next()
		dir.list_dir_end()

	var user_dir = DirAccess.open("user://Custom/")
	if user_dir:
		user_dir.list_dir_begin()
		var folder_name = user_dir.get_next()
		while folder_name != "":
			if folder_name != "." and folder_name != "..":
				var subfolder = "user://Custom/" + folder_name
				var sub_dir = DirAccess.open(subfolder)
				if sub_dir:
					sub_dir.list_dir_begin()
					var subfile = sub_dir.get_next()
					while subfile != "":
						if not sub_dir.current_is_dir() and subfile.ends_with(".mp3"):
							song_files.append(subfolder + "/" + subfile)
						subfile = sub_dir.get_next()
					sub_dir.list_dir_end()
			folder_name = user_dir.get_next()
		user_dir.list_dir_end()

	if song_files.is_empty():
		print("No songs found.")
		return

	var random_song = song_files[randi() % song_files.size()]
	data["path"] = random_song

	# Load stream
	if random_song.begins_with("res://"):
		bgsong = load(random_song)
	else:
		var ext = random_song.get_extension().to_lower()
		if ext == "mp3":
			bgsong = AudioStreamMP3.load_from_file(random_song)
		elif ext == "ogg":
			bgsong = AudioStreamOggVorbis.load_from_file(random_song)
	data["stream"] = bgsong

	# Parse info.json etc. (same as before)
	data["title"] = random_song.get_file().trim_suffix("." + random_song.get_extension())
	data["artist"] = ""
	data["album"] = ""
	data["year"] = -1
	data["cover"] = null

	if random_song.begins_with("user://Custom/"):
		var folder_path = random_song.get_base_dir()
		var info_path = folder_path.path_join("info.json")
		if FileAccess.file_exists(info_path):
			var info = JSON.parse_string(FileAccess.get_file_as_string(info_path))
			if typeof(info) == TYPE_DICTIONARY and info.has("info"):
				var i = info["info"]
				data["title"] = i.get("title", data["title"])
				data["artist"] = i.get("artist", "")
				data["album"] = i.get("album", "")
				data["year"] = i.get("year", -1)
				if i.has("cover"):
					var cover_path = folder_path.path_join(str(i["cover"]))
					if FileAccess.file_exists(cover_path):
						var img := Image.new()
						if img.load(ProjectSettings.globalize_path(cover_path)) == OK:
							data["cover"] = ImageTexture.create_from_image(img)
	
	elif random_song.begins_with("res://Resources/Songs/"): 
		print("Internal song ", random_song) 
		var info_path: String = "res://song_info.json" 
		if FileAccess.file_exists(info_path): 
			var info_file := FileAccess.open(info_path, FileAccess.READ) 
			var info_data = JSON.parse_string(info_file.get_as_text()) 
			info_file.close() 
			if typeof(info_data) == TYPE_ARRAY: 
				var target_file = random_song.get_file() 
				for entry in info_data: 
					if entry.has("file_name") and entry["file_name"] == target_file: 
						data["title"] = entry.get("song_name", target_file)
						data["artist"] = entry.get("artist", "")
						data["album"] = entry.get("album", "")
						data["year"] = entry.get("year", -1) 
						var cover_path = "res://Resources/Covers/" + data["album"] + ".png"
						if ResourceLoader.exists(cover_path): 
							data["cover"] = load(cover_path) 
							break
						else: print("Invalid song_info.json format") 
					else: print("No song_info.json found in res://")

	# Now safely apply results in main thread
	call_deferred("apply_song_data", data)
	can_random = true

func apply_song_data(data: Dictionary) -> void:
	if not data.has("stream"):
		print("Thread failed to load song.")
		return

	$bg_song.stream = bgsong
	$Visualizer/Song_left.stream = bgsong
	$Visualizer/Song_right.stream = bgsong

	$Visualizer/Song_left.play()
	$Visualizer/Song_right.play()
	$bg_song.play()
	
	var colors: Array[Color] = [Color.WHITE]
	
	# Example of optional color extraction (do in main thread)
	if data["cover"]:
		var img = data["cover"].get_image()
		if img:
			var cols: Array[Color] = General.extract_dominant_colors(img)
			if not cols.is_empty():
				$Visualizer.colors = cols
				colors = cols
			else:
				$Visualizer.colors = [Color.WHITE] as Array[Color]
	
	$playing_bar.set_song(
		data["title"], 
		data["artist"], 
		bgsong.get_length(),
		data["year"], 
		data["album"], 
		data["cover"],
		colors
	)

func _on_play_button_button_up() -> void:
	$play_button.release_focus()
	if current_menu == "loading": return
	
	if !Settings.misc.reduce_motion:
		$AnimationPlayer.play("scene_load")
		await get_tree().create_timer(0.73).timeout
	else:
		$AnimationPlayer.play("scene_load", -1, 250.0)
		$play_sprite.hide()
	$logo_sprite.hide()
	$bg_main_menu.hide()
	$exit_game.hide()
	$exit_text.hide()
	
	current_menu = "list"
	
	$main_list.show()
	
	General._set_rpc("A Rhythm Game by GuayabR", "Selecting a Song...", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(Time.get_unix_time_from_system()), 0)
	
	if !Settings.misc.reduce_motion:
		$AnimationPlayer.play("scene_finish_load")
	else:
		$AnimationPlayer.play("scene_finish_load", -1, 250.0)

func _on_exit_game_button_up() -> void:
	$exit_game.release_focus()
	if current_menu == "main":
		if Settings.misc.reduce_motion:
			$AnimationPlayer.play("popup_leave", -1, 250.0)
		else:
			$AnimationPlayer.play("popup_leave")
	elif current_menu == "settings":
		if Settings.misc.reduce_motion:
			$AnimationPlayer.play("from_settings_to_main", -1, 250.0)
		else:
			$AnimationPlayer.play("from_settings_to_main")

func _on_main_list_went_back() -> void:
	if !Settings.misc.reduce_motion:
		$AnimationPlayer.play("finish_back")
	else:
		$AnimationPlayer.play("finish_back", -1, 250.0)
		$play_sprite.show()
	
	$bg_main_menu.show()
	$play_button.show()
	$main_list.hide()
	
	General._set_rpc("A Rhythm Game by GuayabR", "Main Menu", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", General.play_start_time, 0)

func _input(event: InputEvent) -> void:
	if Input.get_connected_joypads().size() > 0:
		# Only process if this event came from a controller
		if event.is_action_pressed("controller-back") and event.device in Input.get_connected_joypads():
			print("controlo back")
			_handle_back_pressed()
		
		if event.is_action_pressed("controller-pause") and event.device in Input.get_connected_joypads():
			print("controlo pause")
			if current_menu == "main": _on_settings_button_up()
			elif current_menu == "settings": _handle_back_pressed()
		
		if event.is_action_pressed("controller-accept") and event.device in Input.get_connected_joypads():
			print("controlo accept")
			if current_menu == "main":
				_on_play_button_button_up()
			elif current_menu == "popup_leave":
				print("popup cancel control")
				_on_accept_pressed()
	
	if Input.is_action_just_pressed("pause-back"):
		_handle_back_pressed()
	
	if Input.is_action_pressed("randomize_menu_song") and can_random:
		play_random_song()
	
	if Input.is_action_just_pressed("vol_up") or Input.is_action_just_pressed("vol_down"):
		$playing_bar._on_volume_changed()
		
		# Adjust volume
		if Input.is_action_just_pressed("vol_up"):
			Settings.game.master_vol += 1.0
		else:
			Settings.game.master_vol -= 1.0
		
		# Clamp & apply
		Settings.game.master_vol = clampf(Settings.game.master_vol, 0.0, 100.0)
		Settings._save()
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index("Master"),
			linear_to_db(Settings.game.master_vol / 100.0)
		)
		
		$settings/ScrollContainer/settings_list/master_vol_slider.set_value_no_signal(Settings.game.master_vol)
		$settings/ScrollContainer/settings_list/master_vol_label.text = "Master Volume: " + str(Settings.game.master_vol)
		
		# Reset the hide timer
		if volume_hide_timer:
			volume_hide_timer.disconnect("timeout", Callable($playing_bar, "_on_volume_corner_mouse_exited"))
			volume_hide_timer = null

		volume_hide_timer = get_tree().create_timer(1.5)
		volume_hide_timer.timeout.connect($playing_bar._on_volume_corner_mouse_exited)

var volume_hide_timer: SceneTreeTimer

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_pressed()

func _handle_back_pressed() -> void:
	match current_menu:
		"loading":
			print("new menu loading cant go back")
			print(current_menu)
		"main":
			print("menu back")
			_on_exit_game_button_up()
		"popup_leave":
			print("popup cancel")
			_on_cancel_pressed()
		"list":
			print("list back")
			$main_list/background.release_focus()
			$main_list/center/song_list.deselect_all()
			$main_list/center/song_list.release_focus()
			$main_list._on_back_button_up()
		"settings":
			print("settings back")
			var anim_name := "from_settings_to_main"
			var speed := 250.0 if Settings.misc.reduce_motion else 1.0
			$AnimationPlayer.play(anim_name, -1, speed)
		"binds":
			print("binds back")
			$AnimationPlayer.play("from_binds_to_stgs")

func _on_settings_button_up() -> void:
	$settings_button.release_focus()
	if current_menu == "loading": return
	if !Settings.misc.reduce_motion:
		$AnimationPlayer.play("go_to_settings")
	else:
		$AnimationPlayer.play("go_to_settings", -1, 250.0)

func _on_main_list_song_sel() -> void: # When a song is selected, fade out the background song
	var tween := create_tween()
	tween.tween_property($bg_song, "volume_db", -80.0, 1.2)

func _on_accept_pressed() -> void:
	$popup_leave/Panel/Accept.release_focus()
	if !Settings.misc.reduce_motion:
		$AnimationPlayer.play("accept_popup_leave")
		await get_tree().create_timer(0.7).timeout
		
		var tween := create_tween()
		tween.tween_property($bg_song, "volume_db", -80.0, 1.0)
		await get_tree().create_timer(0.9).timeout
	
	get_tree().quit()

func _on_cancel_pressed() -> void:
	$popup_leave/Panel/Cancel.release_focus()
	if !Settings.misc.reduce_motion:
		$AnimationPlayer.play("cancel_popup_leave")
	else:
		$AnimationPlayer.play("cancel_popup_leave", -1, 250.0)

func _on_settings_bg_changed(tex: ImageTexture) -> void:
	$bg_main_menu.texture = tex
	$TransitionRect.texture = tex
	$main_list/background.texture = tex
	$main_list/TransitionRect.texture = tex

func _on_settings_vis_toggled(toggled: bool) -> void:
	if not toggled:
		$Visualizer.force_fade_out(0.75)
	else:
		$Visualizer/Song_left.stream = $bg_song.stream
		$Visualizer/Song_right.stream = $bg_song.stream
		$Visualizer/Song_left.play($bg_song.get_playback_position())
		$Visualizer/Song_right.play($bg_song.get_playback_position())
		$Visualizer.force_fade_in()

func _on_playing_bar_seek_ended(value_changed: bool, ending_value: float) -> void:
	if not value_changed: return
	else:
		$bg_song.seek(ending_value)
		$Visualizer/Song_left.seek(ending_value)
		$Visualizer/Song_right.seek(ending_value)
		print(ending_value)

func _on_playing_bar_randomized() -> void:
	play_random_song()

func _on_playing_bar_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu Song"), linear_to_db(value / 100.0))
	Settings.game.menu_song_vol = value
	$settings/ScrollContainer/settings_list/menu_song_vol_slider.set_value_no_signal(value)
	$settings/ScrollContainer/settings_list/menu_song_vol_label.text = "Menu Song Volume: " + str(value)

func _on_playing_bar_volume_drag_ended(value_changed: bool, _value: float):
	if value_changed: Settings._save()

var saved_pos: float

func _on_playing_bar_play_toggled() -> void:
	if $bg_song.is_playing():
		saved_pos = $bg_song.get_playback_position()
		$bg_song.stop()
		$Visualizer/Song_left.stop()
		$Visualizer/Song_right.stop()
	else:
		$bg_song.play(saved_pos)
		$Visualizer/Song_left.play(saved_pos)
		$Visualizer/Song_right.play(saved_pos)

func _on_playing_bar_cover_pressed() -> void:
	small_cover_pulse = !small_cover_pulse

func _on_song_list_context_play_as_bg_song(path: String) -> void:
	var data := {}
	data["path"] = path

	# --- Load audio stream ---
	if path.begins_with("res://"):
		bgsong = load(path)
	else:
		var ext = path.get_extension().to_lower()
		if ext == "mp3":
			bgsong = AudioStreamMP3.load_from_file(path)
		elif ext == "ogg":
			bgsong = AudioStreamOggVorbis.load_from_file(path)
		else:
			print("Unsupported audio format: ", path)
			return
	data["stream"] = bgsong

	# --- Default metadata ---
	data["title"] = path.get_file().trim_suffix("." + path.get_extension())
	data["artist"] = ""
	data["album"] = ""
	data["year"] = -1
	data["cover"] = null

	# --- Handle Custom songs ---
	if path.begins_with("user://Custom/"):
		var folder_path = path.get_base_dir()
		var info_path = folder_path.path_join("info.json")
		if FileAccess.file_exists(info_path):
			var info = JSON.parse_string(FileAccess.get_file_as_string(info_path))
			if typeof(info) == TYPE_DICTIONARY and info.has("info"):
				var i = info["info"]
				data["title"] = i.get("title", data["title"])
				data["artist"] = i.get("artist", "")
				data["album"] = i.get("album", "")
				data["year"] = i.get("year", -1)
				if i.has("cover"):
					var cover_path = folder_path.path_join(str(i["cover"]))
					if FileAccess.file_exists(cover_path):
						var img := Image.new()
						if img.load(ProjectSettings.globalize_path(cover_path)) == OK:
							data["cover"] = ImageTexture.create_from_image(img)

	# --- Handle Resources/Songs ---
	elif path.begins_with("res://Resources/Songs/"):
		var info_path: String = "res://song_info.json"
		if FileAccess.file_exists(info_path):
			var info_data = JSON.parse_string(FileAccess.get_file_as_string(info_path))
			if typeof(info_data) == TYPE_ARRAY:
				var target_file = path.get_file()
				for entry in info_data:
					if entry.has("file_name") and entry["file_name"] == target_file:
						data["title"] = entry.get("song_name", data["title"])
						data["artist"] = entry.get("artist", "")
						data["album"] = entry.get("album", "")
						data["year"] = entry.get("year", -1)
						var cover_path = "res://Resources/Covers/" + data["album"] + ".png"
						if ResourceLoader.exists(cover_path):
							data["cover"] = load(cover_path)
						break

	# --- Apply data safely on main thread ---
	call_deferred("apply_song_data", data)


func _on_main_list_item_context_menu(meta: Dictionary, pos: Vector2, idx: int) -> void:
	$song_list_context.show()
	$song_list_context.global_position = pos + Vector2(210, 8)
	$song_list_context.appear(meta.song_name, meta, idx)

func _on_main_list_item_context_menu_focus_released() -> void:
	$song_list_context.hide()

func _on_main_list_item_play_as_bg(path: String) -> void:
	_on_song_list_context_play_as_bg_song(path)

func _on_new_ver_popup_new_version() -> void:
	$new_ver_popup/HBoxContainer/ok.grab_focus()
	$overlay.show()
	var t = create_tween() 
	t.tween_property($new_ver_popup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CIRC)
	t.parallel().tween_property($overlay, "color", Color(0.0, 0.0, 0.0, 0.75), 0.2).set_trans(Tween.TRANS_CIRC)

func _on_overlay_focus_entered() -> void:
	_on_new_ver_popup_close()

func _on_new_ver_popup_close() -> void:
	$overlay.release_focus()
	var t = create_tween() 
	t.tween_property($new_ver_popup, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_CIRC)
	t.parallel().tween_property($overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.2).set_trans(Tween.TRANS_CIRC)
	await t.finished
	$overlay.hide()

func _on_settings_check_for_upd_pressed() -> void:
	$new_ver_popup.check_for_update(true)

func _on_message_focus_entered() -> void:
	$logo_sprite/message.release_focus()
	
	$logo_sprite/message.text = General.MAIN_MENU_MSGS.pick_random()
	await get_tree().process_frame
	$logo_sprite/message.pivot_offset = $logo_sprite/message.size / 2

func _on_settings_set_profile(img: ImageTexture) -> void:
	$settings/ScrollContainer/settings_list/profile_small.set_profile(img)

func _on_settings_set_banner(img: ImageTexture) -> void:
	$settings/ScrollContainer/settings_list/profile_small.set_banner(img)

func _on_settings_set_username(user: String) -> void:
	$settings/ScrollContainer/settings_list/profile_small.set_user(user)

func _on_settings_set_title(title: String) -> void:
	$settings/ScrollContainer/settings_list/profile_small.set_title(title)

func _on_settings_set_clan(clan: String) -> void:
	$settings/ScrollContainer/settings_list/profile_small.set_clan(clan)

func _on_song_list_context_play(idx: int, _path: String, from_album: bool) -> void:
	$main_list/center/song_list.mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	$main_list/album_view/charts_side/song_list.mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	
	print("Playing from context, ", idx, ", ", _path)
	var metadata = $main_list/center/song_list.get_item_metadata(idx) if not from_album else $main_list/album_view/charts_side/song_list.get_item_metadata(idx)
	
	print(metadata)
	
	$main_list/AnimationPlayer.play("go_to_selected")
	
	var tween := create_tween()
	tween.tween_property($bg_song, "volume_db", -80.0, 0.8).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	var selected_beatz_path = metadata["beatz_path"]
	var selected_title = metadata["song_name"]
	var selected_album = metadata["album"]
	var selected_cover = metadata["cover_texture"]
	var diff_texture_path = metadata["diff_texture_path"]
	var selected_artist = metadata["artist"]
	var selected_year = metadata["year"]
	var selected_bpm = metadata["bpm"]
	var selected_charter = metadata["charter"]
	var selected_stream = metadata["stream"]
	var selected_beat_offset = metadata["local_beat_offset"]
	var selected_background: String = metadata["selected_background"]
	
	var background_vid_path: String = metadata["background_vid"]
	
	var game = General.MAIN.instantiate()
	
	var beatz_file := FileAccess.open(selected_beatz_path, FileAccess.READ)
	var content := beatz_file.get_as_text()
	var beatz_data := General.import_beatz_file(content)
	
	# Pass data to the loading scene (it will forward it to main when loaded)
	game.set("chart_path", selected_beatz_path)
	game.set("song_path", selected_stream)
	
	var stream: AudioStream

	if not FileAccess.file_exists(selected_stream):
		push_warning("Stream file not found: " + selected_stream)
		return

	var ext = selected_stream.get_extension().to_lower()

	match ext:
		"mp3":
			stream = AudioStreamMP3.load_from_file(selected_stream)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(selected_stream)
		"wav":
			stream = AudioStreamWAV.load_from_file(selected_stream)
		_:
			push_warning("Unsupported audio format: " + ext)
			return

	if stream:
		game.set("song", stream)
		print("✅ Loaded audio stream:", selected_stream, "(", ext, ")")
	else:
		push_warning("Failed to load audio stream from: " + selected_stream)
	
	game.set("song_title", selected_title)
	game.set("BPM", selected_bpm)
	game.set("local_beat_offset", selected_beat_offset)
	game.set("selected_background", selected_background)
	game.set("selected_background_name", selected_background.get_file())
	game.set("background_vid_path", background_vid_path)
	game.set("album", selected_album)
	game.set("artist", selected_artist)
	game.set("year", selected_year)
	game.set("cover", selected_cover.get_image())
	game.set("start_wait", beatz_data["start_wait"])
	game.set("preview_start", beatz_data["preview_start"])
	game.set("preview_end", beatz_data["preview_end"])
	game.set("charter", selected_charter)
	game.set("difficulty", beatz_data["difficulty"])
	game.set("diff_texture_path", diff_texture_path)
	game.set("customNotes", beatz_data["notes"])
	game.set("chart_name", beatz_data["chart_name"])
	game.set("start_wait", beatz_data["start_wait"])
	game.set("colors", General.extract_dominant_colors(selected_cover.get_image()))
	
	get_tree().root.add_child(game)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game

func _on_song_list_context_edit(idx: int, _path: String, from_album: bool) -> void:
	$main_list/center/song_list.mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	
	print("Editing from context, ", idx, ", ", _path)
	var metadata = $main_list/center/song_list.get_item_metadata(idx) if not from_album else $main_list/album_view/charts_side/song_list.get_item_metadata(idx)
	
	print(metadata)
	
	$main_list/AnimationPlayer.play("go_to_selected")
	
	var tween := create_tween()
	tween.tween_property($bg_song, "volume_db", -80.0, 0.8).set_ease(Tween.EASE_OUT)
	
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
	
	var selected_background: String = metadata["selected_background"]
	
	var background_vid_path: String = metadata["background_vid"]
	
	#var speed = metadata["speed"]
	# Ignore separators (they have no metadata or missing stream)
	if metadata == null or !metadata.has("stream"):
		print("Selected item is a separator or missing data")
		return
	
	$main_list/center/cover_sel.texture = $main_list/center/song_list.get_item_icon(idx)
	
	$main_list/center/song_list.mouse_filter = MOUSE_FILTER_IGNORE
	
	if metadata:
		await get_tree().create_timer(1.4).timeout
		
		print("Selected song: %s by %s (%d) from album %s" % [song_name, artist, year, album])
		
		var edit = General.EDITOR.instantiate()
		
		var beatz_file := FileAccess.open(beatz_path, FileAccess.READ)
		var content := beatz_file.get_as_text()
		var beatz_data := General.import_beatz_file(content)
		
		edit.new_beatzmap = false
		
		edit.set("selected_stream_path", selected_stream)

		var stream: AudioStream

		if not FileAccess.file_exists(selected_stream):
			push_warning("Stream file not found: " + selected_stream)
			return

		var ext = selected_stream.get_extension().to_lower()

		match ext:
			"mp3":
				stream = AudioStreamMP3.load_from_file(selected_stream)
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(selected_stream)
			"wav":
				stream = AudioStreamWAV.load_from_file(selected_stream)
			_:
				push_warning("Unsupported audio format: " + ext)
				return

		if stream:
			edit.set("selected_stream", stream)
			print("✅ Loaded audio stream:", selected_stream, "(", ext, ")")
		else:
			push_warning("Failed to load audio stream from: " + selected_stream)

		edit.set("selected_title", song_name)
		edit.set("selected_album", album)
		
		var cover_img: Image = cover_texture.get_image()
		edit.set("selected_cover", cover_img)
		edit.set("selected_artist", artist)
		edit.set("selected_year", year)
		
		edit.set("start_wait", beatz_data["start_wait"])
		edit.set("preview_start", beatz_data["preview_start"])
		edit.set("preview_end", beatz_data["preview_end"])
		
		edit.set("selected_difficulty", beatz_data["difficulty"])
		
		if diff_texture_path:
			var d_img := Image.load_from_file(diff_texture_path)
			var d_tex := ImageTexture.create_from_image(d_img)
			
			edit.set("selected_diff_texture", d_tex)
		
		edit.set("notes", beatz_data["notes"])
		edit.set("selected_chart_name", beatz_data["chart_name"])
		
		edit.set("selected_beatz_path", beatz_path)
		
		edit.set("selected_beat_offset", selected_beat_offset)
		
		edit.set("background_vid_path", background_vid_path)
		
		if selected_background != "" and not selected_background.ends_with("/"):
			var img_ext := selected_background.get_extension().to_lower()
			if img_ext in General.IMG_FORMATS:
				# ✅ It's a valid image file
				if FileAccess.file_exists(selected_background):
					var img := Image.load_from_file(selected_background)
					edit.set("selected_background", img)
					edit.set("selected_background_name", selected_background.get_file())
					print("Loaded background:", selected_background.get_file())
				else:
					push_warning("Background file does not exist: " + selected_background)
			else:
				push_warning("Invalid background extension: " + img_ext)
		else:
			push_warning("Selected background is a folder or invalid path: " + selected_background)
		
		edit.set("selected_bpm", bpm)
		edit.set("selected_charter", charter)
		
		var colors: Array[Color] = General.extract_dominant_colors(cover_img)
		
		edit.set("colors", colors)
		
		get_tree().root.add_child(edit)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = edit
	else:
		print("No metadata found for song list item: ", idx) # If no metadata found, return to main menu
		print(selected_stream)
		print(metadata)
		
		if !Settings.misc.reduce_motion: await get_tree().create_timer(1.4).timeout
		
		var main = load("res://Scenes/main_menu.tscn").instantiate()
		get_tree().root.add_child(main)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = main

func _on_song_list_context_delete(idx: int, _path: String, from_album: bool) -> void:
	if not from_album:
		$main_list.delete_from_context = true
		$main_list.edit_mode = true
		$main_list.pending_delete_index = idx
		$main_list._on_song_selected(idx)
	else:
		print("do something from album view delete")

func _on_settings_menu_brightness_changed(value: float) -> void:
	$bg_main_menu.modulate = Color(value, value, value)
	$main_list/background.self_modulate = Color(value, value, value)

func _on_main_list_loaded_song(title: String) -> void:
	$loading_text.text = "Loaded " + title + "."

func _on_main_list_loading_song(title: String) -> void:
	$loading_text.text = "Loading Song: " + title
	#print("loading ", title)

func _on_main_list_loaded_song_meta(title: String) -> void:
	$loading_text.text = "Loaded " + title + "'s metadata."
	#print("meta ", title)

func _on_song_list_context_go_to_album_pressed(idx: int, album_name: String, album_artist: String, album_year: int, album_cover: Image) -> void:
	print(idx)
	print(album_name)
	$main_list.go_to_album(album_name, album_artist, album_year, album_cover)

func _on_album_view_item_context_menu(meta: Dictionary, pos: Vector2, idx: int) -> void:
	$song_list_context.show()
	$song_list_context.global_position = pos + Vector2(420, 8)
	$song_list_context.appear(meta.song_name, meta, idx, true)

func _on_album_view_item_context_menu_focus_released() -> void:
	$song_list_context.hide()

func _on_album_view_item_play_as_bg(path: Variant) -> void:
	_on_song_list_context_play_as_bg_song(path)
