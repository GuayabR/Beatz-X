extends ColorRect

var _color := Color(1.0, 1.0, 1.0, 0.2)
@export var COLOR: Color = _color:
	set(value):
		COLOR = value
		_apply_waveform_color()
	#get():
		#return Settings.misc.editor_waveform_color# Color(1.0, 1.0, 1.0, 0.25)

const CHUNK_MS := 5000.0
const CHUNK_WIDTH: int = 964

var preview
var stream_len := 0.0
var preview_len := 0.0
var loaded := false
var stream: AudioStream

# false = original _draw() method
# true = chunked texture generation
var use_chunks: bool = false

var thread: Thread
var mutex := Mutex
var chunk_queue: Array = []
var generating := false
var next_chunk := 0
var total_chunks := 0

enum WaveformQuality {
	ULTRA,   # current behavior (1:1 sampling)
	HIGH,    # slight vertical skip
	MEDIUM,  # visible downsampling
	LOW      # aggressive downsampling (fast)
}

@export var waveform_quality: WaveformQuality = WaveformQuality.ULTRA:
	set(value):
		waveform_quality = value
		_apply_waveform_quality()
	

var vertical_step: int = 1
var horizontal_step: int = 1
var amp_smooth: int = 1

func _apply_waveform_quality():
	match waveform_quality:
		WaveformQuality.ULTRA:
			vertical_step = 1
			horizontal_step = 1
			amp_smooth = 1

		WaveformQuality.HIGH:
			vertical_step = 1
			horizontal_step = 1
			amp_smooth = 2

		WaveformQuality.MEDIUM:
			vertical_step = 2
			horizontal_step = 1
			amp_smooth = 3

		WaveformQuality.LOW:
			vertical_step = 3
			horizontal_step = 2
			amp_smooth = 4

func _apply_waveform_color():
	for c in rendered_chunks.values():
		if is_instance_valid(c):
			c.modulate = COLOR

enum WaveformAlign {
	CENTER,
	LEFT,
	RIGHT
}

@export var waveform_align: WaveformAlign = WaveformAlign.CENTER

func setup(stream_to_preview: AudioStream):
	print("Setting up")
	
	regenerate()
	
	_apply_waveform_quality()
	
	var gen := AudioStreamPreviewGenerator.new()

	gen.connect(
		"preview_updated",
		Callable(self, "_on_preview_updated")
	)
	
	stream = stream_to_preview

	preview = gen.generate_preview(stream_to_preview)
	stream_len = stream_to_preview.get_length()
	preview_len = preview.get_length()
	
	#stop_generation()


func _draw_preview():
	print("_draw_preview")

	var rect = get_rect()
	var s = rect.size

	for i in range(0, s.x):
		var ofs = i * preview_len / s.x
		var ofs_n = (i + 1) * preview_len / s.x

		var maxint = preview.get_max(ofs, ofs_n) * 0.5 + 0.5
		var minint = preview.get_min(ofs, ofs_n) * 0.5 + 0.5

		var center: float = s.y * 0.5

		var y0: float
		var y1: float

		match waveform_align:
			WaveformAlign.CENTER:
				y0 = center + minint * center * 0.9
				y1 = center + maxint * center * 0.9

			WaveformAlign.LEFT:
				y0 = center
				y1 = center + maxint * center * 0.9

			WaveformAlign.RIGHT:
				y0 = center + minint * center * 0.9
				y1 = center

		draw_line(
			Vector2(i + 1, y0),
			Vector2(i + 1, y1),
			COLOR,
			1,
			false
		)


func _generate_chunks():
	for c in get_children():
		c.queue_free()

	chunk_textures.clear()
	rendered_chunks.clear()

	var song_ms: float = preview_len * 1000.0
	total_chunks = int(ceil(song_ms / CHUNK_MS))

	next_chunk = 0
	generating = true

	thread = Thread.new()
	thread.start(_chunk_worker)

func _chunk_worker():
	while next_chunk < total_chunks and generating:
		if not is_instance_valid(self): return
		var idx := next_chunk
		next_chunk += 1

		var img := _build_chunk_image(idx)

		# send result back to main thread safely
		call_deferred("_on_chunk_ready", idx, img)

var chunk_height_offset: float = 1879.6#94.0

func _build_chunk_image(chunk_idx: int) -> Image:
	var start_ms := float(chunk_idx) * CHUNK_MS
	var end_ms: float = min(start_ms + CHUNK_MS, preview_len * 1000.0)

	var top_y := Beatz.time_to_y(start_ms)
	var bottom_y := Beatz.time_to_y(end_ms)

	var height: int = abs(bottom_y - top_y)
	height = max(height, 1) - chunk_height_offset

	var img := Image.create(
		CHUNK_WIDTH,
		height,
		false,
		Image.FORMAT_RGBA8
	)

	img.fill(Color.TRANSPARENT)

	for y in range(0, height, vertical_step):
		var t0: float = lerp(start_ms, end_ms, float(y) / float(height))
		var t1: float = lerp(start_ms, end_ms, float(min(y + vertical_step, height)) / float(height))

		var min_amp = preview.get_min(t0 / 1000.0, t1 / 1000.0)
		var max_amp = preview.get_max(t0 / 1000.0, t1 / 1000.0)

		var center := CHUNK_WIDTH * 0.5

		var left_x: float
		var right_x: float

		match waveform_align:
			WaveformAlign.CENTER:
				left_x = center + min_amp * center * 0.9
				right_x = center + max_amp * center * 0.9

			WaveformAlign.LEFT:
				left_x = center
				right_x = center + max_amp * center * 0.9

			WaveformAlign.RIGHT:
				left_x = center + min_amp * center * 0.9
				right_x = center
		
		for x in range(int(min(left_x, right_x)), int(max(left_x, right_x)), horizontal_step):
			img.set_pixel(x, y, COLOR)

	img = _rotate_image_ccw_90(img)

	return img

func _on_chunk_ready(chunk_idx: int, img: Image):
	if not generating:
		return

	var tex := ImageTexture.create_from_image(img)

	var rect := TextureRect.new()
	rect.texture = tex
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size = Vector2(img.get_height(), CHUNK_WIDTH)
	rect.modulate = COLOR

	var start_ms := float(chunk_idx) * CHUNK_MS
	var top_y := Beatz.time_to_y(start_ms) - (chunk_height_offset * chunk_idx)

	rect.position = Vector2(top_y, -40.0)

	add_child(rect)

	chunk_textures.append(tex)

	# finished?
	if chunk_textures.size() >= total_chunks:
		generating = false
		thread.wait_to_finish()

func stop_generation():
	generating = false

	if thread and thread.is_started():
		thread.wait_to_finish()

func regenerate():
	if not use_chunks: return
	if generating:
		stop_generation()
	
	_generate_chunks()

func _rotate_image_ccw_90(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()

	var rotated := Image.create(h, w, false, img.get_format())

	for y in range(h):
		for x in range(w):
			rotated.set_pixel(
				y,
				w - 1 - x,
				img.get_pixel(x, y)
			)

	return rotated


const WAVE_RENDER_DISTANCE := 12000.0

var chunk_textures := []
var rendered_chunks := {}

func update_visible_chunks(scroll_y: float):
	var min_y = -scroll_y - WAVE_RENDER_DISTANCE
	var max_y = -scroll_y + WAVE_RENDER_DISTANCE

	var visible_chunks := {}

	for i in range(chunk_textures.size()):
		var start_ms := float(i) * CHUNK_MS
		var end_ms := start_ms + CHUNK_MS

		var top_y := Beatz.time_to_y(start_ms)
		var bottom_y := Beatz.time_to_y(end_ms)

		var chunk_top = min(top_y, bottom_y)
		var chunk_bottom = max(top_y, bottom_y)

		if chunk_bottom < min_y or chunk_top > max_y:
			continue

		visible_chunks[i] = true

		if not rendered_chunks.has(i):
			var spr := Sprite2D.new()
			spr.texture = chunk_textures[i]
			spr.centered = false
			spr.position = Vector2(0.0, top_y)

			add_child(spr)
			rendered_chunks[i] = spr

	for i in rendered_chunks.keys():
		if visible_chunks.has(i):
			continue

		if is_instance_valid(rendered_chunks[i]):
			rendered_chunks[i].queue_free()

		rendered_chunks.erase(i)


func _on_preview_updated(_e):
	if loaded:
		return

	loaded = true

	if use_chunks:
		_generate_chunks()
	else:
		queue_redraw()


func _draw():
	if loaded and not use_chunks:
		_draw_preview()
