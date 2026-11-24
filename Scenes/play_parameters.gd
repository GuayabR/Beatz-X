extends Control
class_name PlayParameters

enum PanelMode { PLAY, RECORD }

signal confirmed(start_pos: float, playback_speed: float)
signal recording_confirmed(playback_speed: float)
signal change_file_requested

@onready var play_panel: Control = $Panel
@onready var recording_panel: Control = $RecordingPanel
@onready var start_position_slider: HSlider = $Panel/start_position_slider
@onready var start_position_label: RichTextLabel = $Panel/start_position_label
@onready var start_position_edit: LineEdit = $Panel/start_position_edit
@onready var playback_speed_slider: HSlider = $Panel/playback_speed_slider
@onready var playback_speed_label: RichTextLabel = $Panel/playback_speed_label
@onready var playback_speed_edit: LineEdit = $Panel/playback_speed_edit
@onready var recording_speed_slider: HSlider = $RecordingPanel/recording_speed_slider
@onready var recording_speed_label: RichTextLabel = $RecordingPanel/recording_speed_label
@onready var recording_speed_edit: LineEdit = $RecordingPanel/recording_speed_edit
@onready var recording_title: RichTextLabel = $RecordingPanel/recording_title
@onready var recording_artist: RichTextLabel = $RecordingPanel/recording_artist
@onready var recording_album: RichTextLabel = $RecordingPanel/recording_album
@onready var recording_year: RichTextLabel = $RecordingPanel/recording_year
@onready var recording_cover: TextureRect = $RecordingPanel/recording_cover
@onready var change_file_button: Button = $RecordingPanel/change_file
@onready var shade: ColorRect = $Shade

var panel_mode: int = PanelMode.PLAY
var song_length: float = 0.0
var recording_metadata: Dictionary = {}
var allow_file_change: bool = false
var initial_playback_speed: float = 1.0
var active_panel: Control
var transition_tween: Tween
var is_closing: bool = false

func configure(
	mode: int,
	length_seconds: float = 0.0,
	metadata: Dictionary = {},
	can_change_file: bool = false,
	playback_speed: float = 1.0
) -> void:
	panel_mode = mode
	song_length = length_seconds
	recording_metadata = metadata.duplicate()
	allow_file_change = can_change_file
	initial_playback_speed = playback_speed

func update_recording_metadata(metadata: Dictionary) -> void:
	recording_metadata = metadata.duplicate()
	if is_node_ready():
		_update_recording_metadata()

func _ready() -> void:
	if panel_mode == PanelMode.PLAY:
		active_panel = play_panel
		recording_panel.hide()
		play_panel.show()
		_configure_play_panel()
	else:
		active_panel = recording_panel
		play_panel.hide()
		recording_panel.show()
		_configure_recording_panel()

	active_panel.scale = Vector2.ZERO
	transition_tween = create_tween()
	transition_tween.tween_property(active_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CIRC)
	transition_tween.parallel().tween_property(shade, "color", Color(0, 0, 0, 0.5), 0.2).set_trans(Tween.TRANS_CUBIC)

func _configure_play_panel() -> void:
	start_position_slider.max_value = maxf(song_length, 0.01)
	start_position_slider.value = 0.0
	playback_speed_slider.min_value = 0.01
	playback_speed_slider.max_value = 8.0
	playback_speed_slider.step = 0.01
	playback_speed_slider.value = clampf(initial_playback_speed, 0.01, 8.0)
	_update_start_position_label(start_position_slider.value)
	_update_playback_speed_label(playback_speed_slider.value)

func _configure_recording_panel() -> void:
	recording_speed_slider.min_value = 0.01
	recording_speed_slider.max_value = 8.0
	recording_speed_slider.step = 0.01
	recording_speed_slider.value = clampf(initial_playback_speed, 0.01, 8.0)
	change_file_button.visible = allow_file_change
	_update_recording_speed_label(recording_speed_slider.value)
	_update_recording_metadata()

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	for edit in [start_position_edit, playback_speed_edit, recording_speed_edit]:
		if edit.visible and not edit.get_global_rect().has_point(event.position):
			edit.release_focus()

func _on_start_position_value_changed(value: float) -> void:
	_update_start_position_label(value)

func _on_playback_speed_value_changed(value: float) -> void:
	_update_playback_speed_label(value)

func _on_recording_speed_value_changed(value: float) -> void:
	_update_recording_speed_label(value)

func _on_start_position_label_focus_entered() -> void:
	start_position_label.hide()
	start_position_edit.text = "%.2f" % start_position_slider.value
	start_position_edit.show()
	start_position_edit.grab_focus()
	start_position_edit.select_all()

func _on_start_position_edit_text_submitted(new_text: String) -> void:
	var value := General._num_eval(new_text)
	if not is_finite(value):
		push_warning("Invalid start position: " + new_text)
		return
	start_position_slider.value = clampf(value, 0.0, start_position_slider.max_value)
	start_position_edit.release_focus()
	start_position_edit.hide()
	start_position_label.show()

func _on_start_position_edit_focus_exited() -> void:
	start_position_edit.hide()
	start_position_label.show()

func _on_playback_speed_label_focus_entered() -> void:
	playback_speed_label.hide()
	playback_speed_edit.text = "%.2f" % playback_speed_slider.value
	playback_speed_edit.show()
	playback_speed_edit.grab_focus()
	playback_speed_edit.select_all()

func _on_playback_speed_edit_text_submitted(new_text: String) -> void:
	var value := General._num_eval(new_text)
	if not is_finite(value):
		push_warning("Invalid playback speed: " + new_text)
		return
	playback_speed_slider.value = clampf(value, playback_speed_slider.min_value, playback_speed_slider.max_value)
	playback_speed_edit.release_focus()
	playback_speed_edit.hide()
	playback_speed_label.show()

func _on_playback_speed_edit_focus_exited() -> void:
	playback_speed_edit.hide()
	playback_speed_label.show()

func _on_recording_speed_label_focus_entered() -> void:
	recording_speed_label.hide()
	recording_speed_edit.text = "%.2f" % recording_speed_slider.value
	recording_speed_edit.show()
	recording_speed_edit.grab_focus()
	recording_speed_edit.select_all()

func _on_recording_speed_edit_text_submitted(new_text: String) -> void:
	var value := General._num_eval(new_text)
	if not is_finite(value):
		push_warning("Invalid recording speed: " + new_text)
		return
	recording_speed_slider.value = clampf(value, recording_speed_slider.min_value, recording_speed_slider.max_value)
	recording_speed_edit.release_focus()
	recording_speed_edit.hide()
	recording_speed_label.show()

func _on_recording_speed_edit_focus_exited() -> void:
	recording_speed_edit.hide()
	recording_speed_label.show()

func _update_start_position_label(value: float) -> void:
	start_position_label.text = "Start Position: %s" % General.format_time(value)

func _update_playback_speed_label(value: float) -> void:
	playback_speed_label.text = "Playback Speed: %.2fx" % value

func _update_recording_speed_label(value: float) -> void:
	recording_speed_label.text = "Recording Speed: %.2fx" % value

func _update_recording_metadata() -> void:
	recording_title.text = "Song: " + _metadata_text("title")
	recording_artist.text = "Artist: " + _metadata_text("artist")
	recording_album.text = "Album: " + _metadata_text("album")
	recording_year.text = "Year: " + _metadata_text("year")

	var cover_data: Variant = recording_metadata.get("cover")
	if cover_data is Image and not cover_data.is_empty():
		recording_cover.texture = ImageTexture.create_from_image(cover_data)
	elif cover_data is Texture2D:
		recording_cover.texture = cover_data
	else:
		recording_cover.texture = load("res://Resources/misc/noCover.png")

func _metadata_text(key: String) -> String:
	var value: String = str(recording_metadata.get(key, "")).strip_edges()
	if value == "" or (key == "year" and value == "0"):
		return "Unknown"
	return value

func _on_play_pressed() -> void:
	if is_closing:
		return
	confirmed.emit(start_position_slider.value, playback_speed_slider.value)
	_close()

func _on_record_pressed() -> void:
	if is_closing:
		return
	recording_confirmed.emit(recording_speed_slider.value)
	_close()

func _on_change_file_pressed() -> void:
	if not is_closing:
		change_file_requested.emit()

func _on_cancel_pressed() -> void:
	_close()

func _close() -> void:
	if is_closing:
		return
	is_closing = true
	if transition_tween != null and transition_tween.is_running():
		transition_tween.kill()
	transition_tween = create_tween()
	transition_tween.tween_property(active_panel, "scale", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_CIRC)
	transition_tween.parallel().tween_property(shade, "color", Color(0, 0, 0, 0), 0.2).set_trans(Tween.TRANS_CUBIC)
	transition_tween.finished.connect(queue_free)
