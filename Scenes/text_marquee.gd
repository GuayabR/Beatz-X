extends Control

const TEXT_PADDING := 8.0
const START_OVERSCROLL := 15.0
const LEFTWARD_OVERSCROLL := 20.0
const FADE_SHADER: Shader = preload("res://Scenes/text_marquee_fade.gdshader")

@export var label_path: NodePath = "Text"
@export var max_width: float = 450.0
@export var expand_to_content: bool = true
@export var center_when_fitting: bool = false

var _label: RichTextLabel
var _fade_material: ShaderMaterial
var _scroll_tween: Tween
var _refresh_request_id := 0
var _initial_width := 0.0

func _ready() -> void:
	clip_contents = true
	_initial_width = size.x
	_label = get_node_or_null(label_path) as RichTextLabel
	if not _label:
		push_error("Text marquee is missing its RichTextLabel: %s" % label_path)
		return

	_fade_material = ShaderMaterial.new()
	_fade_material.shader = FADE_SHADER
	_label.material = _fade_material
	get_viewport().size_changed.connect(_update_fade_bounds)
	call_deferred("refresh")

func refresh() -> void:
	if not _label:
		return

	_refresh_request_id += 1
	var request_id := _refresh_request_id
	await get_tree().process_frame
	if request_id != _refresh_request_id or not is_instance_valid(_label):
		return

	var content_width := maxf(_label.get_content_width(), 0.0)
	if expand_to_content:
		size.x = minf(max_width, maxf(_initial_width, content_width))

	var overflows := content_width > size.x + 1.0
	_label.position = Vector2.ZERO
	_label.size = Vector2(content_width + TEXT_PADDING if overflows else size.x, size.y)
	_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_LEFT if overflows or not center_when_fitting
		else HORIZONTAL_ALIGNMENT_CENTER
	)
	_start_scroll(content_width, overflows)
	_update_fade_bounds()

func _start_scroll(content_width: float, overflows: bool) -> void:
	if _scroll_tween and _scroll_tween.is_running():
		_scroll_tween.kill()

	if not overflows:
		_label.position.x = 0.0
		return

	var overflow := content_width - size.x
	var movement_distance := overflow + START_OVERSCROLL + LEFTWARD_OVERSCROLL
	var movement_time := maxf(movement_distance / 32.0, 0.5)
	_label.position.x = START_OVERSCROLL
	_scroll_tween = create_tween().set_loops()
	_scroll_tween.tween_interval(0.8)
	_scroll_tween.tween_property(
		_label,
		"position:x",
		-overflow - LEFTWARD_OVERSCROLL,
		movement_time
	).set_trans(Tween.TRANS_LINEAR)
	_scroll_tween.tween_interval(1.0)
	_scroll_tween.tween_property(
		_label,
		"position:x",
		START_OVERSCROLL,
		movement_time
	).set_trans(Tween.TRANS_LINEAR)
	_scroll_tween.tween_interval(1.5)

func _update_fade_bounds() -> void:
	if not _fade_material or not _label:
		return

	var screen_width := get_viewport_rect().size.x
	if screen_width <= 0.0:
		return

	var viewport_rect := get_global_rect()
	_fade_material.set_shader_parameter(
		"left_edge",
		clampf(viewport_rect.position.x / screen_width, 0.0, 1.0)
	)
	_fade_material.set_shader_parameter(
		"right_edge",
		clampf(viewport_rect.end.x / screen_width, 0.0, 1.0)
	)
	_fade_material.set_shader_parameter(
		"fade_width",
		minf(24.0, viewport_rect.size.x * 0.15) / screen_width
	)
	_fade_material.set_shader_parameter(
		"fade_enabled",
		_label.get_content_width() > size.x + 1.0
	)
