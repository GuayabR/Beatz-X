extends VideoPlayback

var grids: Array[Array] = []
var tween: Tween

const ROT_STEPS := [0, 45, 90, 135, 180, 225, 270, 315, 360, -45, -90, -135, -225, -270, -315]

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
	_collect_grids()
	if Settings.misc.hq_background: _start_loop()
	else: $AnimationPlayer.stop()


func _collect_grids() -> void:
	grids.clear()

	for grid in $HBoxContainer.get_children():
		if grid is Container:
			var list: Array[TextureRect] = []
			_collect_texture_rects(grid, list)
			grids.append(list)


func _collect_texture_rects(node: Node, list: Array[TextureRect]) -> void:
	for child in node.get_children():
		if child is TextureRect:
			child.pivot_offset = child.size / 2.0
			var new_material = CanvasItemMaterial.new()
	
			# 2. Configure properties like blend_mode or light_mode using built-in enums
			new_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			child.material = new_material
			list.append(child)
		else:
			_collect_texture_rects(child, list)

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
		for item: TextureRect in grid:
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
	$AnimationPlayer.play()

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
						if item.rotation != angle: _tween_rotate(item, angle)
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
		var target: TextureRect = grid[idx]

		_tween_rotate(target)

	wave_index += 1


func _random_step() -> void:
	var all: Array[TextureRect] = []

	for grid in grids:
		all.append_array(grid)

	if all.is_empty():
		return

	var target: TextureRect = all[randi() % all.size()]
	_tween_rotate(target)

func _random_multi_step() -> void:
	var all: Array[TextureRect] = []

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

		for item in grid:
			_tween_rotate(item, angle)

func _random_burst_step() -> void:
	for grid in grids:
		if grid.is_empty():
			continue

		for item: TextureRect in grid:
			var angle: float = ROT_STEPS[randi() % ROT_STEPS.size()]
			_tween_rotate(item, angle)


func _tween_rotate(target: TextureRect, force_angle: float = -999.0) -> void:
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
