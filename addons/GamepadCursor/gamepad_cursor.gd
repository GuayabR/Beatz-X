@icon("res://addons/GamepadCursor/icon.png")
extends Node

@export_group("Visual", "Visual")
@export var custom_cursor_normal = load("res://addons/GamepadCursor/dry-clean.png")
@export var custom_cursor_pressed = load("res://addons/GamepadCursor/dry-clean-pressed.png")
@export_group("Action", "Controller Binds")
@export var action_button = JOY_BUTTON_A
@export var right_click_button = JOY_BUTTON_X
@export var mouse_sens: float = 400.0 

var tex: ImageTexture
var scale_factor: float

var time_pressed_start: float
var time_pressed_end: float

enum CursorShapes {
	CURSOR_ARROW,
	CURSOR_BDIAGSIZE,
	CURSOR_BUSY,
	CURSOR_CAN_DROP,
	CURSOR_CROSS,
	CURSOR_DRAG,
	CURSOR_FDIAGSIZE,
	CURSOR_FORBIDDEN,
	CURSOR_HELP,
	CURSOR_HSIZE,
	CURSOR_HSPLIT,
	CURSOR_IBEAM,
	CURSOR_MOVE,
	CURSOR_POINTING_HAND,
	CURSOR_VSIZE,
	CURSOR_VSPLIT,
	CURSOR_WAIT
}

func _ready():
	get_tree().get_root().size_changed.connect(resize)
	resize()
	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)


func resize():
	scale_factor = min(float(get_viewport().size.x) / get_viewport().get_visible_rect().size.x, float(get_viewport().size.y) / get_viewport().get_visible_rect().size.y)


func _set_cursor(type: Texture2D):
	if type == null:
		tex = null
		for i in CursorShapes:
			Input.set_custom_mouse_cursor(tex, Input[i])
	else:
		var img: Image = type.get_image()
		var size := Vector2(128, 128) * (scale_factor/2)
		img.resize(int(size.x), int(size.y))
		tex = ImageTexture.create_from_image(img)
		var hotspot := Vector2(64, 64) * (scale_factor/2)
		for i in CursorShapes:
			Input.set_custom_mouse_cursor(tex, Input[i], hotspot)

func _process(delta):
	var x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var y := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)

	var direction := Vector2(x, y)

	# deadzone
	if direction.length() < 0.1:
		return

	# circular clamp
	if direction.length() > 1.0:
		direction = direction.normalized()

	# smoother response curve
	var strength := pow(direction.length(), 1.4)

	var movement = direction.normalized() * strength * mouse_sens * delta

	get_viewport().warp_mouse(
		get_viewport().get_mouse_position() + movement
	)

func _input(event):
	if event is InputEventJoypadButton and event.device == 0:
		var mouse_button := -1

		if event.button_index == action_button:
			mouse_button = MOUSE_BUTTON_LEFT

		elif event.button_index == right_click_button:
			mouse_button = MOUSE_BUTTON_RIGHT

		if mouse_button != -1:
			var pressed = event.is_pressed()

			var joy_click := InputEventMouseButton.new()

			joy_click.button_index = mouse_button

			joy_click.position = (
				get_viewport()
				.get_final_transform()
				.basis_xform_inv(get_viewport().get_mouse_position())
			)

			joy_click.pressed = pressed

			Input.parse_input_event(joy_click)

			# only animate cursor for left click
			if mouse_button == MOUSE_BUTTON_LEFT:
				if pressed:
					_set_cursor(custom_cursor_pressed)
					time_pressed_start = Time.get_ticks_msec()

				else:
					_set_cursor(custom_cursor_normal)
					time_pressed_end = Time.get_ticks_msec()

					var time_pressed := (
						float(time_pressed_end - time_pressed_start)
						/ 1000.0
					)

	if event is InputEventKey and event.is_pressed():
		if event.physical_keycode:
			_set_cursor(null)
