extends Control

@export_range(10, 360, 1) var visualizer_fps : float = 60.0
var _update_timer : float = 0.0
var cached_fft_left: PackedFloat32Array = []
var cached_fft_right: PackedFloat32Array = []

@export_enum("Bars", "Circle") var type: String = "Bars"
@export_enum("Mono", "Left and Right") var mode: String = "Mono"
@export_enum("Mirror vertically", "None") var appearance: String = "Mirror vertically"
@export_enum("Center", "Sides") var bass_bar_position: String = "Center"
@export_range(0, 100, 0.5) var circle_size: float = 25.0
@export_enum("Shake with bass", "Increase with all", "Increase with bass", "Increase and shake with all", "Increase and shake with bass","None") var reaction: String = "Shake with bass"
@export_range(0.1, 10.0, 0.1) var shake_strength := 1.0
@export_range(0.1, 10.0, 0.5) var shake_start := 5

@export var colored: bool = true
@export var custom_colors: bool = false
@export var colors: Array[Color] = [Color.WHITE]

@export var mirror_to_bottom: bool = false

@export_range(24, 540, 1) var bar_count: int = 240

@export var exponential_bounce := false
@export_range(1.0, 5.0, 0.1) var exponent_strength := 2.0

@export var extra_exponential := false

var _extra_exponential_points := [
	Vector2(0.0, 0.0),
	Vector2(0.1, 0.0),
	Vector2(0.2, 0.03),
	Vector2(0.3, 0.10),
	Vector2(0.4, 0.13),
	Vector2(0.5, 0.19),
	Vector2(0.6, 0.38),
	Vector2(0.7, 0.55),
	Vector2(0.8, 0.85),
	Vector2(0.9, 1.6),
	Vector2(0.95, 2),
	Vector2(1.0, 3.5)
]

@export var use_lerp: bool = false
@export_range(10, 1000, 1) var decay_speed: float = 120.0
@export_range(0.1, 50.0, 0.1) var lerp_strength: float = 10.0

const FREQ_MAX: float = 11050.0

var bass_energy := 0.0
var bass_energy_smoothed := 0.0
const BASS_SMOOTH_SPEED: float = 0.07  # tweak for smoothing speed (0 = no smoothing, 1 = very slow)

var loudness_smoothed := 0.0

var shake_offset := Vector2.ZERO

@export var fill_with_bars: bool = true
@export_range(0, 200, 1) var bar_spacing: float = 10.0
@export_range(1, 200, 1) var individual_bar_width: float = 8.0

const WIDTH = 1920.0 / 2.0
@export_range(0, 1080, 1) var HEIGHT: int = 150
const HEIGHT_SCALE: float = 10.0
const MIN_DB: int = 111

var spectrum
var min_values: Array[Variant] = []
var max_values: Array[Variant] = []

var transition_timer := 0.0
var transition_duration := 0.0
var target_values_left := []
var target_values_right := []
var transitioning_to_zero := false

func apply_extra_exponential(input: float) -> float:
	for i in range(_extra_exponential_points.size() - 1):
		var a = _extra_exponential_points[i]
		var b = _extra_exponential_points[i + 1]
		if input >= a.x and input <= b.x:
			var t = (input - a.x) / (b.x - a.x)
			return lerp(a.y, b.y, t)
	
	# If input exceeds provided points, clamp accordingly
	if input <= 0.0:
		return _extra_exponential_points[0].y
	elif input >= 1.0:
		return _extra_exponential_points[_extra_exponential_points.size() - 1].y
	
	return input  # Fallback

func get_bar_color(index: int) -> Color:
	if not colored:
		return Color.WHITE
	elif custom_colors:
		if colors is Array and colors.size() > 1:
			# Gradient between custom colors based on index
			var t = float(index) / (bar_count - 1)
			var step = 1.0 / (colors.size() - 1)
			var i = int(t / step)
			var local_t = (t - (i * step)) / step
			if i < colors.size() - 1:
				return colors[i].lerp(colors[i + 1], local_t)
			else:
				return colors[i]
		elif colors is Array and colors.size() == 1:
			return colors[0]
		else:
			return Color.WHITE # fallback to a default color

	else:
		return Color.from_hsv(float(index * 0.5) / bar_count, 0.5, 0.6)

func _draw():
	# Apply shake offset if any
	if shake_offset != Vector2.ZERO:
		draw_set_transform(shake_offset, 0, Vector2(1,1))
	else:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1,1))
		
	var w = WIDTH / bar_count
	if not fill_with_bars:
		w = individual_bar_width
	var center_x = size.x / 2

	var y_offset = size.y

	if type == "Bars":
		# Left bars (from center going left)
		for i in range(bar_count):
			var freq_index = i
			
			if bass_bar_position == "Sides":
				var quarter = bar_count / 4.0
				
				if i < quarter:
					freq_index = i + quarter * 3  # treble
				elif i < quarter * 2:
					freq_index = i - quarter  # bass
				elif i < quarter * 3:
					freq_index = quarter * 3 - i - 1  # bass mirrored
				else:
					freq_index = bar_count - i - 1  # treble mirrored
			
			var bar_x = center_x - (i + 1) * (w + (2.0 if fill_with_bars else bar_spacing - 2.0))
			draw_rect(Rect2(bar_x, y_offset - left_max_values[freq_index], w - 2, left_max_values[freq_index]), get_bar_color(freq_index))
			
			if mirror_to_bottom:
				draw_rect(Rect2(bar_x, y_offset, w - 2, left_max_values[freq_index]), get_bar_color(freq_index) * Color(1, 1, 1, 0.125))


		# Right bars (from center going right)
		for i in range(bar_count):
			var freq_index = i
			
			if bass_bar_position == "Sides":
				var quarter = bar_count / 4.0
				
				if i < quarter:
					freq_index = i + quarter * 3  # treble
				elif i < quarter * 2:
					freq_index = i - quarter  # bass
				elif i < quarter * 3:
					freq_index = quarter * 3 - i - 1  # bass mirrored
				else:
					freq_index = bar_count - i - 1  # treble mirrored
			
			var bar_x = center_x + i * (w + (2.0 if fill_with_bars else bar_spacing - 2.0))
			draw_rect(Rect2(bar_x, y_offset - right_max_values[freq_index], w - 2, right_max_values[freq_index]), get_bar_color(freq_index))
			
			if mirror_to_bottom:
				draw_rect(Rect2(bar_x, y_offset, w - 2, right_max_values[freq_index]), get_bar_color(freq_index) * Color(1, 1, 1, 0.125))


			
	else: # Circle type
		var cx = size.x / 2
		var cy = size.y / 2
		var base_radius = circle_size * 4.0
		
		var radius = base_radius
		if type == "Circle":
			match reaction:
				"Increase with bass", "Increase and shake with bass":
					radius = base_radius * (0.5 + bass_energy * 3)
				"Increase with all", "Increase and shake with all":
					radius = base_radius * (0.3 + loudness_smoothed * 5)

		for i in range(bar_count - 1):
			var angle_left = lerp(-PI, 0.0, float(i) / float(bar_count - 1))
			var angle_right = lerp(0.0, PI, float(i) / float(bar_count - 1))
			var height_l = left_max_values[i]
			var height_r = right_max_values[i]

			if mode == "Mono":
				var height = right_max_values[i]
				var angle = lerp(-PI, 0.0, float(i) / float(bar_count - 1))
				var dir = Vector2(cos(angle), sin(angle))
				var from = Vector2(cx, cy) + dir * radius
				var to = from + dir * height
				draw_line(from, to, get_bar_color(bar_count - i), 3)

				angle = lerp(0.0, PI, float(i) / float(bar_count - 1))
				dir = Vector2(cos(angle), sin(angle))
				from = Vector2(cx, cy) + dir * radius
				to = from + dir * height
				draw_line(from, to, get_bar_color(i), 3)

			elif mode == "Left and Right":
				var dir_l = Vector2(cos(angle_left), sin(angle_left))
				var dir_r = Vector2(cos(angle_right), sin(angle_right))

				var from_l = Vector2(cx, cy) + dir_l * radius
				var from_r = Vector2(cx, cy) + dir_r * radius

				var to_l = from_l + dir_l * height_l
				var to_r = from_r + dir_r * height_r

				# Left side colors use reversed index to match right side flow inward
				draw_line(from_l, to_l, get_bar_color(bar_count - i), 3)

				# Right side colors use reversed index so gradient flows toward center
				draw_line(from_r, to_r, get_bar_color(i), 3)

func _update_spectrum_cache() -> void:
	if spectrum_left == null or spectrum_right == null:
		print(spectrum_left, " or ", spectrum_right, " are null")
		return
	
	var step = FREQ_MAX / bar_count
	var prev_hz := 0.0
	
	for i in range(bar_count):
		var hz = (i + 1) * step
		cached_fft_left[i] = spectrum_left.get_magnitude_for_frequency_range(prev_hz, hz).length()
		cached_fft_right[i] = spectrum_right.get_magnitude_for_frequency_range(prev_hz, hz).length()
		prev_hz = hz


func _update_visualizer_logic(delta: float) -> void:
	var bass_min_hz := 20.0
	var bass_max_hz := 150.0

	# Get bass energy from cached FFT
	var mag_left_bass := cached_fft_left[0]
	var mag_right_bass := cached_fft_right[0]
	var bass_raw := clampf((MIN_DB + linear_to_db(mag_left_bass + mag_right_bass)) / MIN_DB, 0, 1)
	bass_energy = bass_raw

	for i in range(bar_count):
		# --- Left channel ---
		var energy_left := clampf((MIN_DB + linear_to_db(cached_fft_left[i])) / MIN_DB, 0, 1)
		var adjusted_left := pow(energy_left, exponent_strength) if exponential_bounce else energy_left
		if extra_exponential:
			adjusted_left = apply_extra_exponential(energy_left)
		var target_left := adjusted_left * HEIGHT

		# --- Right channel ---
		var energy_right := clampf((MIN_DB + linear_to_db(cached_fft_right[i])) / MIN_DB, 0, 1)
		var adjusted_right := pow(energy_right, exponent_strength) if exponential_bounce else energy_right
		if extra_exponential:
			adjusted_right = apply_extra_exponential(energy_right)
		var target_right := adjusted_right * HEIGHT

		# --- Apply decay / lerp smoothing ---
		if target_left > left_max_values[i]:
			left_max_values[i] = target_left
		else:
			if use_lerp:
				left_max_values[i] = lerp(left_max_values[i], target_left, delta * lerp_strength)
			else:
				left_max_values[i] = max(0.0, left_max_values[i] - decay_speed * delta)

		if target_right > right_max_values[i]:
			right_max_values[i] = target_right
		else:
			if use_lerp:
				right_max_values[i] = lerp(right_max_values[i], target_right, delta * lerp_strength)
			else:
				right_max_values[i] = max(0.0, right_max_values[i] - decay_speed * delta)

	# --- Shake logic (unchanged) ---
	if reaction == "Shake with all" or reaction == "Increase and shake with all":
		if bass_energy * 10 >= shake_start:
			shake_offset = Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)).normalized() \
				* pow(bass_energy, -4.0) * shake_strength
		else:
			shake_offset = Vector2.ZERO
	elif reaction == "Shake with bass" or reaction == "Increase and shake with bass":
		if bass_energy * 10 >= shake_start:
			shake_offset = Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)).normalized() \
				* pow(bass_energy, -4.0) * shake_strength
		else:
			shake_offset = Vector2.ZERO
	else:
		shake_offset = Vector2.ZERO

func _process(delta: float) -> void:
	# Stop updating if main window is not focused
	if not DisplayServer.window_is_focused():
		return
	
	if not $Song_left.playing: 
		hide()
		return
	else: show()
	
	_update_timer += delta
	var interval := 1.0 / visualizer_fps
	if _update_timer < interval:
		return
	_update_timer = 0.0

	# copy spectrum magnitudes once (thread-safe snapshot)
	_update_spectrum_cache()

	# then just read cached data, no locks here
	_update_visualizer_logic(delta)
	queue_redraw()


var _fading := false
var force_fading := false
var force_fade_timer := 0.0
var force_fade_duration := 0.75
var force_target_left := []
var force_target_right := []

func force_fade_out(duration := 0.75) -> void:
	if _fading or transitioning_to_zero or force_fading:
		return
	
	force_fading = true
	force_fade_timer = 0.0
	force_fade_duration = duration
	force_target_left = left_max_values.duplicate()
	force_target_right = right_max_values.duplicate()

func force_fade_in():
	_fading = false
	force_fading = false
	force_fade_timer = 0.0
	force_fade_duration = 0.0
	show()

var spectrum_left
var spectrum_right
var left_min_values: Array[Variant] = []
var left_max_values: Array[Variant] = []
var right_min_values: Array[Variant] = []
var right_max_values: Array[Variant] = []

func _ready():
	#$Song_left.play()
	#$Song_right.play()
	
	spectrum_left = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Song left signal"), 0)
	spectrum_right = AudioServer.get_bus_effect_instance(AudioServer.get_bus_index("Song right signal"), 0)

	left_min_values.resize(bar_count)
	left_max_values.resize(bar_count)
	right_min_values.resize(bar_count)
	right_max_values.resize(bar_count)
	left_min_values.fill(0.0)
	left_max_values.fill(0.0)
	right_min_values.fill(0.0)
	right_max_values.fill(0.0)
	
	target_values_left.resize(bar_count)
	target_values_right.resize(bar_count)
	target_values_left.fill(0.0)
	target_values_right.fill(0.0)
	
	cached_fft_left.resize(bar_count)
	cached_fft_right.resize(bar_count)
