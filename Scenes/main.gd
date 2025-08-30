extends Node

# Song details
var song: AudioStreamMP3
var song_title: String
var album: String
var artist: String
var year: int

var cover

var chart_name: String

var chart_path

var screen: String = "game" # game / paused / end_screen / settings

var menu := load("res://Scenes/main_menu.tscn")

var noteSpeed = Globals.settings.game.note_speed # Speed at which notes fall
var noteSpawnY = 0
var BPM: float = 150 # Beats per minute
var beattime: float # Interval between beats

var total_points := 0
var points_per_note := 0.0
var total_valid_notes := 0

var start_wait: int = 0

var gameStarted = false

var gamePaused = false

const noteTypes = ["Upleft", "Downleft", "Left", "Up", "Down", "Right", "Upright", "Downright"];

var points = 0;
var maxStreak = 0;
var streak = 0;
var misses = 0;
var exactHits = 0;
var insanes = 0;
var perfects = 0;
var earlys = 0;
var lates = 0;
var notesHit = 0;
var customNotes = {}; # Store the custom notes to play
var notes = {}

var auto_hit = false

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

func _process_custom_notes(ns: Array) -> void:
	match Globals.settings.game.note_speed:
		20.0: noteSpawnY = -2100
		15.0: noteSpawnY = -1180
		13.0: noteSpawnY = -989
		10.0: noteSpawnY = -420
		8.0: noteSpawnY = -120
		5.0: noteSpawnY = 370
		_: noteSpawnY = 0

	var has_end := false
	var last_timestamp := -INF

	for n in ns:
		if n.has("end"):
			has_end = true

		if n.has("type") and n.has("timestamp"):
			var direction = n["type"]
			var timestamp: float = n["timestamp"]
			last_timestamp = max(last_timestamp, timestamp)

			var offset = Globals.settings.misc_settings.note_offset

			var timer := Timer.new()
			timer.one_shot = true
			if timestamp == -start_wait:
				timer.wait_time = 0.5
			elif start_wait > 0:
				timer.wait_time = (timestamp + offset + start_wait + 500) / 1000.0
			else:
				timer.wait_time = (timestamp + offset) / 1000.0

			timer.connect("timeout", Callable(self, "_on_custom_note_timeout").bind(direction))
			$UI/noteTimeouts.add_child(timer)
			timer.start()

	# Add _on_song_finished timeout only if none of the notes have "end"
	if not has_end and last_timestamp > -INF:
		var offset = Globals.settings.misc_settings.note_offset
		var wait_time: float
		if start_wait > 0:
			wait_time = (last_timestamp + offset + start_wait + 500) / 1000.0 + 2.0
		else:
			wait_time = (last_timestamp + offset) / 1000.0 + 2.0

		var end_timer := Timer.new()
		end_timer.one_shot = true
		end_timer.wait_time = wait_time
		end_timer.connect("timeout", Callable(self, "_on_song_finished").bind("true"))
		$UI/noteTimeouts.add_child(end_timer)
		end_timer.start()

func _on_custom_note_timeout(direction: String) -> void:
	#print("Spawning note with direction ", direction)
	spawn_note(direction)

# List of directions and their related UI sprite names and textures
var note_data = {
	"noteUpleft": {"key": "Upleft", "sprite": "noteUpleftSprite", "press": "NoteUpleftPress.png", "idle": "NoteUpleft.png"},
	"noteDownleft": {"key": "Downleft", "sprite": "noteDownleftSprite", "press": "NoteDownleftpress.png", "idle": "NoteDownleft.png"},
	"noteLeft": {"key": "Left", "sprite": "noteLeftSprite", "press": "NoteLeftPress.png", "idle": "NoteLeft.png"},
	"noteDown": {"key": "Down", "sprite": "noteDownSprite", "press": "NoteDownPress.png", "idle": "NoteDown.png"},
	"noteUp": {"key": "Up", "sprite": "noteUpSprite", "press": "NoteUpPress.png", "idle": "NoteUp.png"},
	"noteRight": {"key": "Right", "sprite": "noteRightSprite", "press": "NoteRightPress.png", "idle": "NoteRight.png"},
	"noteDownright": {"key": "Downright", "sprite": "noteDownrightSprite", "press": "NoteDownrightPress.png", "idle": "NoteDownright.png"},
	"noteUpright": {"key": "Upright", "sprite": "noteUprightSprite", "press": "NoteUprightPress.png", "idle": "NoteUpright.png"}
}

func _ready():
	if OS.get_name() == "Android": 
		print("Android")
		$UI/points.position.y = 122
		$UI/key_hints.hide()
		$mbl_pausebtn.show()
		$pausebtn.hide()
		match Globals.settings.game.mbl_btn_layout:
			0: $mbl_buttons.show()
			1: $mbl_buttons2.show()
	
	Engine.time_scale = Globals.settings.game.speed
	
	print(Globals.settings.game.note_speed)
	match Globals.settings.game.note_speed: # Match the speed to a specific Y spawn point so all speeds are synced to the song
		20.0: noteSpawnY = -2100
		15.0: noteSpawnY = -1180
		13.0: noteSpawnY = -1000
		10.0: noteSpawnY = -420
		8.0: noteSpawnY = -170
		5.0: noteSpawnY = 370
		_: noteSpawnY = 0
	
	print(noteSpawnY)
	
	match Globals.settings.misc_settings.note_style:
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
			
	if song:
		$song.stream = song
		$Visualizer/Song_left.stream = song
		$Visualizer/Song_right.stream = song
		
		$UI/song_title.text = "Song: " + song_title
		$UI/rec_song_title.text = song_title
		align_control($UI/rec_song_title)
		
		print("Song stream set in main scene.", $song.stream)
		
		# Handle album cover
		if cover:
			$song_cover.texture = cover
			$song_cover.visible = true
			$song_cover.set("scale", Vector2(0.28, 0.28))
		elif album != null and album.strip_edges() != "":
			var sanitized_album_name = album.replace("/", "_").replace("\\", "_").replace(":", "_") # Replace all invalid characters for underscores to then load as an image
			var cover_path = "res://Resources/Covers/" + sanitized_album_name + ".png"
			
			if FileAccess.file_exists(cover_path):
				var cover_image = load(cover_path)
				$song_cover.texture = cover_image
				$song_cover.visible = true
				$song_cover.set("scale", Vector2(0.28, 0.28))
			else:
				var fallback_image = load("res://Resources/Covers/noCover.png")
				var fallback_texture = ImageTexture.create_from_image(fallback_image)
				$song_cover.texture = fallback_texture
				$song_cover.visible = false
		else:
			var fallback_image = load("res://Resources/Covers/noCover.png")
			var fallback_texture := ImageTexture.create_from_image(fallback_image)
			$song_cover.texture = fallback_texture
			$song_cover.visible = false
	await get_tree().create_timer(1.2).timeout
	
	if customNotes.size() > 0 and _has_valid_notes(customNotes):
		print("Using notes in chart")
		_process_custom_notes(customNotes)
		gameStarted = true
		screen = "game"
		gamePaused = false
	else:
		print("Random notes since chart file doesnt contain valid notes or it doesnt exist")
		beattime = 60 / BPM
	
		gameStarted = true
		generateNotes()
	
	total_valid_notes = customNotes.filter(func(n):
		return n.has("type") and n.has("timestamp") and n["type"] != "Effect"
	).size()

	if total_valid_notes < 250:
		total_points = 25000
	elif total_valid_notes < 450:
		total_points = 50000
	elif total_valid_notes < 800:
		total_points = 75000
	elif total_valid_notes < 1150:
		total_points = 100000
	elif total_valid_notes < 1800:
		total_points = 175000
	elif total_valid_notes < 2500:
		total_points = 250000
	elif total_valid_notes < 3750:
		total_points = 500000
	elif total_valid_notes < 5000:
		total_points = 750000
	elif total_valid_notes < 6000:
		total_points = 1000000
	elif total_valid_notes < 7250:
		total_points = 2500000
	elif total_valid_notes < 8500:
		total_points = 5000000
	else:
		total_points = 10000000
	
	points_per_note = float(total_points) / total_valid_notes
	
	print(total_points, " points and ", points_per_note)
	
	$song.pitch_scale = Engine.time_scale
	
	$Visualizer/Song_left.pitch_scale = Engine.time_scale
	$Visualizer/Song_right.pitch_scale = Engine.time_scale
	
	if start_wait > 0:
		print("Waiting ", (start_wait + 500) / 1000.0)
		await get_tree().create_timer((start_wait + 500) / 1000.0).timeout
		print("Waited")
		$song.play()
		$Visualizer/Song_left.play()
		$Visualizer/Song_right.play()
	else:
		print("No waiting")
		$song.play()
		$Visualizer/Song_left.play()
		$Visualizer/Song_right.play()
	
	spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Song"), 0) as AudioEffectSpectrumAnalyzerInstance

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()

func handle_back():
	if gamePaused == false and screen != "end" and screen != "settings":
		_on_pause()
	elif gamePaused == true and screen != "end" and screen != "settings":
		_on_unpause()
	elif screen == "settings":
		$pause.play("from_stgs_to_pause")

func _process(delta):
	if recording:
		for action in note_data.keys():
			var key = note_data[action]["key"]
			if Input.is_action_just_pressed(action):
				var current_time = Time.get_ticks_msec() - recording_start_time
				recorded_notes.append({"type": key, "timestamp": current_time - 1080})
				spawn_note(key, true)
				print("Recorded: ", key, " at ", current_time, "ms")
	
	for action in note_data.keys():
		var key = note_data[action]["key"]
		var sprite_path = note_data[action]["sprite"]
		var press_texture = note_data[action]["press"]
		var idle_texture = note_data[action]["idle"]

		if Input.is_action_pressed(action):
			$stationary_notes.get_node(sprite_path).texture = load("res://Resources/Arrows/" + press_texture) # If the action is pressed, draw the pressed texture
		else:
			$stationary_notes.get_node(sprite_path).texture = load("res://Resources/Arrows/" + idle_texture) # Otherwise draw the normal texture
			
		if Input.is_action_just_pressed(action): # Register hit only the frame the input was hit
			if key == "Left" or key == "Down" or key == "Up" or key == "Right":
				if Globals.settings.misc_settings.note_anims == true:
					var ani: AnimationPlayer = get_node("stationary_notes/note_" + key.to_lower())
					
					ani.play("RESET")
					ani.play(key.to_lower() + "_pulse")
			
			highlightedNotes[key] = true
			registerHit(key)
			
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
				_on_reset_song_btn_up(true)
				recording = false
	
	# Keep other control inputs here
	if Input.is_action_just_pressed("autoHit"):
		auto_hit = !auto_hit
		
	if Input.is_action_just_pressed("ui_cancel"):
		handle_back()
	
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
		if check_fade(n, false, true) == "great": n.global_position.y += 100 * (noteSpeed as int) * (delta) / 3
		else: n.global_position.y += 100 * (noteSpeed as int) * (delta)
		
		if n.global_position.y > $stationary_notes/lines/linemiss.global_position.y: miss_note(n)
		
		if auto_hit && n.global_position.y > $stationary_notes/lines/linemiddle.global_position.y:
			
			if check_fade(n): # If the note exists but it is faded or great faded, dont register a hit
				continue
			
			if Globals.settings.misc_settings.note_anims == true:
				var ani: AnimationPlayer = get_node("stationary_notes/note_" + n.type.to_lower())
				
				ani.play("RESET")
				ani.play(n.type.to_lower() + "_pulse")
			highlightedNotes[n.type] = true
			registerHit(n.type)
				
				
				
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
		var base_scale : float = 1.0
		var max_title : float = 1.5
		var max_cover : float = 1.4
		var max_bg : float = 1.3
		var max_cam : float = 1.03
		
		# Interpolated targets
		var title_target = lerp(base_scale, max_title, exp_treble)
		var cover_target = lerp(base_scale, max_cover, exp_overall)
		var bg_target = lerp(base_scale, max_bg, exp_bg)
		var cam_target = lerp(base_scale, max_cam, exp_overall)
		
		# Smooth transitions
		#$Title.scale = lerp($Title.scale, Vector2.ONE * title_target, 13.0 * delta)
		#$Artist.scale = lerp($Title.scale, Vector2.ONE * title_target, 10.0 * delta)
		#$vis_anim.scale = lerp($vis_anim.scale, Vector2(2.6,2.6) * cover_target, 15.0 * delta)
		#$cover_anim.scale = lerp($cover_anim.scale, Vector2.ONE * cover_target, 20.0 * delta)
		
		#$Camera.zoom = lerp($Camera.zoom, Vector2.ONE * cam_target, 16.0 * delta)
		
		$Background.scale = lerp($Background.scale, Vector2.ONE * bg_target, 16.0 * delta)
		$TransitionRect.scale = lerp($TransitionRect.scale, Vector2.ONE * bg_target, 16.0 * delta)
		$ActualTransitionRect.scale = lerp($ActualTransitionRect.scale, Vector2.ONE * bg_target, 16.0 * delta)

func check_fade(n: Node2D, hit: bool = true, great: bool = true): # Add the note, and specify what type of fade it should check for
	if !n.has_method("hit"): 
		print("not a note, or it doesn't exist, ", n)
		return
	if n.faded and hit: # If note is faded, it means it was hit in the perfect, insane or exact zone
		return "hit"
	if n.faded_great and great: # If the note is great faded, it means the note was not hit in the perfect, insane or exact zone
		return "great"
	else:
		return

func miss_note(n):
	if check_fade(n):
		return
	if n.rec:
		n.queue_free()
		return
	$main_anims.stop()
	$main_anims.play("missed_hit_text")
	n.queue_free()
	streak = 0
	misses += 1
	$UI/stat_missed.text = "Misses: " + str(misses)
	$UI/streak.text = str(streak)

func generateNotes():
	if not gameStarted or gamePaused:
		return
	
	var dur = $song.stream.get_length()
	var numberOfNotes = snappedf(dur / beattime, 1)
	print("Song Duration: ", dur, " seconds")
	print("Number of notes ", numberOfNotes)
	
	const directions = ["Up", "Down", "Left", "Right"]
	
	for n in range(numberOfNotes):
			
		while gamePaused:
			await get_tree().process_frame
			
		var dir = directions.pick_random()
		spawn_note(dir)
				
		await get_tree().create_timer(beattime).timeout

func spawn_note(direction: String = "Up", rec: bool = false) -> void:
	if screen == "end": return
	if gamePaused: return
	if not gameStarted: return
	var new_note = note.instantiate()
	var x: float = 0.0
	match direction:
		"Left": x = $stationary_notes/noteLeftSprite.position.x# - 960
		"Down": x = $stationary_notes/noteDownSprite.position.x# - 990
		"Up": x = $stationary_notes/noteUpSprite.position.x # - 930
		"Right": x = $stationary_notes/noteRightSprite.global_position.x# - 872
		_: x = $stationary_notes/noteUpSprite.global_position.x #- 1000
	new_note.position = Vector2(x, noteSpawnY)
	new_note.scale = Vector2(0.65, 0.65)
	new_note.set_type(direction)
	if rec:
		new_note.set("rec", true)
		new_note.global_position.y = 285
	
	%notes.add_child(new_note)

var recorded_notes := []  # Array to store recorded notes as dictionaries
var recording := false
var recording_start_time := 0.0

func start_recording():
	# Stop song if playing
	$song.stop()
	
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
	
	$UI/points.text = "Points: 0"
	$UI/stat_exacts.text = "EXACTS: 0"
	$UI/stat_insanes.text = "INSANES: 0"
	$UI/stat_perfects.text = "Perfects: 0"
	$UI/stat_earlys.text = "Earlys: 0"
	$UI/stat_lates.text = "Lates: 0"
	$UI/stat_missed.text = "Misses: 0"
	$UI/streak.text = "0"
	$UI/max_streak.text = "0"
	
	# Reset state
	gamePaused = false
	screen = "game"
	gameStarted = true
	
	# Clear recorded notes
	recorded_notes.clear()
	
	# Start song
	$song.play(0.0)
	
	# Start recording
	recording = true
	recording_start_time = Time.get_ticks_msec()
	print("Recording started")

func registerHit(type):
	if gamePaused:
		print("Game is paused why are you trying to hit a note")
		return
	
	if notesHit == total_valid_notes and misses == 0 and earlys == 0 and lates == 0:
		points = total_points
	
	for n in %notes.get_children():
		if n.type != type or check_fade(n) or n.rec:
			continue
		
		var y = n.global_position.y
		var hit_window_top = $stationary_notes/lines/linegreat1.global_position.y
		var hit_window_bottom = $stationary_notes/lines/linegreat2.global_position.y
		
		if y >= hit_window_top and y <= hit_window_bottom:
			if highlightedNotes.get(n.type, false):
				$main_anims.stop()
				streak += 1
				if streak > maxStreak:
					maxStreak = streak
				
				var add_points := 0.0

				if y >= $stationary_notes/lines/lineexact1.global_position.y and y <= $stationary_notes/lines/lineexact2.global_position.y:
					n.hit()
					n.global_position.y = $stationary_notes/lines/linemiddle.global_position.y
					$main_anims.play("exact_hit_text")
					add_points = points_per_note
					exactHits += 1
				elif y >= $stationary_notes/lines/lineinsane1.global_position.y and y <= $stationary_notes/lines/lineinsane2.global_position.y:
					n.hit()
					n.global_position.y = $stationary_notes/lines/linemiddle.global_position.y
					$main_anims.play("insane_hit_text")
					add_points = points_per_note
					insanes += 1
				elif y >= $stationary_notes/lines/lineperfect1.global_position.y and y <= $stationary_notes/lines/lineperfect2.global_position.y:
					n.hit()
					n.global_position.y = $stationary_notes/lines/linemiddle.global_position.y
					$main_anims.play("perfect_hit_text")
					add_points = points_per_note
					perfects += 1
				else:
					n.great_hit()
					$main_anims.play("great_hit_text")

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
				
				points += add_points
				
				$UI/points_awarded.text = "%.0f" % add_points
				
				highlightedNotes[n.type] = false
				
				$UI/points.text = "Points: " + str(points).pad_decimals(0)
				$UI/stat_exacts.text = "EXACTS: " + str(exactHits)
				$UI/stat_insanes.text = "INSANES: " + str(insanes)
				$UI/stat_perfects.text = "Perfects: " + str(perfects)
				$UI/stat_earlys.text = "Earlys: " + str(earlys)
				$UI/stat_lates.text = "Lates: " + str(lates)
				$UI/streak.text = str(streak)
				$UI/max_streak.text = str(maxStreak)
				
				align_control($UI/points)
				return  # Stop checking once you hit one note

func _on_song_finished(debug: bool = false) -> void:
	if not recording:
		$end_screen_anims.play("song_end")
		
		# Get current date in MM/DD/YYYY format
		var now := Time.get_datetime_dict_from_system()
		var date_string := "%02d/%02d/%04d" % [now.month, now.day, now.year]
		
		# Prepare new score data
		var new_score := {
			"file": chart_path,
			"score": int(points),
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

		var file_path := "user://.scores_data"
		var readable_path := "user://scores.json"
		var file_data: Array = []
		var pw = "8YouAreNOTsupposedToBeHereThisKeyIsVerySecureDoNOTeditYourScoresItsBetterWhenYouAchieveAFullPerfectOnYourOwnÑ"

		# Read existing encrypted data
		if FileAccess.file_exists(file_path):
			var file := FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, pw)
			if file:
				var content := file.get_as_text()
				var result = JSON.parse_string(content)
				if result is Array:
					file_data = result
				file.close()

		# Check for existing score and update if the new one is higher
		var replaced := false
		for i in file_data.size():
			if file_data[i].has("file") and file_data[i]["file"] == chart_path:
				if new_score["score"] > file_data[i]["score"]:
					file_data[i] = new_score
				replaced = true
				break

		if not replaced:
			file_data.append(new_score)

		# Write encrypted .scores_data
		var enc_file := FileAccess.open_encrypted_with_pass(file_path, FileAccess.WRITE, pw)
		enc_file.store_string(JSON.stringify(file_data))
		enc_file.close()

		# Write readable JSON for debugging
		var readable_file := FileAccess.open(readable_path, FileAccess.WRITE)
		readable_file.store_string(JSON.stringify(file_data, "\t"))
		readable_file.close()

		# Replay song if not debug
		if not debug:
			await get_tree().create_timer(1.2).timeout
			$song.play(0.0)
	else:
		pass


var pausedpos: float

func _on_pause() -> void:
	$pausebtn.release_focus()
	$mbl_pausebtn.release_focus()
	gamePaused = true
	pausedpos = $song.get_playback_position()
	$pause.play("pause")

	# Pause song
	$song.stop()
	$Visualizer/Song_left.stop()
	$Visualizer/Song_right.stop()
	
	for timer: Timer in $UI/noteTimeouts.get_children():
		timer.paused = true # Pause all timers

func _on_unpause() -> void:
	$unpause_btn.release_focus()
	$pause.play("unpause")
	await get_tree().create_timer(0.6).timeout
	gamePaused = false
	
	# Resume song from paused position
	$song.play(pausedpos)
	$Visualizer/Song_left.play(pausedpos)
	$Visualizer/Song_right.play(pausedpos)
	
	for timer: Timer in $UI/noteTimeouts.get_children():
		timer.paused = false # Unpause all timers

func stagger(n: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout # Await but since this is called deferred, it wont stop code
	if !n: return # If the note doesn't exist, return
	if !n.is_queued_for_deletion() and !check_fade(n, false, true): n.reset_game() # If the note was called queue_free() or if it isn't great_faded (it was hit), dont call reset_game on it

func _on_going_back() -> void:
	$back.release_focus()
	if screen == "pause":
		print("pause back")
		$pause.play("back")
		# Clear existing notes
		var delay := 0.001
		var ns := %notes.get_children()
		
		for i in range(ns.size() - 1, -1, -1):
			var n = ns[i]
			n.faded = true
			call_deferred("stagger", n, delay)
			delay += 0.01
	elif screen == "end":
		print("end back")
		print("")
		print("")
		print("main:")
		$end_screen_anims.play("end_screen_to_main")
	elif screen == "settings":
		screen = "pause"
		$pause.play("from_stgs_to_pause")
		return
	elif screen == "game":
		print("How")
		return
	await get_tree().create_timer(1.5).timeout
	var switch_menu = menu.instantiate()
	
	get_tree().root.add_child(switch_menu)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = switch_menu

func _on_reset_song_btn_up(fast: bool = false) -> void:
	$reset_song_btn.release_focus()
	# Stop all audio and restart song
	$song.stop()
	$Visualizer/Song_left.stop()
	$Visualizer/Song_right.stop()
	
	if !fast:
		$pause.play("song_reset")
	
	if Globals.settings.misc_settings.note_anims == true:
		# Clear existing notes
		var delay := 0.00001
		
		for n in %notes.get_children():
			n.faded = true
			call_deferred("stagger", n, delay) # await stops the code from running, so call deferred so it doesnt stop it
			delay += 0.02
	else:
		for n in %notes.get_children():
			n.faded = true
			if !n: return # If the note doesn't exist, return
			if !n.is_queued_for_deletion() and !check_fade(n, false, true): n.reset_game() # If the note was called queue_free() or if it isn't great_faded (it was hit), dont call reset_game on it
	
	gameStarted = true
	
	gamePaused = false
	screen = "game"
	
	# Reset counters and game state
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
	
	$UI/points.text = "Points: 0"
	$UI/stat_exacts.text = "EXACTS: 0"
	$UI/stat_insanes.text = "INSANES: 0"
	$UI/stat_perfects.text = "Perfects: 0"
	$UI/stat_earlys.text = "Earlys: 0"
	$UI/stat_lates.text = "Lates: 0"
	$UI/stat_missed.text = "Misses: 0"
	$UI/streak.text = "0"
	$UI/max_streak.text = "0"
	
	# Stop and remove custom note timers
	for child in $UI/noteTimeouts.get_children():
		if child is Timer:
			child.stop()
			child.queue_free()
	
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
		$song.play()
		$Visualizer/Song_left.play()
		$Visualizer/Song_right.play()
	else:
		$song.play()
		$Visualizer/Song_left.play()
		$Visualizer/Song_right.play()
	

func align_control(node: Control): # Used to always center the pivot offset of a control node (right now only used for $UI/points)
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
	$pause.play("start_rec_from_pause")
	await get_tree().create_timer(0.87).timeout
	$end_screen_anims.play("start_rec")
	start_recording()

var preview_start: float
var preview_end: float

var difficulty: String = "easy"

var charter: String

func _on_edit_btn_pressed() -> void:
	var edit = preload("res://Scenes/editor.tscn").instantiate()
	
	edit.set("start_wait", start_wait)
	
	edit.set("selected_stream", $song.stream)
	edit.set("selected_title", song_title)
	edit.set("selected_album", album)
	
	edit.set("selected_cover", cover)
	edit.set("selected_artist", artist)
	edit.set("selected_year", year)
	
	edit.set("preview_start", preview_start)
	edit.set("preview_end",preview_end)
	
	edit.set("selected_difficulty", difficulty)
	edit.set("notes", customNotes)
	edit.set("selected_chart_name", chart_name)
	
	edit.set("selected_beatz_path", chart_path)
	
	edit.set("selected_bpm", BPM)
	edit.set("selected_charter", charter)
	
	get_tree().root.add_child(edit)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = edit
