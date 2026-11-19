extends Node

var filter_rect: ColorRect
var layer: CanvasLayer

func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 4096

	filter_rect = ColorRect.new()
	filter_rect.anchor_left = 0.0
	filter_rect.anchor_top = 0.0
	filter_rect.anchor_right = 1.0
	filter_rect.anchor_bottom = 1.0

	filter_rect.offset_left = 0
	filter_rect.offset_top = 0
	filter_rect.offset_right = 0
	filter_rect.offset_bottom = 0

	filter_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# IMPORTANT: ensure it renders AFTER the scene
	filter_rect.z_index = 1000

	filter_rect.material = preload("res://Resources/Themes/visual_filters.tres")

	layer.add_child(filter_rect)
	get_tree().root.call_deferred("add_child", layer)

	await get_tree().process_frame
	apply_settings()


func apply_settings() -> void:
	if !filter_rect:
		return

	var mat := filter_rect.material as ShaderMaterial
	if !mat:
		return

	mat.set_shader_parameter("brightness", Settings.game.brightness)
	mat.set_shader_parameter("contrast", Settings.game.contrast)
	mat.set_shader_parameter("gamma", Settings.game.gamma)
	mat.set_shader_parameter("colourblind_mode", Settings.game.colourblind_mode)
	mat.set_shader_parameter("colourblind_strength", Settings.game.colourblind_strength)
