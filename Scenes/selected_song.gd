extends Control

var selected_stream: AudioStream
var selected_stream_path: String

var selected_title: String
var selected_artist: String
var selected_album: String
var selected_cover: Image
var selected_year: int

var selected_background: Image
var selected_background_name: String

var background_vid_path: String = ""

var selected_beat_offset: float

var selected_beatz_path

var colors: Array[Color]

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

var screen: String = "song"

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
		$vis_anim.scale = lerp($vis_anim.scale, Vector2(2.6, 2.6) * cover_target, 25.0 * delta)
		$cover_anim.scale = lerp($cover_anim.scale, Vector2.ONE * cover_target, 20.0 * delta)
		$bg_cover_anim.scale = lerp($bg_cover_anim.scale, Vector2(1.0, 1.0) * bg_target, 16.0 * delta)

func _ready() -> void:
	if Settings.misc.menu_bg_img_path != "":
		var img := Image.load_from_file(Settings.misc.menu_bg_img_path)
		if img: # make sure it loaded
			var tex := ImageTexture.create_from_image(img)
			$TransitionRect.texture = tex
		else:
			print("Failed to load image at path:", Settings.misc.menu_bg_img_path)
	
	if Settings.misc.reduce_motion:
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
	
	$cover_anim/circlemask/cover.texture = ImageTexture.create_from_image(selected_cover)
	$bg_cover_anim/bg_cover.texture = ImageTexture.create_from_image(selected_cover)
	
	var extracted_colors: Array[Color] = General.extract_dominant_colors(selected_cover)
	$vis_anim/Visualizer.colors = extracted_colors
	colors = extracted_colors
	
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
	
	General._set_rpc(selected_title + " - " + selected_artist, "Selected a Song!", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "", int(Time.get_unix_time_from_system()), int(Time.get_unix_time_from_system() + $song.stream.get_length() * 1000))

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
		tween.tween_property($song, "volume_db", 0.0, 1.25).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property($vis_anim/Visualizer/Song_left, "volume_db", 0.0, 1.25).set_trans(Tween.TRANS_CUBIC)
		tween.parallel().tween_property($vis_anim/Visualizer/Song_right, "volume_db", 0.0, 1.25).set_trans(Tween.TRANS_CUBIC)
	else:
		$song.volume_db = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _input(event: InputEvent) -> void:
	if not get_viewport().gui_get_focus_owner() and event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller-back"):
		_on_back_pressed()
	elif screen == "song" and event.is_action_pressed("ui_accept") or event.is_action_pressed("controller-accept"):
		_on_play_button_up()
	elif event.is_action_pressed("controller-pause"):
		_on_go_to_stgs_pressed()

func _on_play_button_up() -> void:
	$Play.release_focus()

	# Optional animation before loading screen
	if Settings.misc.reduce_motion:
		$AnimationPlayer.play("play_song", -1, 250.0)
	else:
		$AnimationPlayer.play("play_song")
		
		var tween := create_tween()
		tween.tween_property($song, "volume_db", -80.0, 1.0)
		await get_tree().create_timer(1.0).timeout
		
	var game = General.MAIN.instantiate()
	
	# Pass data to the loading scene (it will forward it to main when loaded)
	game.set("chart_path", selected_beatz_path)
	game.set("song", $song.stream)
	game.set("song_title", selected_title)
	game.set("BPM", selected_bpm)
	game.set("local_beat_offset", selected_beat_offset)
	game.set("selected_background", selected_background)
	game.set("selected_background_name", selected_background_name)
	game.set("background_vid_path", background_vid_path)
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
	game.set("colors", colors)
	
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
		
		var tween := create_tween()
		tween.tween_property($song, "volume_db", -80.0, 1.25)
		
		if Settings.misc.reduce_motion:
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
	var edit = General.EDITOR.instantiate()
	
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
	
	edit.set("local_beat_offset", selected_beat_offset)
	
	edit.set("start_wait", start_wait)
	
	edit.set("selected_difficulty", selected_difficulty)
	edit.set("selected_diff_texture", $cover_anim/circlemask/difficulty_label.texture)
	edit.set("notes", notes)
	edit.set("selected_chart_name", selected_chart_name)
	
	edit.set("selected_background", selected_background)
	edit.set("selected_background_name", selected_background_name)
	
	edit.set("background_vid_path", background_vid_path)
	
	edit.set("selected_beatz_path", selected_beatz_path)
	
	edit.set("selected_bpm", selected_bpm)
	edit.set("selected_charter", selected_charter)
	
	edit.set("colors", colors)
	
	var tween := create_tween()
	tween.tween_property($song, "volume_db", -80.0, 0.8).set_ease(Tween.EASE_OUT)
	
	$AnimationPlayer.play("play_song")
	await get_tree().create_timer(0.81).timeout
	
	get_tree().root.add_child(edit)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = edit
