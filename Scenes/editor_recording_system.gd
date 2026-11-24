extends Node

var System: Variant

var recording: bool = false
var recording_paused: bool = false
var section_start_ms: float = 0.0
var section_end_ms: float = 0.0
var lead_in_ms: float = 0.0
var playback_start_ms: float = 0.0
var paused_position_ms: float = 0.0
var recording_speed: float = 1.0
var before_notes: Array = []
var recorded_notes: Array = []
var active_recorded_holds: Dictionary = {}
var range_preview_active: bool = false
var chart_position_selecting: bool = false
var chart_position_target: String = ""
var active_chart_position_button: Button
var chart_selection_overlay_modulate: Color
var chart_selection_overlay_mouse_filter: int
var panel_position_tween: Tween

func _ready() -> void:
	System = get_parent()

func _format_time(value: float) -> String:
	var total_milliseconds: int = int(round(max(value, 0.0) * 1000.0))
	var minutes: int = total_milliseconds / 60000
	var seconds: int = (total_milliseconds % 60000) / 1000
	var milliseconds: int = total_milliseconds % 1000
	return "%d:%02d:%03d" % [minutes, seconds, milliseconds]

func _parse_time_component(text: String) -> float:
	var input := text.strip_edges()
	if input.is_empty() or not RegEx.create_from_string("^[0-9+\\-*/().\\s]+$").search(input):
		return -1.0
	var expression := Expression.new()
	if expression.parse(input) != OK:
		return -1.0
	var result: Variant = expression.execute()
	if typeof(result) not in [TYPE_INT, TYPE_FLOAT]:
		return -1.0
	var value := float(result)
	return value if is_finite(value) and value >= 0.0 else -1.0

func _parse_time_value(text: String) -> float:
	var parts := text.strip_edges().split(":")
	if parts.size() < 1 or parts.size() > 3:
		return -1.0
	var values: Array[float] = []
	for part in parts:
		var value := _parse_time_component(part)
		if value < 0.0:
			return -1.0
		values.append(value)
	match values.size():
		1:
			return values[0]
		2:
			return values[0] * 60.0 + values[1]
		3:
			return values[0] * 60.0 + values[1] + values[2] / 1000.0
	return -1.0

func _apply_range_visuals(start_ms: float, end_ms: float) -> void:
	for note_node in System.get_node("notes").get_children():
		if note_node.name == "preview":
			continue
		if not "timestamp" in note_node:
			continue
		var note_timestamp: float = float(note_node.timestamp)
		var note_hold: float = float(note_node.hold_ms) if note_node.hold_ms > 0.0 else 0.0
		var intersects: bool = (
			note_timestamp >= start_ms
			and note_timestamp <= end_ms
		) or (
			note_hold > 0.0
			and note_timestamp + note_hold >= start_ms
			and note_timestamp <= end_ms
		)
		if intersects:
			note_node.apply_recording_range_dim()
		else:
			note_node.restore_recording_range_modulate()

func _restore_range_visuals() -> void:
	for note_node in System.get_node("notes").get_children():
		if "restore_recording_range_modulate" in note_node:
			note_node.restore_recording_range_modulate()

func refresh_note_range_visual(note_node: Node2D) -> void:
	if not range_preview_active:
		if "restore_recording_range_modulate" in note_node:
			note_node.restore_recording_range_modulate()
		return
	if not "timestamp" in note_node:
		return

	var note_timestamp: float = float(note_node.timestamp)
	var note_hold: float = float(note_node.hold_ms) if note_node.hold_ms > 0.0 else 0.0
	var intersects: bool = (
		note_timestamp >= section_start_ms
		and note_timestamp <= section_end_ms
	) or (
		note_hold > 0.0
		and note_timestamp + note_hold >= section_start_ms
		and note_timestamp <= section_end_ms
	)
	if intersects:
		note_node.apply_recording_range_dim()
	else:
		note_node.restore_recording_range_modulate()

func open_panel() -> void:
	if recording:
		_finish_recording()
		return
	if System.setting_up:
		return

	var start_seconds: float = clampf(System.get_node("Control/chart_controls/chart_scroll").value, 0.0, System.song_len)
	var end_seconds: float = clampf(start_seconds + 10.0, 0.0, System.song_len)
	if end_seconds <= start_seconds:
		end_seconds = System.song_len

	var panel: Control = System.get_node("Control/recording_panel")
	var start_slider: HSlider = panel.get_node("start_slider")
	var end_slider: HSlider = panel.get_node("end_slider")
	var lead_slider: HSlider = panel.get_node("lead_slider")
	var speed_slider: HSlider = panel.get_node("speed_slider")

	start_slider.max_value = System.song_len
	end_slider.max_value = System.song_len
	lead_slider.max_value = 10.0

	start_slider.set_value_no_signal(start_seconds)
	end_slider.set_value_no_signal(end_seconds)
	lead_slider.set_value_no_signal(2.0)
	speed_slider.set_value_no_signal(recording_speed)
	panel.get_node("status_lbl").text = ""
	_on_recording_speed_changed(recording_speed)
	range_preview_active = true

	_on_start_value_changed(start_seconds)
	_on_end_value_changed(end_seconds)
	_on_lead_value_changed(2.0)
	_apply_range_visuals(start_seconds * 1000.0, end_seconds * 1000.0)
	System.transition(panel, "scale", Vector2.ONE, 0.2, false, false)

func close_panel() -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	_leave_chart_position_mode(false)
	range_preview_active = false
	_restore_range_visuals()
	System.transition(panel, "scale", Vector2.ZERO, 0.2, true, false)

func _on_start_value_changed(value: float) -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	panel.get_node("start_lbl").text = "Recording Start: " + _format_time(value)
	section_start_ms = value * 1000.0
	var end_slider: HSlider = panel.get_node("end_slider")
	if end_slider.value <= value:
		end_slider.set_value_no_signal(min(value + 1.0, System.song_len))
		_on_end_value_changed(end_slider.value)
	else:
		_apply_range_visuals(section_start_ms, end_slider.value * 1000.0)

func _on_end_value_changed(value: float) -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	panel.get_node("end_lbl").text = "Recording End: " + _format_time(value)
	section_end_ms = value * 1000.0
	var start_slider: HSlider = System.get_node("Control/recording_panel/start_slider")
	_apply_range_visuals(start_slider.value * 1000.0, section_end_ms)

func _on_start_label_focus_entered() -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	var slider: HSlider = panel.get_node("start_slider")
	var label: RichTextLabel = panel.get_node("start_lbl")
	var edit: LineEdit = panel.get_node("start_edit")
	label.hide()
	edit.text = _format_time(slider.value)
	edit.show()
	edit.grab_focus()
	edit.select_all()

func _on_end_label_focus_entered() -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	var slider: HSlider = panel.get_node("end_slider")
	var label: RichTextLabel = panel.get_node("end_lbl")
	var edit: LineEdit = panel.get_node("end_edit")
	label.hide()
	edit.text = _format_time(slider.value)
	edit.show()
	edit.grab_focus()
	edit.select_all()

func _on_start_edit_text_submitted(new_text: String) -> void:
	_submit_position_edit(new_text, "start")

func _on_end_edit_text_submitted(new_text: String) -> void:
	_submit_position_edit(new_text, "end")

func _submit_position_edit(new_text: String, position_type: String) -> void:
	var value := _parse_time_value(new_text)
	if value < 0.0:
		push_warning("Invalid recording %s position: %s" % [position_type, new_text])
		return

	var panel: Control = System.get_node("Control/recording_panel")
	var slider: HSlider = panel.get_node("%s_slider" % position_type)
	slider.value = clampf(value, 0.0, System.song_len)
	var edit: LineEdit = panel.get_node("%s_edit" % position_type)
	edit.release_focus()
	edit.hide()
	panel.get_node("%s_lbl" % position_type).show()

func _on_start_edit_focus_exited() -> void:
	_hide_position_edit("start")

func _on_end_edit_focus_exited() -> void:
	_hide_position_edit("end")

func _hide_position_edit(position_type: String) -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	panel.get_node("%s_edit" % position_type).hide()
	panel.get_node("%s_lbl" % position_type).show()

func _on_lead_value_changed(value: float) -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	panel.get_node("lead_lbl").text = "Recording Lead-in: %.2fs" % value

func _on_recording_speed_changed(value: float) -> void:
	recording_speed = value
	var panel: Control = System.get_node("Control/recording_panel")
	panel.get_node("speed_lbl").text = "Recording Speed: %.2fx" % value

func _on_use_current_start_pressed() -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	var slider: HSlider = panel.get_node("start_slider")
	slider.value = clampf(System.get_node("Control/chart_controls/chart_scroll").value, 0.0, System.song_len)
	_on_start_value_changed(slider.value)

func _on_use_current_end_pressed() -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	var slider: HSlider = panel.get_node("end_slider")
	slider.value = clampf(System.get_node("Control/chart_controls/chart_scroll").value, 0.0, System.song_len)
	_on_end_value_changed(slider.value)

func _on_set_start_from_chart_pressed() -> void:
	_toggle_chart_position_selection("start", System.get_node("Control/recording_panel/start_from_chart") as Button)

func _on_set_end_from_chart_pressed() -> void:
	_toggle_chart_position_selection("end", System.get_node("Control/recording_panel/end_from_chart") as Button)

func _toggle_chart_position_selection(position_type: String, button: Button) -> void:
	if chart_position_selecting:
		if chart_position_target != position_type:
			return
		var chart_position: float = clampf(
			System.get_node("Control/chart_controls/chart_scroll").value,
			0.0,
			System.song_len
		)
		var panel: Control = System.get_node("Control/recording_panel")
		var slider: HSlider = panel.get_node("%s_slider" % position_type)
		slider.set_value_no_signal(chart_position)
		if position_type == "start":
			_on_start_value_changed(chart_position)
		else:
			_on_end_value_changed(chart_position)
		panel.get_node("status_lbl").text = ""
		_leave_chart_position_mode(true)
		return

	chart_position_selecting = true
	chart_position_target = position_type
	active_chart_position_button = button
	button.text = "Confirm Recording %s" % position_type.capitalize()
	_set_panel_controls_for_chart_selection(button)

	var panel: Control = System.get_node("Control/recording_panel")
	panel.get_node("status_lbl").text = "Scroll or play the chart, then confirm the position."
	var overlay: Control = System.get_node("overlay")
	chart_selection_overlay_modulate = overlay.modulate
	chart_selection_overlay_mouse_filter = overlay.mouse_filter
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport_size: Vector2 = System.get_viewport_rect().size
	var scaled_panel_width: float = panel.get_node("Panel").size.x * 0.8
	var left_position := Vector2(
		75.0 + scaled_panel_width * 0.5 - panel.size.x * 0.5,
		viewport_size.y * 0.5 - panel.size.y * 0.5
	)
	_animate_chart_selection_transition(
		panel,
		overlay,
		left_position,
		Color(0.0, 0.0, 0.0, 0.0),
		true,
		Vector2(0.8, 0.8)
	)

func _set_panel_controls_for_chart_selection(active_button: Button) -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	for button_name in ["use_start", "start_from_chart", "use_end", "end_from_chart", "start_recording", "cancel"]:
		var button: Button = panel.get_node(button_name)
		button.disabled = button != active_button

	for slider_name in ["start_slider", "end_slider", "lead_slider", "speed_slider"]:
		var slider: HSlider = panel.get_node(slider_name)
		slider.editable = false

	for position_type in ["start", "end"]:
		var label: RichTextLabel = panel.get_node("%s_lbl" % position_type)
		var edit: LineEdit = panel.get_node("%s_edit" % position_type)
		edit.release_focus()
		edit.hide()
		label.show()
		label.focus_mode = Control.FOCUS_NONE
		edit.editable = false

func _restore_panel_controls_after_chart_selection() -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	for button_name in ["use_start", "start_from_chart", "use_end", "end_from_chart", "start_recording", "cancel"]:
		panel.get_node(button_name).disabled = false

	for slider_name in ["start_slider", "end_slider", "lead_slider", "speed_slider"]:
		panel.get_node(slider_name).editable = true

	for position_type in ["start", "end"]:
		panel.get_node("%s_lbl" % position_type).focus_mode = Control.FOCUS_CLICK
		panel.get_node("%s_edit" % position_type).editable = true

	panel.get_node("start_from_chart").text = "Set Position from Chart"
	panel.get_node("end_from_chart").text = "Set Position from Chart"

func _leave_chart_position_mode(restore_overlay: bool) -> void:
	if not chart_position_selecting:
		return

	chart_position_selecting = false
	chart_position_target = ""
	_restore_panel_controls_after_chart_selection()
	active_chart_position_button = null

	var panel: Control = System.get_node("Control/recording_panel")
	var overlay: Control = System.get_node("overlay")
	overlay.mouse_filter = chart_selection_overlay_mouse_filter

	var viewport_size: Vector2 = System.get_viewport_rect().size
	var center_position := Vector2(
		viewport_size.x * 0.5 - panel.size.x * 0.5,
		viewport_size.y * 0.5 - panel.size.y * 0.5
	)
	var target_overlay_modulate: Color = chart_selection_overlay_modulate if restore_overlay else overlay.modulate
	var target_scale: Vector2 = Vector2.ONE if restore_overlay else panel.scale
	_animate_chart_selection_transition(
		panel,
		overlay,
		center_position,
		target_overlay_modulate,
		restore_overlay,
		target_scale,
		restore_overlay
	)

func _animate_chart_selection_transition(
	panel: Control,
	overlay: Control,
	target_position: Vector2,
	target_overlay_modulate: Color,
	animate_overlay: bool = true,
	target_scale: Vector2 = Vector2.ONE,
	animate_scale: bool = true
) -> void:
	if panel_position_tween and panel_position_tween.is_running():
		panel_position_tween.kill()
	panel_position_tween = System.create_tween()
	panel_position_tween.set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_IN_OUT)
	panel_position_tween.tween_property(panel, "position", target_position, 0.25)
	if animate_scale:
		panel_position_tween.parallel().tween_property(panel, "scale", target_scale, 0.25)
	if animate_overlay:
		panel_position_tween.parallel().tween_property(overlay, "modulate", target_overlay_modulate, 0.25)

func _on_start_recording_pressed() -> void:
	var panel: Control = System.get_node("Control/recording_panel")
	section_start_ms = panel.get_node("start_slider").value * 1000.0
	section_end_ms = panel.get_node("end_slider").value * 1000.0
	lead_in_ms = panel.get_node("lead_slider").value * 1000.0

	if section_end_ms <= section_start_ms:
		panel.get_node("status_lbl").text = "End must be after start."
		return
	if section_start_ms < 0.0:
		panel.get_node("status_lbl").text = "Invalid recording section."
		return
	
	$"../Control/recording_panel/start_recording".release_focus()
	close_panel()
	_begin_recording()
	_apply_range_visuals(section_start_ms, section_end_ms)

func _begin_recording() -> void:
	before_notes = []
	for note_data in System.notes:
		before_notes.append(note_data.duplicate(true))

	recorded_notes.clear()
	active_recorded_holds.clear()
	recording = true
	recording_paused = false
	range_preview_active = true
	paused_position_ms = 0.0
	playback_start_ms = max(section_start_ms - lead_in_ms, 0.0)

	System.save_editor_mode()
	if System.preview_note:
		System.preview_note.hide()

	System.playing = true
	System.get_node("Control/chart_btns/btn_cont/play").text = "Pause"
	System.get_node("Control/chart_btns/btn_cont/record").text = "Stop"
	System.get_node("Control/chart_btns/btn_cont/playtest").disabled = true
	System.get_node("Control/chart_controls/chart_scroll").value = playback_start_ms / 1000.0

	for btn in System.buttons_to_disable_on_play:
		if btn == null:
			continue
		if btn is Button:
			btn.disabled = true
		else:
			btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	System.get_node("song").pitch_scale = recording_speed
	System.get_node("song").play(playback_start_ms / 1000.0)
	if System.get_node("Control/VideoPlayback").is_open():
		System.get_node("Control/VideoPlayback").playback_speed = recording_speed
		var fps: float = System.get_node("Control/VideoPlayback").get_video_framerate()
		var target_frame: int = int((playback_start_ms / 1000.0) * fps)
		System.get_node("Control/VideoPlayback").seek_frame(clampi(target_frame, 0, System.get_node("Control/VideoPlayback").get_video_frame_count() - 1))
		System.get_node("Control/VideoPlayback").play()

func toggle_pause() -> void:
	if not recording:
		return
	if recording_paused:
		recording_paused = false
		var resume_ms: float = max(paused_position_ms - (Settings.game.pause_resume_time * 1000.0), playback_start_ms)
		System.get_node("song").pitch_scale = recording_speed
		System.get_node("song").play(resume_ms / 1000.0)
		if System.get_node("Control/VideoPlayback").is_open():
			System.get_node("Control/VideoPlayback").playback_speed = recording_speed
			var fps: float = System.get_node("Control/VideoPlayback").get_video_framerate()
			System.get_node("Control/VideoPlayback").seek_frame(clampi(int((resume_ms / 1000.0) * fps), 0, System.get_node("Control/VideoPlayback").get_video_frame_count() - 1))
			System.get_node("Control/VideoPlayback").play()
		return

	recording_paused = true
	paused_position_ms = System.get_node("song").get_playback_position() * 1000.0
	System.get_node("song").stop()
	System.get_node("song").pitch_scale = 1.0
	if System.get_node("Control/VideoPlayback").is_open():
		System.get_node("Control/VideoPlayback").pause()
		System.get_node("Control/VideoPlayback").playback_speed = 1.0

func _process(delta: float) -> void:
	if not recording or recording_paused:
		return

	var song: AudioStreamPlayer = System.get_node("song")
	var playback_ms: float = (song.get_playback_position() * 1000.0) - Beatz.BASE_REC_TIME_MS

	if playback_ms >= section_end_ms:
		_finish_recording()
		return

	System.get_node("Control/chart_controls/chart_scroll").set_value_no_signal(playback_ms / 1000.0)

	for action_name in System.note_data:
		var action_info: Dictionary = System.note_data[action_name]
		var lane_name: String = str(action_info.get("key", ""))
		if lane_name == "" or not InputMap.has_action(action_name):
			continue

		if playback_ms >= section_start_ms:
			if Input.is_action_just_pressed(action_name):
				_record_note_press(action_name, lane_name, playback_ms)
			elif Input.is_action_just_released(action_name):
				_record_note_release(action_name, playback_ms)

		if active_recorded_holds.has(action_name):
			_update_recorded_hold(action_name, playback_ms)

func _record_note_press(action_name: StringName, lane_name: String, playback_ms: float) -> void:
	if active_recorded_holds.has(action_name):
		return

	var note_data: Dictionary = {
		"id": General.generate_note_id(),
		"timestamp": snappedf(playback_ms, 1.0),
		"type": lane_name
	}
	recorded_notes.append(note_data)
	active_recorded_holds[action_name] = {
		"start_ms": playback_ms,
		"note_index": recorded_notes.size() - 1
	}

func _record_note_release(action_name: StringName, playback_ms: float) -> void:
	if not active_recorded_holds.has(action_name):
		return
	var hold_data: Dictionary = active_recorded_holds[action_name]
	active_recorded_holds.erase(action_name)
	var held_ms: float = max(playback_ms - float(hold_data.start_ms), 0.0)
	if held_ms >= 150.0:
		var note_index: int = int(hold_data.note_index)
		if note_index >= 0 and note_index < recorded_notes.size():
			recorded_notes[note_index]["hold"] = snappedf(held_ms, 1.0)

func _update_recorded_hold(action_name: StringName, playback_ms: float) -> void:
	if not active_recorded_holds.has(action_name):
		return
	var hold_data: Dictionary = active_recorded_holds[action_name]
	var held_ms: float = max(playback_ms - float(hold_data.start_ms), 0.0)
	var note_index: int = int(hold_data.note_index)
	if held_ms >= 150.0 and note_index >= 0 and note_index < recorded_notes.size():
		recorded_notes[note_index]["hold"] = snappedf(held_ms, 1.0)

func _finish_recording() -> void:
	if not recording:
		return

	var held_actions: Array = active_recorded_holds.keys()
	for action_name in held_actions:
		_record_note_release(action_name, section_end_ms)
	active_recorded_holds.clear()

	recording = false
	recording_paused = false
	range_preview_active = false
	System.playing = false
	System.get_node("song").stop()
	System.get_node("song").pitch_scale = 1.0
	if System.get_node("Control/VideoPlayback").is_open():
		System.get_node("Control/VideoPlayback").pause()
		System.get_node("Control/VideoPlayback").playback_speed = 1.0

	var range_start: float = section_start_ms
	var range_end: float = section_end_ms
	var kept_notes: Array = []

	for existing_note in System.notes:
		var note_start: float = float(existing_note.get("timestamp", 0.0))
		var note_end: float = note_start + float(existing_note.get("hold", 0.0))
		var intersects: bool = note_end >= range_start and note_start <= range_end
		if not intersects:
			kept_notes.append(existing_note.duplicate(true))

	var replacement_notes: Array = []
	for recorded_note in recorded_notes:
		replacement_notes.append(recorded_note.duplicate(true))

	System.notes = kept_notes
	System.notes.append_array(replacement_notes)
	System.notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("timestamp", 0.0)) < float(b.get("timestamp", 0.0))
	)

	var after_notes: Array = []
	for note_data in System.notes:
		after_notes.append(note_data.duplicate(true))

	System.push_history({
		"mode": "record_section",
		"before": before_notes,
		"after": after_notes,
		"scroll": range_end / 1000.0
	})

	System.restore_editor_mode()
	System.preview_note = System.preview_note
	if System.preview_note:
		System.preview_note.show()
	System.get_node("Control/chart_btns/btn_cont/play").text = "Play"
	System.get_node("Control/chart_btns/btn_cont/record").text = "Record"
	System.get_node("Control/chart_btns/btn_cont/playtest").disabled = false
	for btn in System.buttons_to_disable_on_play:
		if btn == null:
			continue
		if btn is Button:
			btn.disabled = false
		else:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP

	_restore_range_visuals()
	System.ChartDisplaySystem._setup_notes()
	System.ChartDisplaySystem.calculate_difficulty_threaded()
	System.set_save_warn()
	System.get_node("Control/chart_details/note_count").text = "Total notes: " + str(System.notes.size())
	System.get_node("Control/chart_controls/chart_scroll").value = range_end / 1000.0
