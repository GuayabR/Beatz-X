extends Node

const HOVER_SFX := preload("res://Resources/SFX/hover.wav")
const CLICK_SFX := preload("res://Resources/SFX/click.wav")
const BASS_CLICK_SFX := preload("res://Resources/SFX/bass_click.wav")

const CANCEL_CLICK_SFX := preload("res://Resources/SFX/clickBtn2.mp3")
const ACCEPT_CLICK_SFX := preload("res://Resources/SFX/clickBtn.mp3")

const HIT_SOUND_SFX := preload("res://Resources/SFX/hitSound.mp3")

const CHECK_ON_SFX := preload("res://Resources/SFX/hoverBtn.mp3")
const CHECK_OFF_SFX := preload("res://Resources/SFX/clickBtn2.mp3")

var sfx_map := {
	&"hover": HOVER_SFX,
	&"bass_click": BASS_CLICK_SFX,
	&"cancel_click": CANCEL_CLICK_SFX,
	&"accept_click": ACCEPT_CLICK_SFX,
	&"click": CLICK_SFX,
	&"check_on": CHECK_ON_SFX,
	&"check_off": CHECK_OFF_SFX,
	&"hit_sound": HIT_SOUND_SFX
}

var sfx_reverse_map := {}

var sfx_defaults := {
	"cancel_click": 0.04,
	"check_off": 0.04
}

func _get_sfx(node: Node, meta_key: StringName, default_sfx: AudioStream) -> AudioStream:
	# ------------------------------------------------
	# 1. ACTION-SPECIFIC OVERRIDES (highest priority)
	# ------------------------------------------------
	var override_key_name := ""

	match meta_key:
		&"sfx_hover":
			override_key_name = "sfx_hover_override"
		&"sfx_click":
			override_key_name = "sfx_click_override"
		&"sfx_toggle_on":
			override_key_name = "sfx_toggle_on_override"
		&"sfx_toggle_off":
			override_key_name = "sfx_toggle_off_override"

	if override_key_name != "" and node.has_meta(override_key_name):
		var key = node.get_meta(override_key_name)

		if key is StringName and sfx_map.has(key):
			return sfx_map[key]
		else:
			print("[UISFX] Invalid ACTION override on", node.name, "->", key)

	# ------------------------------------------------
	# 2. GLOBAL OVERRIDE (fallback for all actions)
	# ------------------------------------------------
	if node.has_meta("sfx_override"):
		var override_key = node.get_meta("sfx_override")

		if override_key is StringName and sfx_map.has(override_key):
			return sfx_map[override_key]
		else:
			print("[UISFX] Invalid GLOBAL override on", node.name, "->", override_key)

	# ------------------------------------------------
	# 3. NORMAL PER-ACTION META
	# ------------------------------------------------
	if node.has_meta(meta_key):
		var key = node.get_meta(meta_key)

		if key is StringName and sfx_map.has(key):
			return sfx_map[key]

	# ------------------------------------------------
	# 4. DEFAULT
	# ------------------------------------------------
	return default_sfx

var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var toggle_player: AudioStreamPlayer

func _ready() -> void:
	hover_player = AudioStreamPlayer.new()
	hover_player.stream = HOVER_SFX
	add_child(hover_player)

	click_player = AudioStreamPlayer.new()
	click_player.stream = CLICK_SFX
	add_child(click_player)

	toggle_player = AudioStreamPlayer.new()
	add_child(toggle_player)
	
	for player: AudioStreamPlayer in get_children():
		player.bus = "SFX"
	
	for key in sfx_map.keys():
		sfx_reverse_map[sfx_map[key]] = key

	get_tree().node_added.connect(_on_node_added)

	# In case this autoload isn't first in the Autoload list.
	for child in get_tree().root.get_children():
		_connect_recursive(child)

func _on_node_added(node: Node) -> void:
	_connect_control(node)

func _connect_recursive(node: Node) -> void:
	_connect_control(node)

	for child in node.get_children():
		_connect_recursive(child)

func _connect_control(node: Node) -> void:
	if !(node is Control):
		return

	if node is CheckButton:
		if !node.mouse_entered.is_connected(_on_button_hover):
			node.mouse_entered.connect(_on_button_hover.bind(node))
			node.pressed.connect(_on_button_pressed.bind(node))
			node.toggled.connect(_on_checkbox_toggled.bind(node))

		if !node.toggled.is_connected(_on_checkbox_toggled):
			node.mouse_entered.connect(_on_button_hover.bind(node))
			node.pressed.connect(_on_button_pressed.bind(node))
			node.toggled.connect(_on_checkbox_toggled.bind(node))

	elif node is BaseButton:
		if !node.mouse_entered.is_connected(_on_button_hover):
			node.mouse_entered.connect(_on_button_hover.bind(node))
			node.pressed.connect(_on_button_pressed.bind(node))

		if !node.pressed.is_connected(_on_button_pressed):
			node.mouse_entered.connect(_on_button_hover.bind(node))
			node.pressed.connect(_on_button_pressed.bind(node))

func _apply_sfx_modifiers(player: AudioStreamPlayer, node: Node) -> void:
	# volume
	if node.has_meta("sfx_volume"):
		var v = node.get_meta("sfx_volume")
		if v is float:
			player.volume_db = linear_to_db(v)
			print("  volume:", v)

	else:
		player.volume_db = 0.0

	# pitch
	if node.has_meta("sfx_pitch_scale"):
		var p = node.get_meta("sfx_pitch_scale")
		if p is float:
			player.pitch_scale = p
			print("  pitch:", p)
		elif p is int:
			player.pitch_scale = float(p)
			print("  pitch(int):", p)
	else:
		player.pitch_scale = 1.0

	# start position
	var start := 0.0

	if node.has_meta("sfx_startpos"):
		var t = node.get_meta("sfx_startpos")
		if t is float:
			start = t
			print("  startpos (meta):", start)
	else:
		# fallback to default per-sfx stream
		var stream_key: String = sfx_reverse_map.get(player.stream, "")

		if stream_key != "" and sfx_defaults.has(stream_key):
			start = sfx_defaults[stream_key]
			print("  startpos (default):", start)

	player.play(start)

func _play_sfx(player: AudioStreamPlayer, node: Node, stream: AudioStream) -> void:
	player.stream = stream
	_apply_sfx_modifiers(player, node)

func _on_button_hover(button: BaseButton) -> void:
	_play_sfx(hover_player, button, _get_sfx(button, &"sfx_hover", HOVER_SFX))

func _on_button_pressed(button: BaseButton) -> void:
	_play_sfx(click_player, button, _get_sfx(button, &"sfx_click", CLICK_SFX))

func _on_checkbox_toggled(toggled_on: bool, button: BaseButton) -> void:
	var meta_key := &"sfx_toggle_on" if toggled_on else &"sfx_toggle_off"
	var default_sfx := CHECK_ON_SFX if toggled_on else CHECK_OFF_SFX

	_play_sfx(toggle_player, button, _get_sfx(button, meta_key, default_sfx))
