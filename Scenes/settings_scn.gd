extends Control

signal note_speed_changed(speed: float)

signal bg_changed(tex: ImageTexture)

signal vis_toggled(toggled: bool)

signal check_for_upd_pressed

signal menu_brightness_changed(value: float)
signal brightness_changed(value: float)
signal editor_brightness_changed(value: float)

signal set_username(user: String)
signal set_title(title: String)
signal set_clan(clan: String)

signal set_profile(img: ImageTexture)
signal set_banner(img: ImageTexture)

signal note_backdrop_opacity_changed(opacity: float)
signal editor_note_backdrop_opacity_changed(opacity: float)

signal bg_vids_toggled(toggled_on: bool)
signal editor_bg_vids_toggled(toggled_on: bool)

var input_listened
var screen: String = "stgs"

func _ready() -> void:
	$ScrollContainer/settings_list/slogan.text = General.SLOGAN
	if OS.has_feature("Deluxe"):
		print("Deluxe Edition \"SWAG GAME\"")
		$ScrollContainer/settings_list/ver.text = "%s Deluxe Edition \"SWAG GAME\" %s" % [General.NAME, General.VERSION]
		$ScrollContainer/settings_list/ver.tooltip_text = "%s Deluxe Edition \"SWAG GAME\" (%s) Version %s\nApplication built 11/08/2025" % [General.NAME, General.port, General.VERSION]
	elif OS.has_feature("ONETHIRTYONE"):
		print("Special Edition \"ONETHIRTYONE\"")
		$ScrollContainer/settings_list/ver.text = "%s Special Edition \"ONETHIRTYONE\" %s" % [General.NAME, General.VERSION]
		$ScrollContainer/settings_list/ver.tooltip_text = "%s Special Edition \"ONETHIRTYONE\" (%s) Version %s\nApplication built 10/26/2025" % [General.NAME, General.port, General.VERSION]
	else:
		$ScrollContainer/settings_list/ver.text = "%s (%s) %s" % [General.NAME, General.port, General.VERSION]
		$ScrollContainer/settings_list/ver.tooltip_text = "%s (%s) Version %s\nApplication built 10/26/2025" % [General.NAME, General.port, General.VERSION]
	_apply_loaded_settings()
	
	if get_parent().name in ["main_menu", "selected_song"]:
		$ScrollContainer/settings_list/end_space.hide()

func _input(event: InputEvent) -> void:
	if screen == "binds" and event.is_action_pressed("pause-back"):
		$switch.play("to_stgs")

	if Settings.listening and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.pressed:
		$keybinds_layer/input_listen_cont/listening_lbl2.text = event.as_text()
		input_listened = event

func _apply_loaded_settings():
	$ScrollContainer/settings_list/lifetime_points.text = "Lifetime Points: " + General.format_number_with_commas(Beatz.lifetime_points) + " Points"
	
	$ScrollContainer/settings_list/master_vol_slider.set_value_no_signal(Settings.game.master_vol)
	$ScrollContainer/settings_list/song_vol_slider.set_value_no_signal(Settings.game.song_vol)
	$ScrollContainer/settings_list/menu_song_vol_slider.set_value_no_signal(Settings.game.menu_song_vol)
	$ScrollContainer/settings_list/sfx_vol_slider.set_value_no_signal(Settings.game.sfx_vol)
	$ScrollContainer/settings_list/master_vol_label.text = "Master Volume: " + str(Settings.game.master_vol)
	$ScrollContainer/settings_list/song_vol_label.text = "Song Volume: " + str(Settings.game.song_vol)
	$ScrollContainer/settings_list/menu_song_vol_label.text = "Menu Song Volume: " + str(Settings.game.menu_song_vol)
	$ScrollContainer/settings_list/sfx_vol_label.text = "SFX Volume: " + str(Settings.game.sfx_vol)
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(Settings.game.master_vol / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Song"), linear_to_db(Settings.game.song_vol / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu Song"), linear_to_db(Settings.game.menu_song_vol / 100.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(Settings.game.sfx_vol / 100.0))
	
	if OS.get_name() == "Android":
		print("android load btns")
		$ScrollContainer/settings_list/mbl_btn_layout_label.show()
		$ScrollContainer/settings_list/mbl_btn_layout_drop.show()
		# Apply btn layout
		var btn_layouts = {
			0: 0,
			1: 1
		}.get(Settings.game.mbl_btn_layout, 0) # defaults to 4 btn
		$ScrollContainer/settings_list/mbl_btn_layout_drop.select(btn_layouts)
		$ScrollContainer/settings_list/ver.text = "Beatz! X (" + str(OS.get_name()) + " Port) 1.3.0"
		
		$ScrollContainer/settings_list/res_label.hide()
		$ScrollContainer/settings_list/display_resolutions.hide()
		$ScrollContainer/settings_list/window_modes_label.hide()
		$ScrollContainer/settings_list/display_options.hide()
		$ScrollContainer/settings_list/borderless_check.hide()
		Settings.misc.borderless = true
		Settings.misc.window_mode = "exclusive_fullscreen"
		Settings.misc.resolution = [1920, 1080]
		Settings._save()
	
	# Apply note anim toggle
	$ScrollContainer/settings_list/note_anim_toggle.set_pressed_no_signal(Settings.misc.note_anims)
	#if not Settings.misc.note_anims: $ScrollContainer/settings_list/HBoxContainer.hide()
	
	# Apply btn layout
	var note_particles = {
		0: 0,
		1: 1,
		3: 3,
		4: 4
	}.get(Settings.misc.note_particle_fx, 1) # defaults to splash
	$ScrollContainer/settings_list/note_particle_fx.select(note_particles)
	
	# Apply Visualizer show
	$ScrollContainer/settings_list/visualizer_toggle.set_pressed_no_signal(Settings.misc.vis)
	
	# Apply bg videos showing
	$ScrollContainer/settings_list/bg_vids_toggle.set_pressed_no_signal(Settings.misc.bg_videos)
	$ScrollContainer/settings_list/bg_vids_edit_toggle.set_pressed_no_signal(Settings.misc.editor_bg_videos)
	
	# Apply note style 
	var note_styles = {
		"dance": 0,
		"techno": 1,
		"para": 2,
		"circles": 3,
	}.get(Settings.misc.note_style, 0) # defaults to dance
	$ScrollContainer/settings_list/note_style_drop.select(note_styles)
	
	if note_styles == 3: $ScrollContainer/settings_list/circle_note_settings.show()
	else: $ScrollContainer/settings_list/circle_note_settings.hide()
	
	## Apply note speed
	#var note_speeds = {
		#5.0: 0,
		#8.0: 1,
		#10.0: 2,
		#13.0: 3,
		#15.0: 4,
		#20.0: 5,
	#}.get(Settings.game.note_speed, 2) # defaults to 10
	#$ScrollContainer/settings_list/note_speed_drop.select(note_speeds)
	
	$ScrollContainer/settings_list/note_speed_value_lbl.text = "Note Speed: %.2f" % Settings.game.note_speed
	$ScrollContainer/settings_list/note_speed_edit.set_value_no_signal(Settings.game.note_speed)
	
	# Apply note offset
	$ScrollContainer/settings_list/note_offset_edit.text = str(Settings.misc.note_offset)
	
	# Apply game speed
	$ScrollContainer/settings_list/game_speed_edit.text = str(Settings.game.speed)
	
	# Apply reduced motion
	$ScrollContainer/settings_list/reduce_motion_check.set_pressed_no_signal(Settings.misc.reduce_motion)
	
	# Apply reduced motion
	$ScrollContainer/settings_list/animated_scrolls_check.set_pressed_no_signal(Settings.misc.smooth_scrolls)
	
	# Get custom backgrounds and add them to $ScrollContainer/settings_list/bg_img_drop
	get_custom_backgrounds()
	
	# Set Bg pulse values
	$ScrollContainer/settings_list/bg_pulse_toggle.set_pressed_no_signal(Settings.misc.menu_bg_pulse)
	$ScrollContainer/settings_list/bg_pulse_slider.set_value_no_signal(Settings.misc.menu_bg_pulse_strength)
	$ScrollContainer/settings_list/bg_pulse_lbl.text = "---- Background Pulse Strength: " + str(Settings.misc.menu_bg_pulse_strength) + "x ----"
	
	$ScrollContainer/settings_list/menu_bg_brightness_label.text = "---- Background Brightness (Main Menu): " + str(Settings.game.menu_bg_brightness * 100.0)  + "% ----"
	$ScrollContainer/settings_list/menu_bg_brightness_slider.set_value_no_signal(Settings.game.menu_bg_brightness * 100.0)
	
	$ScrollContainer/settings_list/bg_brightness_label.text = "---- Background Brightness (In Game): " + str(Settings.game.bg_brightness * 100.0)  + "% ----"
	$ScrollContainer/settings_list/bg_brightness_slider.set_value_no_signal(Settings.game.bg_brightness * 100.0)
	
	$ScrollContainer/settings_list/note_backdrop_brightness.text = "---- Notes Backdrop Opacity (In Game): " + str(Settings.misc.notes_backdrop_opacity * 100.0)  + "% ----"
	$ScrollContainer/settings_list/note_backdrop_brightness_slider.set_value_no_signal(Settings.misc.notes_backdrop_opacity * 100.0)
	
	
	
	$ScrollContainer/settings_list/editor_bg_brightness_label.text = "---- Background Brightness (Editor): " + str(Settings.game.editor_bg_brightness * 100.0)  + "% ----"
	$ScrollContainer/settings_list/editor_bg_brightness_slider.set_value_no_signal(Settings.game.editor_bg_brightness * 100.0)
	
	$ScrollContainer/settings_list/editor_note_backdrop_brightness.text = "---- Notes Backdrop Opacity (Editor): " + str(Settings.misc.editor_notes_backdrop_opacity * 100.0)  + "% ----"
	$ScrollContainer/settings_list/editor_note_backdrop_brightness_slider.set_value_no_signal(Settings.misc.editor_notes_backdrop_opacity * 100.0)
	
	
	
	$ScrollContainer/settings_list/bg_colour_toggle.set_pressed_no_signal(Settings.misc.colour_bg_with_cover)
	
	$ScrollContainer/settings_list/username_edit.text = Settings.game.username
	$ScrollContainer/settings_list/title_edit.text = Settings.game.title
	$ScrollContainer/settings_list/clan_edit.text = Settings.game.clan
	if Settings.game.profile_path != "": $ScrollContainer/settings_list/pfp_edit.icon = ImageTexture.create_from_image(Image.load_from_file(Settings.game.profile_path))
	
	if Settings.game.banner_path != "": $ScrollContainer/settings_list/banner_edit.icon = ImageTexture.create_from_image(Image.load_from_file(Settings.game.banner_path))
	
	# Apply show fps label
	$ScrollContainer/settings_list/fpsCheck.set_pressed_no_signal(Settings.misc.show_fps)
	
	# Apply accurate fps
	$ScrollContainer/settings_list/avrg_fps_check.set_pressed_no_signal(Settings.misc.accurate_fps)
	
	# Apply advanced fps toggle
	$ScrollContainer/settings_list/advanced_fps_check.set_pressed_no_signal(Settings.misc.advanced_fps)
	
	if Settings.misc.advanced_fps:
		# Show advanced UI
		$ScrollContainer/settings_list/fps_main_menu_lbl.show()
		$ScrollContainer/settings_list/fps_main_menu_options.show()
		$ScrollContainer/settings_list/fps_main_lbl.show()
		$ScrollContainer/settings_list/fps_main_options.show()
		$ScrollContainer/settings_list/fps_unfocused.show()
		$ScrollContainer/settings_list/fps_unfocused_options.show()
	
		# Hide general UI
		$ScrollContainer/settings_list/fps_label.hide()
		$ScrollContainer/settings_list/fps_options.hide()
	else:
		# Hide advanced UI
		$ScrollContainer/settings_list/fps_main_menu_lbl.hide()
		$ScrollContainer/settings_list/fps_main_menu_options.hide()
		$ScrollContainer/settings_list/fps_main_lbl.hide()
		$ScrollContainer/settings_list/fps_main_options.hide()
		$ScrollContainer/settings_list/fps_unfocused.hide()
		$ScrollContainer/settings_list/fps_unfocused_options.hide()
	
		# Show general UI
		$ScrollContainer/settings_list/fps_label.show()
		$ScrollContainer/settings_list/fps_options.show()
	
	# Apply MAIN MENU fps value
	_select_fps_dropdown_from_value(
		$ScrollContainer/settings_list/fps_main_menu_options,
		Settings.misc.fps_main_menu
	)

	# Apply MAIN gameplay fps value
	_select_fps_dropdown_from_value(
		$ScrollContainer/settings_list/fps_main_options,
		Settings.misc.fps_main
	)

	# Apply UNFOCUSED fps value (special index set)
	_select_fps_dropdown_from_value(
		$ScrollContainer/settings_list/fps_unfocused_options,
		Settings.misc.fps_unfocused,
		true
	)
	
	# Apply general fps mode if not advanced fps 
	if not Settings.misc.advanced_fps:
		match Settings.misc.fps as int:
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
				$ScrollContainer/settings_list/custom_fps.text = str(int(Settings.misc.fps))
				$ScrollContainer/settings_list/custom_fps.show()
	
	for child in $ScrollContainer/settings_list.get_children():
		if child is not OptionButton: continue
		var option_button: OptionButton = child
		_connect_popup(option_button)
	
	_connect_popup($ScrollContainer/settings_list/eq/presets)
	
	
	# Apply resolution
	var res_index = {
		Vector2i(3840, 2160): 0,
		Vector2i(2560, 1440): 1,
		Vector2i(1920, 1080): 2,
		Vector2i(1280, 720): 3
	}.get(Vector2i(Settings.misc.resolution[0], Settings.misc.resolution[1]), 2) # defaults to 1920x1080
	$ScrollContainer/settings_list/display_resolutions.select(res_index)
	
	# Apply window mode
	var window_modes := {
		"exclusive_fullscreen": 0,
		"fullscreen": 1,
		"maximized": 2,
		"windowed": 3
	}
	
	$ScrollContainer/settings_list/display_options.select(window_modes.get(Settings.misc.window_mode, 4)) # defaults to windowed
	
	# Apply borderless check
	$ScrollContainer/settings_list/borderless_check.set_pressed_no_signal(Settings.misc.borderless)
	
	# Apply drc check
	$ScrollContainer/settings_list/drp_toggle.set_pressed_no_signal(Settings.misc.drc)
	
	if get_parent().name == "main" or get_parent().name == "selected_song":
		print("hiding cuz playing s")
		$ScrollContainer/settings_list/space9.hide()
		$ScrollContainer/settings_list/credits_btn.hide()
		$ScrollContainer/settings_list/space6.hide()
		$ScrollContainer/settings_list/redeem_btn.hide()
		$ScrollContainer/settings_list/space12.hide()
		$ScrollContainer/settings_list/check_for_update.hide()
	
	$ScrollContainer/settings_list/show_chart_alignment.set_pressed_no_signal(Settings.other.show_chart_alignment)

func _connect_popup(btn: OptionButton) -> void:
	print("Connected ", btn.name)
	
	var popup: PopupMenu = btn.get_popup()

	popup.about_to_popup.connect(func():
		General.is_popup_open = true
	)

	popup.popup_hide.connect(func():
		General.is_popup_open = false
	)

func _select_fps_dropdown_from_value(node: OptionButton, value: int, is_unfocused := false) -> void:
	# VSync
	if value == -1:
		node.select(0)
		return

	if is_unfocused:
		match value:
			15: node.select(1)
			30: node.select(2)
			60: node.select(3)
			90: node.select(4)
			120: node.select(5)
			144: node.select(6)
			165: node.select(7)
			180: node.select(8)
			240: node.select(9)
			360: node.select(10)
			540: node.select(11)
			5000: node.select(12)
			_: 
				node.select(13)
				# ONLY change the custom fps field if this dropdown uses it
				if node == $ScrollContainer/settings_list/fps_options or node == $ScrollContainer/settings_list/fps_unfocused_options:
					$ScrollContainer/settings_list/custom_fps.text = str(value)
		return

	# Normal (non-unfocused)
	match value:
		30: node.select(1)
		60: node.select(2)
		90: node.select(3)
		120: node.select(4)
		144: node.select(5)
		165: node.select(6)
		180: node.select(7)
		240: node.select(8)
		360: node.select(9)
		540: node.select(10)
		5000: node.select(11)
		_:
			node.select(12)
			$ScrollContainer/settings_list/custom_fps.text = str(value)

func get_custom_backgrounds() -> void:
	var option_button: OptionButton = $ScrollContainer/settings_list/bg_img_drop
	option_button.clear()

	# --- Add default options ---
	var def_img: CompressedTexture2D = preload("res://Resources/defaultBG.png")
	var conv_def_img = def_img.get_image()
	conv_def_img.resize(200, 112, Image.INTERPOLATE_BILINEAR)
	var def_tex := ImageTexture.create_from_image(conv_def_img)
	option_button.add_icon_item(def_tex, "Default")
	option_button.add_separator()

	# --- Prepare directory ---
	var backgrounds_dir := "user://Backgrounds"
	var dir := DirAccess.open(backgrounds_dir)
	if dir == null:
		print("No Backgrounds folder found, creating one at:", backgrounds_dir)
		DirAccess.make_dir_recursive_absolute(backgrounds_dir)
		return

	# --- Get valid file extensions ---
	var valid_exts := []
	for pattern in General.IMG_FORMATS:
		var ext = pattern.get_extension().to_lower()
		if ext != "":
			valid_exts.append(ext)

	# --- Iterate through files ---
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			var ext := file_name.get_extension().to_lower()
			if ext in valid_exts:
				var full_path := backgrounds_dir.path_join(file_name)
				var img := Image.new()
				var err := img.load(full_path)
				if err == OK:
					# Resize image safely to 1280x720 (keep aspect by fitting)
					img.resize(200, 112, Image.INTERPOLATE_BILINEAR)
					var tex := ImageTexture.create_from_image(img)

					# Add as option with icon
					option_button.add_icon_item(tex, file_name)
				else:
					push_warning("Failed to load background image: %s (%s)" % [full_path, error_string(err)])
		file_name = dir.get_next()

	dir.list_dir_end()
	
	print("✅ Background options loaded:", option_button.item_count)
	
	var new_item := -1
	var dropdown := $ScrollContainer/settings_list/bg_img_drop
	var selected: String = Settings.misc.menu_bg_img_path
	
	if selected == "":
		return
	
	for i in range(dropdown.item_count):
		var item_text: String = dropdown.get_item_text(i)
		if item_text == selected.get_file(): # compare filename only, not full path
			new_item = i
			break

	if new_item != -1:
		dropdown.select(new_item)
		print("Selected background:", dropdown.get_item_text(new_item))
	else:
		print("No matching background found for:", selected)

func _on_fps_check_toggled(toggled_on: bool) -> void:
	Settings.misc.show_fps = toggled_on
	save_stgs() # Always save settings

func _on_fps_options_item_selected(index: int) -> void: # Instantly sets the selected setting when the user selects an option
	match index:
		0:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
			Settings.misc.fps = -1 # Setting a max fps isnt needed since v sync overrides the max fps set
			$ScrollContainer/settings_list/custom_fps.hide()
		1:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 30
			Engine.max_fps = 30
			$ScrollContainer/settings_list/custom_fps.hide()
		2:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 60
			Engine.max_fps = 60
			$ScrollContainer/settings_list/custom_fps.hide()
		3:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 90
			Engine.max_fps = 90
			$ScrollContainer/settings_list/custom_fps.hide()
		4:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 120
			Engine.max_fps = 120
			$ScrollContainer/settings_list/custom_fps.hide()
		5:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 144
			Engine.max_fps = 144
			$ScrollContainer/settings_list/custom_fps.hide()
		6:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 165
			Engine.max_fps = 165
			$ScrollContainer/settings_list/custom_fps.hide()
		7:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 180
			Engine.max_fps = 180
			$ScrollContainer/settings_list/custom_fps.hide()
		8:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 240
			Engine.max_fps = 240
			$ScrollContainer/settings_list/custom_fps.hide()
		9:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 360
			Engine.max_fps = 360
			$ScrollContainer/settings_list/custom_fps.hide()
		10:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 540
			Engine.max_fps = 540
			$ScrollContainer/settings_list/custom_fps.hide()
		11:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Settings.misc.fps = 5000
			Engine.max_fps = 5000 # Set the max fps to a very high number so it overrides any other max fps
			$ScrollContainer/settings_list/custom_fps.hide()
		12:
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			Engine.max_fps = Settings.misc.fps
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
	Settings.misc.fps = new_fps
	Engine.max_fps = new_fps
	save_stgs()

func apply_fps_limit(context: String) -> void:
	if not Settings.misc.advanced_fps:
		# Normal mode → always use general FPS
		_apply_general_fps()
		return

	match context:
		"main_menu":
			Engine.max_fps = Settings.misc.fps_main_menu
		"main":
			Engine.max_fps = Settings.misc.fps_main
		"unfocused":
			Engine.max_fps = Settings.misc.fps_unfocused
		_:
			Engine.max_fps = 240

	# All advanced modes disable vsync by definition
	if Engine.max_fps == -1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _apply_general_fps() -> void:
	var fps = Settings.misc.fps
	if fps == -1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = fps

func _on_advanced_fps_toggled(toggled_on: bool) -> void:
	if toggled_on:
		# show advanced fps UI
		$ScrollContainer/settings_list/fps_main_menu_lbl.show()
		$ScrollContainer/settings_list/fps_main_menu_options.show()
		$ScrollContainer/settings_list/fps_main_lbl.show()
		$ScrollContainer/settings_list/fps_main_options.show()
		$ScrollContainer/settings_list/fps_unfocused.show()
		$ScrollContainer/settings_list/fps_unfocused_options.show()

		# hide general fps UI
		$ScrollContainer/settings_list/fps_label.hide()
		$ScrollContainer/settings_list/fps_options.hide()
	else:
		# hide advanced fps UI
		$ScrollContainer/settings_list/fps_main_menu_lbl.hide()
		$ScrollContainer/settings_list/fps_main_menu_options.hide()
		$ScrollContainer/settings_list/fps_main_lbl.hide()
		$ScrollContainer/settings_list/fps_main_options.hide()
		$ScrollContainer/settings_list/fps_unfocused.hide()
		$ScrollContainer/settings_list/fps_unfocused_options.hide()

		# show general fps UI
		$ScrollContainer/settings_list/fps_label.show()
		$ScrollContainer/settings_list/fps_options.show()

	Settings.misc.advanced_fps = toggled_on
	save_stgs()

	# APPLY FPS RIGHT NOW
	if toggled_on:
		General.apply_fps_limit(get_parent().name) # or "main" depending on the scene
	else:
		General.apply_fps_limit("main_menu")

func _on_fps_main_menu_options_item_selected(index: int) -> void:
	Settings.misc.fps_main_menu = _fps_from_index(index)
	save_stgs()
	General.apply_fps_limit("main_menu")

func _on_fps_main_options_item_selected(index: int) -> void:
	Settings.misc.fps_main = _fps_from_index(index)
	save_stgs()
	General.apply_fps_limit("main")

func _on_fps_unfocused_options_item_selected(index: int) -> void:
	Settings.misc.fps_unfocused = _fps_from_index(index, true)
	save_stgs()

func _fps_from_index(i: int, is_unfocused: bool = false) -> int:
	if i == 0:
		return -1  # VSync

	# Unfocused menu has the 15 FPS entry at index 1
	if is_unfocused:
		match i:
			1: return 15
			2: return 30
			3: return 60
			4: return 90
			5: return 120
			6: return 144
			7: return 165
			8: return 180
			9: return 240
			10: return 360
			11: return 540
			12: return 5000
			13:
				return Settings.misc.fps_unfocused  # custom
			_:
				return 240
	else:
		# Standard 12-index dropdown
		match i:
			1: return 30
			2: return 60
			3: return 90
			4: return 120
			5: return 144
			6: return 165
			7: return 180
			8: return 240
			9: return 360
			10: return 540
			11: return 5000
			12:
				return Settings.misc.fps  # custom
			_:
				return 240

func _on_display_item_selected(index: int) -> void:
	var screen_size: Vector2i
	match index:
		0: screen_size = Vector2i(3840, 2160)
		1: screen_size = Vector2i(2560, 1440)
		2: screen_size = Vector2i(1920, 1080)
		3: screen_size = Vector2i(1280, 720)
	DisplayServer.window_set_size(screen_size)
	Settings.misc.resolution = [screen_size.x, screen_size.y]
	save_stgs()

func _on_display_options_selected(index: int) -> void:
	match index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			Settings.misc.window_mode = "exclusive_fullscreen"
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			Settings.misc.window_mode = "fullscreen"
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
			Settings.misc.window_mode = "maximized"
		4:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			Settings.misc.window_mode = "windowed"
	save_stgs()

func _on_borderless_check_toggled(toggled_on: bool) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, toggled_on)
	Settings.misc.borderless = toggled_on
	save_stgs()

func _on_note_speed_item_selected(index: int) -> void:
	match index:
		0: Settings.game.note_speed = 5.0
		1: Settings.game.note_speed = 8.0
		2: Settings.game.note_speed = 10.0
		3: Settings.game.note_speed = 13.0
		4: Settings.game.note_speed = 15.0
		5: Settings.game.note_speed = 20.0
	save_stgs()

func _on_reduce_motion_toggled(toggled_on: bool) -> void:
	Settings.misc.reduce_motion = toggled_on
	save_stgs()

func _on_credits_btn_pressed() -> void:
	get_parent().get_node("AnimationPlayer").play("might_yap")
	var t = create_tween()
	t.tween_property(get_parent().get_node("bg_song"), "volume_db", -80.0, 0.75)
	await t.finished
	get_tree().change_scene_to_file("res://Scenes/thank_you.tscn")

func _on_note_style_item_selected(index: int) -> void:
	match index:
		0: Settings.misc.note_style = "dance"
		1: Settings.misc.note_style = "techno"
		2: Settings.misc.note_style = "para"
		3: Settings.misc.note_style = "circles"
	save_stgs()
	if index == 3: $ScrollContainer/settings_list/circle_note_settings.show()
	else: $ScrollContainer/settings_list/circle_note_settings.hide()

func _on_note_offset_text_submitted(new_text: String) -> void:
	if new_text.is_valid_float():
		Settings.misc.note_offset = new_text.to_float() # If text is a valid number, change it from a string to a number and save
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
			$ScrollContainer/settings_list/game_speed_edit.text = "This will either crash your game or just destroy your ears nice one bro"
			Settings.game.speed = 1.0
			Engine.time_scale = 1.0
			return  # Exit early to avoid entering speed back to the invalid number
		
		Settings.game.speed = value
		Engine.time_scale = value
		save_stgs()
	else:
		$ScrollContainer/settings_list/game_speed_edit.text = "Please enter a number."

func change_text_back_to_num_after_telling_user_a_higher_number(time: float = 1): # Function only used for the function above to tell user to use a slower or faster speed and then reset the text to whatever number they entered after a specific time
	await get_tree().create_timer(time).timeout
	$ScrollContainer/settings_list/game_speed_edit.text = str(Settings.game.speed)

func _on_master_vol_slider_value_changed(value: float) -> void:
	var new_vol: float = value
	$ScrollContainer/settings_list/master_vol_label.text = "Master Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(new_vol / 100.0))

func _on_song_vol_slider_value_changed(value: float) -> void:
	var new_vol: float = value
	$ScrollContainer/settings_list/song_vol_label.text = "Song Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Song"), linear_to_db(new_vol / 100.0))

func _on_menu_song_vol_slider_value_changed(value: float) -> void:
	var new_vol: float = value
	$ScrollContainer/settings_list/menu_song_vol_label.text = "Menu Song Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Menu Song"), linear_to_db(new_vol / 100.0))

func _on_sfx_vol_slider_value_changed(value: float) -> void:
	var new_vol: float = value
	$ScrollContainer/settings_list/sfx_vol_label.text = "SFX Volume: " + str(new_vol)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(new_vol / 100.0))

func _on_master_vol_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	Settings.game.master_vol = $ScrollContainer/settings_list/master_vol_slider.value
	save_stgs()

func _on_song_vol_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	Settings.game.song_vol = $ScrollContainer/settings_list/song_vol_slider.value
	save_stgs()

func _on_menu_song_vol_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	Settings.game.menu_song_vol = $ScrollContainer/settings_list/menu_song_vol_slider.value
	save_stgs()

func _on_sfx_vol_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	Settings.game.sfx_vol = $ScrollContainer/settings_list/sfx_vol_slider.value
	save_stgs()

func _on_mbl_btn_layout_drop_item_selected(index: int) -> void:
	match index:
		0: Settings.game.mbl_btn_layout = 0
		1: Settings.game.mbl_btn_layout = 1
	save_stgs()

func _on_note_anim_toggled(toggled_on: bool) -> void:
	Settings.misc.note_anims = toggled_on
	#if toggled_on: $ScrollContainer/settings_list/HBoxContainer.show()
	#else: $ScrollContainer/settings_list/HBoxContainer.hide()
	save_stgs()

func save_stgs(): # Saves settings and plays the pop up
	var focused = get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()
	Settings._save()
	$save_anim.stop()
	$save_anim.play("save")

func _on_change_binds_btn_pressed() -> void:
	screen = "binds"
	$switch.play("to_binds")

func _on_bg_pulse_toggle_toggled(toggled_on: bool) -> void:
	Settings.misc.menu_bg_pulse = toggled_on
	save_stgs()

func _on_bg_pulse_slider_value_changed(value: float) -> void:
	$ScrollContainer/settings_list/bg_pulse_lbl.text = "---- Background Pulse Strength: " + str(value) + "x ----"
	Settings.misc.menu_bg_pulse_strength = $ScrollContainer/settings_list/bg_pulse_slider.value

func _on_bg_pulse_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed: return
	save_stgs()

func _on_bg_img_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file for your background.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_bg_img_file_selected")
	)
	if err != OK:
		print("Couldnt show native file dialog ", err, error_string(err))

func _on_bg_img_file_selected(status, paths: PackedStringArray, _filter_idx: int) -> void:
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	var image := Image.new()
	var err := image.load(paths[0])
	if err == OK:
		var dir := "user://Backgrounds"
		DirAccess.make_dir_recursive_absolute(dir)

		var img_save_path := dir.path_join(paths[0].get_file())
		var err2 := General.save_image_with_correct_extension(image, img_save_path)
		printerr(err2, " ", error_string(err2))

		if err2 == OK:
			Settings.misc.menu_bg_img_path = img_save_path
			print("Saved banner image to %s" % img_save_path)
			save_stgs()
		
		# Create a texture from the image
		var tex := ImageTexture.create_from_image(image)
		
		get_custom_backgrounds()
		
		# Emit signal with the texture
		bg_changed.emit(tex)
	else:
		print("Failed to load image: ", paths[0], " ", err, " ", error_string(err))

func _on_l_btn_pressed() -> void:
	start_listening(General.INPUTS.left)

func _on_d_btn_pressed() -> void:
	start_listening(General.INPUTS.down)

func _on_u_btn_pressed() -> void:
	start_listening(General.INPUTS.up)

func _on_r_btn_pressed() -> void:
	start_listening(General.INPUTS.right)

func _on_pause_btn_button_up() -> void:
	start_listening(General.INPUTS.pause)

func open_listen_panel():
	var t = create_tween()
	t.tween_property($keybinds_layer/input_listen_cont, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUART)

func close_listen_panel():
	var t = create_tween()
	t.tween_property($keybinds_layer/input_listen_cont, "scale", Vector2.ZERO, 0.25).set_trans(Tween.TRANS_CIRC)

func start_listening(input_name: int):
	Settings.listening = true
	match input_name:
		General.INPUTS.left: 
			$keybinds_layer/input_listen_cont/input_lbl.text = "Note Left"
			open_listen_panel()
		General.INPUTS.down: 
			$keybinds_layer/input_listen_cont/input_lbl.text = "Note Down"
			open_listen_panel()
		General.INPUTS.up: 
			$keybinds_layer/input_listen_cont/input_lbl.text = "Note Up"
			open_listen_panel()
		General.INPUTS.right: 
			$keybinds_layer/input_listen_cont/input_lbl.text = "Note Right"
			open_listen_panel()
		General.INPUTS.pause: 
			$keybinds_layer/input_listen_cont/input_lbl.text = "Pause"
			open_listen_panel()

func _on_ok_pressed() -> void:
	Settings.listening = false
	save_stgs()
	close_listen_panel()

func _on_cancel_pressed() -> void:
	Settings.listening = false
	close_listen_panel()

func _on_see_github_pressed() -> void:
	OS.shell_open("https://github.com/GuayabR/Beatz-X")

func _on_see_tos_pressed() -> void:
	OS.shell_open("https://github.com/GuayabR/Beatz-X?tab=MIT-1-ov-file#readme")

func _on_drp_toggle_toggled(toggled_on: bool) -> void:
	Settings.misc.drc = toggled_on
	save_stgs()

func _on_visualizer_toggle_toggled(toggled_on: bool) -> void:
	Settings.misc.vis = toggled_on
	vis_toggled.emit(toggled_on)
	save_stgs()

func _on_avrg_fps_check_toggled(toggled_on: bool) -> void:
	Settings.misc.accurate_fps = toggled_on
	save_stgs()

func _on_background_focus_entered() -> void:
	get_viewport().gui_get_focus_owner().release_focus()

func _on_check_for_update_pressed() -> void:
	check_for_upd_pressed.emit()

func _on_animated_scrolls_check_toggled(toggled_on: bool) -> void:
	Settings.misc.smooth_scrolls = toggled_on

var scroll_tween: Tween
var scroll_velocity := 0.0
var last_scroll_time := 0.0

func _on_scroll_cont_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Settings.misc.smooth_scrolls:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var scroll_bar = $ScrollContainer.get_v_scroll_bar()
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

			var duration := clampf(abs(scroll_velocity) / 1200.0, 0.2, 1.0)

			scroll_tween = create_tween()
			scroll_tween.tween_property(scroll_bar, "value", target_value, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

			# Slowly decay velocity over time
			scroll_tween.finished.connect(func():
				scroll_velocity *= 0.5
			)

func _on_master_vol_label_focus_entered() -> void:
	$ScrollContainer/settings_list/master_vol_label.hide()
	$ScrollContainer/settings_list/master_vol_edit.show()
	$ScrollContainer/settings_list/master_vol_edit.grab_focus()
	$ScrollContainer/settings_list/master_vol_edit.text = str($ScrollContainer/settings_list/master_vol_slider.value)
	$ScrollContainer/settings_list/master_vol_edit.caret_column = 6

func _on_song_vol_label_focus_entered() -> void:
	$ScrollContainer/settings_list/song_vol_label.hide()
	$ScrollContainer/settings_list/song_vol_edit.show()
	$ScrollContainer/settings_list/song_vol_edit.grab_focus()
	$ScrollContainer/settings_list/song_vol_edit.text = str($ScrollContainer/settings_list/song_vol_slider.value)
	$ScrollContainer/settings_list/song_vol_edit.caret_column = 6

func _on_menu_song_vol_label_focus_entered() -> void:
	$ScrollContainer/settings_list/menu_song_vol_label.hide()
	$ScrollContainer/settings_list/menu_song_vol_edit.show()
	$ScrollContainer/settings_list/menu_song_vol_edit.grab_focus()
	$ScrollContainer/settings_list/menu_song_vol_edit.text = str($ScrollContainer/settings_list/menu_song_vol_slider.value)
	$ScrollContainer/settings_list/menu_song_vol_edit.caret_column = 6

func _on_sfx_vol_label_focus_entered() -> void:
	$ScrollContainer/settings_list/sfx_vol_label.hide()
	$ScrollContainer/settings_list/sfx_vol_edit.show()
	$ScrollContainer/settings_list/sfx_vol_edit.grab_focus()
	$ScrollContainer/settings_list/sfx_vol_edit.text = str($ScrollContainer/settings_list/sfx_vol_slider.value)
	$ScrollContainer/settings_list/sfx_vol_edit.caret_column = 6

func _on_master_vol_edit_text_submitted(new_text: String) -> void:
	var new_vol = clampf(General._num_eval(new_text), 0.0, 100.0)
	$ScrollContainer/settings_list/master_vol_slider.value = new_vol
	$ScrollContainer/settings_list/master_vol_edit.release_focus()
	$ScrollContainer/settings_list/master_vol_edit.hide()
	$ScrollContainer/settings_list/master_vol_label.show()
	Settings.game.master_vol = new_vol
	save_stgs()

func _on_song_vol_edit_text_submitted(new_text: String) -> void:
	var new_vol = clampf(General._num_eval(new_text), 0.0, 100.0)
	$ScrollContainer/settings_list/song_vol_slider.value = new_vol
	$ScrollContainer/settings_list/song_vol_edit.release_focus()
	$ScrollContainer/settings_list/song_vol_edit.hide()
	$ScrollContainer/settings_list/song_vol_label.show()
	Settings.game.song_vol = new_vol
	save_stgs()

func _on_menu_song_vol_edit_text_submitted(new_text: String) -> void:
	var new_vol = clampf(General._num_eval(new_text), 0.0, 100.0)
	$ScrollContainer/settings_list/menu_song_vol_slider.value = new_vol
	$ScrollContainer/settings_list/menu_song_vol_edit.release_focus()
	$ScrollContainer/settings_list/menu_song_vol_edit.hide()
	$ScrollContainer/settings_list/menu_song_vol_label.show()
	Settings.game.menu_song_vol = new_vol
	save_stgs()

func _on_sfx_vol_edit_text_submitted(new_text: String) -> void:
	var new_vol = clampf(General._num_eval(new_text), 0.0, 100.0)
	$ScrollContainer/settings_list/sfx_vol_slider.value = new_vol
	$ScrollContainer/settings_list/sfx_vol_edit.release_focus()
	$ScrollContainer/settings_list/sfx_vol_edit.hide()
	$ScrollContainer/settings_list/sfx_vol_label.show()
	Settings.game.sfx_vol = new_vol
	save_stgs()

func _on_master_vol_edit_focus_exited() -> void:
	$ScrollContainer/settings_list/master_vol_edit.hide()
	$ScrollContainer/settings_list/master_vol_label.show()

func _on_song_vol_edit_focus_exited() -> void:
	$ScrollContainer/settings_list/song_vol_edit.hide()
	$ScrollContainer/settings_list/song_vol_label.show()

func _on_menu_song_vol_edit_focus_exited() -> void:
	$ScrollContainer/settings_list/menu_song_vol_edit.hide()
	$ScrollContainer/settings_list/menu_song_vol_label.show()

func _on_sfx_vol_edit_focus_exited() -> void:
	$ScrollContainer/settings_list/sfx_vol_edit.hide()
	$ScrollContainer/settings_list/sfx_vol_label.show()

func _on_menu_bg_brightness_slider_value_changed(value: float) -> void:
	$ScrollContainer/settings_list/menu_bg_brightness_label.text = "---- Background Brightness (Main Menu): " + str(value) + "% ----"
	menu_brightness_changed.emit(value / 100.0)

func _on_menu_bg_brightness_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.game.menu_bg_brightness = $ScrollContainer/settings_list/menu_bg_brightness_slider.value / 100.0
		save_stgs()

func _on_bg_brightness_slider_value_changed(value: float) -> void:
	$ScrollContainer/settings_list/bg_brightness_label.text = "---- Background Brightness (In Game): " + str(value) + "% ----"
	brightness_changed.emit(value / 100.0)

func _on_bg_brightness_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.game.bg_brightness = $ScrollContainer/settings_list/bg_brightness_slider.value / 100.0
		save_stgs()

func _on_username_edit_text_submitted(new_text: String) -> void:
	Settings.game.username = new_text
	save_stgs()
	set_username.emit(new_text)

func _on_title_edit_text_submitted(new_text: String) -> void:
	Settings.game.title = new_text
	save_stgs()
	set_title.emit(new_text)

func _on_clan_edit_text_submitted(new_text: String) -> void:
	Settings.game.clan = new_text
	save_stgs()
	set_clan.emit(new_text)

func _on_profile_img_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file for your profile picture.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_pfp_img_file_selected")
	)
	if err != OK:
		print("Couldnt show native file dialog ", err, error_string(err))

func _on_pfp_img_file_selected(status, paths: PackedStringArray, _filter_idx: int) -> void:
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	var image := Image.new()
	var err := image.load(paths[0])
	if err == OK:
		var dir := "user://Profile/pfps"
		DirAccess.make_dir_recursive_absolute(dir)

		var img_save_path := dir.path_join(paths[0].get_file())
		var err2 := General.save_image_with_correct_extension(image, img_save_path)
		printerr(err2, " ", error_string(err2))

		if err2 == OK:
			Settings.game.profile_path = img_save_path
			print("Saved profile image to %s" % img_save_path)
			save_stgs()

			var tex := ImageTexture.create_from_image(image)
			$ScrollContainer/settings_list/pfp_edit.icon = tex
			set_profile.emit(tex)
		else:
			print("Failed to save image at %s" % img_save_path)
	else:
		print("Failed to load image: ", paths[0], " ", err, " ", error_string(err))

func _on_banner_img_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file for your banner.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_banner_img_file_selected")
	)
	if err != OK:
		print("Couldnt show native file dialog ", err, error_string(err))

func _on_banner_img_file_selected(status, paths: PackedStringArray, _filter_idx: int) -> void:
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)
	
	if not status or paths.is_empty():
		return
	
	var image := Image.new()
	var err := image.load(paths[0])
	if err == OK:
		var dir := "user://Profile/banners"
		DirAccess.make_dir_recursive_absolute(dir)

		var img_save_path := dir.path_join(paths[0].get_file())
		var err2 := General.save_image_with_correct_extension(image, img_save_path)
		printerr(err2, " ", error_string(err2))

		if err2 == OK:
			Settings.game.banner_path = img_save_path
			print("Saved banner image to %s" % img_save_path)
			save_stgs()

			var tex := ImageTexture.create_from_image(image)
			$ScrollContainer/settings_list/banner_edit.icon = tex
			set_banner.emit(tex)
		else:
			print("Failed to save image at %s" % img_save_path)
	else:
		print("Failed to load image: ", paths[0], " ", err, " ", error_string(err))

func _on_bg_colour_toggle_toggled(toggled_on: bool) -> void:
	Settings.misc.colour_bg_with_cover = toggled_on
	save_stgs()

func _on_note_backdrop_brightness_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.misc.notes_backdrop_opacity = $ScrollContainer/settings_list/note_backdrop_brightness_slider.value / 100.0
		save_stgs()
		note_backdrop_opacity_changed.emit($ScrollContainer/settings_list/note_backdrop_brightness_slider.value / 100.0)

func _on_note_backdrop_brightness_slider_value_changed(value: float) -> void:
	$ScrollContainer/settings_list/note_backdrop_brightness.text = "---- Notes Backdrop Opacity (In Game): " + str(value)  + "% ----"
	editor_note_backdrop_opacity_changed.emit($ScrollContainer/settings_list/editor_note_backdrop_brightness_slider.value / 100.0)

func _on_editor_note_backdrop_brightness_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.misc.editor_notes_backdrop_opacity = $ScrollContainer/settings_list/editor_note_backdrop_brightness_slider.value / 100.0
		save_stgs()

func _on_editor_note_backdrop_brightness_slider_value_changed(value: float) -> void:
	$ScrollContainer/settings_list/editor_note_backdrop_brightness.text = "---- Notes Backdrop Opacity (Editor): " + str(value)  + "% ----"
	editor_note_backdrop_opacity_changed.emit(value / 100.0)


func _on_editor_bg_brightness_slider_value_changed(value: float) -> void:
	$ScrollContainer/settings_list/editor_bg_brightness_label.text = "---- Background Brightness (Editor): " + str(value) + "% ----"
	editor_brightness_changed.emit(value / 100.0)

func _on_editor_bg_brightness_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.game.editor_bg_brightness = $ScrollContainer/settings_list/editor_bg_brightness_slider.value / 100.0
		save_stgs()

func _on_bg_img_drop_item_selected(index: int) -> void:
	if index == 0:
		var def_img := Image.load_from_file("res://Resources/defaultBG.png")
		var tex := ImageTexture.create_from_image(def_img)
		bg_changed.emit(tex)
		Settings.misc.menu_bg_img_path = ""
		save_stgs()
		return
	
	var img_file_name: String = $ScrollContainer/settings_list/bg_img_drop.get_item_text(index)
	var img := Image.load_from_file("user://Backgrounds/" + img_file_name)
	if img: # make sure it loaded
		var tex := ImageTexture.create_from_image(img)
		bg_changed.emit(tex)
		Settings.misc.menu_bg_img_path = ProjectSettings.globalize_path("user://Backgrounds/" + img_file_name)
		save_stgs()
	else:
		print("Failed to load image at path: user://Backgrounds/" + img_file_name)

func _on_bg_img_delete_pressed() -> void:
	$ScrollContainer/settings_list/bg_img_delete.release_focus()
	if Settings.misc.menu_bg_img_path == "":
		$ScrollContainer/settings_list/bg_img_delete.disabled = true
		$ScrollContainer/settings_list/bg_img_delete.text = "Cannot delete Default BG."
		$ScrollContainer/settings_list/bg_img_delete.mouse_default_cursor_shape = CURSOR_FORBIDDEN
		await get_tree().create_timer(2.0).timeout
		$ScrollContainer/settings_list/bg_img_delete.text = "Delete Current Background Image"
		$ScrollContainer/settings_list/bg_img_delete.disabled = false
		$ScrollContainer/settings_list/bg_img_delete.mouse_default_cursor_shape = CURSOR_POINTING_HAND
		return
	$ScrollContainer/settings_list/bg_img_delete.hide()
	$ScrollContainer/settings_list/bg_img_dlt_confirmation.show()
	$ScrollContainer/settings_list/bg_img_dlt_confirmation/bg_img_delete_confirm.text = "Delete " + Settings.misc.menu_bg_img_path.get_file() + "?"

func _on_bg_img_confirm_pressed() -> void:
	var err = DirAccess.remove_absolute(Settings.misc.menu_bg_img_path)
	print(err, " ", error_string(err))
	_on_bg_img_drop_item_selected(0)
	get_custom_backgrounds()
	
	$ScrollContainer/settings_list/bg_img_delete.show()
	$ScrollContainer/settings_list/bg_img_dlt_confirmation.hide()

func _on_bg_img_delete_cancel_pressed() -> void:
	$ScrollContainer/settings_list/bg_img_delete.show()
	$ScrollContainer/settings_list/bg_img_dlt_confirmation.hide()


func _on_bg_vids_toggle_toggled(toggled_on: bool) -> void:
	$ScrollContainer/settings_list/bg_vids_toggle.release_focus()
	Settings.misc.bg_videos = toggled_on
	save_stgs()
	bg_vids_toggled.emit(toggled_on)


func _on_bg_vids_edit_toggle_toggled(toggled_on: bool) -> void:
	$ScrollContainer/settings_list/bg_vids_edit_toggle.release_focus()
	Settings.misc.editor_bg_videos = toggled_on
	editor_bg_vids_toggled.emit(toggled_on)

func _on_note_particle_fx_item_selected(index: int) -> void:
	Settings.misc.note_particle_fx = index
	save_stgs()

func _on_note_speed_edit_drag_ended(value_changed: bool) -> void:
	if value_changed:
		Settings.game.note_speed = $ScrollContainer/settings_list/note_speed_edit.value
		
		$ScrollContainer/settings_list/note_speed_value_lbl.text = "Note Speed: %.2f" % $ScrollContainer/settings_list/note_speed_edit.value
		save_stgs()

func _on_note_speed_value_lbl_focus_entered() -> void:
	$ScrollContainer/settings_list/note_speed_value_edit.show()
	$ScrollContainer/settings_list/note_speed_value_lbl.hide()
	
	$ScrollContainer/settings_list/note_speed_value_edit.text = str($ScrollContainer/settings_list/note_speed_edit.value)
	$ScrollContainer/settings_list/note_speed_value_edit.caret_column = 8
	
	$ScrollContainer/settings_list/note_speed_value_edit.grab_focus()

func _on_menu_song_vol_edit_2_focus_exited() -> void:
	$ScrollContainer/settings_list/note_speed_value_lbl.show()
	
	$ScrollContainer/settings_list/note_speed_value_edit.hide()

func _on_menu_song_vol_edit_2_text_submitted(new_text: String) -> void:
	var new_speed: float = clampf(General._num_eval(new_text), 1.0, 50.0)
	$ScrollContainer/settings_list/note_speed_edit.value = new_speed
	$ScrollContainer/settings_list/note_speed_value_edit.release_focus()
	_on_menu_song_vol_edit_2_focus_exited()
	
	Settings.game.note_speed = new_speed
	save_stgs()


func _on_note_speed_edit_value_changed(value: float) -> void:
	$ScrollContainer/settings_list/note_speed_value_lbl.text = "Note Speed: %.2f" % value
	Settings.game.note_speed = value
	note_speed_changed.emit(value)


func _on_show_chart_alignment_toggled(toggled_on: bool) -> void:
	Settings.other.show_chart_alignment = toggled_on
	save_stgs()
