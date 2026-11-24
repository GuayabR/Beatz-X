extends Control

signal seek_ended(value_changed: bool, ending_value: float)
signal seek_started(starting_value: float)
signal seeked(value: float) # value changed

signal going_to_artist(path: String)
signal randomized
signal prev_next_pressed(path: String, prev_next: int)
signal play_toggled
signal going_to_song(path: String, imported_stream: bool)
signal going_to_album(path: String)

signal volume_drag_ended(value_changed: bool, value: float)
signal volume_changed(value: float)

signal cover_pressed(scale_with_audio: bool)

## If true, hovering the left side of the screen just above the progress bar shows a Menu Song Volume slider, changing this slider changes the audio server volume but doesn't save it to settings.
@export var enable_volume: bool = true

const MARQUEE_TEXT_PADDING := 8.0

var data: Dictionary = {}

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

var stream: String

var not_imported_stream: bool = false

@onready var btns_to_disable = [$go_to_artist, $previous, $next, $go_to_album]

var _external_media_active: bool = false
var _external_media_info: Dictionary = {}
var _external_artwork_bytes: PackedByteArray = PackedByteArray()
var _last_external_artwork_bytes: PackedByteArray = PackedByteArray()
var _external_artwork_texture: Texture2D
var _external_artwork_decode_failed: bool = false
var _external_cover_loop_path: String = ""
var _external_cover_loop_applied_path: String = ""
var _external_cover_loop_mode_active: bool = false
var _external_background_primary: Color = Color.WHITE
var _external_background_secondary: Color = Color.WHITE
var _local_background_primary: Color = Color.WHITE
var _local_background_secondary: Color = Color.WHITE
var _local_cover_texture: Texture2D
var _default_cover_texture: Texture2D
var _default_square_cover_texture: Texture2D
var _artwork_color_tween: Tween
var _background_primary_target: Color = Color.WHITE
var _background_secondary_target: Color = Color.WHITE
var _local_navigation_disabled: bool = false
var _local_go_to_song_disabled: bool = false
var _external_seek_pending: bool = false
var _external_pending_seek_ms: int = 0
const COVER_MODE_STATIONARY: int = 0
const COVER_MODE_ROTATE: int = 1
const COVER_MODE_AUDIO_SCALE: int = 2
const COVER_MODE_ROTATE_AND_SCALE: int = 3

var _marquee_request_id := 0
var _title_scroll_tween: Tween
var _artist_scroll_tween: Tween
var _album_scroll_tween: Tween

func _ready() -> void:
	_default_cover_texture = $cover_mask/cover.texture
	_default_square_cover_texture = $cover_mask/square_cover.texture
	if OS.get_name() == "Android": $mbl.play("mbl_expand")
	_apply_cover_shape()
	
	$volume.value = Settings.game.menu_song_vol
	$volume/Label.text = str(Settings.game.menu_song_vol)
	if enable_volume: $volume.show()
	else: $volume.hide()

	_duplicate_fade_material($title_artist_cont/title/text)
	_duplicate_fade_material($title_artist_cont/artist/text)
	_duplicate_fade_material($album/text)
	resized.connect(_update_marquee_fades)
	_update_marquee_fades()
	_refresh_marquee_layout()
	WindowsMediaIntegration.external_media_changed.connect(_on_external_media_changed)
	WindowsMediaIntegration.playback_status_changed.connect(_on_external_playback_status_changed)
	WindowsMediaIntegration.media_position_changed.connect(_on_external_media_position_changed)
	WindowsMediaIntegration.playback_command_state_changed.connect(_on_external_playback_command_state_changed)
	WindowsMediaIntegration.playback_command_completed.connect(_on_external_playback_command_completed)
	_on_external_media_changed(
		WindowsMediaIntegration.media_available,
		WindowsMediaIntegration.media_info,
		WindowsMediaIntegration.artwork_bytes
	)

func _duplicate_fade_material(label: RichTextLabel) -> void:
	var material := label.material as ShaderMaterial
	if material:
		label.material = material.duplicate()

func set_song(data_dict: Dictionary):
	if data_dict["path"]:
		stream = ProjectSettings.globalize_path(data_dict["path"])
	
	if stream.contains("Beatz! X (Desktop Port)/Resources/Songs") or stream.contains("AppData/Roaming/Godot/app_userdata") or stream.contains("storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/"):
		print("imported")
		$go_to_song.text = ""
		not_imported_stream = false
		_local_go_to_song_disabled = false
		_local_navigation_disabled = false
		
		$go_to_song.tooltip_text = "Play %s - %s" % [data_dict["title"], data_dict["artist"]]
		
		for btn in btns_to_disable:
			btn.disabled = false
			btn.modulate = Color.WHITE
			btn.mouse_filter = MOUSE_FILTER_STOP
	else:
		print("not imported")
		$go_to_song.text = ""
		not_imported_stream = true
		_local_go_to_song_disabled = true
		_local_navigation_disabled = true
		
		$go_to_song.tooltip_text = "Start Recording Notes for %s - %s" % [data_dict["title"], data_dict["artist"]]
		
		for btn in btns_to_disable:
			btn.disabled = true
			btn.modulate = Color(1.0, 1.0, 1.0, 0.25)
			btn.mouse_filter = MOUSE_FILTER_IGNORE
	
	$title_artist_cont/title/text.text = "[b]%s[/b]" % data_dict["title"]
	$title_artist_cont/artist/text.text = data_dict["artist"]
	$length.text = "0:00 / " + General.format_time(data_dict["length"])
	length = data_dict["length"]
	$playpause.text = ""
	
	playing = true
	
	if data_dict["year"]:
		$year.text = str(int(data_dict["year"]))
		$year.show()
	else: 
		$year.hide()
		print("No year for ", data_dict["title"])
	
	var same_album: bool = data.has("album") and data["album"] == data_dict["album"]

	if data_dict["album"] != "":
		if not same_album:
			$album/text.text = "[b]%s[/b]" % data_dict["album"]
			$album.show()
		else:
			pass
	else:
		$album/text.text = ""
		$album.hide()
		print("No album for ", data_dict["title"])
	
	_local_cover_texture = null
	if data_dict["cover"] != null:
		if data_dict["cover"] is Image:
			_local_cover_texture = ImageTexture.create_from_image(data_dict["cover"])
		else:
			_local_cover_texture = data_dict["cover"] as Texture2D

		$cover_mask/cover.texture = _local_cover_texture
		$cover_mask/square_cover.texture = _local_cover_texture

		if not showing:
			show_cover()
		
		if not same_album:
			$cover_mask/VideoPlayback.close()
			$cover_mask/VideoPlayback.hide()
	else:
		$cover_mask/cover.texture = _default_cover_texture
		$cover_mask/square_cover.texture = _default_square_cover_texture
		hide_cover()
		print("No cover for ", data_dict["title"])

	if not _external_media_active and data_dict["cover_loop"] != "" and Settings.misc.cover_loops_playing_bar:
		if not same_album:
			$cover_mask/VideoPlayback.close()
			$cover_mask/VideoPlayback.set_video_path(data_dict["cover_loop"])
			$cover_mask/VideoPlayback.show()
			print(data_dict["cover_loop"], " showing")
	
	var cover_image: Image = _get_image(data_dict.get("cover"))
	if cover_image != null and not cover_image.is_empty():
		_apply_artwork_colors(cover_image)
	else:
		_local_background_primary = Color.WHITE
		_local_background_secondary = Color.WHITE
		_transition_background_colors(Color.WHITE, Color.WHITE)
	
	data = data_dict
	if _external_media_active:
		_display_external_metadata()
	_update_external_controls()
	_refresh_marquee_layout()

func _on_external_media_changed(active: bool, media_info: Dictionary, artwork_bytes: PackedByteArray) -> void:
	_external_media_active = active
	_external_media_info = media_info.duplicate(true) if active else {}
	_external_artwork_bytes = artwork_bytes
	if not active:
		_external_seek_pending = false
		_external_pending_seek_ms = 0
		seeking = false
		_external_cover_loop_path = ""
		_external_cover_loop_applied_path = ""
		_external_cover_loop_mode_active = false

	if active:
		_display_external_metadata()
	else:
		_clear_external_artwork_cache()
		$cover_mask/VideoPlayback.close()
		$cover_mask/VideoPlayback.hide()
		_restore_local_metadata()

	_update_external_controls()

func _display_external_metadata() -> void:
	var title: String = str(_external_media_info.get("title", "")).strip_edges()
	var artist: String = str(_external_media_info.get("artist", "")).strip_edges()
	var album: String = str(_external_media_info.get("album", "")).strip_edges()
	var source_app_id: String = str(_external_media_info.get("source_app_id", "")).strip_edges()
	var source_name: String = source_app_id.get_basename().strip_edges()

	if title.is_empty():
		title = str(data.get("title", "")).strip_edges()
	if title.is_empty():
		title = "Unknown title"
	if artist.is_empty():
		artist = str(data.get("artist", "")).strip_edges()
	if artist.is_empty():
		artist = "Unknown artist"
	if album.is_empty():
		album = str(data.get("album", "")).strip_edges()

	$title_artist_cont/title/text.text = "[b]%s[/b]" % title
	$title_artist_cont/artist/text.text = artist
	_set_album_text(album)
	var duration_ms: int = int(_external_media_info.get("duration_ms", 0))
	var position_ms: int = int(_external_media_info.get("position_ms", 0))
	length = float(duration_ms) / 1000.0
	current_pos = float(position_ms) / 1000.0
	$length.text = General.format_time(current_pos) + " / " + General.format_time(length)
	if not seeking and not _external_seek_pending:
		if length > 0.0:
			$progress.value = clampf(current_pos / length * 100.0, 0.0, 100.0)
		else:
			$progress.value = 0.0
	if source_name.is_empty():
		$year.hide()
	else:
		$year.text = source_name
		$year.show()

	if not _external_artwork_bytes.is_empty():
		if _external_artwork_bytes != _last_external_artwork_bytes:
			_last_external_artwork_bytes = _external_artwork_bytes
			_external_artwork_texture = null
			_external_artwork_decode_failed = false
		if _external_artwork_texture == null and not _external_artwork_decode_failed:
			var image := Image.new()
			var error: Error = image.load_png_from_buffer(_external_artwork_bytes)
			if error == OK and not image.is_empty():
				_external_artwork_texture = ImageTexture.create_from_image(image)
				var external_colors: Array[Color] = _extract_artwork_colors(image)
				_external_background_primary = external_colors[0]
				_external_background_secondary = external_colors[1]
				_transition_background_colors(_external_background_primary, _external_background_secondary)
			else:
				_external_artwork_decode_failed = true
				push_warning("Windows media album artwork could not be decoded as PNG.")

		if _external_artwork_texture != null:
			$cover_mask/cover.texture = _external_artwork_texture
			$cover_mask/square_cover.texture = _external_artwork_texture
			_transition_background_colors(_external_background_primary, _external_background_secondary)
			if not showing:
				show_cover()
		else:
			_restore_local_cover_and_colors()
	else:
		_clear_external_artwork_cache()
		_restore_local_cover_and_colors()

	_apply_external_cover_loop()
	_refresh_marquee_layout()

func set_external_cover_loop(path: String) -> void:
	_external_cover_loop_path = path
	if _external_media_active:
		_apply_external_cover_loop()

func refresh_external_cover_loop() -> void:
	if _external_media_active:
		_apply_external_cover_loop()

func _apply_external_cover_loop() -> void:
	var video: VideoPlayback = $cover_mask/VideoPlayback
	var desired_path: String = _external_cover_loop_path if Settings.misc.cover_loops_playing_bar else ""
	if desired_path.is_empty():
		if not _external_cover_loop_mode_active or not _external_cover_loop_applied_path.is_empty():
			video.close()
			video.hide()
		_external_cover_loop_mode_active = true
		_external_cover_loop_applied_path = ""
		return

	if _external_cover_loop_mode_active and _external_cover_loop_applied_path == desired_path:
		return

	video.close()
	video.set_video_path(desired_path)
	video.show()
	_external_cover_loop_mode_active = true
	_external_cover_loop_applied_path = desired_path

func _restore_local_metadata() -> void:
	if data.is_empty():
		$title_artist_cont/title/text.text = "[b]Title[/b]"
		$title_artist_cont/artist/text.text = "Artist"
		_set_album_text("")
		$year.hide()
		_restore_local_cover_and_colors()
		$cover_mask/VideoPlayback.close()
		$cover_mask/VideoPlayback.hide()
		_refresh_marquee_layout()
		return

	$title_artist_cont/title/text.text = "[b]%s[/b]" % str(data.get("title", ""))
	$title_artist_cont/artist/text.text = str(data.get("artist", ""))
	_set_album_text(str(data.get("album", "")))

	if data.get("year", null):
		$year.text = str(int(data["year"]))
		$year.show()
	else:
		$year.hide()

	_restore_local_cover_and_colors()
	if data.get("cover_loop", "") != "" and Settings.misc.cover_loops_playing_bar:
		$cover_mask/VideoPlayback.close()
		$cover_mask/VideoPlayback.set_video_path(data["cover_loop"])
		$cover_mask/VideoPlayback.show()

	_refresh_marquee_layout()

func _set_album_text(album: String) -> void:
	if album.is_empty():
		$album/text.text = ""
		$album.hide()
	else:
		$album/text.text = "[b]%s[/b]" % album
		$album.show()

func _restore_local_cover_and_colors() -> void:
	if _local_cover_texture != null:
		$cover_mask/cover.texture = _local_cover_texture
		$cover_mask/square_cover.texture = _local_cover_texture
		if not showing:
			show_cover()
	elif not data.is_empty():
		$cover_mask/cover.texture = _default_cover_texture
		$cover_mask/square_cover.texture = _default_square_cover_texture
		hide_cover()
	else:
		$cover_mask/cover.texture = _default_cover_texture
		$cover_mask/square_cover.texture = _default_square_cover_texture

	_transition_background_colors(_local_background_primary, _local_background_secondary)

func _clear_external_artwork_cache() -> void:
	_last_external_artwork_bytes = PackedByteArray()
	_external_artwork_texture = null
	_external_artwork_decode_failed = false
	_external_background_primary = Color.WHITE
	_external_background_secondary = Color.WHITE

func _get_image(source: Variant) -> Image:
	if source is Image:
		return source
	if source is Texture2D:
		return source.get_image()
	return null

func _apply_artwork_colors(image: Image) -> void:
	var palette: Array[Color] = _extract_artwork_colors(image)
	_local_background_primary = palette[0]
	_local_background_secondary = palette[1]
	_transition_background_colors(_local_background_primary, _local_background_secondary)

func _extract_artwork_colors(image: Image) -> Array[Color]:
	var palette: Array[Color] = General.extract_dominant_colors(image)
	if palette.is_empty():
		palette = [
			General.get_dominant_color(image, 12),
			General.get_average_color(image, 16)
		]

	var primary: Color = _tone_background_color(palette[0])
	var secondary: Color
	if palette.size() > 1:
		secondary = _tone_background_color(palette[1])
	else:
		var hsv: Vector3 = General.rgb_to_hsv(primary)
		var complementary_color: Color = General.hsv_to_rgb(
			fposmod(hsv.x + 0.48, 1.0),
			minf(hsv.y, 0.65),
			minf(hsv.z * 1.1, 0.58)
		)
		secondary = _tone_background_color(complementary_color)
	var colors: Array[Color] = [primary, secondary]
	return colors

func _tone_background_color(color: Color) -> Color:
	var hsv: Vector3 = General.rgb_to_hsv(color)
	hsv.y = minf(hsv.y, 0.75)
	hsv.z = minf(hsv.z, 0.58)
	return General.hsv_to_rgb(hsv.x, hsv.y, hsv.z)

func _transition_background_colors(primary: Color, secondary: Color) -> void:
	if primary == _background_primary_target and secondary == _background_secondary_target:
		return

	if _artwork_color_tween and _artwork_color_tween.is_running():
		_artwork_color_tween.kill()

	_background_primary_target = primary
	_background_secondary_target = secondary
	_artwork_color_tween = create_tween().set_parallel()
	_artwork_color_tween.tween_property($bg_col, "color", primary, 0.5)
	_artwork_color_tween.tween_property($VideoPlayback2, "modulate", secondary, 0.5)
	_artwork_color_tween.tween_property($bg_col_grad, "self_modulate", primary, 0.5)
	_artwork_color_tween.tween_property($VideoPlayback, "modulate", primary, 0.5)

func _on_external_playback_status_changed(status: String) -> void:
	if not _external_media_active:
		return

	_external_media_info["playback_status"] = status
	$external_playpause.text = "" if status == "playing" else ""

func _on_external_media_position_changed(position_ms: int, duration_ms: int) -> void:
	if not _external_media_active or _external_seek_pending:
		return

	length = float(duration_ms) / 1000.0
	current_pos = float(position_ms) / 1000.0
	$length.text = General.format_time(current_pos) + " / " + General.format_time(length)
	if not seeking:
		if length > 0.0:
			$progress.value = clampf(current_pos / length * 100.0, 0.0, 100.0)
		else:
			$progress.value = 0.0

func _on_external_playback_command_state_changed(_command: String) -> void:
	_update_external_controls()

func _on_external_playback_command_completed(command: String, succeeded: bool) -> void:
	if command == "seek":
		_external_seek_pending = false
		seeking = false
		if succeeded:
			var seek_ms: int = _external_pending_seek_ms
			current_pos = float(seek_ms) / 1000.0
			current_pos = clampf(current_pos, 0.0, length)
			_external_media_info["position_ms"] = int(current_pos * 1000.0)
			$length.text = General.format_time(current_pos) + " / " + General.format_time(length)
			if length > 0.0:
				$progress.value = clampf(current_pos / length * 100.0, 0.0, 100.0)
			else:
				$progress.value = 0.0
			_update_external_controls()
		else:
			_update_external_controls()
			_refresh_external_position()
		_external_pending_seek_ms = 0
	else:
		_update_external_controls()

func _update_external_controls() -> void:
	$previous.visible = not _external_media_active
	$playpause.visible = not _external_media_active
	$next.visible = not _external_media_active
	$external_previous.visible = _external_media_active
	$external_playpause.visible = _external_media_active
	$external_next.visible = _external_media_active

	_set_navigation_button_state($randomize, _external_media_active)
	_set_navigation_button_state($go_to_artist, _external_media_active or _local_navigation_disabled)
	_set_navigation_button_state($go_to_album, _external_media_active or _local_navigation_disabled)
	_set_navigation_button_state($go_to_song, _external_media_active or _local_go_to_song_disabled)

	var command_pending: bool = not WindowsMediaIntegration.outstanding_command.is_empty()
	var controls_enabled: bool = _external_media_active and not command_pending
	$external_previous.disabled = not controls_enabled
	$external_playpause.disabled = not controls_enabled
	$external_next.disabled = not controls_enabled
	$progress.editable = !_external_seek_pending or (_external_media_active and length <= 0.0)

	if _external_media_active:
		$external_playpause.text = "" if WindowsMediaIntegration.playback_status == "playing" else ""

func _set_navigation_button_state(button: BaseButton, disabled: bool) -> void:
	button.disabled = disabled
	button.modulate = Color(1.0, 1.0, 1.0, 0.25) if disabled else Color.WHITE
	button.mouse_filter = MOUSE_FILTER_IGNORE if disabled else MOUSE_FILTER_STOP

func _on_external_previous_pressed() -> void:
	$external_previous.release_focus()
	WindowsMediaIntegration.request_previous()

func _on_external_playpause_pressed() -> void:
	$external_playpause.release_focus()
	WindowsMediaIntegration.request_play_pause()

func _on_external_next_pressed() -> void:
	$external_next.release_focus()
	WindowsMediaIntegration.request_next()

func _refresh_external_position() -> void:
	if not _external_media_active:
		$progress.editable = true
		return

	var manager_info: Dictionary = WindowsMediaIntegration.media_info
	var position_ms: int = int(manager_info.get("position_ms", _external_media_info.get("position_ms", 0)))
	var duration_ms: int = int(manager_info.get("duration_ms", _external_media_info.get("duration_ms", 0)))
	length = float(duration_ms) / 1000.0
	current_pos = float(position_ms) / 1000.0
	current_pos = clampf(current_pos, 0.0, length if length > 0.0 else current_pos)
	$length.text = General.format_time(current_pos) + " / " + General.format_time(length)
	if length > 0.0:
		$progress.value = clampf(current_pos / length * 100.0, 0.0, 100.0)
	else:
		$progress.value = 0.0
	$progress.editable = !length <= 0.0

func _refresh_marquee_layout() -> void:
	_marquee_request_id += 1
	var request_id := _marquee_request_id
	await get_tree().process_frame
	if request_id != _marquee_request_id:
		return

	var title_label: RichTextLabel = $title_artist_cont/title/text
	var artist_label: RichTextLabel = $title_artist_cont/artist/text
	var title_content_width := maxf(title_label.get_content_width(), 0.0)
	var artist_content_width := maxf(artist_label.get_content_width(), 0.0)
	var title_base_width := minf(title_content_width, 340.0)
	var artist_base_width := minf(artist_content_width, 340.0)
	var title_viewport_width := minf(
		title_content_width,
		340.0 + maxf(340.0 - artist_base_width, 0.0)
	)
	var artist_viewport_width := minf(
		artist_content_width,
		340.0 + maxf(340.0 - title_base_width, 0.0)
	)
	_set_marquee_viewport_width($title_artist_cont/title, title_viewport_width)
	_set_marquee_viewport_width($title_artist_cont/artist, artist_viewport_width)
	await get_tree().process_frame
	if request_id != _marquee_request_id:
		return

	_configure_marquee($title_artist_cont/title, $title_artist_cont/title/text, title_viewport_width)
	_configure_marquee($title_artist_cont/artist, $title_artist_cont/artist/text, artist_viewport_width)
	_configure_marquee($album, $album/text, 560.0)

	_title_scroll_tween = _start_marquee(
		$title_artist_cont/title,
		$title_artist_cont/title/text,
		_title_scroll_tween
	)
	_artist_scroll_tween = _start_marquee(
		$title_artist_cont/artist,
		$title_artist_cont/artist/text,
		_artist_scroll_tween
	)
	_album_scroll_tween = _start_marquee(
		$album,
		$album/text,
		_album_scroll_tween
	)
	_update_marquee_fades()

func _set_marquee_viewport_width(viewport: Control, width: float) -> void:
	viewport.custom_minimum_size.x = width

func _configure_marquee(viewport: Control, label: RichTextLabel, max_width: float) -> void:
	var text_width := maxf(label.get_content_width(), 0.0)
	var viewport_width := minf(viewport.size.x, max_width)
	var overflows := text_width > viewport_width + 1.0
	label.position = Vector2.ZERO
	label.size = Vector2(
		text_width + MARQUEE_TEXT_PADDING if overflows else viewport_width,
		viewport.size.y
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if overflows else HORIZONTAL_ALIGNMENT_CENTER

func _start_marquee(viewport: Control, label: RichTextLabel, current_tween: Tween) -> Tween:
	if current_tween and current_tween.is_running():
		current_tween.kill()

	var overflow := label.get_content_width() - viewport.size.x
	if overflow <= 1.0:
		label.position.x = 0.0
		return null

	var start_overscroll := 15.0
	var leftward_overscroll := 20.0
	var movement_distance := overflow + start_overscroll + leftward_overscroll
	var movement_time := maxf(movement_distance / 32.0, 0.5)
	label.position.x = start_overscroll
	var tween := create_tween().set_loops()
	tween.tween_interval(0.8)
	tween.tween_property(label, "position:x", -overflow - leftward_overscroll, movement_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_interval(1.0)
	tween.tween_property(label, "position:x", start_overscroll, movement_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_interval(1.5)
	return tween

func _update_marquee_fades() -> void:
	var screen_width := get_viewport_rect().size.x
	if screen_width <= 0.0:
		return

	_set_marquee_fade_bounds($title_artist_cont/title, $title_artist_cont/title/text, screen_width)
	_set_marquee_fade_bounds($title_artist_cont/artist, $title_artist_cont/artist/text, screen_width)
	_set_marquee_fade_bounds($album, $album/text, screen_width)

func _set_marquee_fade_bounds(viewport: Control, label: RichTextLabel, screen_width: float) -> void:
	var material := label.material as ShaderMaterial
	if not material:
		return
	var viewport_rect := viewport.get_global_rect()
	material.set_shader_parameter("left_edge", clampf(viewport_rect.position.x / screen_width, 0.0, 1.0))
	material.set_shader_parameter("right_edge", clampf(viewport_rect.end.x / screen_width, 0.0, 1.0))
	material.set_shader_parameter("fade_width", minf(24.0, viewport_rect.size.x * 0.15) / screen_width)
	material.set_shader_parameter("fade_enabled", label.get_content_width() > viewport.size.x + 1.0)

func set_time(time_s: float = 1.0):
	current_pos = time_s
	$length.text = General.format_time(current_pos) + " / " + General.format_time(length)
	if not seeking: $progress.value = (pos_ms / len_ms) * 100.0

func show_cover():
	$hide.stop()
	
	if OS.get_name() == "Windows": $hide.play("show")
	else: $hide.play("mbl_show")
	
	showing = true

func hide_cover():
	$hide.stop()
	
	if OS.get_name() == "Windows": $hide.play("hide")
	else: $hide.play("mbl_hide")
	
	showing = false

func _on_progress_value_changed(value: float) -> void:
	seeked.emit(value)

func _on_progress_drag_started() -> void:
	seeking = true
	seek_started.emit(current_pos)

func _on_progress_drag_ended(value_changed: bool) -> void:
	$progress.release_focus()
	if _external_media_active:
		if value_changed:
			var duration_ms: int = int(maxf(length, 0.0) * 1000.0)
			var target_ms: int = int(clampf($progress.value / 100.0, 0.0, 1.0) * duration_ms)
			_external_seek_pending = true
			_external_pending_seek_ms = target_ms
			seeking = false
			$progress.editable = false
			if not WindowsMediaIntegration.request_seek(target_ms):
				_external_seek_pending = false
				seeking = false
				_update_external_controls()
				_refresh_external_position()
		else:
			seeking = false
			_refresh_external_position()
		return

	seeking = false
	seek_ended.emit(value_changed, ($progress.value * length) / 100.0)

func _on_randomize_pressed() -> void:
	$randomize.release_focus()
	randomized.emit()

func _on_previous_pressed() -> void:
	$previous.release_focus()
	prev_next_pressed.emit(stream, -1)

func _on_playpause_pressed() -> void:
	$playpause.release_focus()
	play_toggled.emit()
	if playing: 
		$playpause.text = ""
		playing = false
	else:
		$playpause.text = ""
		playing = true

func set_local_playback_state(is_playing: bool) -> void:
	playing = is_playing
	$playpause.text = "" if is_playing else ""

func _on_next_pressed() -> void:
	$next.release_focus()
	prev_next_pressed.emit(stream, 1)

func _on_go_to_song_pressed() -> void:
	$go_to_song.release_focus()
	going_to_song.emit(stream, !not_imported_stream)

func _on_go_to_album_pressed() -> void:
	$go_to_album.release_focus()
	going_to_album.emit(stream)

func _on_go_to_artist_pressed() -> void:
	$go_to_artist.release_focus()
	going_to_artist.emit(stream)

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

var cover_type: int = COVER_MODE_ROTATE_AND_SCALE

func _on_cover_mask_focus_entered() -> void:
	if Settings.misc.square_playing_bar_cover:
		return

	$cover_mask.release_focus()
	cover_type = COVER_MODE_STATIONARY if cover_type >= COVER_MODE_ROTATE_AND_SCALE else cover_type + 1
	_apply_cover_mode()
	cover_pressed.emit(_cover_mode_scales_with_audio())

func set_square_cover_enabled(enabled: bool) -> void:
	Settings.misc.square_playing_bar_cover = enabled
	_apply_cover_shape()

func cover_scales_with_audio() -> bool:
	return not Settings.misc.square_playing_bar_cover and _cover_mode_scales_with_audio()

func _cover_mode_scales_with_audio() -> bool:
	return cover_type == COVER_MODE_AUDIO_SCALE or cover_type == COVER_MODE_ROTATE_AND_SCALE

func _apply_cover_shape() -> void:
	var square_cover_enabled: bool = Settings.misc.square_playing_bar_cover
	$cover_mask/cover.visible = not square_cover_enabled
	$cover_mask/square_cover.visible = square_cover_enabled
	$cover_mask.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED if square_cover_enabled else CanvasItem.CLIP_CHILDREN_ONLY
	$cover_mask.focus_mode = Control.FOCUS_NONE if square_cover_enabled else Control.FOCUS_ALL
	$cover_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE if square_cover_enabled else Control.MOUSE_FILTER_STOP
	_apply_cover_mode()

func _apply_cover_mode() -> void:
	var square_cover_enabled: bool = Settings.misc.square_playing_bar_cover
	var should_rotate: bool = not square_cover_enabled and (
		cover_type == COVER_MODE_ROTATE or cover_type == COVER_MODE_ROTATE_AND_SCALE
	)
	if should_rotate:
		$AnimationPlayer.play("rotate")
	else:
		$AnimationPlayer.stop()
		$cover_mask/cover.rotation = 0.0
		$cover_mask/VideoPlayback.rotation = 0.0

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
