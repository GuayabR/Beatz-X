extends Node

var System: Variant

func _ready() -> void:
	System = get_parent()

var type_map = [
	"Effect",
	"Upleft",
	"Downleft",
	"Left",
	"Down",
	"Up",
	"Right",
	"Downright",
	"Upright"
]

func get_note_by_id(id: String) -> Dictionary:
	for n in System.notes:
		if n.get("id", "") == id:
			return n
	return {}

func _on_singular_ctx_hold_edit_text_submitted(new_text: String) -> void:
	if System.ctx_note == null:
		return

	var before := get_note_by_id(System.ctx_note.note_id)

	var value := float(new_text)
	var idx = System.ctx_note.note_index

	if idx < 0 or idx >= System.notes.size():
		return

	System.notes[idx]["hold"] = max(value, 0.0)
	System.ctx_note.hold_ms = max(value, 0.0)

	System._apply_note_changes()

	System.push_history({
		"mode": "hold",
		"before": [before.duplicate(true)],
		"after": [System.notes[idx].duplicate(true)],
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System.hide_all_note_context_menus()
	System.get_node("note_context/hold_edit").release_focus()

func _on_singular_ctx_timestamp_edit_text_submitted(new_text: String) -> void:
	if System.ctx_note == null:
		return

	var before := get_note_by_id(System.ctx_note.note_id)

	var value := float(new_text)
	var idx = System.ctx_note.note_index

	if idx < 0 or idx >= System.notes.size():
		return

	System.notes[idx]["timestamp"] = value
	System.ctx_note.timestamp = value

	System._apply_note_changes()

	var after = System.notes[idx].duplicate(true)

	System.push_history({
		"mode": "move",
		"before": [before.duplicate(true)],
		"after": [after],
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System.ChartDisplaySystem.calculate_difficulty_threaded()
	System.hide_all_note_context_menus()
	System.get_node("note_context/timestamp_edit").release_focus()


func _on_singular_ctx_type_drop_item_selected(index: int) -> void:
	if System.ctx_note == null:
		return

	var before := get_note_by_id(System.ctx_note.note_id)

	var idx = System.ctx_note.note_index
	if idx < 0 or idx >= System.notes.size():
		return

	System.notes[idx]["type"] = type_map[index]
	System.ctx_note.type = type_map[index]
	System.ctx_note.set_type(System.ctx_note.type)

	System._apply_note_changes()

	var after = System.notes[idx].duplicate(true)

	System.push_history({
		"mode": "move",
		"before": [before.duplicate(true)],
		"after": [after],
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System.ChartDisplaySystem.calculate_difficulty_threaded()
	System.hide_all_note_context_menus()
	System.get_node("note_context/type_drop").release_focus()


func _on_singular_ctx_delete_pressed() -> void:
	if System.ctx_note == null:
		return

	delete_notes([System.ctx_note])

	System.ctx_note = null
	System.ctx_note_index = -1

	_reindex_notes()

	System.get_node("note_context/btns_cont/delete").release_focus()
	System.get_node("note_context").hide()

func _on_singular_ctx_to_grid_pressed() -> void:
	System.get_node("note_context/btns_cont/to_grid_cont/to_grid").release_focus()

	align_notes_to_grid([System.ctx_note])

	System.hide_all_note_context_menus()

func _on_singular_ctx_snap_pressed() -> void:
	var btn = System.get_node("note_context/btns_cont/to_grid_cont/snap")

	btn.release_focus()

	cycle_context_snap(btn)

func _reindex_notes():
	for i in range(System.notes.size()):
		var node = System.rendered_notes.get(i)
		if node:
			node.note_index = i

func _on_multiple_ctx_timestamp_edit_text_submitted(new_text: String) -> void:
	if System.ctx_multiple_notes.is_empty():
		return

	_sort_ctx_multiple_notes()

	var target_timestamp := float(new_text)
	var first_note = System.ctx_multiple_notes[0]
	var delta = target_timestamp - first_note.timestamp

	var before := []

	for n in System.ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for n in System.ctx_multiple_notes:
		n.timestamp += delta

		var y = (
			(n.timestamp + System.OFFSET + System.BASE_TIME)
			* System.note_speed / 10.0
		) * -1

		n.position.y = y

	var after := []

	for n in System.ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	System.push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System._apply_multiple_note_changes()
	System.hide_all_note_context_menus()
	System.ChartDisplaySystem._setup_notes()
	System.get_node("multiple_note_context/timestamp_edit").release_focus()


func _on_multiple_ctx_align_pressed() -> void:
	if System.ctx_multiple_notes.is_empty():
		return

	_sort_ctx_multiple_notes()

	var target_timestamp = System.ctx_multiple_notes[0].timestamp

	var before := []

	for n in System.ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for n in System.ctx_multiple_notes:
		n.timestamp = target_timestamp

		var y = (
			(n.timestamp + System.OFFSET + System.BASE_TIME)
			* System.note_speed / 10.0
		) * -1

		n.position.y = y

	var after := []

	for n in System.ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	System.push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System._apply_multiple_note_changes()
	System.hide_all_note_context_menus()
	System.ChartDisplaySystem._setup_notes()
	System.get_node("multiple_note_context/btns_cont/align").release_focus()


func _on_multiple_ctx_stream_pressed() -> void:
	if System.ctx_multiple_notes.size() < 3:
		return

	_sort_ctx_multiple_notes()

	var first = System.ctx_multiple_notes[0]
	var last = System.ctx_multiple_notes[-1]

	var start_time = first.timestamp
	var end_time = last.timestamp
	var count = System.ctx_multiple_notes.size()

	var spacing = (end_time - start_time) / float(count - 1)

	var before := []

	for n in System.ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for i in range(count):
		var n = System.ctx_multiple_notes[i]

		n.timestamp = start_time + (spacing * i)

		var y = (
			(n.timestamp + System.OFFSET + System.BASE_TIME)
			* System.note_speed / 10.0
		) * -1

		n.position.y = y

	var after := []

	for n in System.ctx_multiple_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	System.push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System._apply_multiple_note_changes()
	System.hide_all_note_context_menus()
	System.ChartDisplaySystem._setup_notes()
	System.get_node("multiple_note_context/btns_cont/stream").release_focus()

func _sort_ctx_multiple_notes():
	System.ctx_multiple_notes.sort_custom(func(a, b):
		return a.timestamp < b.timestamp
	)

func _on_multiple_ctx_delete_pressed() -> void:
	System.get_node("multiple_note_context/btns_cont/delete").release_focus()

	delete_notes(System.ctx_multiple_notes)

func delete_notes(targets: Array) -> void:
	if targets.is_empty():
		return

	var before := []
	var indices := []

	for n in targets:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

		indices.append(n.note_index)

	indices.sort()
	indices.reverse()

	for idx in indices:
		if idx >= 0 and idx < System.notes.size():
			System.notes.remove_at(idx)

		if System.rendered_notes.has(idx):
			var obj = System.rendered_notes[idx]
			if is_instance_valid(obj):
				obj.queue_free()
			System.rendered_notes.erase(idx)

	System.selected_notes.clear()
	System.ctx_multiple_notes.clear()

	System.ChartDisplaySystem._setup_notes()
	System.set_save_warn()
	System.ChartDisplaySystem.calculate_difficulty_threaded()

	System.push_history({
		"mode": "multi_delete",
		"before": before,
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System.hide_all_note_context_menus()

var context_snap_division := "1/4"

func cycle_context_snap(button: Button) -> void:
	var options = ["1/2", "1/4", "1/8", "1/16", "1/32", "1/64"]

	var current_index = options.find(context_snap_division)

	if current_index == -1:
		current_index = 0

	current_index = (current_index + 1) % options.size()

	context_snap_division = options[current_index]

	button.text = context_snap_division

func get_snap_interval_from_division(div: String) -> float:
	match div:
		"1/2":
			return System.doubles

		"1/4":
			return System.quads

		"1/8":
			return System.eights

		"1/16":
			return System.sixteenths

		"1/32":
			return System.thirtyseconds

		"1/64":
			return System.sixtyfourths

	return 0.0

func snap_timestamp_to_division(timestamp: float, div: String) -> float:
	var interval := get_snap_interval_from_division(div)

	if interval <= 0.0:
		return timestamp

	var snapped_value = snapped(timestamp, interval)

	return snapped_value

func align_notes_to_grid(target_notes: Array):
	var before := []

	for n in target_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			before.append(snap.duplicate(true))

	for n in target_notes:
		if not is_instance_valid(n):
			continue

		var snapped_timestamp = snap_timestamp_to_division(
			n.timestamp,
			context_snap_division
		)

		# visual node
		n.timestamp = snapped_timestamp

		# actual chart data
		if n.note_index >= 0 and n.note_index < System.notes.size():
			System.notes[n.note_index]["timestamp"] = snapped_timestamp

		var new_y = (
			(snapped_timestamp + System.BASE_TIME - System.OFFSET)
			* System.note_speed
			/ System.zoom
		) * -1.0

		n.position.y = new_y

	var after := []

	for n in target_notes:
		var snap = get_note_by_id(n.note_id)
		if snap:
			after.append(snap.duplicate(true))

	System.push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System.set_save_warn()
	System.ChartDisplaySystem.calculate_difficulty_threaded()

func _on_multiple_ctx_to_grid_pressed() -> void:
	System.get_node("multiple_note_context/btns_cont/to_grid_cont/to_grid").release_focus()

	align_notes_to_grid(System.selected_notes)
	System.hide_all_note_context_menus()

func _on_multiple_ctx_snap_pressed() -> void:
	System.get_node("multiple_note_context/btns_cont/to_grid_cont/snap").release_focus()

	cycle_context_snap(System.get_node("multiple_note_context/btns_cont/to_grid_cont/snap"))


func _on_settings_editor_diff_graph_toggled(toggled_on: bool) -> void:
	if not toggled_on:
		for color in System.get_node("Control/chart_controls/chart_scroll").get_children():
			color.queue_free()
	else:
		System.ChartDisplaySystem.update_difficulty_graph()


func _on_settings_selection_box_quality_changed(toggled_on: bool) -> void:
	if toggled_on: System.selection_box = System.get_node("selection_box_hq")
	else: System.selection_box = System.get_node("selection_box")

var copied_notes: Array = []

var flip_note_map := {
	"Left": "Right",
	"Right": "Left",

	"Upleft": "Upright",
	"Upright": "Upleft",

	"Downleft": "Downright",
	"Downright": "Downleft",

	"Up": "Down",
	"Down": "Up",
	"Effect": "Effect"
}

func _on_multiple_ctx_copy_pressed() -> void:
	copy_selected_notes()

	System.hide_all_note_context_menus()

	System.get_node("note_context/btns_cont/copycutpaste/copy").release_focus()


func _on_multiple_ctx_cut_pressed() -> void:
	cut_selected_notes()

	System.hide_all_note_context_menus()

	System.get_node("multiple_note_context/btns_cont/copycutpaste/cut").release_focus()

func _on_multiple_ctx_mirror_pressed() -> void:
	if System.ctx_multiple_notes.is_empty():
		return

	var before := []

	for n in System.ctx_multiple_notes:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)

		if snap.is_empty():
			continue

		before.append(snap.duplicate(true))

	for n in System.ctx_multiple_notes:
		if not is_instance_valid(n):
			continue

		var idx = n.note_index

		if idx < 0 or idx >= System.notes.size():
			continue

		var old_type: String = System.notes[idx]["type"]

		if not flip_note_map.has(old_type):
			continue

		var new_type: String = flip_note_map[old_type]

		System.notes[idx]["type"] = new_type

		n.type = new_type
		n.set_type(new_type)

	var after := []

	for n in System.ctx_multiple_notes:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)

		if snap.is_empty():
			continue

		after.append(snap.duplicate(true))

	System.push_history({
		"mode": "multi",
		"before": before,
		"after": after,
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System._apply_multiple_note_changes()

	System.set_save_warn()
	System.ChartDisplaySystem.calculate_difficulty_threaded()

	System.hide_all_note_context_menus()
	System.get_node("multiple_note_context/btns_cont/mirror").release_focus()

func _on_singular_ctx_copy_pressed() -> void:
	copy_selected_notes()

	System.hide_all_note_context_menus()
	System.get_node("note_context/btns_cont/copycutpaste/copy").release_focus()


func _on_singular_ctx_cut_pressed() -> void:
	cut_selected_notes()

	System.hide_all_note_context_menus()
	System.get_node("note_context/btns_cont/copycutpaste/cut").release_focus()

func _on_singular_ctx_flip_pressed() -> void:
	if System.ctx_note == null:
		return

	var idx = System.ctx_note.note_index

	if idx < 0 or idx >= System.notes.size():
		return

	var before = System.notes[idx].duplicate(true)

	var old_type: String = System.notes[idx]["type"]

	if not flip_note_map.has(old_type):
		return

	var new_type: String = flip_note_map[old_type]

	System.notes[idx]["type"] = new_type

	System.ctx_note.type = new_type
	System.ctx_note.set_type(new_type)

	var after = System.notes[idx].duplicate(true)

	System.push_history({
		"mode": "move",
		"before": [before],
		"after": [after],
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System._apply_note_changes()

	System.set_save_warn()
	System.ChartDisplaySystem.calculate_difficulty_threaded()

	System.hide_all_note_context_menus()
	System.get_node("note_context/btns_cont/flip").release_focus()





var no_ctx_place_hold := 0.0
var no_ctx_place_type := "Left"

func _on_no_ctx_hold_edit_text_changed(new_text: String) -> void:
	no_ctx_place_hold = max(float(new_text), 0.0)


func _on_no_ctx_type_drop_item_selected(index: int) -> void:
	if index < 0 or index >= type_map.size():
		return

	no_ctx_place_type = type_map[index]


func _on_no_ctx_place_pressed() -> void:
	var local_pos = System.get_node("notes").to_local(System.ctx_menu_anchor_pos - Vector2(15, 15))

	var timestamp = (
		((local_pos.y * -1.0) * System.zoom / System.note_speed)
		- System.BASE_TIME
		- System.OFFSET * 2
	)

	var new_note := {
		"id": str(Time.get_ticks_usec()),
		"type": no_ctx_place_type,
		"timestamp": snappedf(timestamp, 0.01),
		"hold": no_ctx_place_hold
	}

	System.notes.append(new_note)

	System.push_history({
		"mode": "place",
		"note": new_note.duplicate(true),
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System.hide_all_note_context_menus()

	System.ChartDisplaySystem._setup_notes()

	System.set_save_warn()
	System.ChartDisplaySystem.calculate_difficulty_threaded()

	System.get_node("no_note_context/place").release_focus()


func _on_no_ctx_paste_pressed() -> void:
	paste_copied_notes(true)

	System.get_node("no_note_context/btns_cont/paste").release_focus()

func copy_selected_notes():
	if System.selected_notes.is_empty():
		return

	copied_notes.clear()

	for n in System.selected_notes:
		if not is_instance_valid(n):
			continue

		var snap = get_note_by_id(n.note_id)

		if snap.is_empty():
			continue

		copied_notes.append(snap.duplicate(true))


func cut_selected_notes():
	if System.selected_notes.is_empty():
		return

	copy_selected_notes()
	delete_notes(System.selected_notes)


func paste_copied_notes(use_context_menu_position := false):
	if copied_notes.is_empty():
		return

	var paste_pos: Vector2

	if use_context_menu_position:
		paste_pos = System.ctx_menu_anchor_pos - Vector2(15, 15)
	else:
		paste_pos = System.get_global_mouse_position()

	var local_pos = System.get_node("notes").to_local(paste_pos)

	var target_timestamp = (
		((local_pos.y * -1.0) * System.zoom / System.note_speed)
		- System.BASE_TIME
		- System.OFFSET * 2
	)

	var pasted_notes := []

	var first_timestamp = copied_notes[0]["timestamp"]

	for note in copied_notes:
		first_timestamp = min(
			first_timestamp,
			note["timestamp"]
		)

	for note in copied_notes:
		var new_note = note.duplicate(true)

		var relative_offset = (
			note["timestamp"] - first_timestamp
		)

		new_note["id"] = General.generate_note_id()

		new_note["timestamp"] = snappedf(
			target_timestamp + relative_offset,
			0.01
		)

		System.notes.append(new_note)

		pasted_notes.append(
			new_note.duplicate(true)
		)

	System.push_history({
		"mode": "multi_place",
		"notes": pasted_notes,
		"scroll": System.get_node("Control/chart_controls/chart_scroll").value
	})

	System.hide_all_note_context_menus()

	System.ChartDisplaySystem._setup_notes()

	System.set_save_warn()
	System.ChartDisplaySystem.calculate_difficulty_threaded()

func _on_no_ctx_create_stream_pressed() -> void:
	pass # Replace with function body.


func _on_no_ctx_space_pressed() -> void:
	pass # Replace with function body.


func _on_no_ctx_place_jack_pressed() -> void:
	pass # Replace with function body.


func _on_no_ctx_jack_quantity_pressed() -> void:
	pass # Replace with function body.
