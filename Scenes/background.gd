extends VideoPlayback

class CanvasTextureItem extends RefCounted:
	var canvas_item: RID
	var rect: Rect2
	var pivot_offset: Vector2
	var _rotation_degrees := 0.0

	var rotation_degrees: float:
		get:
			return _rotation_degrees
		set(value):
			_rotation_degrees = value
			_update_transform()

	func _init(item_rid: RID, item_rect: Rect2) -> void:
		canvas_item = item_rid
		rect = item_rect
		pivot_offset = item_rect.size / 2.0

	func _update_transform() -> void:
		var angle := deg_to_rad(_rotation_degrees)
		var pivot := rect.position + pivot_offset
		var basis := Transform2D(angle, Vector2.ZERO)
		var origin := pivot - basis.basis_xform(pivot)
		RenderingServer.canvas_item_set_transform(canvas_item, Transform2D(angle, origin))

var grids: Array[Array] = []
var tween: Tween

const ROT_STEPS := [0, 45, 90, 135, 180, 225, 270, 315, 360, -45, -90, -135, -225, -270, -315]
const GRID_COLUMNS := 11
const GRID_ROWS := 6
const ITEMS_PER_GRID := 66
const GRID_GAP: float = 50.0

@export var background_texture: Texture2D
@export var start_on_ready := true

var _canvas_material: CanvasItemMaterial

enum EffectMode {
	NONE,
	WAVE,
	RANDOM_SINGLE,
	GRID_BURST,
	RANDOM_BURST,
	RANDOM_MULTI
}

@export var effect_mode: EffectMode = EffectMode.WAVE
@export var step_time: float = 0.15
@export var tween_time: float = 0.4

@export var multi_min: int = 2
@export var multi_max: int = 10

@export var tween_ease_mode: TweenEaseMode = TweenEaseMode.EASE_IN_OUT
@export var tween_trans_mode: TweenTransMode = TweenTransMode.SINE

enum TweenEaseMode {
	LINEAR,
	EASE_IN,
	EASE_OUT,
	EASE_IN_OUT,
	ELASTIC,
	BOUNCE
}

enum TweenTransMode {
	LINEAR,
	SINE,
	QUAD,
	CUBIC,
	QUART,
	QUINT,
	EXPO,
	CIRC,
	SPRING
}

func _get_ease() -> Tween.EaseType:
	match tween_ease_mode:
		TweenEaseMode.LINEAR:
			return Tween.EASE_IN_OUT # closest equivalent (no true linear ease type combo in shorthand)
		TweenEaseMode.EASE_IN:
			return Tween.EASE_IN
		TweenEaseMode.EASE_OUT:
			return Tween.EASE_OUT
		TweenEaseMode.EASE_IN_OUT:
			return Tween.EASE_IN_OUT
		TweenEaseMode.ELASTIC:
			return Tween.EASE_IN_OUT
		TweenEaseMode.BOUNCE:
			return Tween.EASE_IN_OUT
	return Tween.EASE_IN_OUT


func _get_trans() -> Tween.TransitionType:
	match tween_trans_mode:
		TweenTransMode.LINEAR:
			return Tween.TRANS_LINEAR
		TweenTransMode.SINE:
			return Tween.TRANS_SINE
		TweenTransMode.QUAD:
			return Tween.TRANS_QUAD
		TweenTransMode.CUBIC:
			return Tween.TRANS_CUBIC
		TweenTransMode.QUART:
			return Tween.TRANS_QUART
		TweenTransMode.QUINT:
			return Tween.TRANS_QUINT
		TweenTransMode.EXPO:
			return Tween.TRANS_EXPO
		TweenTransMode.CIRC:
			return Tween.TRANS_CIRC
		TweenTransMode.SPRING:
			return Tween.TRANS_SPRING
	return Tween.TRANS_SINE

var wave_index := 0


func _ready() -> void:
	_create_canvas_items()
	if Settings.misc.hq_background and start_on_ready: start()
	else: $AnimationPlayer.stop()


func _create_canvas_items() -> void:
	grids.clear()

	if background_texture == null:
		push_error("HQ background texture is not assigned.")
		return

	_canvas_material = CanvasItemMaterial.new()
	_canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var texture_size := background_texture.get_size()
	var grid_width := GRID_COLUMNS * texture_size.x + (GRID_COLUMNS - 1) * GRID_GAP
	var grid_height := GRID_ROWS * texture_size.y + (GRID_ROWS - 1) * GRID_GAP
	var grid_step := Vector2(grid_width + GRID_GAP, grid_height + GRID_GAP)
	var layout_size := Vector2(grid_width * 2 + GRID_GAP, grid_height * 2 + GRID_GAP)
	var layout_origin = ($HBoxContainer.size - layout_size) / 2.0
	var parent_rid: RID = $HBoxContainer.get_canvas_item()

	for grid_index in 4:
		var grid: Array[CanvasTextureItem] = []
		grids.append(grid)
		var grid_origin = layout_origin + Vector2(grid_index % 2, floori(float(grid_index) / 2.0)) * grid_step

		for item_index in ITEMS_PER_GRID:
			var item_position = grid_origin + Vector2(
				(item_index % GRID_COLUMNS) * (texture_size.x + GRID_GAP),
				floori(float(item_index) / GRID_COLUMNS) * (texture_size.y + GRID_GAP)
			)
			var item_rid := RenderingServer.canvas_item_create()
			RenderingServer.canvas_item_set_parent(item_rid, parent_rid)
			RenderingServer.canvas_item_add_texture_rect(
				item_rid,
				Rect2(item_position, texture_size),
				background_texture.get_rid()
			)
			RenderingServer.canvas_item_set_material(item_rid, _canvas_material.get_rid())
			grid.append(CanvasTextureItem.new(item_rid, Rect2(item_position, texture_size)))


func _exit_tree() -> void:
	for grid in grids:
		for item: CanvasTextureItem in grid:
			if item.canvas_item.is_valid():
				RenderingServer.free_rid(item.canvas_item)
	grids.clear()

## Array of colours must be size 2.
func tint(with: Array[Color]) -> void:
	if with.size() > 2: print("HQ Background will only use the first and second index of the \"with\" property.")
	var t = create_tween()
	t.tween_property(self, "self_modulate", with[0], 0.5)
	t.set_parallel().tween_property($VideoPlayback, "self_modulate", with[1], 0.5)

var _running := true

var active_tweens: Array[Tween] = []

func stop() -> void:
	_running = false
	
	pause()
	$VideoPlayback.pause()
	
	$AnimationPlayer.stop(true)

	for t in active_tweens:
		if is_instance_valid(t):
			t.kill()

	active_tweens.clear()

	for grid in grids:
		for item: CanvasTextureItem in grid:
			item.rotation_degrees = 0.0

func start() -> void:
	if _running:
		return
	
	play()
	$VideoPlayback.play()
	
	$AnimationPlayer.play("scroll")
	
	_running = true
	_start_loop()


func play_parallax() -> void:
	$AnimationPlayer.play("scroll")

func stop_parallax() -> void:
	$AnimationPlayer.stop()

func _start_loop() -> void:
	while _running:
		match effect_mode:
			EffectMode.NONE:
				for grid in grids:
					if grid.is_empty():
						continue

					var angle: float = 0.0

					for item in grid:
						if item.rotation_degrees != angle: _tween_rotate(item, angle)
			EffectMode.WAVE:
				_wave_step()
			EffectMode.RANDOM_SINGLE:
				_random_step()
			EffectMode.GRID_BURST:
				_grid_burst_step()
			EffectMode.RANDOM_BURST:
				_random_burst_step()
			EffectMode.RANDOM_MULTI:
				_random_multi_step()

		await get_tree().create_timer(step_time).timeout

# EFFECTS

func _wave_step() -> void:
	for grid in grids:
		if grid.is_empty():
			continue

		var idx := wave_index % grid.size()
		var target: CanvasTextureItem = grid[idx]

		_tween_rotate(target)

	wave_index += 1


func _random_step() -> void:
	var all: Array[CanvasTextureItem] = []

	for grid in grids:
		all.append_array(grid)

	if all.is_empty():
		return

	var target: CanvasTextureItem = all[randi() % all.size()]
	_tween_rotate(target)

func _random_multi_step() -> void:
	var all: Array[CanvasTextureItem] = []

	for grid in grids:
		all.append_array(grid)

	if all.is_empty():
		return

	var count := randi_range(multi_min, multi_max)
	count = clamp(count, 1, all.size())

	var used_indices := {}

	for i in count:
		var idx := randi() % all.size()

		# avoid duplicates in same burst
		while used_indices.has(idx):
			idx = randi() % all.size()

		used_indices[idx] = true

		_tween_rotate(all[idx])

func _grid_burst_step() -> void:
	for grid in grids:
		if grid.is_empty():
			continue

		var angle: float = ROT_STEPS[randi() % ROT_STEPS.size()]

		for item: CanvasTextureItem in grid:
			_tween_rotate(item, angle)

func _random_burst_step() -> void:
	for grid in grids:
		if grid.is_empty():
			continue

		for item: CanvasTextureItem in grid:
			var angle: float = ROT_STEPS[randi() % ROT_STEPS.size()]
			_tween_rotate(item, angle)


func _tween_rotate(target: CanvasTextureItem, force_angle: float = -999.0) -> void:
	var angle: float = force_angle

	if angle == -999.0:
		angle = ROT_STEPS[randi() % ROT_STEPS.size()]

	var local_tween := create_tween()
	active_tweens.append(local_tween)

	local_tween.finished.connect(func():
		active_tweens.erase(local_tween)
	)
	
	local_tween.tween_property(
		target,
		"rotation_degrees",
		angle,
		tween_time
	).set_trans(_get_trans()).set_ease(_get_ease())
