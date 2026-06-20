extends Node2D

@export var timestamp: float
var spawned_at: float

var type: String
var style: String = Settings.misc.note_style
var faded: bool = false # Becomes true when hit perfectly, insanely or exactly
var faded_great: bool = false # Becomes true when not hit perfectly, insanely or exactly

var effects = []

var hold_ms: float = -1.0
@onready var hold_bar: Line2D = $HoldBar2D

var rec: bool = false

var edit: bool = false
var editor_deleted: bool = false

var selected := false

var note_index: int

var note_id: String = ""

var is_recording_hold: bool = false

signal editor_hovered(note)
signal editor_unhovered(note)
signal editor_pressed(note, event)

func _ready() -> void:
	if rec:
		$noteImg.self_modulate = Color("9b9b9bff")
		$editor_hitbox.queue_free()
	
	if not edit:
		$editor_hitbox.queue_free()
		#$HoldBar.queue_free()
		$editor_effect_label.hide()
	
	if not effects.is_empty() and edit and type == "Effect":
			$editor_effect_label.text = JSON.stringify(effects, "\t")
	else:
		$editor_effect_label.hide()
	
	if Settings.misc.note_style == "dance":
		match type:
			"Upleft": 
				hold_bar.self_modulate = Color.MAGENTA
			"Downleft": 
				hold_bar.self_modulate = Color.MAGENTA
			"Left": 
				hold_bar.self_modulate = Color.RED
			"Down": 
				hold_bar.self_modulate = Color.YELLOW
			"Up": 
				hold_bar.self_modulate = Color.GREEN
			"Right": 
				hold_bar.self_modulate = Color.CYAN
			"Downright": 
				hold_bar.self_modulate = Color.PURPLE
			"Upright": 
				hold_bar.self_modulate = Color.RED
	elif Settings.misc.note_style == "techno":
		match type:
			"Up": hold_bar.self_modulate  = Color(0.0, 0.9, 1.0) # Cobalt blue to sky blue kinda color
			"Down": hold_bar.self_modulate  = Color(0.0, 1.0, 0.7) # Green mixed with cyan
			"Left": hold_bar.self_modulate  = Color.YELLOW # Purple
			"Right": hold_bar.self_modulate  = Color(0.5, 0.0, 1.0)
	elif Settings.misc.note_style == "para":
		match type:
			"Up": hold_bar.self_modulate  = Color.GREEN
			"Down": hold_bar.self_modulate  = Color.MAGENTA 
			"Left": hold_bar.self_modulate  = Color.RED
			"Right": hold_bar.self_modulate  = Color(0.0, 0.9, 1.0) # Cobalt blue to sky blue kinda color
	elif Settings.misc.note_style == "circles":
		if type or type != "":
			$noteImg.self_modulate = Settings.circles[type + "Chart"]
			hold_bar.self_modulate = Settings.circles[type + "Chart"]
	
	$note_hold_end.z_index = 2
	$note_hold_end.visible = true if edit == true and hold_ms > 0.0 and Settings.misc.editor_show_note_hold_ends else false
	$note_hold_end.scale = Vector2(0.25, 0.25)
	
	hold_bar.self_modulate.a = 0.75
	hold_bar.visible = true if hold_ms > 0.0 else false
	hold_bar.rotation_degrees = 180.0
	
	$HoldBar.z_index = -1
	$HoldBar.size.y = (Beatz.time_to_y(hold_ms, edit) * Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER) * Beatz.playback_speed
	$HoldBar.self_modulate.a = 0.5
	hold_bar.points[1].y = (Beatz.time_to_y(hold_ms, edit) * Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER) * Beatz.playback_speed
	hold_bar.points[2].y = ((Beatz.time_to_y(hold_ms, edit) * Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER) * Beatz.playback_speed) + clampf(hold_bar.points[1].y / 5.0, 7.5, 50.0)
	$note_hold_end.position.y = (Beatz.time_to_y(hold_ms, edit) * -Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER) * Beatz.playback_speed
	
	if hold_ms > 0.0:
		$editor_hitbox.size.y = Beatz.time_to_y(hold_ms, edit) * Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER + 100
		$editor_hitbox.position.y = Beatz.time_to_y(hold_ms, edit) * -Beatz.ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER - 25
	
	$noteImg.scale = Vector2(Settings.circles.size, Settings.circles.size) if Settings.misc.note_style == "circles" else Vector2.ONE 
	$shadow.scale = Vector2(Settings.circles.size, Settings.circles.size) if Settings.misc.note_style == "circles" else Vector2.ONE
	$HoldBar2D.width = 52.0 * Settings.circles.size if Settings.misc.note_style == "circles" else 52.0
	$HoldBar.size.x = 28.0 * Settings.circles.size if Settings.misc.note_style == "circles" else 28.0
	#$HoldBar.position.x =
	
	if Settings.misc.hold_bar_no_end_fade:
		$HoldBar2D.gradient = null
		$HoldBar2D.points[1].y -= 20.0
		$HoldBar2D.points[2].y -= 25.0
	else:
		$HoldBar2D.gradient = preload("res://Resources/misc/hold_note_end_fade.tres")
	
	if Settings.misc.hold_bar_solid:
		$HoldBar2D.material.blend_mode = 0
		$HoldBar2D.modulate = Color.WHITE
	else:
		$HoldBar2D.material.blend_mode = 1
		$HoldBar2D.modulate = Color(1.0, 1.0, 1.0, 0.851)
	
	if Settings.misc.note_anims == false:
		$noteImg.position = Vector2.ZERO
		if not style == "circles": $noteImg.self_modulate = Color.WHITE
		return

func update_hold_visual(pixels: float) -> void:
	if hold_ms > 0:
		if hold_bar:
			hold_bar.points[1].y -= pixels if hold_bar.points[1].y > 15 else 0
			hold_bar.points[2].y -= pixels if hold_bar.points[2].y > 20 else 0
		if $note_hold_end: $note_hold_end.position.y += pixels
		if $HoldBar: $HoldBar.size.y -= pixels

func create_hold_visual(pixels: float) -> void:
	if hold_bar:
		hold_bar.points[1].y += pixels
		hold_bar.points[2].y += pixels

	if $note_hold_end:
		$note_hold_end.position.y -= pixels

	if $HoldBar:
		$HoldBar.size.y += pixels

func great_hit():
	faded_great = true
	
	if Settings.misc.note_anims == false and hold_ms <= 0.0:
		queue_free()
		return
	
	$init.play("great_hit")
	var tween = create_tween()
	var rand = randf_range(-60, 60)
	var target_rot = rand
	tween.tween_property($noteImg, "rotation_degrees", target_rot, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	z_index = -2
	
	await get_tree().create_timer(1.0).timeout
	queue_free()

func hit(fake: bool = false):
	faded = true
	if Settings.misc.note_anims == false and not fake and hold_ms <= 0.0:
		queue_free()
		return
	
	if Settings.misc.note_anims:
		$noteImg.material = preload("res://Resources/misc/note_mask.tres")
		
		var col: Color
		if Settings.misc.note_style == "dance":
			match type:
				"Upleft": col = Color.MAGENTA
				"Downleft": col = Color.BLUE
				"Left": col = Color.RED
				"Down": col = Color.YELLOW
				"Up": col = Color.GREEN
				"Right": col = Color.CYAN
				"Downright": col = Color.PURPLE
				"Upright": col = Color.RED
		elif Settings.misc.note_style == "techno":
			match type:
				"Up": col = Color(0.0, 0.9, 1.0)
				"Down": col = Color(0.0, 1.0, 0.7)
				"Left": col = Color.YELLOW
				"Right": col = Color(0.5, 0.0, 1.0)
		elif Settings.misc.note_style == "para":
			match type:
				"Up": col = Color.GREEN
				"Down": col = Color.MAGENTA 
				"Left": col = Color.RED
				"Right": col = Color(0.0, 0.9, 1.0)
		elif Settings.misc.note_style == "circles":
			if type or type != "": col = Settings.circles[type + "Chart"]
		
		$noteImg/mask.self_modulate = col # Set the mask the same color so the note now becomes a solid color
		$shadow.self_modulate = col # Set the shadows color to the set color
		
		var t2 = create_tween() # Create a tween and make the shadow become transparent after 1 second on an ease out
		t2.parallel().tween_property($shadow, "self_modulate", Color.TRANSPARENT, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var rand = randi_range(-25, 25)
		var target_rot = rand
		$noteImg.scale = Vector2(1.2 * Settings.circles.size, 1.2 * Settings.circles.size)
		$shadow.scale = Vector2(0.6 * Settings.circles.size, 0.6 * Settings.circles.size)
		t2.parallel().tween_property($noteImg, "rotation_degrees", target_rot, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property($noteImg, "modulate", Color.TRANSPARENT, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property($noteImg, "scale", Vector2.ONE * Settings.circles.size, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property($shadow, "scale", Vector2(0.4 * Settings.circles.size, 0.4 * Settings.circles.size), 0.35).set_ease(Tween.EASE_IN)
		if fake: return
	else:
		$noteImg.hide()
	
	if hold_ms < 0.0:
		await get_tree().create_timer(0.55).timeout
		queue_free()
	else:
		await get_tree().create_timer(0.55 + (clampf((hold_ms / 1000.0), 0.0, hold_ms / 1000.0))).timeout
		queue_free()

func editor_reset():
	$init.stop()
	$init.play("RESET")
	$noteImg.rotation_degrees = 0.0
	$shadow.self_modulate = Color.TRANSPARENT

func _on_editor_hitbox_mouse_entered() -> void:
	if editor_deleted or faded:
		return
	emit_signal("editor_hovered", self)


func _on_editor_hitbox_mouse_exited() -> void:
	if editor_deleted or faded:
		return
	emit_signal("editor_unhovered", self)


func _on_editor_hitbox_gui_input(event: InputEvent) -> void:
	if editor_deleted or faded:
		return

	if event is InputEventMouseButton:
		if event.pressed:
			emit_signal("editor_pressed", self, event)

func reset_game():
	if hold_bar: hold_bar.queue_free()
	if $HoldBar: $HoldBar.queue_free()
	if Settings.misc.note_anims == false:
		faded = true
		queue_free()
		return
	
	$init.play("reset_game")
	
	var tween = create_tween()
	var current_pos = $noteImg.position
	var random_offset = Vector2(randf_range(-250, 250), randf_range(-250, 250))
	var target_pos = current_pos + random_offset
	
	var rot_rand2 = 180
	tween.tween_property($noteImg, "position", target_pos, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($noteImg, "rotation_degrees", rot_rand2, 1.5).set_ease(Tween.EASE_OUT)

func set_type(noteType: String):
	type = noteType

	# dance style is the "no prefix" style
	if style == "dance":
		style = ""

	# circle notes: same sprite for all directions
	if style == "circles":
		var circle_tex := load("res://Resources/Arrows/circles/Circle.png")
		$noteImg.texture = circle_tex
		$note_hold_end.texture = circle_tex
		return

	# normal styles
	var base := "res://Resources/Arrows/" + style + "/" + style
	
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	
	match noteType:
		"Section":
			$noteImg.texture = load("res://Resources/Arrows/beatLine.png")
			$note_hold_end.texture = load("res://Resources/Arrows/beatLine.png")
			modulate = Color.CYAN
		"Effect":
			$noteImg.texture = load("res://Resources/favicon.png")
			$note_hold_end.texture = load("res://Resources/favicon.png")
		"Upleft":
			$noteImg.texture = load(base + "NoteUpleft.png")
			$note_hold_end.texture = load(base + "NoteUpleft.png")
		"Downleft":
			$noteImg.texture = load(base + "NoteDownleft.png")
			$note_hold_end.texture = load(base + "NoteDownleft.png")
		"Left":
			$noteImg.texture = load(base + "NoteLeft.png")
			$note_hold_end.texture = load(base + "NoteLeft.png")
		"Down":
			$noteImg.texture = load(base + "NoteDown.png")
			$note_hold_end.texture = load(base + "NoteDown.png")
		"Up":
			$noteImg.texture = load(base + "NoteUp.png")
			$note_hold_end.texture = load(base + "NoteUp.png")
		"Right":
			$noteImg.texture = load(base + "NoteRight.png")
			$note_hold_end.texture = load(base + "NoteRight.png")
		"Downright":
			$noteImg.texture = load(base + "NoteDownright.png")
			$note_hold_end.texture = load(base + "NoteDownright.png")
		"Upright":
			$noteImg.texture = load(base + "NoteUpright.png")
			$note_hold_end.texture = load(base + "NoteUpright.png")
		_:
			if noteType != "out": print("Unrecognized note type: ", noteType)
			if Settings.misc.show_error_notes:
				$noteImg.texture = load("res://Resources/NoteUpTransparent.png")
				$note_hold_end.texture = load("res://Resources/Arrows/NoteUp.png")
				modulate = Color.RED
			else:
				modulate = Color.TRANSPARENT
				self_modulate = Color.TRANSPARENT
				hide()
