extends Control

const BezierChart = preload("res://Scenes/Tools/BezierChart.gd")

var selected_stream: AudioStream

var selected_title: String = "Bezier test"
var selected_artist: String = "GuayabR"
var selected_album: String
var selected_cover = load("res://Resources/Covers/Beatz! Originals.png")

var spectrum: AudioEffectSpectrumAnalyzerInstance

var current_scale: float = 1.0

var _extra_exponential_points := [
	Vector2(0.000, 0.779),
	Vector2(0.100, 0.791),
	Vector2(0.200, 0.820),
	Vector2(0.300, 0.854),
	Vector2(0.400, 0.882),
	Vector2(0.500, 0.893),
	Vector2(0.600, 0.905),
	Vector2(0.700, 0.932),
	Vector2(0.800, 0.963),
	Vector2(0.900, 0.989),
	Vector2(1.000, 1.000),
]

func _process(delta: float):
	if spectrum:
		# Get energy levels
		var overall_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 11050.0).length()
		var overall_loudness: float = clampf((111 + linear_to_db(overall_energy)) / 111.0, 0.0, 1.0)

		var bass_energy: float = spectrum.get_magnitude_for_frequency_range(20.0, 250.0).length()
		var bass_loudness: float = clampf((111 + linear_to_db(bass_energy)) / 111.0, 0.0, 1.0)

		var treble_energy: float = spectrum.get_magnitude_for_frequency_range(5000.0, 11050.0).length()
		var treble_loudness: float = clampf((111 + linear_to_db(treble_energy)) / 111.0, 0.0, 1.0)

		# Exponentiate for punch
		var exp_treble := pow(treble_loudness, 1.5)
		var exp_overall := pow(overall_loudness, 3.0)
		var exp_bass := pow(bass_loudness, 2.5)
		var exp_bg := clampf(exp_bass * 0.8 + exp_overall * 0.1, 0.0, 1.0)
		
		# Base and max scale ranges
		var base_scale := 1.0
		var max_title := 1.5
		var max_bg := 1.3

		# Interpolated targets
		var title_target = lerp(base_scale, max_title, exp_treble)
		var cover_target = _evaluate_extra_exponential(overall_loudness)
		var bg_target = lerp(base_scale, max_bg, exp_bg)

		# Smooth transitions
		$Title.scale = lerp($Title.scale, Vector2.ONE * title_target, 13.0 * delta)
		$Artist.scale = lerp($Title.scale, Vector2.ONE * title_target, 10.0 * delta)
		$vis_anim.scale = lerp($vis_anim.scale, Vector2(2.6, 2.6) * cover_target, 15.0 * delta)
		$cover_anim.scale = lerp($cover_anim.scale, Vector2.ONE * cover_target, 20.0 * delta)
		$bg_cover_anim.scale = lerp($bg_cover_anim.scale, Vector2(1.0, 1.0) * bg_target, 16.0 * delta)


func _evaluate_extra_exponential(value: float) -> float:
	for i in range(_extra_exponential_points.size() - 1):
		var p1 = _extra_exponential_points[i]
		var p2 = _extra_exponential_points[i + 1]
		if value >= p1.x and value <= p2.x:
			var t = (value - p1.x) / (p2.x - p1.x)
			return lerp(p1.y, p2.y, t)
	
	# If below or above defined range, clamp to min/max
	if value < _extra_exponential_points[0].x:
		return _extra_exponential_points[0].y
	if value > _extra_exponential_points[_extra_exponential_points.size() - 1].x:
		return _extra_exponential_points[_extra_exponential_points.size() - 1].y
	
	return value

func _ready() -> void:
	if Globals.settings.misc_settings.reduce_motion:
		$AnimationPlayer.play("load_song", -1, 250.0)
	else:
		$AnimationPlayer.play("load_song")
	print($Title.pivot_offset, $Title.size)
	$Title.text = str(selected_title)
	$Artist.text = str(selected_artist)
	
	await get_tree().process_frame
	
	$Title.pivot_offset.x = $Title.size.x / 2
	print($Title.pivot_offset, $Title.size)
	
	$Artist.pivot_offset.x = $Artist.size.x / 2
	print($Artist.pivot_offset, $Artist.size)
	
	$cover_anim/circlemask/cover.texture = selected_cover
	$bg_cover_anim/bg_cover.texture = selected_cover
	
	var extracted_colors = extract_dominant_colors(selected_cover)
	$vis_anim/Visualizer.colors = extracted_colors
	
	$song.play(0.0)
	$vis_anim/Visualizer/Song_left.stream = $song.stream
	$vis_anim/Visualizer/Song_right.stream = $song.stream
	$vis_anim/Visualizer/Song_left.play(0.0)
	$vis_anim/Visualizer/Song_right.play(0.0)
	
	spectrum = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Song"), 0) as AudioEffectSpectrumAnalyzerInstance

var _color_from_string_map: Dictionary = {}

func extract_dominant_colors(texture: Texture2D) -> Array[Color]:
	print("Extracting dominant colors...")
	var image: Image = texture.get_image()
	if image.is_compressed():
		print("Image is compressed. Decompressing...")
		image.decompress()
	image.resize(64, 1, Image.INTERPOLATE_TRILINEAR)
	print("Image resized to 64x1")
	
	var color_counts = _scan_colors(image, false)
	print("Scanned normal colors. Found:", color_counts.size(), "distinct colors")
	
	var dark_count = 0
	var total_count = 0
	for c in color_counts.keys():
		var color = _color_from_string_map.get(c, Color(0, 0, 0))
		total_count += color_counts[c]
		if color.r < 0.314 or color.g < 0.314 or color.b < 0.314:
			dark_count += color_counts[c]
	print("Total color samples:", total_count)
	print("Dark color samples:", dark_count)
	
	if total_count > 0 and float(dark_count) / float(total_count) > 0.6:
		print("Too many dark colors. Trying to scan for brighter colors...")
		var bright_counts = _scan_colors(image, true)
		print("Scanned bright colors. Found:", bright_counts.size(), "distinct colors")
		if bright_counts.size() > 0:
			color_counts = bright_counts
		else:
			print("No brighter colors found. Brightening existing dark colors...")
			var new_counts = {}
			for c in color_counts.keys():
				var original_color = _color_from_string_map.get(c, Color(0, 0, 0))
				var brighter := Color(
					clamp(original_color.r + 0.3, 0, 1),
					clamp(original_color.g + 0.3, 0, 1),
					clamp(original_color.b + 0.3, 0, 1),
					1.0
				)
				var key_str := str(brighter)
				new_counts[key_str] = color_counts[c]
				_color_from_string_map[key_str] = brighter
			color_counts = new_counts
			_latest_color_counts = color_counts
			
	var sorted_colors = color_counts.keys()
	sorted_colors.sort_custom(Callable(self, "_compare_colors_by_frequency"))
	print("Sorted colors by frequency")
	
	var result: Array[Color] = []
	for i in range(min(6, sorted_colors.size())):
		var col_str = sorted_colors[i]
		result.append(_color_from_string_map.get(col_str, Color(0, 0, 0)))
		
	print("Final extracted colors:", result)
	return result

var _latest_color_counts: Dictionary

func _scan_colors(image: Image, only_bright: bool) -> Dictionary:
	var counts := {}
	for x in range(image.get_width()):
		var c: Color = image.get_pixel(x, 0)
		if only_bright:
			if c.r < 0.314 and c.g < 0.314 and c.b < 0.314:
				continue
		else:
			if c.r < 0.05 and c.g < 0.05 and c.b < 0.05:
				continue
		var key_color := Color(
			round(c.r * 10.0) / 10.0,
			round(c.g * 10.0) / 10.0,
			round(c.b * 10.0) / 10.0,
			1.0
		)
		var key_str := str(key_color)
		counts[key_str] = counts.get(key_str, 0) + 1
		_color_from_string_map[key_str] = key_color

	print("Scan complete. only_bright =", only_bright, "Unique entries:", counts.size())
	_latest_color_counts = counts
	return counts

func _compare_colors_by_frequency(a: String, b: String) -> int:
	if not _latest_color_counts.has(a) or not _latest_color_counts.has(b):
		print("Missing color count for", a, "or", b)
		return 0
	var result = _latest_color_counts[b] - _latest_color_counts[a]
	print("Comparing", a, "vs", b, "->", result)
	return result

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause-back"):
		_on_back_pressed()
	elif event.is_action_pressed("ui_accept"):
		_on_play_button_up()

func _on_play_button_up() -> void:
	_open_bezier_editor()

func _open_bezier_editor() -> void:
	var editor = Control.new()
	editor.name = "BezierEditor"
	editor.mouse_filter = Control.MOUSE_FILTER_STOP
	editor.size = Vector2(800, 700)
	editor.anchor_right = 1.0
	editor.anchor_bottom = 1.0
	editor.z_index = 999
	get_tree().root.add_child(editor)
	editor.top_level = true

	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.9)
	bg.size_flags_horizontal = Control.SIZE_FILL
	bg.size_flags_vertical = Control.SIZE_FILL
	editor.add_child(bg)

	# Canvas for the chart
	var chart = preload("res://Scenes/Tools/BezierChart.gd").new()
	chart.position = Vector2(450, 100)
	chart.size = Vector2(600, 400)
	chart.value_updated_callback = func():
		_extra_exponential_points = chart.get_sampled_array()

	editor.add_child(chart)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.position = Vector2(300, 0)
	close_btn.pressed.connect(func(): editor.queue_free())
	editor.add_child(close_btn)
	
	# Show array button
	var show_btn = Button.new()
	show_btn.text = "Show Array"
	show_btn.position = Vector2(400, 0)
	editor.add_child(show_btn)

	# TextEdit to display array
	var array_text = TextEdit.new()
	array_text.size = Vector2(600, 200)
	array_text.position = Vector2(100, 500)
	array_text.selecting_enabled = true
	array_text.visible = false
	array_text.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	editor.add_child(array_text)

	# Button logic
	show_btn.pressed.connect(func():
		var output := "[\n"
		for p in _extra_exponential_points:
			output += "\tVector2(%.3f, %.3f),\n" % [p.x, p.y]
		output += "]"
		array_text.text = output
		array_text.visible = true
		array_text.grab_focus()
		array_text.select_all()
	)

func _on_back_pressed() -> void:
	if $AnimationPlayer.is_playing():
		print("playing")
		await $AnimationPlayer.animation_finished
	
	var menu := preload("res://Scenes/main_menu.tscn").instantiate()
	menu.set("current_menu", "list")
	
	$AnimationPlayer.play("play_song")
	await get_tree().create_timer(1.0).timeout
	
	get_tree().root.add_child(menu)
	get_tree().current_scene.queue_free()
	get_tree().current_scene = menu
