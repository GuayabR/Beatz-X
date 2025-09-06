extends Control

var selected_stream: AudioStream
var selected_stream_path: String

var selected_title: String
var selected_artist: String
var selected_album: String
var selected_cover
var selected_year: int

var selected_beatz_path

var start_wait: int = 0 

var preview_start: float = 0.0
var preview_end: float = 30.0

var fade_in: bool = false
var fade_out: bool = false

var selected_difficulty: String
var selected_diff_texture: String

var selected_chart_name: String
var selected_charter: String

var selected_bpm: float = 120.0

var notes

var spectrum: AudioEffectSpectrumAnalyzerInstance

var current_scale: float = 1.0

var fading: bool = false

var screen = "song"

var imported_beatz

func _process(delta: float):
	if $song.playing and $song.get_playback_position() >= preview_end and not fading:
		print("looping back")
		if fade_out:
			_fade_out_and_loop()
		else:
			$song.seek(preview_start)
			$vis_anim/Visualizer/Song_left.seek(preview_start)
			$vis_anim/Visualizer/Song_right.seek(preview_start)
	
	if spectrum:
		# Get energy levels
		var overall_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 11050.0).length()
		var overall_loudness: float = clampf((111 + linear_to_db(overall_energy)) / 111.0, 0.0, 1.0)

		var bass_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 250.0).length()
		var bass_loudness: float = clampf((111 + linear_to_db(bass_energy)) / 111.0, 0.0, 1.0)

		var treble_energy: float = spectrum.get_magnitude_for_frequency_range(5000.0, 11050.0).length()
		var treble_loudness: float = clampf((111 + linear_to_db(treble_energy)) / 111.0, 0.0, 1.0)

		# Exponentiate for punch
		var exp_treble := pow(treble_loudness, 1.5)
		var exp_overall := pow(overall_loudness, 3.0)
		var exp_bass := pow(bass_loudness, 2.5)
		var exp_bg := clampf(exp_bass * 0.8 + exp_overall * 0.1, 0.0, 1.0)
		
		# Base and max scale ranges
		var base_scale := 1.0
		var max_title := 1.5
		var max_bg := 1.3
		var max_cover := 1.35

		# Interpolated targets
		var title_target = lerp(base_scale, max_title, exp_treble)
		var cover_target = lerp(base_scale - 0.1, max_cover, exp_bass)
		var bg_target = lerp(base_scale, max_bg, exp_bg)

		# Smooth transitions
		$Title.scale = lerp($Title.scale, Vector2.ONE * title_target, 13.0 * delta)
		$Artist.scale = lerp($Artist.scale, Vector2.ONE * bg_target * 1.1, 10.0 * delta)
		$vis_anim.scale = lerp($vis_anim.scale, Vector2(2.6, 2.6) * cover_target, 15.0 * delta)
		$cover_anim.scale = lerp($cover_anim.scale, Vector2.ONE * cover_target, 20.0 * delta)
		$bg_cover_anim.scale = lerp($bg_cover_anim.scale, Vector2(1.0, 1.0) * bg_target, 16.0 * delta)

func _ready() -> void:
	if Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("load_song", -1, 250.0)
	else:
		$AnimationPlayer.play("load_song")
	
	print($Title.pivot_offset, $Title.size)
	$Title.text = str(selected_title)
	$Artist.text = str(selected_artist)
	
	$CenterContainer/scores.beatz_file = selected_beatz_path
	$CenterContainer/scores._set_items()
	
	await get_tree().process_frame
	
	$Title.pivot_offset.x = $Title.size.x / 2
	print($Title.pivot_offset, $Title.size)
	
	$Artist.pivot_offset.x = $Artist.size.x / 2
	print($Artist.pivot_offset, $Artist.size)
	
	$cover_anim/circlemask/cover.texture = selected_cover
	$bg_cover_anim/bg_cover.texture = selected_cover
	
	var extracted_colors = extract_dominant_colors(selected_cover)
	$vis_anim/Visualizer.colors = extracted_colors
	
	var diff_texture := "" 
	if not selected_diff_texture: 
		diff_texture = "res://Resources/Misc/" + selected_difficulty + "_label.png"
		$cover_anim/circlemask/difficulty_label.texture = load(diff_texture)
	else: 
		print("diff tex ", selected_diff_texture)
		diff_texture = selected_diff_texture
		if FileAccess.file_exists(diff_texture):
			var img := Image.new()
			var err := img.load(diff_texture)
			if err == OK:
				var tex := ImageTexture.create_from_image(img)
				$cover_anim/circlemask/difficulty_label.texture = tex
			else:
				print("Failed to load diff texture at: ", diff_texture)
		else:
			print("Diff texture file not found: ", diff_texture)

	
	var audio_ext = selected_stream_path.get_extension().to_lower()
	
	if audio_ext == "mp3":
		$song.stream = AudioStreamMP3.load_from_file(selected_stream_path)
	elif audio_ext == "ogg":
		$song.stream = AudioStreamOggVorbis.load_from_file(selected_stream_path)
	elif audio_ext == "wav":
		$song.stream = AudioStreamWAV.load_from_file(selected_stream_path)
	
	$song.volume_db = -80.0 if fade_in else 0.0
	$song.play(preview_start)
	if fade_in:
		var tween = create_tween()
		tween.parallel().tween_property($song, "volume_db", 0.0, 0.75).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property($vis_anim/Visualizer/Song_left, "volume_db", 0.0, 0.75).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property($vis_anim/Visualizer/Song_right, "volume_db", 0.0, 0.75).set_trans(Tween.TRANS_CUBIC)
	$vis_anim/Visualizer/Song_left.stream = $song.stream
	$vis_anim/Visualizer/Song_right.stream = $song.stream
	$vis_anim/Visualizer/Song_left.play(preview_start)
	$vis_anim/Visualizer/Song_right.play(preview_start)
	
	spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Song"), 0) as AudioEffectSpectrumAnalyzerInstance
	
	
	imported_beatz = Globals.import_beatz_file(selected_beatz_path)

func _fade_out_and_loop():
	fading = true
	var tween = create_tween()
	tween.parallel().tween_property($song, "volume_db", -80.0, 0.75).set_trans(Tween.TRANS_EXPO).finished.connect(_on_fade_out_complete)
	tween.parallel().tween_property($vis_anim/Visualizer/Song_left, "volume_db", -80.0, 0.75).set_trans(Tween.TRANS_EXPO)
	tween.parallel().tween_property($vis_anim/Visualizer/Song_right, "volume_db", -80.0, 0.75).set_trans(Tween.TRANS_EXPO)

func _on_fade_out_complete():
	$song.seek(preview_start)
	$vis_anim/Visualizer/Song_left.seek(preview_start)
	$vis_anim/Visualizer/Song_right.seek(preview_start)
	fading = false
	if fade_in:
		var tween = create_tween()
		$song.volume_db = -80.0
		$vis_anim/Visualizer/Song_left.volume_db = -80.0
		$vis_anim/Visualizer/Song_right.volume_db = -80.0
		tween.parallel().tween_property($song, "volume_db", 0.0, 1.25).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property($vis_anim/Visualizer/Song_left, "volume_db", 0.0, 1.25).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property($vis_anim/Visualizer/Song_right, "volume_db", 0.0, 1.25).set_trans(Tween.TRANS_CUBIC)
	else:
		$song.volume_db = 0.0

var _color_from_string_map: Dictionary = {}

func extract_dominant_colors(texture: Texture2D) -> Array[Color]:
	print("Extracting dominant colors...")
	var image: Image = texture.get_image()
	if image.is_compressed():
		print("Image is compressed. Decompressing...")
		image.decompress()
	image.resize(64, 1, Image.INTERPOLATE_TRILINEAR)
	print("Image resized to 64x1")
	
	var color_counts = _scan_colors(image, false)
	print("Scanned normal colors. Found:", color_counts.size(), "distinct colors")
	
	var dark_count = 0
	var total_count = 0
	for c in color_counts.keys():
		var color = _color_from_string_map.get(c, Color(0, 0, 0))
		total_count += color_counts[c]
		if color.r < 0.314 or color.g < 0.314 or color.b < 0.314:
			dark_count += color_counts[c]
	print("Total color samples:", total_count)
	print("Dark color samples:", dark_count)
	
	if total_count > 0 and float(dark_count) / float(total_count) > 0.6:
		print("Too many dark colors. Trying to scan for brighter colors...")
		var bright_counts = _scan_colors(image, true)
		print("Scanned bright colors. Found:", bright_counts.size(), "distinct colors")
		if bright_counts.size() > 0:
			color_counts = bright_counts
		else:
			print("No brighter colors found. Brightening existing dark colors...")
			var new_counts = {}
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
	print("Sorted colors by frequency")
	
	var result: Array[Color] = []
	for i in range(min(6, sorted_colors.size())):
		var col_str = sorted_colors[i]
		result.append(_color_from_string_map.get(col_str, Color(0, 0, 0)))
		
	print("Final extracted colors:", result)
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

	print("Scan complete. only_bright =", only_bright, "Unique entries:", counts.size())
	_latest_color_counts = counts
	return counts

func _compare_colors_by_frequency(a: String, b: String) -> int:
	if not _latest_color_counts.has(a) or not _latest_color_counts.has(b):
		print("Missing color count for", a, "or", b)
		return 0
	var result = _latest_color_counts[b] - _latest_color_counts[a]
	#print("Comparing ", a, " vs ", b, " -> ", result)
	return result

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept"):
		_on_play_button_up()

func _on_play_button_up() -> void:
	$Play.release_focus()

	# Optional animation before loading screen
	if Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("play_song", -1, 250.0)
	else:
		$AnimationPlayer.play("play_song")
		await get_tree().create_timer(1.0).timeout
		
	var game = Globals.MAIN.instantiate()
	
	# Pass data to the loading scene (it will forward it to main when loaded)
	game.set("chart_path", selected_beatz_path)
	game.set("song", $song.stream)
	game.set("song_title", selected_title)
	game.set("album", selected_album)
	game.set("artist", selected_artist)
	game.set("year", selected_year)
	game.set("cover", selected_cover)
	game.set("preview_start", preview_start)
	game.set("preview_end", preview_end)
	game.set("charter", selected_charter)
	game.set("difficulty", selected_difficulty)
	game.set("customNotes", notes)
	game.set("chart_name", selected_chart_name)
	game.set("start_wait", start_wait)
	
	get_tree().root.add_child(game)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = game

func _on_back_pressed() -> void:
	$back.release_focus()
	if $AnimationPlayer.is_playing():
		print("playing")
		await $AnimationPlayer.animation_finished
	
	if screen == "song":
		var menu := preload("res://Scenes/main_menu.tscn").instantiate()
		menu.set("current_menu", "list")
		
		if Globals.settings.misc_settings.reduce_motion:
			$AnimationPlayer.play("play_song", -1, 250.0)
		else:
			$AnimationPlayer.play("play_song")
			await get_tree().create_timer(1.0).timeout
		
		get_tree().root.add_child(menu)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = menu
	elif screen == "settings":
		$AnimationPlayer.play("back_from_stgs")
		screen = "song"

func _on_song_finished() -> void:
	$song.play(preview_start)
	$vis_anim/Visualizer/Song_left.play(preview_start)
	$vis_anim/Visualizer/Song_right.play(preview_start)

func _on_go_to_stgs_pressed() -> void:
	$go_to_stgs.release_focus()
	$AnimationPlayer.play("go_to_stgs")
	screen = "settings"

func _on_edit_pressed() -> void:
	var edit = Globals.EDITOR.instantiate()
	
	edit.set("selected_stream", $song.stream)
	edit.set("selected_stream_path", selected_stream_path)
	
	edit.new_beatzmap = false
	
	edit.set("selected_title", selected_title)
	edit.set("selected_album", selected_album)
	
	edit.set("selected_cover", selected_cover)
	edit.set("selected_artist", selected_artist)
	edit.set("selected_year", selected_year)
	
	edit.set("preview_start", preview_start)
	edit.set("preview_end",preview_end)
	
	edit.set("start_wait", start_wait)
	
	edit.set("selected_difficulty", selected_difficulty)
	edit.set("selected_diff_texture", $cover_anim/circlemask/difficulty_label.texture)
	edit.set("notes", notes)
	edit.set("selected_chart_name", selected_chart_name)
	
	edit.set("selected_beatz_path", selected_beatz_path)
	
	edit.set("selected_bpm", selected_bpm)
	edit.set("selected_charter", selected_charter)
	
	get_tree().root.add_child(edit)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = edit
