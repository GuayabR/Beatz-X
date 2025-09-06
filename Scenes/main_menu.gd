extends Control

var bgsong: AudioStream # randomly selected stream

var current_menu = "main" # main / list / settings / loading | loading is selected when an animation is playing so you dont press buttons that trigger other animations

var spectrum: AudioEffectSpectrumAnalyzerInstance

var can_random := true

func _on_files_dropped(files: PackedStringArray) -> void:
	for file in files:
		_process_file(file)
	
func _process_file(path: String) -> void:
	var lower_ext := path.get_extension().to_lower()
	match lower_ext:
		"bx":
			print("Uploading beatzmap: ", path)
			$main_list._on_file_dialog_files_selected(true, [path], 0)
		"beatz":
			print("Uploading beatz chart: ", path)
			$main_list._on_file_dialog_files_selected(true, [path], 0)
		"mp3", "ogg", "wav":
			print("Song dropped passing to editor: ", path)
			$main_list.entered_mp3_on_window(path)
		_:
			print("Unsupported file dropped: ", path)

func _handle_file_args(args: PackedStringArray) -> void:
	for arg in args:
		_process_file(arg)

func _ready() -> void:
	var args = OS.get_cmdline_args()
	if args.size() > 0:
		_handle_file_args(args)
	
	get_window().files_dropped.connect(_on_files_dropped)
	
	if OS.get_name() in ["Android", "iOS", "Web"]:
		$exit_text.hide()
		$exit_game.hide()
	
	get_tree().quit_on_go_back = false
	spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Menu Song"), 0) as AudioEffectSpectrumAnalyzerInstance
	
	if current_menu == "list":
		if !Globals.settings.misc_settings.reduce_motion:
			$AnimationPlayer.play("scene_finish_load", -1, 0.75)
		else:
			$AnimationPlayer.play("scene_finish_load", -1, 250.0) # if reduce motion is turned on, play the animation at a very high speed so items still end up where they should be
		
		# all code below also happens after clicking the play button, changed it a bit so it also plays after clicking back on the selected song scene
		$settings_button.position = Vector2(780.0, -200.0)
		$settings_button.disabled = false
		$settings_text.modulate = Color("ffffff00")
		
		$logo_sprite.hide()
		$bg_main_menu.hide()
		$exit_game.hide()
		$exit_text.hide()
		
		$play_sprite.scale = Vector2.ZERO
	
		$main_list.show()
		play_random_song()
	else:
		if Globals.settings.misc_settings.reduce_motion:
			$AnimationPlayer.play("init", -1, 150.0)
			
	_apply_loaded_settings()

func _apply_loaded_settings():
	$settings_layer/ScrollContainer/settings_list/slogan.text = Globals.SLOGAN
	$settings_layer/ScrollContainer/settings_list/ver.text = "%s (%s) %s" % [Globals.NAME, Globals.port, Globals.VERSION]
	
	$settings_layer/ScrollContainer/settings_list/song_vol_slider.set_value_no_signal(Globals.settings.game.song_vol)
	$settings_layer/ScrollContainer/settings_list/menu_song_vol_slider.set_value_no_signal(Globals.settings.game.menu_song_vol)
	$settings_layer/ScrollContainer/settings_list/sfx_vol_slider.set_value_no_signal(Globals.settings.game.sfx_vol)
	
	$settings_layer/ScrollContainer/settings_list/song_vol_label.text = "Song Volume: " + str(int(Globals.settings.game.song_vol))
	$settings_layer/ScrollContainer/settings_list/menu_song_vol_label.text = "Menu Song Volume: " + str(int(Globals.settings.game.menu_song_vol))
	$settings_layer/ScrollContainer/settings_list/sfx_vol_label.text = "SFX Volume: " + str(int(Globals.settings.game.sfx_vol))
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Song"), linear_to_db(Globals.settings.game.song_vol / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu Song"), linear_to_db(Globals.settings.game.menu_song_vol / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(Globals.settings.game.sfx_vol / 100.0))
	
	if OS.get_name() == "Android":
		print("android load btns")
		$settings_layer/ScrollContainer/settings_list/mbl_btn_layout_label.show()
		$settings_layer/ScrollContainer/settings_list/mbl_btn_layout_drop.show()
		# Apply btn layout
		var btn_layouts = {
			0: 0,
			1: 1
		}.get(Globals.settings.game.mbl_btn_layout, 0) # defaults to 4 btn
		$settings_layer/ScrollContainer/settings_list/mbl_btn_layout_drop.select(btn_layouts)
		$settings_layer/ScrollContainer/settings_list/ver.text = "Beatz! X (" + str(OS.get_name()) + " Port) 1.3.0"
		
		$settings_layer/ScrollContainer/settings_list/res_label.hide()
		$settings_layer/ScrollContainer/settings_list/display_resolutions.hide()
		$settings_layer/ScrollContainer/settings_list/window_modes_label.hide()
		$settings_layer/ScrollContainer/settings_list/display_options.hide()
		$settings_layer/ScrollContainer/settings_list/borderless_check.hide()
		Globals.settings.misc_settings.borderless = true
		Globals.settings.misc_settings.window_mode = "exclusive_fullscreen"
		Globals.settings.misc_settings.resolution = [1920, 1080]
		Globals._save_settings()
	
	# Apply note anim toggle
	$settings_layer/ScrollContainer/settings_list/note_anim_toggle.set_pressed_no_signal(Globals.settings.misc_settings.note_anims)
	#if not Globals.settings.misc_settings.note_anims: $settings_layer/ScrollContainer/settings_list/HBoxContainer.hide()
	
	# Apply note style
	var note_styles = {
		"dance": 0,
		"techno": 1,
		"para": 2,
	}.get(Globals.settings.misc_settings.note_style, 0) # defaults to dance
	$settings_layer/ScrollContainer/settings_list/note_style_drop.select(note_styles)
	
	# Apply note speed
	var note_speeds = {
		5.0: 0,
		8.0: 1,
		10.0: 2,
		13.0: 3,
		15.0: 4,
		20.0: 5,
	}.get(Globals.settings.game.note_speed, 2) # defaults to 10
	$settings_layer/ScrollContainer/settings_list/note_speed_drop.select(note_speeds)
	
	# Apply note offset
	$settings_layer/ScrollContainer/settings_list/note_offset_edit.text = str(Globals.settings.misc_settings.note_offset)
	
	# Apply game speed
	$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = str(Globals.settings.game.speed)
	Engine.time_scale = Globals.settings.game.speed
	$bg_song.pitch_scale = Globals.settings.game.speed
	
	# Apply reduced motion
	$settings_layer/ScrollContainer/settings_list/reduce_motion_check.set_pressed_no_signal(Globals.settings.misc_settings.reduce_motion)
	
	# Apply show fps label
	$settings_layer/ScrollContainer/settings_list/fpsCheck.set_pressed_no_signal(Globals.settings.misc_settings.show_fps)
	
	# Apply fps mode
	match Globals.settings.misc_settings.fps as int:
		-1: $settings_layer/ScrollContainer/settings_list/fps_options.select(0)
		30: $settings_layer/ScrollContainer/settings_list/fps_options.select(1)
		60: $settings_layer/ScrollContainer/settings_list/fps_options.select(2)
		90: $settings_layer/ScrollContainer/settings_list/fps_options.select(3)
		120: $settings_layer/ScrollContainer/settings_list/fps_options.select(4)
		144: $settings_layer/ScrollContainer/settings_list/fps_options.select(5)
		165: $settings_layer/ScrollContainer/settings_list/fps_options.select(6)
		180: $settings_layer/ScrollContainer/settings_list/fps_options.select(7)
		240: $settings_layer/ScrollContainer/settings_list/fps_options.select(8)
		360: $settings_layer/ScrollContainer/settings_list/fps_options.select(9)
		540: $settings_layer/ScrollContainer/settings_list/fps_options.select(10)
		5000: $settings_layer/ScrollContainer/settings_list/fps_options.select(11)
		_: 
			$settings_layer/ScrollContainer/settings_list/fps_options.select(12)
			$settings_layer/ScrollContainer/settings_list/custom_fps.text = str(int(Globals.settings.misc_settings.fps))
			$settings_layer/ScrollContainer/settings_list/custom_fps.show()
	
	# Apply resolution
	var res_index = {
		Vector2i(3840, 2160): 0,
		Vector2i(2560, 1440): 1,
		Vector2i(1920, 1080): 2,
		Vector2i(1280, 720): 3
	}.get(Vector2i(Globals.settings.misc_settings.resolution[0], Globals.settings.misc_settings.resolution[1]), 2) # defaults to 1920x1080
	$settings_layer/ScrollContainer/settings_list/display_resolutions.select(res_index)
	
	# Apply window mode
	var window_modes := {
		"exclusive_fullscreen": 0,
		"fullscreen": 1,
		"maximized": 2,
		"minimized": 3,
		"windowed": 4
	}
	$settings_layer/ScrollContainer/settings_list/display_options.select(window_modes.get(Globals.settings.misc_settings.window_mode, 4)) # defaults to windowed
	
	# Apply borderless check
	$settings_layer/ScrollContainer/settings_list/borderless_check.set_pressed_no_signal(Globals.settings.misc_settings.borderless)

func _process(delta: float) -> void:
	if spectrum:
		# Get energy levels
		var overall_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 11050.0).length()
		var overall_loudness: float = clampf((111 + linear_to_db(overall_energy)) / 111.0, 0.0, 1.0)

		var bass_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 250.0).length()
		var bass_loudness: float = clampf((111 + linear_to_db(bass_energy)) / 111.0, 0.0, 1.0)

		#var treble_energy: float = spectrum.get_magnitude_for_frequency_range(5000.0, 11050.0).length()
		#var treble_loudness: float = clampf((111 + linear_to_db(treble_energy)) / 111.0, 0.0, 1.0)

		# Exponentiate for punch
		#var exp_treble := pow(treble_loudness, 1.5)
		var exp_overall := pow(overall_loudness, 3.0)
		var exp_bass := pow(bass_loudness, 2.5)
		var exp_bg := clampf(exp_bass * 0.8 + exp_overall * 0.1, 0.0, 1.0)
		
		# Base and max scale ranges
		var base_scale := 1.0
		#var max_title := 1.5
		var max_bg := 1.3

		# Interpolated targets
		#var title_target = lerp(base_scale, max_title, exp_treble)
		var bg_target = lerp(base_scale, max_bg, exp_bg)

		# Smooth transitions
		$bg_main_menu.scale = lerp($bg_main_menu.scale, Vector2(1.0, 1.0) * bg_target, 16.0 * delta)
		$TransitionRect.scale = lerp($TransitionRect.scale, Vector2(1.0, 1.0) * bg_target, 16.0 * delta)
		$main_list/background.scale = lerp($main_list/background.scale, Vector2(1.0, 1.0) * bg_target, 16.0 * delta)
		$main_list/TransitionRect.scale = lerp($main_list/TransitionRect.scale, Vector2(1.0, 1.0) * bg_target, 16.0 * delta)

func _on_bg_song_finished() -> void:
	play_random_song() # Once bg song finishes play another random song

func play_random_song() -> void:
	var song_files := []

	# Scan res://Resources/Songs/
	var dir = DirAccess.open("res://Resources/Songs/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".mp3"):
				song_files.append("res://Resources/Songs/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Scan user://Custom/ for any *.mp3 inside subfolders
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

	# Pick a random song
	if song_files.size() > 0:
		var random_song = song_files[randi() % song_files.size()]
		var bgsong

		if random_song.begins_with("res://"):
			# normal resource
			bgsong = load(random_song)
		else:
			# user:// file — create a new AudioStreamMP3
			var file_ext = random_song.get_extension().to_lower()
			if file_ext == "mp3":
				bgsong = AudioStreamMP3.load_from_file(random_song)
			elif file_ext == "ogg":
				bgsong = AudioStreamOggVorbis.load_from_file(random_song)
			else:
				print("Unsupported audio format: ", random_song)
				return
			$bg_song.stream = bgsong  # assign file data

		# Assign to audio players
		$bg_song.stream = bgsong
		$Visualizer/Song_left.stream = bgsong
		$Visualizer/Song_right.stream = bgsong

		$Visualizer/Song_left.play()
		$Visualizer/Song_right.play()
		$bg_song.play()

		$currently_playing.text = " Currently playing: " + random_song.get_file().trim_suffix("." + random_song.get_extension())
		

		if $song_playing_popup.current_animation in ["new_song_playing", "new_song_interrupt"]:
			$song_playing_popup.stop()
			$song_playing_popup.play("new_song_interrupt")
		else:
			$song_playing_popup.play("new_song_playing")
		
		$hot_corner_current_playing.size = $currently_playing.size + Vector2(30,0)
	else:
		print("No MP3 files found in Resources/Songs/ or user://Custom/")


func _on_play_button_button_up() -> void:
	$play_button.release_focus()
	if current_menu == "loading": return
	
	if !Globals.settings.misc_settings.reduce_motion:
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
	if !Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("scene_finish_load")
	else:
		$AnimationPlayer.play("scene_finish_load", -1, 250.0)

func _on_exit_game_button_up() -> void:
	$exit_game.release_focus()
	if current_menu == "main":
		if Globals.settings.misc_settings.reduce_motion:
			$AnimationPlayer.play("popup_leave", -1, 250.0)
		else:
			$AnimationPlayer.play("popup_leave")
	elif current_menu == "settings":
		if Globals.settings.misc_settings.reduce_motion:
			$AnimationPlayer.play("from_settings_to_main", -1, 250.0)
		else:
			$AnimationPlayer.play("from_settings_to_main")
	elif current_menu == "binds":
		if Globals.settings.misc_settings.reduce_motion:
			$AnimationPlayer.play("from_binds_to_stgs", -1, 250.0)
		else:
			$AnimationPlayer.play("from_binds_to_stgs")

func _on_main_list_went_back() -> void:
	if !Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("finish_back")
	else:
		$AnimationPlayer.play("finish_back", -1, 250.0)
		$play_sprite.show()
	
	$bg_main_menu.show()
	$play_button.show()
	$main_list.hide()

func _input(_event: InputEvent) -> void:
	if Input.is_action_pressed("ui_cancel"):
		_handle_back_pressed()
	
	if Input.is_action_pressed("randomize_menu_song") and can_random:
		play_random_song()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_pressed()

func _handle_back_pressed() -> void:
	match current_menu:
		"loading":
			print("new menu loading cant go back")
		"main":
			print("menu back")
			_on_exit_game_button_up()
		"popup_leave":
			print("popup cancel")
			_on_cancel_pressed()
		"list":
			print("list back")
			$main_list._on_back_button_up()
		"settings":
			print("settings back")
			var anim_name := "from_settings_to_main"
			var speed := 250.0 if Globals.settings.misc_settings.reduce_motion else 1.0
			$AnimationPlayer.play(anim_name, -1, speed)
		"binds":
			print("binds back")
			$AnimationPlayer.play("from_binds_to_stgs")

func _on_settings_button_up() -> void:
	$settings_button.release_focus()
	if current_menu == "loading": return
	if !Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("go_to_settings")
	else:
		$AnimationPlayer.play("go_to_settings", -1, 250.0)

func _on_main_list_song_sel() -> void: # When a song is selected, fade out the background song
	var tween := create_tween()
	tween.tween_property($bg_song, "volume_db", -80.0, 1.2)

func _on_accept_pressed() -> void:
	$popup_leave/Panel/Accept.release_focus()
	if !Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("accept_popup_leave")
		await get_tree().create_timer(0.7).timeout
		
		var tween := create_tween()
		tween.tween_property($bg_song, "volume_db", -80.0, 1.0)
		await get_tree().create_timer(0.9).timeout
	
	get_tree().quit()

func _on_cancel_pressed() -> void:
	$popup_leave/Panel/Cancel.release_focus()
	if !Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("cancel_popup_leave")
	else:
		$AnimationPlayer.play("cancel_popup_leave", -1, 250.0)

func _on_fps_check_toggled(toggled_on: bool) -> void:
	Globals.settings.misc_settings.show_fps = toggled_on
	save_stgs() # Always save settings

func _on_raw_fps_check_toggled(toggled_on: bool) -> void:
	Globals.settings.misc_settings.accurate_fps = toggled_on
	save_stgs() # Always save settings

func _on_fps_options_item_selected(index: int) -> void: # Instantly sets the selected setting when the user selects an option
	match index:
		0:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			Globals.settings.misc_settings.fps = -1 # Setting a max fps isnt needed since v sync overrides the max fps set
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		1:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 30
			Engine.max_fps = 30
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		2:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 60
			Engine.max_fps = 60
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		3:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 90
			Engine.max_fps = 90
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		4:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 120
			Engine.max_fps = 120
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		5:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 144
			Engine.max_fps = 144
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		6:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 165
			Engine.max_fps = 165
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		7:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 180
			Engine.max_fps = 180
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		8:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 240
			Engine.max_fps = 240
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		9:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 360
			Engine.max_fps = 360
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		10:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 540
			Engine.max_fps = 540
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		11:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 5000
			Engine.max_fps = 5000 # Set the max fps to a very high number so it overrides any other max fps
			$settings_layer/ScrollContainer/settings_list/custom_fps.hide()
		12:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Globals.settings.misc_settings.fps
			$settings_layer/ScrollContainer/settings_list/custom_fps.show()
	save_stgs()

func _on_custom_fps_text_submitted(new_text: String) -> void:
	if !new_text.is_valid_int(): 
		$settings_layer/ScrollContainer/settings_list/custom_fps.text = "Please enter a number."
		return
	var new_fps: int = new_text.to_int()
	if new_fps < 15:
		$settings_layer/ScrollContainer/settings_list/custom_fps.text = "Trust me you do not wanna play like this."
		return
	
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Globals.settings.misc_settings.fps = new_fps
	Engine.max_fps = new_fps
	save_stgs()

func _on_display_item_selected(index: int) -> void:
	var screen_size: Vector2i
	match index:
		0: screen_size = Vector2i(3840, 2160)
		1: screen_size = Vector2i(2560, 1440)
		2: screen_size = Vector2i(1920, 1080)
		3: screen_size = Vector2i(1280, 720)
	DisplayServer.window_set_size(screen_size)
	Globals.settings.misc_settings.resolution = [screen_size.x, screen_size.y]
	save_stgs()

func _on_display_options_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			Globals.settings.misc_settings.window_mode = "exclusive_fullscreen"
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			Globals.settings.misc_settings.window_mode = "fullscreen"
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			Globals.settings.misc_settings.window_mode = "maximized"
		3:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
			Globals.settings.misc_settings.window_mode = "minimized"
		4:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			Globals.settings.misc_settings.window_mode = "windowed"
	save_stgs()

func _on_borderless_check_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, toggled_on)
	Globals.settings.misc_settings.borderless = toggled_on
	save_stgs()

func _on_note_speed_item_selected(index: int) -> void:
	match index:
		0: Globals.settings.game.note_speed = 5.0
		1: Globals.settings.game.note_speed = 8.0
		2: Globals.settings.game.note_speed = 10.0
		3: Globals.settings.game.note_speed = 13.0
		4: Globals.settings.game.note_speed = 15.0
		5: Globals.settings.game.note_speed = 20.0
	save_stgs()

func _on_reduce_motion_toggled(toggled_on: bool) -> void:
	Globals.settings.misc_settings.reduce_motion = toggled_on
	save_stgs()

func _on_credits_btn_pressed() -> void:
	$AnimationPlayer.play("might_yap")
	await get_tree().create_timer(0.75).timeout
	get_tree().change_scene_to_file("res://Scenes/thank_you.tscn")

func _on_note_style_item_selected(index: int) -> void:
	match index:
		0: Globals.settings.misc_settings.note_style = "dance"
		1: Globals.settings.misc_settings.note_style = "techno"
		2: Globals.settings.misc_settings.note_style = "para"
	save_stgs()
	
func _on_note_offset_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		Globals.settings.misc_settings.note_offset = new_text.to_float() # If text is a valid number, change it from a string to a number and save
		save_stgs()
	else:
		$settings_layer/ScrollContainer/settings_list/note_offset_edit.text = "Please enter a number."

func _on_game_speed_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		var value := new_text.to_float()
		
		if value <= 0.09:
			$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = "Are you sure this is fun to you"
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 0.3)
		elif value <= 0.4 and value > 0.091:
			$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = "I would suggest a higher number."
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 1)
		elif value >= 3.0 and value < 7.9:
			$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = "I would suggest a smaller number."
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 10)
		elif value >= 8.0 and value < 49.9:
			$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = "I guess this is a little fun but still"
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 100)
		elif value >= 50:
			$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = "This will either crash your game or just destroy your ears, nice one bro"
			Globals.settings.game.speed = 1.0
			Engine.time_scale = 1.0
			$bg_song.pitch_scale = 1.0
			return  # Exit early to avoid entering speed back to the invalid number
		
		Globals.settings.game.speed = value
		Engine.time_scale = value
		$bg_song.pitch_scale = value
		save_stgs()
	else:
		$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = "Please enter a number."

func change_text_back_to_num_after_telling_user_a_higher_number(time: float = 1): # Function only used for the function above to tell user to use a slower or faster speed and then reset the text to whatever number they entered after a specific time
	await get_tree().create_timer(time).timeout
	$settings_layer/ScrollContainer/settings_list/game_speed_edit.text = str(Globals.settings.game.speed)

func save_stgs(): # Saves settings and plays the pop up
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	Globals._save_settings()
	$saved_settings.stop()
	$saved_settings.play("popup")

func _on_song_vol_slider_value_changed(value: float) -> void:
	var new_vol = int(value)
	Globals.settings.game.song_vol = new_vol
	$settings_layer/ScrollContainer/settings_list/song_vol_label.text = "Song Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Song"), linear_to_db(new_vol / 100.0))
	save_stgs()

func _on_menu_song_vol_slider_value_changed(value: float) -> void:
	var new_vol = int(value)
	Globals.settings.game.menu_song_vol = new_vol
	$settings_layer/ScrollContainer/settings_list/menu_song_vol_label.text = "Menu Song Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu Song"), linear_to_db(new_vol / 100.0))
	save_stgs()

func _on_sfx_vol_slider_value_changed(value: float) -> void:
	var new_vol = int(value)
	Globals.settings.game.sfx_vol = new_vol
	$settings_layer/ScrollContainer/settings_list/sfx_vol_label.text = "SFX Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(new_vol / 100.0))
	save_stgs()

func _on_mbl_btn_layout_drop_item_selected(index: int) -> void:
	match index:
		0: Globals.settings.game.mbl_btn_layout = 0
		1: Globals.settings.game.mbl_btn_layout = 1
	save_stgs()

func _on_note_anim_toggled(toggled_on: bool) -> void:
	Globals.settings.misc_settings.note_anims = toggled_on
	#if toggled_on: $settings_layer/ScrollContainer/settings_list/HBoxContainer.show()
	#else: $settings_layer/ScrollContainer/settings_list/HBoxContainer.hide()
	
	save_stgs()

func _on_change_binds_btn_pressed() -> void:
	$AnimationPlayer.play("from_settings_to_binds")

func _on_hot_corner_current_playing_mouse_entered() -> void:
	$song_playing_popup.stop()
	$song_playing_popup.play("new_song_playing", -1, 1.75)

func _on_hot_corner_current_playing_mouse_exited() -> void:
	if $song_playing_popup.is_playing(): $song_playing_popup.seek(2.8)
