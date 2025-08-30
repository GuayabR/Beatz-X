extends Control

func _ready() -> void:
	Engine.time_scale = 1.0

func _on_back():
	print("Thank you for reading.")
	$anim_back.play("back")
	var tween := create_tween()
	tween.tween_property($who_would_have_known, "volume_db", -80.0, 1)
	await get_tree().create_timer(1).timeout
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func back():
	print("Thank you for reading.")
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
