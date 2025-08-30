# Use this instead of extending VideoStreamPlayer
extends Control

@export var scene_to_load: String = "res://Scenes/main_menu.tscn"
var loaded_scene: PackedScene
var custom_data = {}

var progress = []

var status = 0

var rotation_speed = 5.0

func _ready():
	if scene_to_load == "":
		push_error("No scene set to load.")
		return
	
	var err = ResourceLoader.load_threaded_request(scene_to_load)
	if err != OK:
		push_error("Failed to start threaded load: %s" % err)
	else:
		print("Started ", err)

func _process(delta):
	# Rotate the loading icon manually
	$Sprite2D.rotation += rotation_speed * delta
	
	status = ResourceLoader.load_threaded_get_status(scene_to_load, progress)
	
	$RichTextLabel.text = str(floor(progress[0]*100)) + "%"
	
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		get_loaded()

func get_loaded():
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var new = ResourceLoader.load_threaded_get(scene_to_load)

		for key in custom_data:
			if new.has_method("set") or new.has_property(key):
				new.set(key, custom_data[key])

		get_tree().change_scene_to_packed(new)
	else:
		print("Scene hasnt loaded ", loaded_scene)
