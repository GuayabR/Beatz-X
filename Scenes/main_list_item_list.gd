extends ItemList

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			accept_event()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			accept_event()
			return
