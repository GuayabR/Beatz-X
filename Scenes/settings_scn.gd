extends Control

func _ready() -> void:
	$ScrollContainer/settings_list/slogan.text = Globals.SLOGAN
	$ScrollContainer/settings_list/ver.text = "%s (%s) %s" % [Globals.NAME, Globals.port, Globals.VERSION]
	_apply_loaded_settings()

func _apply_loaded_settings():
	$ScrollContainer/settings_list/song_vol_slider.set_value_no_signal(Globals.settings.game.song_vol)
	$ScrollContainer/settings_list/menu_song_vol_slider.set_value_no_signal(Globals.settings.game.menu_song_vol)
	$ScrollContainer/settings_list/sfx_vol_slider.set_value_no_signal(Globals.settings.game.sfx_vol)
	$ScrollContainer/settings_list/song_vol_label.text = "Song Volume: " + str(int(Globals.settings.game.song_vol))
	$ScrollContainer/settings_list/menu_song_vol_label.text = "Menu Song Volume: " + str(int(Globals.settings.game.menu_song_vol))
	$ScrollContainer/settings_list/sfx_vol_label.text = "SFX Volume: " + str(int(Globals.settings.game.sfx_vol))
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Song"), linear_to_db(Globals.settings.game.song_vol / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu Song"), linear_to_db(Globals.settings.game.menu_song_vol / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(Globals.settings.game.sfx_vol / 100.0))
	
	if OS.get_name() == "Android":
		print("android load btns")
		$ScrollContainer/settings_list/mbl_btn_layout_label.show()
		$ScrollContainer/settings_list/mbl_btn_layout_drop.show()
		# Apply btn layout
		var btn_layouts = {
			0: 0,
			1: 1
		}.get(Globals.settings.game.mbl_btn_layout, 0) # defaults to 4 btn
		$ScrollContainer/settings_list/mbl_btn_layout_drop.select(btn_layouts)
		$ScrollContainer/settings_list/ver.text = "Beatz! X (" + str(OS.get_name()) + " Port) 1.3.0"
		
		$ScrollContainer/settings_list/res_label.hide()
		$ScrollContainer/settings_list/display_resolutions.hide()
		$ScrollContainer/settings_list/window_modes_label.hide()
		$ScrollContainer/settings_list/display_options.hide()
		$ScrollContainer/settings_list/borderless_check.hide()
		Globals.settings.misc_settings.borderless = true
		Globals.settings.misc_settings.window_mode = "exclusive_fullscreen"
		Globals.settings.misc_settings.resolution = [1920, 1080]
		Globals._save_settings()
	
	# Apply note anim toggle
	$ScrollContainer/settings_list/note_anim_toggle.set_pressed_no_signal(Globals.settings.misc_settings.note_anims)
	#if not Globals.settings.misc_settings.note_anims: $ScrollContainer/settings_list/HBoxContainer.hide()
	
	# Apply note style
	var note_styles = {
		"dance": 0,
		"techno": 1,
		"para": 2,
	}.get(Globals.settings.misc_settings.note_style, 0) # defaults to dance
	$ScrollContainer/settings_list/note_style_drop.select(note_styles)
	
	# Apply note speed
	var note_speeds = {
		5.0: 0,
		8.0: 1,
		10.0: 2,
		13.0: 3,
		15.0: 4,
		20.0: 5,
	}.get(Globals.settings.game.note_speed, 2) # defaults to 10
	$ScrollContainer/settings_list/note_speed_drop.select(note_speeds)
	
	# Apply note offset
	$ScrollContainer/settings_list/note_offset_edit.text = str(Globals.settings.misc_settings.note_offset)
	
	# Apply game speed
	$ScrollContainer/settings_list/game_speed_edit.text = str(Globals.settings.game.speed)
	
	# Apply reduced motion
	$ScrollContainer/settings_list/reduce_motion_check.set_pressed_no_signal(Globals.settings.misc_settings.reduce_motion)
	
	# Apply show fps label
	$ScrollContainer/settings_list/fpsCheck.set_pressed_no_signal(Globals.settings.misc_settings.show_fps)
	
	# Apply fps mode
	match Globals.settings.misc_settings.fps as int:
		-1: $ScrollContainer/settings_list/fps_options.select(0)
		30: $ScrollContainer/settings_list/fps_options.select(1)
		60: $ScrollContainer/settings_list/fps_options.select(2)
		90: $ScrollContainer/settings_list/fps_options.select(3)
		120: $ScrollContainer/settings_list/fps_options.select(4)
		144: $ScrollContainer/settings_list/fps_options.select(5)
		165: $ScrollContainer/settings_list/fps_options.select(6)
		180: $ScrollContainer/settings_list/fps_options.select(7)
		240: $ScrollContainer/settings_list/fps_options.select(8)
		360: $ScrollContainer/settings_list/fps_options.select(9)
		540: $ScrollContainer/settings_list/fps_options.select(10)
		5000: $ScrollContainer/settings_list/fps_options.select(11)
		_: 
			$ScrollContainer/settings_list/fps_options.select(12)
			$ScrollContainer/settings_list/custom_fps.text = str(int(Globals.settings.misc_settings.fps))
			$ScrollContainer/settings_list/custom_fps.show()
	
	# Apply resolution
	var res_index = {
		Vector2i(3840, 2160): 0,
		Vector2i(2560, 1440): 1,
		Vector2i(1920, 1080): 2,
		Vector2i(1280, 720): 3
	}.get(Vector2i(Globals.settings.misc_settings.resolution[0], Globals.settings.misc_settings.resolution[1]), 2) # defaults to 1920x1080
	$ScrollContainer/settings_list/display_resolutions.select(res_index)
	
	# Apply window mode
	var window_modes := {
		"exclusive_fullscreen": 0,
		"fullscreen": 1,
		"maximized": 2,
		"minimized": 3,
		"windowed": 4
	}
	$ScrollContainer/settings_list/display_options.select(window_modes.get(Globals.settings.misc_settings.window_mode, 4)) # defaults to windowed
	
	# Apply borderless check
	$ScrollContainer/settings_list/borderless_check.set_pressed_no_signal(Globals.settings.misc_settings.borderless)

func _on_fps_check_toggled(toggled_on: bool) -> void:
	Globals.settings.misc_settings.show_fps = toggled_on
	save_stgs() # Always save settings

func _on_fps_options_item_selected(index: int) -> void: # Instantly sets the selected setting when the user selects an option
	match index:
		0:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			Globals.settings.misc_settings.fps = -1 # Setting a max fps isnt needed since v sync overrides the max fps set
			$ScrollContainer/settings_list/custom_fps.hide()
		1:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 30
			Engine.max_fps = 30
			$ScrollContainer/settings_list/custom_fps.hide()
		2:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 60
			Engine.max_fps = 60
			$ScrollContainer/settings_list/custom_fps.hide()
		3:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 90
			Engine.max_fps = 90
			$ScrollContainer/settings_list/custom_fps.hide()
		4:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 120
			Engine.max_fps = 120
			$ScrollContainer/settings_list/custom_fps.hide()
		5:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 144
			Engine.max_fps = 144
			$ScrollContainer/settings_list/custom_fps.hide()
		6:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 165
			Engine.max_fps = 165
			$ScrollContainer/settings_list/custom_fps.hide()
		7:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 180
			Engine.max_fps = 180
			$ScrollContainer/settings_list/custom_fps.hide()
		8:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 240
			Engine.max_fps = 240
			$ScrollContainer/settings_list/custom_fps.hide()
		9:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 360
			Engine.max_fps = 360
			$ScrollContainer/settings_list/custom_fps.hide()
		10:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 540
			Engine.max_fps = 540
			$ScrollContainer/settings_list/custom_fps.hide()
		11:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Globals.settings.misc_settings.fps = 5000
			Engine.max_fps = 5000 # Set the max fps to a very high number so it overrides any other max fps
			$ScrollContainer/settings_list/custom_fps.hide()
		12:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Globals.settings.misc_settings.fps
			$ScrollContainer/settings_list/custom_fps.show()
	save_stgs()

func _on_custom_fps_text_submitted(new_text: String) -> void:
	if !new_text.is_valid_int(): 
		$ScrollContainer/settings_list/custom_fps.text = "Please enter a number."
		return
	var new_fps: int = new_text.to_int()
	if new_fps < 15:
		$ScrollContainer/settings_list/custom_fps.text = "Trust me you do not wanna play like this."
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
		$ScrollContainer/settings_list/note_offset_edit.text = "Please enter a number."

func _on_game_speed_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		var value := new_text.to_float()
		
		if value <= 0.09:
			$ScrollContainer/settings_list/game_speed_edit.text = "Are you sure this is fun to you"
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 0.3)
		elif value <= 0.4 and value > 0.091:
			$ScrollContainer/settings_list/game_speed_edit.text = "I would suggest a higher number."
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 1)
		elif value >= 3.0 and value < 7.9:
			$ScrollContainer/settings_list/game_speed_edit.text = "I would suggest a smaller number."
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 10)
		elif value >= 8.0 and value < 49.9:
			$ScrollContainer/settings_list/game_speed_edit.text = "I guess this is a little fun but still"
			call_deferred("change_text_back_to_num_after_telling_user_a_higher_number", 100)
		elif value >= 50:
			$ScrollContainer/settings_list/game_speed_edit.text = "This will either crash your game or just destroy your ears, nice one bro"
			Globals.settings.game.speed = 1.0
			Engine.time_scale = 1.0
			$bg_song.pitch_scale = 1.0
			return  # Exit early to avoid entering speed back to the invalid number
		
		Globals.settings.game.speed = value
		Engine.time_scale = value
		$bg_song.pitch_scale = value
		save_stgs()
	else:
		$ScrollContainer/settings_list/game_speed_edit.text = "Please enter a number."

func change_text_back_to_num_after_telling_user_a_higher_number(time: float = 1): # Function only used for the function above to tell user to use a slower or faster speed and then reset the text to whatever number they entered after a specific time
	await get_tree().create_timer(time).timeout
	$ScrollContainer/settings_list/game_speed_edit.text = str(Globals.settings.game.speed)

func _on_song_vol_slider_value_changed(value: float) -> void:
	var new_vol = int(value)
	Globals.settings.game.song_vol = new_vol
	$ScrollContainer/settings_list/song_vol_label.text = "Song Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Song"), linear_to_db(new_vol / 100.0))
	save_stgs()

func _on_menu_song_vol_slider_value_changed(value: float) -> void:
	var new_vol = int(value)
	Globals.settings.game.menu_song_vol = new_vol
	$ScrollContainer/settings_list/menu_song_vol_label.text = "Menu Song Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu Song"), linear_to_db(new_vol / 100.0))
	save_stgs()

func _on_sfx_vol_slider_value_changed(value: float) -> void:
	var new_vol = int(value)
	Globals.settings.game.sfx_vol = new_vol
	$ScrollContainer/settings_list/sfx_vol_label.text = "SFX Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(new_vol / 100.0))
	save_stgs()

func _on_mbl_btn_layout_drop_item_selected(index: int) -> void:
	match index:
		0: Globals.settings.game.mbl_btn_layout = 0
		1: Globals.settings.game.mbl_btn_layout = 1
	save_stgs()

func _on_note_anim_toggled(toggled_on: bool) -> void:
	Globals.settings.misc_settings.note_anims = toggled_on
	#if toggled_on: $ScrollContainer/settings_list/HBoxContainer.show()
	#else: $ScrollContainer/settings_list/HBoxContainer.hide()
	save_stgs()

func save_stgs(): # Saves settings and plays the pop up
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	Globals._save_settings()
	$save_anim.stop()
	$save_anim.play("save")
