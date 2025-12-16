extends Control

signal seek_ended(value_changed: bool, ending_value: float)
signal seek_started(starting_value: float)
signal seeked(value: float) # value changed

signal randomized
signal previous_pressed
signal next_pressed
signal play_toggled
signal going_to_song

signal volume_drag_ended(value_changed: bool, value: float)
signal volume_changed(value: float)

signal cover_pressed

## If true, hovering the left side of the screen just above the progress bar shows a Menu Song Volume slider, changing this slider changes the audio server volume but doesn't save it to settings.
@export var enable_volume: bool = true

var length: float = 0.0
var current_pos: float = 0.0

var seeking: bool = false

var showing: bool = true

var playing: bool = true

var pos_ms: float:
	get():
		return current_pos / 1000

var len_ms: float:
	get():
		return length / 1000

func _ready() -> void:
	$volume.value = Settings.game.menu_song_vol
	$volume/Label.text = str(Settings.game.menu_song_vol)
	if enable_volume: $volume.show()
	else: $volume.hide()

func set_song(title: String, artist: String, song_length: float, year: int, album: String, cover: Texture2D, cols: Array[Color]):
	$title_artist_cont/title.text = "[b]%s[/b]" % title
	$title_artist_cont/artist.text = artist
	$length.text = "0:00 / " + General.format_time(song_length)
	length = song_length
	$playpause.text = ""
	
	if year:
		$year.text = str(year)
	else: print("No year for ", title)
	
	if album != "":
		$album.text = "[b]%s[/b]" % album
	else: print("No album for ", title)
	
	if cover != null: 
		$cover_mask/cover.texture = cover
		$square_cover.texture = cover
	else: print("No cover for ", title)
	
	if cols.is_empty():
		$bg_col.color = Color.WHITE
		$bg_col_grad.self_modulate = Color.WHITE
	else: 
		$bg_col.color = cols.pick_random()
		$bg_col_grad.self_modulate = $bg_col.color

func set_time(time_s: float = 1.0):
	current_pos = time_s
	$length.text = General.format_time(current_pos) + " / " + General.format_time(length)
	if not seeking: $progress.value = (pos_ms / len_ms) * 100.0

func show_cover():
	$hide.stop()
	showing = true
	$hide.play("show")

func hide_cover():
	$hide.stop()
	$hide.play("hide")
	showing = false

func _on_progress_value_changed(value: float) -> void:
	seeked.emit(value)

func _on_progress_drag_started() -> void:
	seeking = true
	seek_started.emit(current_pos)

func _on_progress_drag_ended(value_changed: bool) -> void:
	$progress.release_focus()
	seeking = false
	seek_ended.emit(value_changed, ($progress.value * length) / 100.0)

func _on_randomize_pressed() -> void:
	$randomize.release_focus()
	randomized.emit()

func _on_previous_pressed() -> void:
	$previous.release_focus()
	previous_pressed.emit()

func _on_playpause_pressed() -> void:
	$playpause.release_focus()
	play_toggled.emit()
	if playing: 
		$playpause.text = ""
		playing = false
	else:
		$playpause.text = ""
		playing = true

func _on_next_pressed() -> void:
	$next.release_focus()
	next_pressed.emit()

func _on_go_to_song_pressed() -> void:
	$go_to_song.release_focus()
	going_to_song.emit()

func _on_volume_drag_ended(value_changed: bool) -> void:
	volume_drag_ended.emit(value_changed, $volume.value)

func _on_volume_value_changed(value: float) -> void:
	volume_changed.emit($volume.value)
	$volume/Label.text = "Menu\n" + str(value)

var volume_bar_tween: Tween
var volume_bar_moving := false

func _on_volume_corner_mouse_entered() -> void:
	if not enable_volume:
		return
	
	$volume.value = Settings.game.menu_song_vol
	$volume/Label.text = "Menu\n" + str(Settings.game.menu_song_vol)
	$volume/Label.position.y = -49
	$volume.scrollable = true

	# Kill any active tween
	if volume_bar_tween and volume_bar_tween.is_running():
		volume_bar_tween.kill()

	# Start hover tween
	volume_bar_tween = create_tween()
	volume_bar_tween.tween_property($volume, "position:x", 22.0, 0.25).set_trans(Tween.TRANS_BACK)
	volume_bar_tween.finished.connect(func(): volume_bar_moving = false)
	volume_bar_moving = true


func _on_volume_corner_mouse_exited() -> void:
	if not enable_volume:
		return

	# Kill any active tween
	if volume_bar_tween and volume_bar_tween.is_running():
		volume_bar_tween.kill()

	# Start exit tween
	volume_bar_tween = create_tween()
	volume_bar_tween.tween_property($volume, "position:x", -44.0, 0.5).set_trans(Tween.TRANS_BACK)
	volume_bar_tween.finished.connect(func(): volume_bar_moving = false)
	volume_bar_moving = true


func _on_volume_changed() -> void:
	$volume.set_value_no_signal(Settings.game.master_vol)
	$volume/Label.text = "Master\n" + str(Settings.game.master_vol)
	$volume/Label.position.y = -49
	$volume.scrollable = false

	# Kill any active tween
	if volume_bar_tween and volume_bar_tween.is_running():
		volume_bar_tween.kill()

	# Start manual show tween
	volume_bar_tween = create_tween()
	volume_bar_tween.tween_property($volume, "position:x", 22.0, 0.25).set_trans(Tween.TRANS_BACK)
	volume_bar_tween.finished.connect(func(): volume_bar_moving = false)
	volume_bar_moving = true

var cover_type: int = 0
var twe: Tween

func _on_cover_mask_focus_entered() -> void:
	$cover_mask.release_focus()
	cover_pressed.emit()
	cover_type += 1
	if cover_type > 2: cover_type = 0
	match cover_type:
		0: 
			if twe: twe.kill()
			$AnimationPlayer.play("rotate")
		1: 
			$AnimationPlayer.stop(true)
			if twe: twe.kill()
			twe = create_tween()
			twe.parallel().tween_property($cover_mask/cover, "rotation_degrees", 0.0 if $cover_mask/cover.rotation_degrees < 180.0 else 360.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		2:
			if twe: twe.kill()
			$AnimationPlayer.play("rotate")

var _last_mouse_x: float = 0.0
var _last_mouse_time: float = 0.0
var _mouse_x_velocity: float = 0.0
var _tooltip_tween: Tween = null

func _on_progress_mouse_entered() -> void:
	# Kill any running fade/slide tween immediately
	if _tooltip_tween and _tooltip_tween.is_running():
		_tooltip_tween.kill()
		_tooltip_tween = null

	# Fade in smoothly
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property($time_tooltip, "modulate", Color.WHITE, 0.15).set_ease(Tween.EASE_IN_OUT)

func _on_progress_mouse_exited() -> void:
	var tooltip := $time_tooltip

	# Kill any active tween first (prevents overlap)
	if _tooltip_tween and _tooltip_tween.is_running():
		_tooltip_tween.kill()
		_tooltip_tween = null

	# Clamp extreme velocity (avoid insane fling speeds)
	var velocity := clampf(_mouse_x_velocity, -500.0, 500.0)

	# The stronger the velocity, the further the slide
	var slide_offset := velocity * 0.5  # tweak feel
	var final_pos = tooltip.position + Vector2(slide_offset, 0)

	# Smoothly slide + fade away
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(tooltip, "position", final_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tooltip_tween.parallel().tween_property(tooltip, "modulate", Color.TRANSPARENT, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_progress_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var bar := $progress
		var mouse_x = clamp(event.position.x, 0, bar.size.x)
		var now := Time.get_ticks_msec() / 1000.0

		# --- Calculate mouse X velocity (pixels per second)
		if _last_mouse_time > 0:
			var dt = max(0.001, now - _last_mouse_time)
			_mouse_x_velocity = (mouse_x - _last_mouse_x) / dt

		_last_mouse_x = mouse_x
		_last_mouse_time = now

		# --- Tooltip logic ---
		var progress_ratio = mouse_x / (bar.size.x - 14.5)
		var hover_time := clampf(progress_ratio * length, 0.0, length)
		var formatted := General.format_time(hover_time)

		$time_tooltip/time.text = formatted
		$time_tooltip.position.x = clampf(mouse_x + $time_tooltip.size.x, bar.position.x + 20.0, bar.size.x + 40.0)
		$time_tooltip.position.y = -$time_tooltip.size.y - 5
