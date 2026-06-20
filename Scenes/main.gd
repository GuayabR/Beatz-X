extends Node

var hp: float = 100.0
var hp_gain := 1.0
var hp_loss := 10.0

## None: Default gameplay | Infinite Health: No health loss | Classic Streak: Reverts back to no streak gameplay, can't lose or gain streak
## points are given by dividing amount of notes by total points
enum Modifier {NONE, INFINITEHEALTH, CLASSICSTREAK}
var mod: Modifier = Modifier.NONE

## Starts the song and notes at a specific time, in the editor add "bookmarks" to mark different sections of the song.
var start_pos: float = 0.0

## Playback speed for the song and notes, better over [code]playback_speed[/code] because it doesn't affect animations.
var playback_speed: float = 1.0

var init_recording: bool = false

## When playtesting from the editor, set this as false if the song being playtested wasnt saved to list
var editor_saved: bool = true

# Song details
var song: AudioStreamMP3
var song_title: String
var album: String
var artist: String
var year: int

var selected_background: Image
var selected_background_name: String

var background_vid_path: String
var cover_loop_vid_path: String

var local_beat_offset

var song_start_time: int

var cover: Image

var chart_name: String

var colors: Array[Color]

var chart_path
var song_path

var screen: String = "game" # game / paused / end_screen / settings

var songEnded: bool = false

var menu: String = "res://Scenes/main_menu.tscn"

var noteSpeed: float:
	get():
		return Settings.game.note_speed / playback_speed

var noteSpawnY: float:
	get():
		return Beatz.time_to_y(Beatz.BASE_REC_TIME_MS) * -1

var BPM: float = 150.0 # Beats per minute
var beattime: float:
	get:
		return 60.0 / BPM # Interval between beats in milliseconds

var total_points: float = 0.0
var points_per_note: float = 0.0
var total_valid_notes: int = 0

var start_wait: int = 0

var gameStarted: bool = false

var has_paused: bool = false
var gamePaused: bool = false

const noteTypes: Array[Variant] = ["Upleft", "Downleft", "Left", "Up", "Down", "Right", "Upright", "Downright"];

var combo_level: int = 0   # 0 = 1x, 1 = 2x, 2 = 4x, 3 = 8x

var points: float = 0;
var maxStreak: int = 0;
var streak: int = 0;
var misses: int = 0;
var exactHits: int = 0;
var insanes: int = 0;
var perfects: int = 0;
var earlys: int = 0;
var lates: int = 0;
var notesHit: int = 0;
var customNotes := []; # Store the custom notes to play
var notes := []

var active_holds := {}  # { note: {held_ms: float, points_per_ms: float} }

var auto_hit_used: bool = false
var auto_hit: bool = false

var note: PackedScene = preload("res://Scenes/note.tscn")

var highlightedNotes: Dictionary = {
	"Upleft": false,
	"Downleft": false,
	"Left": false,
	"Down": false,
	"Up": false,
	"Right": false,
	"Downright": false,
	"Upright": false,
}

var spectrum: AudioEffectSpectrumAnalyzerInstance

func _has_valid_notes(ns: Array) -> bool:
	for n in ns:
		if n.has("type") and n.has("timestamp"): # If the note has a type and a timestamp it is considered valid
			return true
	return false

@onready var points_lbl: RichTextLabel = $UI/points
@onready var stat_exacts: RichTextLabel = $UI/stat_exacts
@onready var stat_insanes: RichTextLabel = $UI/stat_insanes
@onready var stat_perfects: RichTextLabel = $UI/stat_perfects
@onready var stat_earlys: RichTextLabel = $UI/stat_earlys
@onready var stat_lates: RichTextLabel = $UI/stat_lates
@onready var stat_missed: RichTextLabel = $UI/stat_missed
@onready var streak_lbl: RichTextLabel = $UI/streak
@onready var max_streak_lbl: RichTextLabel = $UI/max_streak
@onready var points_awarded: RichTextLabel = $UI/points_awarded
@onready var hp_gained: RichTextLabel = $UI/hp_gained
@onready var score_mult: RichTextLabel = $UI/score_mult
@onready var song_progress: ProgressBar = $UI/song_progress
@onready var song_progress_lbl: RichTextLabel = $UI/song_progress_lbl
@onready var nps_lbl: RichTextLabel = $UI/infos/nps_lbl
@onready var kps_lbl: RichTextLabel = $UI/infos/kps_lbl
@onready var notes_hit_lbl: RichTextLabel = $UI/infos/notes_hit_lbl

const exact_window_ms: float = 8.0
const insane_window_ms: float = 24.0
const perfect_window_ms: float = 55.0
const great_window_ms: float = 200.0
const miss_window_ms: float = 285.0

var baseline_speed: float = 13.0  # ← base speed

func get_center_y() -> float:
	return $stationary_notes/lines/linemiddle.position.y

func apply_hit_type_windows():
	var offset = get_center_y()
	var speed_factor = 1.0 #sqrt(noteSpeed / 13.0) # ← this is the key

	# divide the ms → pixel result by the speed factor
	# so noteSpeed 13.0 becomes the “neutral” speed
	$stationary_notes/lines/lineexact1.position.y = offset + Beatz.time_to_y(-exact_window_ms) * speed_factor
	
	$stationary_notes/lines/lineexact2.position.y = offset + Beatz.time_to_y(exact_window_ms) * speed_factor

	$stationary_notes/lines/lineinsane1.position.y = offset + Beatz.time_to_y(-insane_window_ms) * speed_factor
	$stationary_notes/lines/lineinsane2.position.y = offset + Beatz.time_to_y(insane_window_ms) * speed_factor

	$stationary_notes/lines/lineperfect1.position.y = offset + Beatz.time_to_y(-perfect_window_ms) * speed_factor
	$stationary_notes/lines/lineperfect2.position.y = offset + Beatz.time_to_y(perfect_window_ms) * speed_factor

	$stationary_notes/lines/linegreat1.position.y = offset + Beatz.time_to_y(-great_window_ms) * speed_factor
	$stationary_notes/lines/linegreat2.position.y = offset + Beatz.time_to_y(great_window_ms) * speed_factor

	$stationary_notes/lines/linemiss.position.y = offset + Beatz.time_to_y(miss_window_ms) * speed_factor
	
	print("new pos")
	#print($stationary_notes/lines/lineexact1.position.y)
	#print($stationary_notes/lines/linemiss.position.y)
	print("spawny")
	print(speed_factor)
	print(offset + (Beatz.time_to_y(-exact_window_ms) / speed_factor))
	#$stationary_notes/lines/lineexact1.position.y = 200
	#print("assign to 200:", $stationary_notes/lines/lineexact1.position.y)


func set_note_spawn_y():
	apply_hit_type_windows()
	
	#match Settings.game.note_speed:
		#20.0: noteSpawnY = -1800
		#15.0: noteSpawnY = -1200
		#13.0: noteSpawnY = -989
		#10.0: noteSpawnY = -680
		#8.0: noteSpawnY = -475
		#5.0: noteSpawnY = -120
		#_: noteSpawnY = 0
	
	print_rich("Note spawn Y = [color=green]", noteSpawnY, "[/color] with speed of [b]%.2f[/b]" % Settings.game.note_speed)

func _process_custom_notes(ns: Array) -> void:
	set_note_spawn_y()
	
	var has_end := false

	var max_end_time_ms := -INF   # NEW — absolute end time of all notes
	
	var start_pos_ms = start_pos * 1000.0
	
	if ns[0].timestamp > 5000.0:
		var t2 := Timer.new()
		t2.one_shot = true
		t2.wait_time = (ns[0].timestamp - 1500.0) / 1000.0
		
		t2.connect("timeout", _on_fade_out_timeout)
		
		$UI/noteTimeouts.add_child(t2)
		t2.start()

	for n in ns:
		if n.has("end"):
			has_end = true

		if n.has("type") and n.has("timestamp"):
			var direction = n["type"]
			var original_timestamp: float = n["timestamp"]
			var hold: float = n.get("hold", 0.0) / playback_speed

			# shift note timeline by start position
			var timestamp: float
			timestamp = (original_timestamp - start_pos_ms) / playback_speed if start_pos > 0.01 else original_timestamp / playback_speed

			# skip notes that already passed before the start point
			if start_pos > 0.01 and (original_timestamp + hold) < start_pos_ms:
				continue

			var note_end: float = timestamp + max(hold, 0.0)
			if note_end > max_end_time_ms:
				max_end_time_ms = note_end

			# offset logic
			var offset = Settings.misc.note_offset
			var timer := Timer.new()
			timer.one_shot = true

			if timestamp <= -start_wait:
				timer.wait_time = (timestamp + offset + start_wait + 500) / 1000.0
			elif start_wait > 0:
				timer.wait_time = (timestamp + offset + start_wait + 500) / 1000.0
			else:
				timer.wait_time = (timestamp + offset) / 1000.0

			# never allow negative timer times
			timer.wait_time = max(timer.wait_time, 0.01)

			timer.connect(
				"timeout",
				Callable(self, "_on_custom_note_timeout").bind(
					direction,
					hold,
					original_timestamp
				)
			)

			$UI/noteTimeouts.add_child(timer)
			timer.start()

	if not has_end and max_end_time_ms > -INF:
		var offset = Settings.misc.note_offset
		var wait_time: float

		if start_wait > 0:
			wait_time = (max_end_time_ms + offset + start_wait + 500) / 1000.0
		else:
			wait_time = (max_end_time_ms + offset) / 1000.0

		# include your existing extra buffer
		wait_time += 3.0

		var end_timer := Timer.new()
		end_timer.one_shot = true
		end_timer.wait_time = wait_time
		end_timer.connect("timeout", Callable(self, "_on_song_finished").bind(true))
		$UI/noteTimeouts.add_child(end_timer)
		end_timer.start()

func _on_fade_out_timeout() -> void:
	print('after fade out')
	$end_screen_anims.play("init_after_fade")

func _on_custom_note_timeout(direction: String, hold: float, timestamp: float) -> void:
	#print("Spawning note with direction ", direction)
	spawn_note(direction, false, hold, timestamp)

# List of directions and their related UI sprite names and textures
var note_data: Dictionary[Variant, Variant] = {
	"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "NoteUpleftPress.png", "idle": "NoteUpleft.png"},
	"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "NoteDownleftpress.png", "idle": "NoteDownleft.png"},
	"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "NoteLeftPress.png", "idle": "NoteLeft.png"},
	"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "NoteDownPress.png", "idle": "NoteDown.png"},
	"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "NoteUpPress.png", "idle": "NoteUp.png"},
	"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "NoteRightPress.png", "idle": "NoteRight.png"},
	"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "NoteDownrightPress.png", "idle": "NoteDownright.png"},
	"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "NoteUprightPress.png", "idle": "NoteUpright.png"}
}

var pos_ms: 
	get:
		return $song.get_playback_position() * 1000.0 # convert to ms
var len_ms:
	get:
		return $song.stream.get_length() * 1000.0
var song_len:
	get:
		return $song.stream.get_length()

func set_discord_rpc():
	if not gamePaused: 
		General.set_presence(
			"Playing " + song_title + " - " + artist,
			EOS.Presence.Status.Online
		)
		General._set_rpc(song_title + " - " + artist, "Playing a Song!", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", song_start_time, int(Time.get_unix_time_from_system() + len_ms))
	else:
		General.set_presence(
			"Song " + song_title + " - " + artist + " paused.",
			EOS.Presence.Status.Online
		)
		General._set_rpc(song_title + " - " + artist, "Song Paused...", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(Time.get_unix_time_from_system()), 0)
	
	if recording:
		General.set_presence(
			"Recording Notes for " + song_title + " - " + artist,
			EOS.Presence.Status.Online
		)
		General._set_rpc(song_title + " - " + artist, "Recording Notes for Song!", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(Time.get_unix_time_from_system()), int(Time.get_unix_time_from_system() + len_ms))
	
	if songEnded:
		General.set_presence(
			"Completed %s - %s with %d points!" % [song_title, artist, int(points)],
			EOS.Presence.Status.Online
		)
		General._set_rpc(song_title + " - " + artist + " with " + str(points) + "!", "Completed a Song!", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", int(Time.get_unix_time_from_system()), 0)

var note_splash_particle: ParticleProcessMaterial = preload("res://Resources/misc/note_splash.tres")

var note_crash_particle: ParticleProcessMaterial = preload("res://Resources/misc/note_crash.tres")

func style():
	if Settings.misc.note_style == "circles":
		for sprite in $stationary_notes.get_children():
			if sprite is Sprite2D: sprite.scale = Vector2(0.65 * Settings.circles.size, 0.65 * Settings.circles.size)
	
	$notes_backdrop/ColorRect.color = Color(0.0, 0.0, 0.0, Settings.misc.notes_backdrop_opacity)
	
	if not Settings.misc.bg_videos:
		$VideoPlayback.process_mode = Node.PROCESS_MODE_DISABLED
		$VideoPlayback.hide()
	else:
		$VideoPlayback.process_mode = Node.PROCESS_MODE_ALWAYS
		$VideoPlayback.show()
	
	if Settings.misc.cover_loops and cover_loop_vid_path != "":
		$song_cover/VideoPlayback.set_video_path(cover_loop_vid_path)
		$song_cover.self_modulate = Color.TRANSPARENT
	
	if not Settings.misc.vis: $Visualizer.process_mode = Node.PROCESS_MODE_DISABLED
	
	if not colors.is_empty() and Settings.misc.colour_bg_with_cover: 
		$Visualizer.colors = colors
		var brightest_color: Color = General.get_average_color(cover, 4)

		$Background.modulate = brightest_color
		$song_cover/TextureRect.color = brightest_color
		
		var hp_bar_sb = StyleBoxFlat.new()
		hp_bar_sb.bg_color = brightest_color # background color
		hp_bar_sb.corner_radius_top_left = 8
		hp_bar_sb.corner_radius_top_right = 8
		hp_bar_sb.corner_radius_bottom_left = 8
		hp_bar_sb.corner_radius_bottom_right = 8
		hp_bar_sb.set_border_width_all(2)
		hp_bar_sb.border_color = Color.WHITE
		
		var hp_bar_bg_sb = StyleBoxFlat.new()
		hp_bar_bg_sb.bg_color = Color(brightest_color, 0.4) # background color
		hp_bar_bg_sb.corner_radius_top_left = 8
		hp_bar_bg_sb.corner_radius_top_right = 8
		hp_bar_bg_sb.corner_radius_bottom_left = 8
		hp_bar_bg_sb.corner_radius_bottom_right = 8
		hp_bar_bg_sb.set_border_width_all(2)
		hp_bar_bg_sb.border_color = Color.WHITE

		$notes_backdrop/hp.add_theme_stylebox_override("fill", hp_bar_sb)
		$notes_backdrop/hp.add_theme_stylebox_override("background", hp_bar_bg_sb)
		
		song_progress.add_theme_stylebox_override("fill", hp_bar_sb)
		song_progress.add_theme_stylebox_override("background", hp_bar_bg_sb)
	else:
		$Background.texture = preload("res://Resources/defaultBG.png")
		$song_cover/TextureRect.color = Color.WHITE
	
	if selected_background:
		var img := selected_background
		if img: # make sure it loaded
			var tex := ImageTexture.create_from_image(img)
			$Background.texture = tex
			$Background.modulate = Color.WHITE
		else: 
			print("No background image for this chart ", chart_path)
	
	if Settings.misc.menu_bg_img_path != "":
		var img := Image.load_from_file(Settings.misc.menu_bg_img_path)
		if img: # make sure it loaded
			var tex := ImageTexture.create_from_image(img)
			#if selected_background == null:
				#$Background.texture = tex
				#$Background.modulate = Color.WHITE
			$TransitionRect.texture = tex
			$ActualTransitionRect.texture = tex
		else:
			print("Failed to load image at path:", Settings.misc.menu_bg_img_path)
	
	if background_vid_path: 
		background_vid_path = ProjectSettings.globalize_path(background_vid_path)
		if Settings.misc.bg_videos:
			print("Setting video as ", background_vid_path)
			$VideoPlayback.set_video_path(background_vid_path)
			await $VideoPlayback.video_loaded
			print("Vid loaded")
	
	$Background.self_modulate = Color(Settings.game.bg_brightness, Settings.game.bg_brightness, Settings.game.bg_brightness)
	$VideoPlayback.self_modulate = Color(Settings.game.bg_brightness, Settings.game.bg_brightness, Settings.game.bg_brightness)
	
	var hp_t = create_tween()
	hp_t.tween_property($notes_backdrop/hp, "value", 100.0, 2.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	match Settings.misc.note_style:
		"dance": 
			note_data = {
				"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "NoteUpleftPress.png", "idle": "NoteUpleft.png"},
				"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "NoteDownleftpress.png", "idle": "NoteDownleft.png"},
				"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "NoteLeftPress.png", "idle": "NoteLeft.png"},
				"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "NoteDownPress.png", "idle": "NoteDown.png"},
				"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "NoteUpPress.png", "idle": "NoteUp.png"},
				"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "NoteRightPress.png", "idle": "NoteRight.png"},
				"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "NoteDownrightPress.png", "idle": "NoteDownright.png"},
				"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "NoteUprightPress.png", "idle": "NoteUpright.png"}
			}
		"techno": 
			note_data = {
				"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "NoteUpleftPress.png", "idle": "NoteUpleft.png"},
				"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "NoteDownleftpress.png", "idle": "NoteDownleft.png"},
				"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "techno/technoNoteLeft.png", "idle": "techno/technoNoteLeft.png"},
				"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "techno/technoNoteDown.png", "idle": "techno/technoNoteDown.png"},
				"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "techno/technoNoteUp.png", "idle": "techno/technoNoteUp.png"},
				"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "techno/technoNoteRight.png", "idle": "techno/technoNoteRight.png"},
				"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "NoteDownrightPress.png", "idle": "NoteDownright.png"},
				"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "NoteUprightPress.png", "idle": "NoteUpright.png"}
			}
		"para": 
			note_data = {
				"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "para/paraNoteUpleftPress.png", "idle": "para/paraNoteUpleft.png"},
				"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "para/paraNoteDownleftPress.png", "idle": "para/paraNoteDownleft.png"},
				"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "para/paraNoteLeftPress.png", "idle": "para/paraNoteLeft.png"},
				"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "para/paraNoteDownPress.png", "idle": "para/paraNoteDown.png"},
				"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "para/paraNoteUpPress.png", "idle": "para/paraNoteUp.png"},
				"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "para/paraNoteRightPress.png", "idle": "para/paraNoteRight.png"},
				"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "para/paraNoteDownrightPress.png", "idle": "para/paraNoteDownright.png"},
				"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "para/paraNoteUprightPress.png", "idle": "para/paraNoteUpright.png"}
			}
		"circles":
			note_data = {
				"noteUpleft": {
					"key": "Upleft",
					"sprite": "noteUpleftSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteDownleft": {
					"key": "Downleft",
					"sprite": "noteDownleftSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteLeft": {
					"key": "Left",
					"sprite": "noteLeftSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteDown": {
					"key": "Down",
					"sprite": "noteDownSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteUp": {
					"key": "Up",
					"sprite": "noteUpSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteRight": {
					"key": "Right",
					"sprite": "noteRightSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteDownright": {
					"key": "Downright",
					"sprite": "noteDownrightSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				},
				"noteUpright": {
					"key": "Upright",
					"sprite": "noteUprightSprite",
					"press": "circles/Circle.png",
					"idle": "circles/Circle.png"
				}
			}

func _on_close_requested() -> void:
	_on_pause()

func _ready():
	DisplayServer.window_set_title("%s - %s | Beatz! X" % [song_title, artist])
	
	_on_settings_bg_parallax_toggled(Settings.misc.bg_parallax)
	_on_settings_parallax_bg_toggled(Settings.misc.hq_background)
	
	_on_settings_bg_effect_changed(Settings.misc.bg_effect)
	
	_on_settings_bg_rot_time_changed(Settings.misc.bg_tween_time_sec)
	_on_settings_bg_time_interval_changed(Settings.misc.bg_time_interval_sec)
	
	_on_settings_bg_fx_random_multi_min_changed(Settings.misc.bg_fx_random_multi_min)
	_on_settings_bg_fx_random_multi_max_changed(Settings.misc.bg_fx_random_multi_max)
	
	_on_settings_bg_parallax_speed_changed(Settings.misc.bg_parallax_speed)
	
	General.apply_fps_limit(name) # main
	
	get_tree().set_auto_accept_quit(false)
	
	Beatz.playback_speed = playback_speed
	
	print("bg vid: ", background_vid_path, "\ncover loop:", cover_loop_vid_path)
	
	if background_vid_path != "":
		$hq_background.stop()
		$hq_background.hide()
	
	#$stationary_notes/trail.use_mouse = false
	
	if OS.get_name() == "Android": 
		print("Android")
		points_lbl.position.y = 122
		$UI/key_hints.hide()
		$mbl_pausebtn.show()
		$pausebtn.hide()
		match Settings.game.mbl_btn_layout:
			0: $mbl_buttons.show()
			1: $mbl_buttons2.show()
			"0": $mbl_buttons.show()
			"1": $mbl_buttons2.show()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		$pausebtn.hide()
	
	$UI/start_song_name.text = "[b]" + song_title + "[/b]"
	$UI/start_artist.text = "[i]" + artist + "[/i]"
	$UI/start_chart_name.text = "[b]\"" + chart_name + "\"[/b]"
	$UI/start_charter.text = charter
	
	style()
	
	if song:
		$song.stream = song
		$Visualizer/Song_left.stream = song
		$Visualizer/Song_right.stream = song
		
		$UI/song_title.text = "Song: " + song_title
		$UI/rec_song_title.text = song_title
		align_control($UI/rec_song_title)
		
		print("Song stream set in main scene.", $song.stream)
		
		print("Start pos is ", start_pos)
		song_progress_lbl.text = "%s / %s" % [General.format_time(start_pos),  General.format_time($song.stream.get_length())]
		
		# Handle album cover
		if cover:
			$song_cover.texture = ImageTexture.create_from_image(cover)
			#$song_cover.visible = true
			$song_cover.set("scale", Vector2(0.28, 0.28))
		elif album != null and album.strip_edges() != "":
			var sanitized_album_name = album.replace("/", "_").replace("\\", "_").replace(":", "_") # Replace all invalid characters for underscores to then load as an image
			var cover_path = "res://Resources/Covers/" + sanitized_album_name + ".png"
			
			if FileAccess.file_exists(cover_path):
				var cover_image = load(cover_path)
				$song_cover.texture = cover_image
				#$song_cover.visible = true
				$song_cover.set("scale", Vector2(0.28, 0.28))
			else:
				var fallback_image = load("res://Resources/misc/noCover.png")
				var fallback_texture = ImageTexture.create_from_image(fallback_image)
				$song_cover.texture = fallback_texture
				#$song_cover.visible = false
		else:
			var fallback_image = load("res://Resources/misc/noCover.png")
			var fallback_texture := ImageTexture.create_from_image(fallback_image)
			$song_cover.texture = fallback_texture
			$song_cover.visible = false
		
		if init_recording:
			print("Random notes since chart file doesn't contain valid notes or it doesn't exist")
			
			beattime = 60.0 / BPM
			gameStarted = true
			gamePaused = false
			screen = "game"
			song_start_time = int(Time.get_unix_time_from_system())
			
			# Once generated, count them as valid notes
			print_rich("[color=green]Getting generated random notes: ", total_valid_notes, "[/color]")
			total_valid_notes = generateNotes()
			print_rich("[color=green]Generated random notes: ", total_valid_notes, "[/color]")
			
			$UI/start_chart_info.text = "[i]" + str(total_valid_notes) + " Notes / " + str(BPM) + " BPM[/i]"
			var start_chart_t = create_tween()
			start_chart_t.tween_property($UI/start_chart_info, "self_modulate", Color.WHITE, 0.336)
			
			song_progress_lbl.text = "%s / %s" % [General.format_time(start_pos),  General.format_time($song.stream.get_length())]

			set_discord_rpc()
			
			
			if total_valid_notes < 250:
				total_points = 25000.0
			elif total_valid_notes < 450:
				total_points = 50000.0
			elif total_valid_notes < 800:
				total_points = 75000.0
			elif total_valid_notes < 1150:
				total_points = 100000.0
			elif total_valid_notes < 1800:
				total_points = 175000.0
			elif total_valid_notes < 2500:
				total_points = 250000.0
			elif total_valid_notes < 3750:
				total_points = 500000.0
			elif total_valid_notes < 5000:
				total_points = 750000.0
			elif total_valid_notes < 6000:
				total_points = 1000000.0
			elif total_valid_notes < 7250:
				total_points = 2500000.0
			elif total_valid_notes < 8500:
				total_points = 5000000.0
			else:
				total_points = 10000000.0
			
			tier1_end = int(total_valid_notes * tier1_percentage)
			tier2_end = int(total_valid_notes * tier2_percentage)
			tier3_end = int(total_valid_notes * tier3_percentage)
			
			var expected := 0.0
			for i in range(total_valid_notes):
				var streak_index = i + 1
				expected += get_precalc_combo_multiplier_for_streak(streak_index)
			
			print("expect ", expected)
			
			points_per_note = float(total_points) / expected if total_valid_notes > 0 else 0.0
			print("%d total points and %.2f per note" % [total_points, points_per_note])
		
			print("Init as recording")
			await get_tree().process_frame
			$end_screen_anims.stop(true)
			$end_screen_anims.play("init_record")
			
			start_recording()
			
			spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Song"), 0) as AudioEffectSpectrumAnalyzerInstance
			return
	else:
		print("somehow no song, song: ", song, " | stringified song: ", str(song))
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
	
	if customNotes[0].timestamp > 5000.0:
		$end_screen_anims.stop()
		$end_screen_anims.play("fade_out")
	await get_tree().create_timer(1.2).timeout
	
	var earliest_negative = null

	for n in customNotes:
		if n.timestamp < 0.0:
			if earliest_negative == null or n.timestamp < earliest_negative:
				earliest_negative = n.timestamp

	if earliest_negative != null:
		start_wait = abs(earliest_negative)
		print("start wait ", start_wait)
	
	if customNotes.size() > 0 and _has_valid_notes(customNotes):
		print("Using notes in chart")
		_process_custom_notes(customNotes)
		gameStarted = true
		screen = "game"
		gamePaused = false
		song_start_time = int(Time.get_unix_time_from_system())

		total_valid_notes = customNotes.filter(func(n):
			return n.has("type") and n.has("timestamp") and n["type"] != "Effect"
		).size()

	else:
		print("Random notes since chart file doesn't contain valid notes or it doesn't exist")
		beattime = 60.0 / BPM
		gameStarted = true
		gamePaused = false
		screen = "game"
		song_start_time = int(Time.get_unix_time_from_system())
		
		# Once generated, count them as valid notes
		print_rich("[color=green]Getting generated random notes: ", total_valid_notes, "[/color]")
		total_valid_notes = generateNotes()
		print_rich("[color=green]Generated random notes: ", total_valid_notes, "[/color]")
	
	$UI/start_chart_info.text = "[i]" + str(total_valid_notes) + " Notes / " + str(BPM) + " BPM[/i]"
	var chart_t = create_tween()
	chart_t.tween_property($UI/start_chart_info, "self_modulate", Color.WHITE, 0.336)
	
	
	set_discord_rpc()
	
	
	if total_valid_notes < 250:
		total_points = 25000.0
	elif total_valid_notes < 450:
		total_points = 50000.0
	elif total_valid_notes < 800:
		total_points = 75000.0
	elif total_valid_notes < 1150:
		total_points = 100000.0
	elif total_valid_notes < 1800:
		total_points = 175000.0
	elif total_valid_notes < 2500:
		total_points = 250000.0
	elif total_valid_notes < 3750:
		total_points = 500000.0
	elif total_valid_notes < 5000:
		total_points = 750000.0
	elif total_valid_notes < 6000:
		total_points = 1000000.0
	elif total_valid_notes < 7250:
		total_points = 2500000.0
	elif total_valid_notes < 8500:
		total_points = 5000000.0
	else:
		total_points = 10000000.0
	
	tier1_end = int(total_valid_notes * tier1_percentage)
	tier2_end = int(total_valid_notes * tier2_percentage)
	tier3_end = int(total_valid_notes * tier3_percentage)
	
	var raw_expected_score := 0.0
	for i in range(total_valid_notes):
		var streak_index = i + 1
		raw_expected_score += get_precalc_combo_multiplier_for_streak(streak_index)
	
	print("expect ", raw_expected_score)
	
	points_per_note = float(total_points) / raw_expected_score if total_valid_notes > 0 else 0.0
	print("%d total points and %.2f per note" % [total_points, points_per_note])
	
	$song.pitch_scale = playback_speed
	
	$Visualizer/Song_left.pitch_scale = playback_speed
	$Visualizer/Song_right.pitch_scale = playback_speed
	
	$VideoPlayback.playback_speed = playback_speed
	
	if start_wait > 0:
		print("Waiting ", (start_wait + 500) / 1000.0)
		await get_tree().create_timer((start_wait + 500) / 1000.0).timeout
		print("Waited")
		$song.play(start_pos)

		$Visualizer/Song_left.play(start_pos)
		$Visualizer/Song_right.play(start_pos)
		
		if start_pos > 0.0: play_vid(start_pos)
		else: play_vid(-1)
		
		beat()
	else:
		print("No waiting")
		
		$song.play(start_pos)

		$Visualizer/Song_left.play(start_pos)
		$Visualizer/Song_right.play(start_pos)
		
		if start_pos > 0.0: play_vid(start_pos)
		else: play_vid(-1)
		beat()
	
	var prog_t := create_tween()
	prog_t.tween_property(song_progress, "value", (start_pos * 1000.0 / len_ms) * 100.0, 0.44).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Song"), 0) as AudioEffectSpectrumAnalyzerInstance

		

var tier1_end: int
var tier2_end: int
var tier3_end: int

var tier1_percentage: float = 0.075
var tier2_percentage: float = 0.15
var tier3_percentage: float = 0.30

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_close_requested()
	
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()

func handle_back():
	if screen == "unpausing":
		screen = "pause"
		_on_pause()
		return

	if gamePaused == false and screen != "end" and screen != "settings":
		_on_pause()
	elif gamePaused == true and screen != "end" and screen != "settings":
		_on_unpause()
	elif screen == "settings":
		$pause.play("from_stgs_to_pause", 0.15)

func update_pulse_animation_scale(ani: AnimationPlayer, key: String):
	if Settings.misc.note_style != "circles":
		return

	var anim_name = key.to_lower() + "_pulse"
	var anim: Animation = ani.get_animation(anim_name)
	if anim == null:
		return
	
	# find the scale track
	var track := -1
	for i in anim.get_track_count():
		var path = anim.track_get_path(i)
		var type = anim.track_get_type(i)
		if type == Animation.TYPE_VALUE and str(path).ends_with(":scale"):
			track = i
			break
	
	if track == -1:
		return

	# calculate scaled sizes
	var size: float = Settings.circles.get("size", 1.0)
	var key0_scale := Vector2(0.75 * size, 0.75 * size)
	var key1_scale := Vector2(0.65 * size, 0.65 * size)

	# ensure the track has at least 2 keyframes
	if anim.track_get_key_count(track) >= 2:
		anim.track_set_key_value(track, 0, key0_scale)
		anim.track_set_key_value(track, 1, key1_scale)

var active_recorded_holds := {} 
# action -> {
# 	"start_time": int,
# 	"note_index": int
# }

func _process(delta):
	for action in note_data.keys():
		var key = note_data[action]["key"]
		var sprite_path = note_data[action]["sprite"]
		var press_texture = note_data[action]["press"]
		var idle_texture = note_data[action]["idle"]
		
		if Input.is_action_just_pressed(action): # Register hit only the frame the input was hit
			highlightedNotes[key] = true
			
			registerHit(key)
			
			if key in ["Upleft", "Downleft", "Left", "Down", "Up", "Right", "Downright", "Upright"] and Settings.misc.note_anims:
				var ani: AnimationPlayer = get_node("stationary_notes/note_" + key.to_lower())
				
				# update animation scale if using circles
				update_pulse_animation_scale(ani, key)
				
				ani.play("RESET")
				ani.play(key.to_lower() + "_pulse")
			
		if Input.is_action_just_released(action):
			highlightedNotes[key] = false
			
		
		var sprite_node = $stationary_notes.get_node(sprite_path)

		# Circle note mode (color-only)
		if Settings.misc.note_style == "circles":
			var base_col = Settings.parse_any_color(Settings.circles.get(key, "ffffff"))
			var press_col

			# pressed color logic
			if Settings.circles.get("pressed_uses_idle_colors", false):
				press_col = base_col
			else:
				press_col = Settings.parse_any_color(Settings.circles.get(key + "Press", base_col))

			# Holding the key → use press color
			if Input.is_action_pressed(action):
				sprite_node.texture = load("res://Resources/Arrows/" + press_texture)
				sprite_node.self_modulate = press_col
			else:
				sprite_node.texture = load("res://Resources/Arrows/" + idle_texture)
				sprite_node.self_modulate = base_col
		else:
			# Holding the key → use press color
			if Input.is_action_pressed(action):
				sprite_node.texture = load("res://Resources/Arrows/" + press_texture)
				sprite_node.self_modulate = Color.WHITE
			else:
				sprite_node.texture = load("res://Resources/Arrows/" + idle_texture)
				sprite_node.self_modulate = Color.WHITE
				

		
		if Input.is_action_just_pressed("record"):
			if not recording and screen!= "end" and not gamePaused:
				print("recording start")
				$end_screen_anims.play("start_rec")
				start_recording()
				
		if Input.is_action_just_pressed("record_stop"):
			if recording:
				print("Recording stopped")
				#print(recorded_notes)
				$end_screen_anims.play("stop_rec")
				
				$record_btn.text = "Start Recording"
				
				notes_hit_lbl.text = "Notes Hit: %d" % notesHit
				
				_on_reset_song_btn_up(true)
				recording = false
	
	if recording and not gamePaused:
		for action in note_data.keys():
			var key = note_data[action]["key"]

			if Input.is_action_just_pressed(action):
				var current_time := Time.get_ticks_msec() - recording_start_time
				var note_index := recorded_notes.size()

				recorded_notes.append({
					"type": key,
					"timestamp": current_time - Beatz.BASE_REC_TIME_MS,
					"id": General.generate_note_id()
				})

				var note_node = spawn_note(key, true)
				note_node.is_recording_hold = true

				active_recorded_holds[action] = {
					"start_time": Time.get_ticks_msec(),
					"note_index": note_index,
					"note_node": note_node,
					"visual_started": false
				}
				
				notes_hit_lbl.text = "Notes Recorded: %d" % recorded_notes.size()

			elif Input.is_action_just_released(action):
				if not active_recorded_holds.has(action):
					continue

				var hold_data = active_recorded_holds[action]
				active_recorded_holds.erase(action)

				var held_ms: int = Time.get_ticks_msec() - hold_data.start_time

				var rec_note = hold_data.note_node
				if rec_note:
					rec_note.is_recording_hold = false

				if held_ms >= 150:
					recorded_notes[hold_data.note_index]["hold"] = held_ms

			if Input.is_action_pressed(action):
				if not active_recorded_holds.has(action):
					continue

				var hold_data = active_recorded_holds[action]
				var held_ms: int = Time.get_ticks_msec() - hold_data.start_time

				if held_ms < 150:
					continue

				var rec_note = hold_data.note_node
				if not rec_note:
					continue

				# First frame after crossing 150ms, catch up visually
				if not hold_data.visual_started:
					var catchup_pixels := Beatz.time_to_y(240)
					rec_note.create_hold_visual(catchup_pixels)
					hold_data.visual_started = true

				# Normal per-frame growth
				var pixels: float = 100.0 * noteSpeed * $song.pitch_scale * delta * Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER
				rec_note.create_hold_visual(pixels)

	
	# Keep other control inputs here
	if Input.is_action_just_pressed("autoHit") and not gamePaused and not recording:
		if not auto_hit_used: auto_hit_used = true
		auto_hit = !auto_hit
		if auto_hit: $UI/auto_hit_lbl.show()
		else: $UI/auto_hit_lbl.hide()
	
	if Input.is_action_just_pressed("ui_cancel"):
		handle_back()
	
	if Input.is_action_just_pressed("controller-pause"):
		if screen != "settings" or screen != "end" and not gamePaused:
			_on_pause()
		elif gamePaused and screen != "settings":
			_on_unpause()
		elif screen == "settings":
			$pause.play("from_pause_to_stgs")
	
	if Input.is_action_just_pressed("controller-back"):
		if screen == "settings":
			$pause.play("from_stgs_to_pause")
	
	if Input.is_action_just_pressed("fast_restart"):
		if !gamePaused: _on_reset_song_btn_up(true)
		elif gamePaused: _on_reset_song_btn_up()
	
	if Input.is_action_just_pressed("debug-end-main"):
		if !gamePaused and not recording:
			print("debug song finished anim play")
			_on_song_finished(true)
	
	# Move all children of the 'notes' node 
	# Skip movement and auto-hit while paused
	for n in %notes.get_children():
		if gamePaused:
			continue
		
		if check_fade(n, true, false) == "hit": # If the note is faded, don't move the note
			continue
		
		# If the note exists but it is great faded, slow the note down to 1/3 of the note speed
		if check_fade(n, false, true) == "great": n.global_position.y += 100.0 * noteSpeed * $song.pitch_scale * (delta) / 3.0
		else: n.global_position.y += 100.0 * noteSpeed * $song.pitch_scale * (delta)
		
		if n.global_position.y > $stationary_notes/lines/linemiss.global_position.y:
			if n.is_recording_hold: continue
			miss_note(n)
		
		if auto_hit && n.global_position.y > $stationary_notes/lines/linemiddle.global_position.y && !n.rec:
			if check_fade(n): # If the note exists but it is faded or great faded, dont register a hit
				continue
			
			highlightedNotes[n.type] = true
			registerHit(n.type)
			
			if n.type in ["Left", "Down", "Up", "Right"] and Settings.misc.note_anims and not recording:
				var ani: AnimationPlayer = get_node("stationary_notes/note_" + n.type.to_lower())
				
				# update animation scale if using circles
				update_pulse_animation_scale(ani, n.type.to_lower())
				
				ani.play("RESET")
				ani.play(n.type.to_lower() + "_pulse")
	
	for n in active_holds.keys():
		if not n: continue
		var data = active_holds[n]

		# must be holding the key
		if highlightedNotes[n.type] == false or gamePaused:
			#print("not holding ", n.type, " ", n)
			end_hold(n)
			continue

		# accumulate time
		data.total_held_ms += delta * 1000.0
		
		# update hold tail
		var tail_pixels = 100.0 * noteSpeed * $song.pitch_scale * delta * Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER
		n.update_hold_visual(tail_pixels)
		
		var expected_ticks = int(floor(data.total_held_ms / data.tick_interval))
		
		while data.ticks_given < expected_ticks and data.ticks_given < data.tick_count:
			data.ticks_given += 1

			# award tick points
			points += data.tick_value
			points_lbl.text = "Points: " + General.format_number_with_commas(roundf(points))
			points_awarded.text = str(int(data.tick_value * data.ticks_given))

			# if finished all ticks
			if data.ticks_given >= data.tick_count:
				end_hold(n)
				break
	
	for b in %beatlines.get_children():
		if gamePaused:
			continue
		
		b.global_position.y += 100.0 * noteSpeed * $song.pitch_scale * (delta)
		
		if b.global_position.y > $stationary_notes/lines/linemiss.global_position.y: b.queue_free()
	
	if not gamePaused and not songEnded and $song.get_playback_position() > 0: 
		song_progress_lbl.text = General.format_time($song.get_playback_position()) + " / " + General.format_time($song.stream.get_length())
		song_progress.value = (pos_ms / len_ms) * 100.0
	
	if spectrum and Settings.misc.menu_bg_pulse:
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
		var base_scale : float = 1.0
		#var max_title : float = 1.5
		#var max_cover : float = 1.4
		var max_bg : float = 1.3
		#var max_cam : float = 1.03
		
		# Interpolated targets
		var bg_target = lerp(base_scale, max_bg, exp_bg)
		#var cam_target = lerp(base_scale, max_cam, exp_overall)
		
		# Smooth transitions
		#$Title.scale = lerp($Title.scale, Vector2.ONE * title_target, 13.0 * delta)
		#$Artist.scale = lerp($Title.scale, Vector2.ONE * title_target, 10.0 * delta)
		#$vis_anim.scale = lerp($vis_anim.scale, Vector2(2.6,2.6) * cover_target, 15.0 * delta)
		#$cover_anim.scale = lerp($cover_anim.scale, Vector2.ONE * cover_target, 20.0 * delta)
		
		#$Camera.zoom = lerp($Camera.zoom, Vector2.ONE * cam_target, 16.0 * delta)
		
		$Background.scale = lerp($Background.scale, Vector2.ONE * bg_target, Settings.misc.menu_bg_pulse_strength * delta)
		if Settings.misc.bg_vid_pulse: $VideoPlayback.scale = lerp($VideoPlayback.scale, Vector2.ONE * bg_target, Settings.misc.bg_vid_pulse_strength * delta)
		$TransitionRect.scale = lerp($TransitionRect.scale, Vector2.ONE * bg_target, Settings.misc.menu_bg_pulse_strength * delta)
		$ActualTransitionRect.scale = lerp($ActualTransitionRect.scale, Vector2.ONE * bg_target, Settings.misc.menu_bg_pulse_strength * delta)
	
	var alignment_x: float
	if Settings.other.show_chart_alignment: 
		alignment_x = get_chart_alignment()
		$stationary_notes/chart_current_avrg_center.position.x = lerp(
			$stationary_notes/chart_current_avrg_center.position.x,
			alignment_x,
			10.0 * delta
		)
	
	var alignment_x_total: float
	if Settings.other.show_chart_alignment: 
		if not $stationary_notes/chart_avrg_center.visible: 
			$stationary_notes/chart_avrg_center.show()
			$stationary_notes/chart_current_avrg_center.show()
			$stationary_notes/chart_avrg_center.modulate = Color.WHITE
			$stationary_notes/chart_current_avrg_center.modulate = Color.WHITE
		
		alignment_x_total = get_chart_alignment(true)
		$stationary_notes/chart_avrg_center.position.x = lerp(
			$stationary_notes/chart_avrg_center.position.x,
			alignment_x_total,
			10.0 * delta
		)
	else:
		if $stationary_notes/chart_avrg_center.visible: 
			$stationary_notes/chart_avrg_center.hide()
			$stationary_notes/chart_current_avrg_center.hide()

func get_chart_alignment(all: bool = false) -> float:
	if not Settings.other.show_chart_alignment: return 960.0
	
	var now := Time.get_ticks_msec()

	var total_x := 0.0
	var count := 0

	for n in %notes.get_children():
		if gamePaused:
			continue
		
		# if recently spawned, ignore it until 1.08s have passed
		if not all and now - n.spawned_at < (Beatz.BASE_REC_TIME_MS * 0.9):
			continue
		
		# skip faded notes
		if check_fade(n, true, false) == "hit":
			continue

		var lane_x := 0.0
		match n.type:
			"Upleft": lane_x = $stationary_notes/noteUpleftSprite.position.x
			"Downleft": lane_x = $stationary_notes/noteDownleftSprite.position.x
			"Left": lane_x = $stationary_notes/noteLeftSprite.position.x
			"Down": lane_x = $stationary_notes/noteDownSprite.position.x
			"Up": lane_x = $stationary_notes/noteUpSprite.position.x
			"Right": lane_x = $stationary_notes/noteRightSprite.position.x
			"Downright": lane_x = $stationary_notes/noteDownrightSprite.position.x
			"Upright": lane_x = $stationary_notes/noteUprightSprite.position.x

		total_x += lane_x
		count += 1

	if count == 0:
		return 960.0

	return total_x / count

func end_hold(n):
	if not n: return
	
	active_holds.erase(n)
	
	var delete_hold = func(holdn):
		if holdn: holdn.queue_free()
	
	inc_dec_hp(hp + 0.625)
	var holdbar2d: Line2D = n.get_node("HoldBar2D")
	var holdbar: ColorRect = n.get_node("HoldBar")
	if Settings.misc.note_anims:
		if holdbar2d != null:
			holdbar2d.points[1].y = 15.0
			holdbar2d.points[2].y = 25.0
			var t = create_tween()
			t.tween_property(holdbar2d, "modulate", Color.TRANSPARENT, 0.2)
			if holdbar != null: t.parallel().tween_property(n.get_node("HoldBar"), "modulate", Color.TRANSPARENT, 0.2)
			t.parallel().tween_property(holdbar2d, "scale", Vector2.ZERO, 0.2)
	else:
		delete_hold.call(n)
	
	hp_gained.text = str(0.625)
	
	var hold_to_anim_with_particle: GPUParticles2D = get_node("stationary_notes/note" + n.type + "Sprite/hold_particles")
	if hold_to_anim_with_particle: hold_to_anim_with_particle.emitting = false

func check_fade(n: Node2D, hit: bool = true, great: bool = true) -> String: # Add the note, and specify what type of fade it should check for
	if !n.has_method("hit"): 
		print("not a note, or it doesn't exist, ", n)
		return ""
	if n.faded and hit: # If note is faded, it means it was hit in the perfect, insane or exact zone
		return "hit"
	if n.faded_great and great: # If the note is great faded, it means the note was not hit in the perfect, insane or exact zone
		return "great"
	else:
		return ""

func inc_dec_hp(new_hp: float) -> void:
	if songEnded: 
		return
	var change = clampf(new_hp, 0.0, 100.0)
	var hp_change := create_tween()
	hp_change.tween_property($notes_backdrop/hp, "value", change, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	hp = change
	
	if hp <= 0.0:
		die()

func die():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("died")
	$pause.play("die")
	screen = "die"
	var song_die := create_tween()
	song_die.tween_property($song, "pitch_scale", 0.0, 0.85)
	song_die.parallel().tween_property($Visualizer/Song_left, "pitch_scale", 0.0, 0.85)
	song_die.parallel().tween_property($Visualizer/Song_right, "pitch_scale", 0.0, 0.85)
	song_die.parallel().tween_property($VideoPlayback, "playback_speed", 0.0, 0.85)
	await get_tree().create_timer(2).timeout
	$song.stop()
	$Visualizer/Song_left.stop()
	$Visualizer/Song_right.stop()
	$VideoPlayback.pause()

func miss_note(n) -> void:
	if check_fade(n):
		return
	if n.rec:
		n.queue_free()
		return
	if n.type == "Effect":
		print(n)
		n.queue_free()
		return
	if n.hold_ms > 0 and n in active_holds:
		active_holds.erase(n)
	if streak != 0 or notesHit == 0 and misses == 0:
		$main_anims.stop()
		$main_anims.play("missed_hit_text")
	n.queue_free()
	streak = 0
	#mult_streak /= 2
	reduce_multiplier_one_tier()
	misses += 1
	inc_dec_hp(hp - hp_loss / 2)
	hp_gained.text = str(-hp_loss / 2)
	points_lbl.text = "Points: " + General.format_number_with_commas(roundf(points))
	stat_missed.text = "Misses: " + str(misses)
	streak_lbl.text = str(streak)
	points_awarded.text = str(-points_per_note).pad_decimals(0)

var generating_notes := false
var generated_notes: Array = []
var generate_task = null

func generateNotes() -> int:
	if not gameStarted or gamePaused or generating_notes:
		return 0
	
	generating_notes = true
	set_note_spawn_y()
	
	var dur = $song.stream.get_length()
	var number_of_notes = snappedf(dur / beattime, 1)
	#number_of_notes *= 2
	print("Song Duration: ", dur, " seconds")
	print("Number of notes: ", number_of_notes)
	
	const directions: Array[Variant] = ["Up", "Down", "Left", "Right"]
	generated_notes.clear()
	
	# --- generate note data instantly ---
	for n in range(number_of_notes):
		var dir = directions.pick_random()
		var timestamp = n * beattime
		generated_notes.append({ "time": timestamp, "dir": dir })
	
	if not init_recording: from_generated_start()
	
	generating_notes = false
	print("Generated ", generated_notes.size(), " notes")
	return generated_notes.size()

func from_generated_start():
	for note_meta in generated_notes:
		await get_tree().create_timer(beattime).timeout
		spawn_note(note_meta["dir"])

func clear_generated_notes() -> void:
	if generating_notes:
		print("Stopping running note generator...")
		generating_notes = false
		await get_tree().process_frame  # Let any active loop yield finish

	generated_notes.clear()

func spawn_note(direction: String = "Up", rec: bool = false, hold: float = -1.0, time = -1.0):
	if screen == "end" or screen == "die": return
	if gamePaused: return
	if not gameStarted: return
	var new_note = note.instantiate()
	var x: float = 0.0
	match direction:
		"Upleft": x = $stationary_notes/noteUpleftSprite.position.x
		"Downleft": x = $stationary_notes/noteDownleftSprite.position.x
		"Left": x = $stationary_notes/noteLeftSprite.position.x
		"Down": x = $stationary_notes/noteDownSprite.position.x
		"Up": x = $stationary_notes/noteUpSprite.position.x
		"Right": x = $stationary_notes/noteRightSprite.global_position.x
		"Downright": x = $stationary_notes/noteDownrightSprite.position.x
		"Upright": x = $stationary_notes/noteUprightSprite.position.x
		"Effect":
			print("Effect notes not yet suppported")
			return
		_: 
			print("Unknown / Unsupported note type: ", direction)
			x = $stationary_notes/noteUpSprite.global_position.x
	new_note.position = Vector2(x, noteSpawnY)
	new_note.scale = Vector2(0.65, 0.65)
	
	if hold > 0.0:
		new_note.hold_ms = hold
	
	new_note.timestamp = time
	new_note.spawned_at = Time.get_ticks_msec()
	
	new_note.set_type(direction)
	
	if rec:
		new_note.rec = true
		new_note.position.y = -600
		new_note.modulate = Color(1.0, 1.0, 1.0, 0.95)
	elif not rec and Settings.misc.note_anims:
		new_note.modulate = Color.TRANSPARENT
		var spawn_t = create_tween()
		spawn_t.tween_property(new_note, "modulate", Color.WHITE, 0.1)
	
	%notes.add_child(new_note)
	
	return new_note

func spawn_beatline():
	if screen == "end" or screen == "die": return
	if gamePaused: return
	if not gameStarted: return
	
	var beatline = preload("res://Scenes/beat_line.tscn").instantiate()
	
	beatline.position = Vector2(950, noteSpawnY)
	
	%beatlines.add_child(beatline)

var recorded_notes := []  # Array to store recorded notes as dictionaries
var recording := false
var recording_start_time := 0.0

func start_recording():
	await clear_generated_notes()
	
	# Stop song if playing
	$song.stop()
	$Visualizer/Song_left.stop()
	$Visualizer/Song_right.stop()
	
	# Clear existing notes
	var delay := 0.001
	for n in %notes.get_children():
		n.faded = true
		call_deferred("stagger", n, delay)
		delay += 0.01
	
	# Stop and clear note timers
	for child in $UI/noteTimeouts.get_children():
		if child is Timer:
			child.stop()
			child.queue_free()
	
	# Reset counters
	points = 0
	streak = 0
	maxStreak = 0
	misses = 0
	exactHits = 0
	insanes = 0
	perfects = 0
	earlys = 0
	lates = 0
	notesHit = 0
	
	editor_saved = false
	
	points_lbl.text = "Points: 0"
	stat_exacts.text = "EXACTS: 0"
	stat_insanes.text = "INSANES: 0"
	stat_perfects.text = "Perfects: 0"
	stat_earlys.text = "Earlys: 0"
	stat_lates.text = "Lates: 0"
	stat_missed.text = "Misses: 0"
	streak_lbl.text = "0"
	max_streak_lbl.text = "0"
	
	notes_hit_lbl.text = "Notes Recorded: 0"
	
	$record_btn.text = "Stop Recording"
	
	# Reset state
	gamePaused = false
	screen = "game"
	gameStarted = true
	
	# Clear recorded notes
	recorded_notes.clear()
	
	# Start song
	$song.play()
	$Visualizer/Song_left.play()
	$Visualizer/Song_right.play()
	beat()
	
	play_vid(0.0)
	
	# Start recording
	recording = true
	recording_start_time = Time.get_ticks_msec()
	print("Recording started")
	
	set_discord_rpc()

func play_vid(time: float) -> void:
	if not $VideoPlayback.is_open():
		return
	
	if time >= 0.0:
		var fps = $VideoPlayback.get_video_framerate()
		var target_frame = int(time * fps)
		var total_frames = $VideoPlayback.get_video_frame_count()
		target_frame = clampi(target_frame, 0, total_frames - 1)
		
		print(target_frame, " out of ", total_frames)
		$VideoPlayback.seek_frame(target_frame)
	
	$VideoPlayback.play()

func pause_vid() -> void:
	if not $VideoPlayback.is_open():
		return
	$VideoPlayback.pause()

var nps := 0

func nps_wait():
	await get_tree().create_timer(1.0).timeout
	nps -= 1
	nps_lbl.text = "NPS: " + str(nps)

var kps := 0

func kps_wait():
	await get_tree().create_timer(1.0).timeout
	kps -= 1
	kps_lbl.text = "KPS: " + str(kps)

func update_multiplier_particles(mult_value: float) -> void:
	if songEnded: return
	
	# grab nodes
	var p4_spark := $notes_backdrop/multiplier/sparkles_4x
	var p4_lava  := $notes_backdrop/multiplier/lavalookingparticle_4x
	
	var p8_spark := $notes_backdrop/multiplier/sparkles_8x
	var p8_lava  := $notes_backdrop/multiplier/lavalookingparticle_8x

	# Helper: fade out one particle group
	var fade_out = func(p):
		#if p.emitting:
			#var t := create_tween()
			#t.tween_property(p, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			#await t.finished
		p.emitting = false

	# Helper: fade in one particle group
	var fade_in = func(p):
		if not p.emitting:
			p.modulate = Color.TRANSPARENT
			p.emitting = true
			
			var t := create_tween()
			t.tween_property(p, "modulate", Color.WHITE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# FIRST fade out all particles that shouldn't be active
	if mult_value < 4.0:
		fade_out.call(p4_spark)
		fade_out.call(p4_lava)
		fade_out.call(p8_spark)
		fade_out.call(p8_lava)
		return

	if mult_value < 8.0:
		fade_out.call(p8_spark)
		fade_out.call(p8_lava)

	if mult_value >= 8.0:
		fade_out.call(p4_spark)
		fade_out.call(p4_lava)

	# THEN fade in the correct tier
	if mult_value >= 8.0:
		fade_in.call(p8_spark)
		fade_in.call(p8_lava)
	elif mult_value >= 4.0:
		fade_in.call(p4_spark)
		fade_in.call(p4_lava)

func update_multiplier_bar() -> void:
	var start := 0.0
	var end := 1.0
	
	if mult_streak <= tier1_end:
		start = 0.0
		end = tier1_end
	elif mult_streak <= tier2_end:
		start = tier1_end
		end = tier2_end
	elif mult_streak <= tier3_end:
		start = tier2_end
		end = tier3_end
	else:
		start = tier3_end
		end = total_valid_notes  # 8x zone
	
	var progress := float(mult_streak - start) / float(end - start) if mult_streak <= tier3_end else float(notesHit - start) / float(end - start)
	progress = clamp(progress, 0.0, 1.0)
	
	var mult_change := create_tween()
	mult_change.tween_property($notes_backdrop/multiplier, "value", progress, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func get_combo_multiplier_for_streak() -> float:
	update_multiplier_bar()

	var mult := 1.0

	if mult_streak <= tier1_end:
		mult = 1.0
	elif mult_streak <= tier2_end:
		mult = 2.0
	elif mult_streak <= tier3_end:
		mult = 4.0
	else:
		mult = 8.0

	score_mult.text = str(mult as int) + "x"

	update_multiplier_particles(mult)

	return mult

func get_precalc_combo_multiplier_for_streak(expected: int) -> float:
	if expected <= tier1_end:
		return 1.0
	elif expected <= tier2_end:
		return 2.0
	elif expected <= tier3_end:
		return 4.0
	else:
		return 8.0

var mult_streak: int = 0

func reduce_multiplier_one_tier():
	var current_mult := get_combo_multiplier_for_streak()
	
	if current_mult == 8.0:
		mult_streak = int((tier3_end + tier2_end) / 1.75)
	elif current_mult == 4.0:
		mult_streak = int((tier2_end + tier1_end) / 1.75)
	elif current_mult == 2.0:
		mult_streak = int(tier1_end / 1.25)
	else:
		mult_streak = int(mult_streak / 2.0)

	update_multiplier_bar()
	get_combo_multiplier_for_streak()    # << updates particles + UI

func registerHit(type) -> void:
	if gamePaused:
		print("Game is paused why are you trying to hit a note")
		return
	
	if screen == "die":
		print("Bro is dead")
		return
	
	var amount: int = int(12.0 * (noteSpeed / 14.0))
	if $stationary_notes/noteLeftSprite/hold_particles.amount != amount:
		for h_particle: GPUParticles2D in [$stationary_notes/noteUpleftSprite/hold_particles, $stationary_notes/noteDownleftSprite/hold_particles, $stationary_notes/noteLeftSprite/hold_particles, $stationary_notes/noteDownSprite/hold_particles, $stationary_notes/noteUpSprite/hold_particles, $stationary_notes/noteRightSprite/hold_particles, $stationary_notes/noteDownrightSprite/hold_particles, $stationary_notes/noteUprightSprite/hold_particles]:
			h_particle.amount = amount
		
		for particle: GPUParticles2D in [$stationary_notes/noteUpleftSprite/hit_particles, $stationary_notes/noteDownleftSprite/hit_particles, $stationary_notes/noteLeftSprite/hit_particles, $stationary_notes/noteDownSprite/hit_particles, $stationary_notes/noteUpSprite/hit_particles, $stationary_notes/noteRightSprite/hit_particles, $stationary_notes/noteDownrightSprite/hit_particles, $stationary_notes/noteUprightSprite/hit_particles]:
			particle.amount = amount
		
	var hit_note := false
	var hold_note_hit: bool = false
	
	kps += 1
	kps_lbl.text = "KPS: " + str(kps)
	call_deferred("kps_wait")
	
	if notesHit == total_valid_notes and misses == 0 and earlys == 0 and lates == 0:
		points = total_points
	
	var gained: float = -1.0
	
	var note_to_anim_with_particle: GPUParticles2D = get_node("stationary_notes/note" + type + "Sprite/hit_particles")
	if note_to_anim_with_particle: 
		note_to_anim_with_particle.z_index = -1
		note_to_anim_with_particle.modulate.a = 0.1
	
	var add_points := 0.0
	
	for n in %notes.get_children():
		if n.type != type or check_fade(n) or n.rec:
			continue
		
		$hit.stop()
		if Settings.game.sfx_vol != 0: $hit.play(0.02)
		
		#var old_hold_y = n.get_node("note_hold_end").global_position.y
		var old_hold_bar_y = n.get_node("HoldBar2D")
		old_hold_bar_y = old_hold_bar_y.global_position.y if old_hold_bar_y else $stationary_notes/lines/linemiddle.global_position.y
		var y = n.global_position.y
		var hit_window_top = $stationary_notes/lines/linegreat1.global_position.y
		var hit_window_bottom = $stationary_notes/lines/linegreat2.global_position.y
		
		var HIT_AT = Time.get_ticks_msec() - n.spawned_at - 1.0
		var OFFSET_FROM_SPAWN = (HIT_AT - Beatz.BASE_REC_TIME_MS) * -1.0 * playback_speed
		if OFFSET_FROM_SPAWN < great_window_ms:
			$UI/hit_at_lbl.text = "+" + str(OFFSET_FROM_SPAWN) + "ms" if OFFSET_FROM_SPAWN > 0.0 else "" + str(OFFSET_FROM_SPAWN) + "ms"
			$UI/precision_line.hit(HIT_AT - Beatz.BASE_REC_TIME_MS / playback_speed, great_window_ms)
		
		var hold_mult: float = 1.0
		
		#if n.hold_ms < 500: hold_mult = 0.935
		#elif n.hold_ms < 1000: hold_mult = 0.95
		#elif n.hold_ms < 1500: hold_mult = 0.96
		#elif n.hold_ms < 2000: hold_mult = 0.975
		#elif n.hold_ms < 2500: hold_mult = 0.995
		#elif n.hold_ms < 3000: hold_mult = 0.998
		#elif n.hold_ms < 4000: hold_mult = 0.999
		#elif n.hold_ms > 4000: hold_mult = 1.0
		
		if y >= hit_window_top and y <= hit_window_bottom:
			if highlightedNotes[n.type] == true:
				$main_anims.stop(true)
				streak += 1
				mult_streak += 1

				if streak > maxStreak:
					maxStreak = streak
				
				if y >= $stationary_notes/lines/lineexact1.global_position.y and y <= $stationary_notes/lines/lineexact2.global_position.y:
					hit_note = true
					n.hit()
					
					add_points = points_per_note
					exactHits += 1
					
					gained = 1.25
					
					#n.get_node("note_hold_end").global_position.y = old_hold_y
					var old_note_global_y = n.global_position.y
					
					n.global_position.y = $stationary_notes/lines/linemiddle.global_position.y
					
					var parent_delta_y = n.global_position.y - old_note_global_y
					
					if Settings.misc.hold_bar_keep_position:
						n.get_node("HoldBar2D").global_position.y = old_hold_bar_y
						n.get_node("HoldBar").global_position.y = old_hold_bar_y
					else:
						var hold_bar := n.get_node("HoldBar2D")
						hold_bar.points[1].y += parent_delta_y
						hold_bar.points[2].y += parent_delta_y
					
					$main_anims.play("exact_hit_text")
					
					if n.hold_ms > 0:
						var hold = n.hold_ms * hold_mult
						hold_note_hit = true
						var tick_count = int(ceil(hold / 500.0) * 8)
						var tick_interval = hold / tick_count
						var tick_value = (add_points * get_combo_multiplier_for_streak()) / tick_count

						active_holds[n] = {
							"tick_count": tick_count,
							"tick_value": tick_value,
							"tick_interval": tick_interval,
							"total_held_ms": 0.0,
							"ticks_given": 0
						}


						# do NOT queue_free(), hold notes stay until tail finishes
						if Settings.misc.note_particle_fx > 0:
							var hold_to_anim_with_particle: GPUParticles2D = get_node("stationary_notes/note" + type + "Sprite/hold_particles")
							if hold_to_anim_with_particle: 
								hold_to_anim_with_particle.emitting = true
								hold_to_anim_with_particle.modulate.a = 0.9
					break
				
				elif y >= $stationary_notes/lines/lineinsane1.global_position.y and y <= $stationary_notes/lines/lineinsane2.global_position.y:
					hit_note = true
					n.hit()
					
					add_points = points_per_note
					insanes += 1
					
					gained = 0.75
					
					#n.get_node("note_hold_end").global_position.y = old_hold_y
					var old_note_global_y = n.global_position.y
					
					n.global_position.y = $stationary_notes/lines/linemiddle.global_position.y
					
					var parent_delta_y = n.global_position.y - old_note_global_y
					
					if Settings.misc.hold_bar_keep_position:
						n.get_node("HoldBar2D").global_position.y = old_hold_bar_y
						n.get_node("HoldBar").global_position.y = old_hold_bar_y
					else:
						var hold_bar := n.get_node("HoldBar2D")
						hold_bar.points[1].y += parent_delta_y
						hold_bar.points[2].y += parent_delta_y

					
					$main_anims.play("insane_hit_text")
					
					if n.hold_ms > 0:
						var hold = n.hold_ms * hold_mult
						hold_note_hit = true
						var tick_count = int(ceil(hold / 500.0) * 8)
						var tick_interval = hold / tick_count
						var tick_value = (add_points * get_combo_multiplier_for_streak()) / tick_count

						active_holds[n] = {
							"tick_count": tick_count,
							"tick_value": tick_value,
							"tick_interval": tick_interval,
							"total_held_ms": 0.0,
							"ticks_given": 0
						}
						
						# do NOT queue_free(), hold notes stay until tail finishes
						if Settings.misc.note_particle_fx > 0:
							var hold_to_anim_with_particle: GPUParticles2D = get_node("stationary_notes/note" + type + "Sprite/hold_particles")
							if hold_to_anim_with_particle: 
								hold_to_anim_with_particle.emitting = true
								hold_to_anim_with_particle.modulate.a = 0.9
					break
					
				elif y >= $stationary_notes/lines/lineperfect1.global_position.y and y <= $stationary_notes/lines/lineperfect2.global_position.y:
					hit_note = true
					n.hit()
					
					add_points = points_per_note
					perfects += 1
					
					gained = 0.5
					
					#n.get_node("note_hold_end").global_position.y = old_hold_y
					
					var old_note_global_y = n.global_position.y
					
					n.global_position.y = $stationary_notes/lines/linemiddle.global_position.y
					
					var parent_delta_y = n.global_position.y - old_note_global_y
					
					if Settings.misc.hold_bar_keep_position:
						n.get_node("HoldBar2D").global_position.y = old_hold_bar_y
						n.get_node("HoldBar").global_position.y = old_hold_bar_y
					else:
						var hold_bar := n.get_node("HoldBar2D")
						hold_bar.points[1].y += parent_delta_y
						hold_bar.points[2].y += parent_delta_y
					
					$main_anims.play("perfect_hit_text")
					
					if n.hold_ms > 0:
						var hold = n.hold_ms * hold_mult
						hold_note_hit = true
						var tick_count = int(ceil(hold / 500.0) * 8)
						var tick_interval = hold / tick_count
						var tick_value = (add_points * get_combo_multiplier_for_streak()) / tick_count

						active_holds[n] = {
							"tick_count": tick_count,
							"tick_value": tick_value,
							"tick_interval": tick_interval,
							"total_held_ms": 0.0,
							"ticks_given": 0
						}
						# do NOT queue_free(), hold notes stay until tail finishes
						if Settings.misc.note_particle_fx > 0:
							var hold_to_anim_with_particle: GPUParticles2D = get_node("stationary_notes/note" + type + "Sprite/hold_particles")
							if hold_to_anim_with_particle: 
								hold_to_anim_with_particle.emitting = true
								hold_to_anim_with_particle.modulate.a = 0.9
					break
				else:
					hit_note = true
					n.great_hit()
					
					$main_anims.play("great_hit_text")
					
					gained = -1.25

					var great_top: float = $stationary_notes/lines/linegreat1.global_position.y
					var great_bottom :float= $stationary_notes/lines/linegreat2.global_position.y
					var perfect_top :float= $stationary_notes/lines/lineperfect1.global_position.y
					var perfect_bottom :float= $stationary_notes/lines/lineperfect2.global_position.y

					var distance :float= min(abs(y - perfect_top), abs(y - perfect_bottom))
					var max_distance :float= max(abs(great_top - perfect_top), abs(great_bottom - perfect_bottom))
					var accuracy :float= clamp(1.0 - (distance / max_distance), 0.0, 1.0)

					add_points = points_per_note * accuracy
					earlys += int(y < perfect_top)
					lates += int(y > perfect_bottom)
					
					if n.hold_ms > 0:
						var hold = n.hold_ms * hold_mult
						hold_note_hit = true
						var tick_count = int(roundf(hold / 500.0) * 8)
						var tick_interval = hold / tick_count
						var tick_value = (add_points * get_combo_multiplier_for_streak()) / tick_count

						active_holds[n] = {
							"tick_count": tick_count,
							"tick_value": tick_value,
							"tick_interval": tick_interval,
							"total_held_ms": 0.0,
							"ticks_given": 0
						}
						
						# do NOT queue_free(), hold notes stay until tail finishes
						if Settings.misc.note_particle_fx > 0:
							var hold_to_anim_with_particle: GPUParticles2D = get_node("stationary_notes/note" + type + "Sprite/hold_particles")
							if hold_to_anim_with_particle: 
								hold_to_anim_with_particle.emitting = true
								hold_to_anim_with_particle.modulate.a = 0.9
					break
	
	if note_to_anim_with_particle: 
		note_to_anim_with_particle.z_index = 2
		note_to_anim_with_particle.modulate.a = 0.25 if gained < 0.0 else 0.7
	
	if hit_note:
		hp_gained.text = str(gained)
		
		inc_dec_hp(hp + gained)
		
		points_awarded.text = str(add_points * get_combo_multiplier_for_streak()).pad_decimals(0)
		
		notesHit += 1
		
		nps += 1
		nps_lbl.text = "NPS: " + str(nps)
		call_deferred("nps_wait")
		if not hold_note_hit:
			var mult = get_combo_multiplier_for_streak()
			points += (add_points * mult)
		
		points_lbl.text = "Points: " + General.format_number_with_commas(roundf(points))
		stat_exacts.text = "EXACTS: " + str(exactHits)
		stat_insanes.text = "INSANES: " + str(insanes)
		stat_perfects.text = "Perfects: " + str(perfects)
		stat_earlys.text = "Earlys: " + str(earlys)
		stat_lates.text = "Lates: " + str(lates)
		streak_lbl.text = str(streak)
		max_streak_lbl.text = str(maxStreak)
		notes_hit_lbl.text = "Notes Hit: " + str(notesHit)
	
	play_particle_fx(type)

func play_particle_fx(type: String):
	if Settings.misc.note_particle_fx == 0: return
	match Settings.misc.note_particle_fx:
		1: 
			$stationary_notes/noteUpleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
			$stationary_notes/noteDownleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
			$stationary_notes/noteLeftSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
			$stationary_notes/noteDownSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
			$stationary_notes/noteUpSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
			$stationary_notes/noteRightSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
			$stationary_notes/noteDownrightSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
			$stationary_notes/noteUprightSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash_and_bounce.tres")
		2:
			$stationary_notes/noteUpleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
			$stationary_notes/noteDownleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
			$stationary_notes/noteLeftSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
			$stationary_notes/noteDownSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
			$stationary_notes/noteUpSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
			$stationary_notes/noteRightSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
			$stationary_notes/noteDownrightSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
			$stationary_notes/noteUprightSprite/hit_particles.process_material = preload("res://Resources/misc/note_crash.tres")
		3:
			$stationary_notes/noteUpleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
			$stationary_notes/noteDownleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
			$stationary_notes/noteLeftSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
			$stationary_notes/noteDownSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
			$stationary_notes/noteUpSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
			$stationary_notes/noteRightSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
			$stationary_notes/noteDownrightSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
			$stationary_notes/noteUprightSprite/hit_particles.process_material = preload("res://Resources/misc/note_splash.tres")
		4:
			$stationary_notes/noteUpleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
			$stationary_notes/noteDownleftSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
			$stationary_notes/noteLeftSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
			$stationary_notes/noteDownSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
			$stationary_notes/noteUpSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
			$stationary_notes/noteRightSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
			$stationary_notes/noteDownrightSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
			$stationary_notes/noteUprightSprite/hit_particles.process_material = preload("res://Resources/misc/note_orbit.tres")
	match type:
		"Upleft":
			$stationary_notes/noteUpleftSprite/hit_particles.restart()
		"Downleft":
			$stationary_notes/noteDownleftSprite/hit_particles.restart()
		"Left":
			$stationary_notes/noteLeftSprite/hit_particles.restart()
		"Down":
			$stationary_notes/noteDownSprite/hit_particles.restart()
		"Up":
			$stationary_notes/noteUpSprite/hit_particles.restart()
		"Right":
			$stationary_notes/noteRightSprite/hit_particles.restart()
		"Downright":
			$stationary_notes/noteDownrightSprite/hit_particles.restart()
		"Upright":
			$stationary_notes/noteUprightSprite/hit_particles.restart()

func _on_song_finished(debug: bool = false) -> void:
	if songEnded:
		if not debug:
			await get_tree().create_timer(1.2).timeout
			$song.play(0.0)
			play_vid(0.0)
			
			if $song_cover/VideoPlayback.is_open(): $song_cover/VideoPlayback.play()
		else:
			if $song_cover/VideoPlayback.is_open(): $song_cover/VideoPlayback.play()
			
		return
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not recording and screen != "die":
		screen = "end"
		songEnded = true
		set_discord_rpc()
		$end_screen_anims.play("song_end")
		
		
		var prog_t := create_tween()
		prog_t.tween_property(song_progress, "value", 100.0, 0.44).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		
		for p in [$notes_backdrop/multiplier/sparkles_8x, $notes_backdrop/multiplier/lavalookingparticle_8x, $notes_backdrop/multiplier/sparkles_4x, $notes_backdrop/multiplier/lavalookingparticle_4x]:
			p.emitting = false
		
		# Get current date in MM/DD/YYYY format
		var now := Time.get_datetime_dict_from_system()
		var date_string := "%02d/%02d/%04d" % [now.month, now.day, now.year]
		
		# Prepare new score data
		var new_score := {
			"file": chart_path,
			"score": points,
			"notes_hit": notesHit,
			"max_streak": maxStreak,
			"exacts": exactHits,
			"insanes": insanes,
			"perfects": perfects,
			"earlies": earlys,
			"lates": lates,
			"misses": misses,
			"date": date_string
		}

		var pw: String = "8YouAreNOTsupposedToBeHereThisKeyIsVerySecureDoNOTeditYourScoresItsBetterWhenYouAchieveAFullPerfectOnYourOwnÑ"

		var file_path := ProjectSettings.globalize_path("user://.scores_data")
		var readable_path := ProjectSettings.globalize_path("user://scores.json")
		var points_path := ProjectSettings.globalize_path("user://.points")

		var file_data: Array = []
		if FileAccess.file_exists(file_path):
			var file := FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, pw)
			if file:
				var content := file.get_as_text()
				var result = JSON.parse_string(content)
				if result is Array:
					file_data = result
				file.close()

		var replaced := false
		for i in file_data.size():
			if file_data[i].has("file") and file_data[i]["file"] == chart_path:
				if new_score["score"] > file_data[i]["score"]:
					file_data[i] = new_score
					print("New high score! ",  new_score)
				replaced = true
				break

		if not replaced:
			file_data.append(new_score)
		
		var readable_file := FileAccess.open(readable_path, FileAccess.WRITE)
		readable_file.store_string(JSON.stringify(file_data, "\t"))
		readable_file.close()
		
		var enc_file := FileAccess.open_encrypted_with_pass(file_path, FileAccess.WRITE, pw)
		enc_file.store_string(JSON.stringify(file_data))
		enc_file.close()
		
		if FileAccess.file_exists(points_path):
			var pfile := FileAccess.open_encrypted_with_pass(points_path, FileAccess.READ, pw)
			if pfile:
				var text := pfile.get_as_text()
				Beatz.lifetime_points = text.to_float()
				pfile.close()

		Beatz.lifetime_points += points

		var enc_points := FileAccess.open_encrypted_with_pass(points_path, FileAccess.WRITE, pw)
		enc_points.store_string(str(Beatz.lifetime_points))
		enc_points.close()

		print("Updated lifetime points: ", Beatz.lifetime_points)
		
		# If auto hit wasnt used and player hasnt paused at all
		# and missed no notes and got no earlies or lates, and flawless is not yet achieved, achieve flawless
		if not debug and not auto_hit_used and not has_paused and misses == 0 and lates == 0 and earlys == 0:
			AchieveMan.unlock("flawless")
			print("User ", General.epic_user_info["display_name"], " completed their first Flawless song!")
		
		# EOS stats
		var options := EOS.Stats.IngestStatOptions.new()

		options.local_user_id = EOSGRuntime.local_product_user_id
		options.target_user_id = EOSGRuntime.local_product_user_id

		options.stats = [
			{
				"stat_name": "lifetime_points",
				"ingest_amount": Beatz.lifetime_points
			},
			{
				"stat_name": "total_points",
				"ingest_amount": points
			}
		]

		EOS.Stats.StatsInterface.ingest_stat(options)
		

		if not debug:
			await get_tree().create_timer(1.2).timeout
			$song.play(0.0)
			play_vid(0.0)
			if $song_cover/VideoPlayback.is_open(): $song_cover/VideoPlayback.play()
		else:
			if $song_cover/VideoPlayback.is_open(): $song_cover/VideoPlayback.play()
		
		await $end_screen_anims.animation_finished
		for n in $notes.get_children():
			n.queue_free()
	else:
		pass

var pausedpos: float

var unpause_timer: SceneTreeTimer

func _on_pause() -> void:
	if not has_paused: has_paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if $end_screen_anims.is_playing():
		$end_screen_anims.pause()
		
	
	$pausebtn.release_focus()
	$mbl_pausebtn.release_focus()
	gamePaused = true
	pausedpos = $song.get_playback_position()
	if $pause_text.position.y > 250.0 and $pause_text.position.y < 1080.0: $pause.play("pause", 0.25)
	else: $pause.play("pause")

	# Pause song
	$song.stop()
	$Visualizer/Song_left.stop()
	$Visualizer/Song_right.stop()
	
	pause_vid()
	
	for timer: Timer in $UI/noteTimeouts.get_children():
		timer.paused = true # Pause all timers
	
	set_discord_rpc()

func _on_unpause() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	$unpause_btn.release_focus()
	if $pause_text.position.y > 200.0 and $pause_text.position.y < 249.5: $pause.play("unpause", 0.2)
	else: $pause.play("unpause")
	screen = "unpausing"

	unpause_timer = get_tree().create_timer(0.55)
	await unpause_timer.timeout
	
	if screen != "unpausing":
		return

	gamePaused = false
	
	screen = "game"
	
	# Resume song from paused position
	$song.play(pausedpos)
	$Visualizer/Song_left.play(pausedpos)
	$Visualizer/Song_right.play(pausedpos)
	
	beat()
	
	play_vid(-1)
	
	for timer: Timer in $UI/noteTimeouts.get_children():
		timer.paused = false # Unpause all timers
	
	set_discord_rpc()
	
	await $pause.animation_finished

func stagger(n: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout # Await but since this is called deferred, it wont stop code
	if !n: return # If the note doesn't exist, return
	if !n.is_queued_for_deletion() and !check_fade(n, false, true): n.reset_game() # If the note was called queue_free() or if it isn't great_faded (it was hit), dont call reset_game on it

func _on_going_back() -> void:
	$back.release_focus()
	if screen == "pause":
		print("pause back")
		SceneLoader.load_scene(menu)
		
		if $back.position.y > -164.0 and $back.position.y < 14.0: $pause.play("back", 0.25)
		else: $pause.play("back")
		# Clear existing notes
		#var delay := 0.001
		var ns := %notes.get_children()
		
		for n in ns:
			n.reset_game()
		
		await get_tree().create_timer(1.06).timeout
	elif screen == "end":
		SceneLoader.load_scene(menu)
		
		var pitch_t = create_tween()
		pitch_t.tween_property($song, "pitch_scale", 0.001, 1.15)
		
		$end_screen_anims.play("end_screen_to_main")
		await get_tree().create_timer(1.16).timeout
	elif screen == "settings":
		screen = "pause"
		$pause.play("from_stgs_to_pause")
		return
	elif screen == "game":
		print("How")
		return
	elif screen == "die":
		SceneLoader.load_scene(menu)
		
		$pause.play("back_from_die")
		await get_tree().create_timer(0.805).timeout
	
	
	var progress_update := func():
		while SceneLoader.is_loading():
			loading_text.text = "Loading... (%d%)" % int(SceneLoader.get_progress() * 100.0)
			await get_tree().process_frame
		loading_text.text = "Loading... 100%"

	progress_update.call()
	
	if SceneLoader.is_loading():
		await SceneLoader.scene_loaded
	
	var switch_menu = SceneLoader.loaded_scene.instantiate()
	
	get_tree().root.add_child(switch_menu)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = switch_menu

func _on_reset_song_btn_up(fast: bool = false) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	$reset_song_btn.release_focus()
	
	await clear_generated_notes()
	
	points_lbl.text = "Points: 0"
	stat_exacts.text = "EXACTS: 0"
	stat_insanes.text = "INSANES: 0"
	stat_perfects.text = "Perfects: 0"
	stat_earlys.text = "Earlys: 0"
	stat_lates.text = "Lates: 0"
	stat_missed.text = "Misses: 0"
	streak_lbl.text = "0"
	max_streak_lbl.text = "0"
	score_mult.text = "1x"
	
	var prog_t := create_tween()
	prog_t.tween_property(song_progress, "value", (start_pos * 1000.0 / len_ms) * 100.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	$stationary_notes/noteUpleftSprite/hold_particles.emitting = false
	$stationary_notes/noteDownleftSprite/hold_particles.emitting = false
	$stationary_notes/noteLeftSprite/hold_particles.emitting = false
	$stationary_notes/noteDownSprite/hold_particles.emitting = false
	$stationary_notes/noteUpSprite/hold_particles.emitting = false
	$stationary_notes/noteRightSprite/hold_particles.emitting = false
	$stationary_notes/noteDownrightSprite/hold_particles.emitting = false
	$stationary_notes/noteUprightSprite/hold_particles.emitting = false
	
	#song_progress.value = 0.0
	
	if Settings.misc.note_anims == true:
		for n in %notes.get_children():
			n.reset_game()
	else:
		for n in %notes.get_children():
			n.faded = true
			if !n: return
			if !n.is_queued_for_deletion() and !check_fade(n, false, true): n.reset_game()
	
	for b in %beatlines.get_children():
		b.queue_free()
	
	# Stop and remove custom note timers
	for child in $UI/noteTimeouts.get_children():
		if child is Timer:
			child.stop()
			child.queue_free()
	
	if !fast:
		if screen != "die" and screen != "end":
			$pause.play("song_reset")
			
			print(screen)
			print(songEnded)
		elif screen == "end" or songEnded:
			$end_screen_anims.play("reset_from_end")
			
			var pitch_t = create_tween()
			pitch_t.tween_property($song, "pitch_scale", 0.001, 2.15)
			
			await $end_screen_anims.animation_finished
			if $song_cover/VideoPlayback.is_open(): $song_cover/VideoPlayback.pause()
		elif screen == "die":
			$pause.play("reset_from_die")
			await $pause.animation_finished
	
	gameStarted = true
	
	gamePaused = false
	songEnded = false
	
	active_holds.clear()
	
	inc_dec_hp(100.0)
	song_progress_lbl.text = "%s / %s" % [General.format_time(start_pos), General.format_time($song.stream.get_length())]
	
	# Reset counters and game state
	points = 0
	streak = 0
	mult_streak = 0
	get_combo_multiplier_for_streak()
	maxStreak = 0
	misses = 0
	exactHits = 0
	insanes = 0
	perfects = 0
	earlys = 0
	lates = 0
	notesHit = 0
	
	await get_tree().create_timer(0.4).timeout
	
	# Stop all audio and restart song
	$song.stop()
	$Visualizer/Song_left.stop()
	$Visualizer/Song_right.stop()
	pause_vid()
	
	$song.pitch_scale = playback_speed
	$Visualizer/Song_left.pitch_scale = playback_speed
	$Visualizer/Song_right.pitch_scale = playback_speed
	
	$VideoPlayback.playback_speed = playback_speed
	
	screen = "game"
	
	# Restart notes
	if recorded_notes.size() > 0 and _has_valid_notes(recorded_notes):
		_process_custom_notes(recorded_notes)
	elif customNotes.size() > 0 and _has_valid_notes(customNotes):
		_process_custom_notes(customNotes)
	else:
		generateNotes()
	
	if start_wait > 0:
		print("Reset waiting: ", (start_wait + 500) / 1000.0)
		await get_tree().create_timer((start_wait + 500) / 1000.0).timeout
		$song.play(start_pos)
		$Visualizer/Song_left.play(start_pos)
		$Visualizer/Song_right.play(start_pos)
		play_vid(start_pos)
		beat()
	else:
		print("playiong")
		$song.play(start_pos)
		$Visualizer/Song_left.play(start_pos)
		$Visualizer/Song_right.play(start_pos)
		play_vid(start_pos)
		beat()

	set_discord_rpc()

func align_control(node: Control): # Used to always center the pivot offset of a control node (right now only used for points_lbl)
	node.pivot_offset = node.size / 2

func _on_left_btn_pressed() -> void:
	Input.action_press("noteLeft")

func _on_down_btn_pressed() -> void:
	Input.action_press("noteDown")

func _on_up_btn_pressed() -> void:
	Input.action_press("noteUp")

func _on_right_btn_pressed() -> void:
	Input.action_press("noteRight")

func _on_left_btn_released() -> void:
	Input.action_release("noteLeft")

func _on_down_btn_released() -> void:
	Input.action_release("noteDown")

func _on_up_btn_released() -> void:
	Input.action_release("noteUp")

func _on_right_btn_released() -> void:
	Input.action_release("noteRight")

func _on_go_to_stgs_pressed() -> void:
	$go_to_stgs.release_focus()
	screen = "settings"
	$pause.play("from_pause_to_stgs")

func _on_record_btn_pressed() -> void:
	$record_btn.release_focus()
	if not recording:
		$pause.play("start_rec_from_pause")
		
		notes_hit_lbl.text = "Notes Recorded: 0"
		
		await get_tree().create_timer(0.87).timeout
		$end_screen_anims.play("start_rec")
		start_recording()
		await get_tree().create_timer(1.0).timeout
	else:
		$pause.play("start_rec_from_pause")
		
		notes_hit_lbl.text = "Notes Hit: %d" % notesHit
		
		await get_tree().create_timer(0.87).timeout
		$end_screen_anims.play("stop_rec")
		_on_reset_song_btn_up(true)
		recording = false
		
		await get_tree().create_timer(1.0).timeout
		$record_btn.text = "Start Recording"

var preview_start: float
var preview_end: float

var difficulty: String = "easy"
var diff_texture_path: String

var charter: String

@onready var loading_text: RichTextLabel = $loading_text

func _on_edit_btn_pressed() -> void:
	$edit_btn.release_focus()

	SceneLoader.load_scene(General.EDITOR)

	var animation_finished: bool = false
	var loaded_scene: PackedScene = null

	var progress_update := func():
		while SceneLoader.is_loading():
			loading_text.text = "Loading... (%d%)" % int(SceneLoader.get_progress() * 100.0)
			await get_tree().process_frame

		loading_text.text = "Loading... 100%"

	progress_update.call()

	if screen == "pause":
		$pause.play("go_to_edit")

		await get_tree().create_timer(0.85).timeout
		animation_finished = true

	elif screen == "end":
		var pitch_t = create_tween()
		pitch_t.tween_property(
			$song,
			"pitch_scale",
			0.001,
			0.95 if screen == "pause" else 0.85
		)

		$end_screen_anims.play("edit_from_end")

		await get_tree().create_timer(0.85).timeout
		animation_finished = true

	if SceneLoader.is_loading():
		await SceneLoader.scene_loaded

	var edit = SceneLoader.loaded_scene.instantiate()

	edit.new_beatzmap = false

	edit.set("saved", editor_saved)
	edit.set("playtest_start_pos", start_pos)

	edit.set("start_wait", start_wait)

	edit.set("selected_stream", $song.stream)
	edit.set("song_path", song_path)
	edit.set("selected_title", song_title)
	edit.set("selected_album", album)

	edit.set("selected_background", selected_background)
	edit.set("selected_background_name", selected_background_name)

	edit.set("background_vid_path", background_vid_path)
	edit.set("cover_loop_vid_path", cover_loop_vid_path)

	edit.set("selected_cover", cover)
	edit.set("selected_artist", artist)
	edit.set("selected_year", year)

	edit.set("preview_start", preview_start)
	edit.set("preview_end", preview_end)

	edit.set("selected_difficulty", difficulty)
	edit.set("diff_texture_path", diff_texture_path)

	if not recorded_notes:
		edit.set("notes", customNotes)
	else:
		edit.set("notes", recorded_notes)

	edit.set("selected_chart_name", chart_name)

	edit.set("selected_beatz_path", chart_path)
	edit.set("song_path", song_path)

	edit.set("selected_bpm", BPM)
	edit.set("selected_charter", charter)

	edit.set("local_beat_offset", local_beat_offset)

	edit.set("colors", colors)

	get_tree().root.add_child(edit)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = edit

func _on_settings_vis_toggled(toggled: bool) -> void:
	if not toggled: 
		$Visualizer.force_fade_out(0.75)
		await get_tree().create_timer(0.75).timeout
		$Visualizer.process_mode = Node.PROCESS_MODE_DISABLED
	else: 
		$Visualizer.process_mode = Node.PROCESS_MODE_ALWAYS
		$Visualizer.force_fade_in()

func _on_settings_brightness_changed(value: float) -> void:
	$Background.self_modulate = Color(value, value, value)
	$VideoPlayback.self_modulate = Color(value, value, value)

func _on_settings_note_backdrop_opacity_changed(opacity: float) -> void:
	$notes_backdrop/ColorRect.color = Color(0.0, 0.0, 0.0, opacity)

func _on_settings_bg_vids_toggled(toggled_on: bool) -> void:
	pass
	if toggled_on:
		$VideoPlayback.process_mode = Node.PROCESS_MODE_ALWAYS
		$VideoPlayback.show()
		print("Setting video as ", background_vid_path)
		$VideoPlayback.set_video_path(background_vid_path)
		await $VideoPlayback.video_loaded
		print("Vid loaded")
	else:
		print("Closing video ", background_vid_path)
		$VideoPlayback.close()
		$VideoPlayback.process_mode = Node.PROCESS_MODE_DISABLED
		$VideoPlayback.hide()

var scale_tween: Tween

func beat():
	pass
	#if songEnded or gamePaused or not $song.is_playing(): return
	#if scale_tween: scale_tween.kill()
	#
	#$Camera2D.zoom = Vector2(1.005, 1.005)
	#
	#var scale_t = create_tween()
	#scale_t.tween_property($Camera2D, "zoom", Vector2.ONE, beattime / 1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	#scale_tween = scale_t
	#
	#spawn_beatline()
	#
	#await get_tree().create_timer((beattime * 2.0) * playback_speed).timeout
	#call_deferred("beat")

func _on_settings_note_speed_changed(_speed: float) -> void:
	set_note_spawn_y()


func _on_settings_cover_loops_toggled(toggled_on: bool) -> void:
	print(toggled_on)
	
	if not toggled_on:
		if $song_cover/VideoPlayback.is_open(): $song_cover/VideoPlayback.close()
		$song_cover.self_modulate = Color.WHITE
		$song_cover/VideoPlayback.hide()
	
	if toggled_on:
		if cover_loop_vid_path == "": return
		$song_cover/VideoPlayback.set_video_path(cover_loop_vid_path)
		$song_cover.self_modulate = Color.TRANSPARENT
		$song_cover/VideoPlayback.show()


func _on_settings_note_style_changed(_style: int) -> void:
	style()
	
	for n in $notes.get_children():
		if not n.has_node("noteImg"):
			continue

		var sprite_node: Sprite2D = n.get_node("noteImg")

		if not sprite_node:
			continue

		var note_type := ""

		if n.has_method("get_type"):
			note_type = n.get_type()
		elif "type" in n:
			note_type = n.type

		var matching_data = null

		for action in note_data.keys():
			if note_data[action]["key"] == note_type:
				matching_data = note_data[action]
				break

		if matching_data == null:
			continue

		var idle_texture: String = matching_data["idle"]

		sprite_node.texture = load("res://Resources/Arrows/" + idle_texture)

		if Settings.misc.note_style == "circles":
			sprite_node.self_modulate = Settings.parse_any_color(
				Settings.circles.get(note_type, "ffffff")
			)
		else:
			sprite_node.self_modulate = Color.WHITE


func _on_tree_exiting() -> void:
	Beatz.playback_speed = 1.0
	playback_speed = 1.0


func _on_settings_parallax_bg_toggled(toggled_on: bool) -> void:
	if toggled_on:
		if background_vid_path != "" or $hq_background._running:
			$hq_background.stop()
			$hq_background.hide()
			return
		
		$Background.hide()
		
		$hq_background.show()
		$hq_background.start()
	else:
		$Background.show()
		
		$hq_background.hide()
		$hq_background.stop()


func _on_settings_bg_parallax_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$hq_background.play_parallax()
	else:
		$hq_background.stop_parallax()

func _on_settings_bg_effect_changed(effect: int) -> void:
	$hq_background.effect_mode = effect

func _on_settings_bg_rot_time_changed(value: float) -> void:
	$hq_background.tween_time = value

func _on_settings_bg_time_interval_changed(value: float) -> void:
	$hq_background.step_time = value


func _on_settings_bg_fx_random_multi_min_changed(value: int) -> void:
	$hq_background.multi_min = value

func _on_settings_bg_fx_random_multi_max_changed(value: int) -> void:
	$hq_background.multi_max = value


func _on_settings_bg_parallax_speed_changed(value: float) -> void:
	$hq_background/AnimationPlayer.speed_scale = value
