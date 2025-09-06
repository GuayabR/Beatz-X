extends Node2D

@export var timestamp: float

var type: String
var style: String = Globals.settings.misc_settings.note_style
var faded := false # Becomes true when hit perfectly, insanely or exactly
var faded_great := false # Becomes true when not hit perfectly, insanely or exactly

var rec := false

var edit := false
var editor_deleted := false

signal hovered(note)
signal exited(note)

func _ready() -> void:
	if rec:
		$init.stop()
		$noteImg.scale = Vector2.ONE
		$noteImg.position = Vector2.ZERO
		$noteImg.self_modulate = Color("828282")
		
		return
	
	if edit:
		$init.stop()
		$noteImg.scale = Vector2.ONE
		$noteImg.position = Vector2.ZERO
		$noteImg.self_modulate = Color.WHITE
		return
	
	if Globals.settings.misc_settings.note_anims == false:
		$init.stop()
		$noteImg.scale = Vector2.ONE
		$noteImg.position = Vector2.ZERO
		$noteImg.self_modulate = Color.WHITE
		return
		
	var tween = create_tween()
	var tween2 = create_tween()
	var rand = randf_range(-200, 200)
	var rot_rand2 = randf_range(-100, 100)
	$noteImg.position.x = rand
	$noteImg.rotation_degrees = rot_rand2
	tween.tween_property($noteImg, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween2.parallel().tween_property($noteImg, "rotation_degrees", 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

func great_hit():
	faded_great = true
	
	if Globals.settings.misc_settings.note_anims == false:
		queue_free()
		return
	
	$init.play("great_hit")
	var tween = create_tween()
	var rand = randf_range(-60, 60)
	var target_rot = rand
	tween.tween_property($noteImg, "rotation_degrees", target_rot, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	self.z_index = -2

func hit():
	
	faded = true
	if Globals.settings.misc_settings.note_anims == false:
		queue_free()
		return
	$init.play("hit")
	
	var col: Color
	if Globals.settings.misc_settings.note_style == "dance":
		match type:
			"Upleft": col = Color.MAGENTA
			"Downleft": col = Color.BLUE
			"Left": col = Color.RED
			"Down": col = Color.YELLOW
			"Up": col = Color.GREEN
			"Right": col = Color.CYAN
			"Downright": col = Color.PURPLE
			"Upright": col = Color.RED
	elif Globals.settings.misc_settings.note_style == "techno":
		match type:
			"Up": col = Color(0.0, 0.9, 1.0) # Cobalt blue to sky blue kinda color
			"Down": col = Color(0.0, 1.0, 0.7) # Green mixed with cyan
			"Left": col = Color.YELLOW # Purple
			"Right": col = Color(0.5, 0.0, 1.0)
	elif Globals.settings.misc_settings.note_style == "para":
		match type:
			"Up": col = Color.GREEN
			"Down": col = Color.MAGENTA 
			"Left": col = Color.RED
			"Right": col = Color(0.0, 0.9, 1.0) # Cobalt blue to sky blue kinda color
	$noteImg/mask.set("self_modulate", col) # Set the mask the same color so the note now becomes a solid color
	$shadow.set("self_modulate", col) # Set the shadows color to the set color
	var t2 = create_tween() # Create a tween and make the shadow become transparent after 1 second on an ease out
	t2.parallel().tween_property($shadow, "self_modulate", Color.TRANSPARENT, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tween = create_tween() # Create a tween and make the note rotate on a random value after half a second on an ease out
	var rand = randf_range(-45, 45)
	var target_rot = rand
	tween.parallel().tween_property($noteImg, "rotation_degrees", target_rot, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func reset_game():
	if Globals.settings.misc_settings.note_anims == false:
		faded = true
		queue_free()
		return
	var anim = randi() % 6
	if anim == 0:
		$init.play("reset_game")
	elif anim == 1:
		$init.play("reset_game_2")
	elif anim == 2:
		$init.play("reset_game_3")
	elif anim == 3:
		$init.play("reset_game_4")
	elif anim == 4:
		$init.play("reset_game_5")
	elif anim == 5:
		$init.play("reset_game_6")
	
	var tween = create_tween()
	var current_pos = $noteImg.position
	var random_offset = Vector2(randf_range(-250, 250), randf_range(-250, 250))
	var target_pos = current_pos + random_offset
	tween.tween_property($noteImg, "position", target_pos, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func editor_delete():
	hit()

func set_type(noteType: String):
	type = noteType
	if style == "dance": style = ""
	var string = "res://Resources/Arrows/" + style + "/" + style
	match noteType:
		"Upleft":
			$noteImg.texture = load(string + "NoteUpleft.png")
		"Downleft":
			$noteImg.texture = load(string + "NoteDownleft.png")
		"Left":
			$noteImg.texture = load(string + "NoteLeft.png")
		"Down":
			$noteImg.texture = load(string + "NoteDown.png")
		"Up":
			$noteImg.texture = load(string + "NoteUp.png")
		"Right":
			$noteImg.texture = load(string + "NoteRight.png")
		"Downright":
			$noteImg.texture = load(string + "NoteDownright.png")
		"Upright":
			$noteImg.texture = load(string + "NoteUpright.png")
