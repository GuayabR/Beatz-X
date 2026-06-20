extends Label

@export var single_line_mode := false

var current_fps := 0.0
var _stat_timer := 0.0

var _cached_mem := 0.0
var _cached_mem_peak := 0.0
var _cached_draw_calls := 0
var _cached_tex_mem := 0.0
var _cached_audio_latency := 0.0
var _cached_mix_rate := 0

func _process(delta):
	if Settings.misc.show_fps:
		if Settings.misc.accurate_fps and delta > 0.0:
			current_fps = 1.0 / delta
		else:
			current_fps = Engine.get_frames_per_second()

		_stat_timer += delta
		if _stat_timer >= 1.0:
			_stat_timer = 0.0
			
			_cached_mem = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
			_cached_mem_peak = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / (1024.0 * 1024.0)
			@warning_ignore("narrowing_conversion")
			_cached_draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			_cached_tex_mem = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / (1024.0 * 1024.0)
			_cached_audio_latency = AudioServer.get_output_latency() * 1000.0
			@warning_ignore("narrowing_conversion")
			_cached_mix_rate = AudioServer.get_mix_rate()

		var frame_time_ms = delta * 1000.0
		var lines := []
		
		lines.append("FPS: " + General.format_number_with_commas(roundf(current_fps)))

		if Settings.misc.show_frame_time:
			lines.append("Frame time: " + str(roundf(frame_time_ms * 100.0) / 100.0) + " ms")

		if Settings.misc.show_ram:
			lines.append("RAM: " + str(roundf(_cached_mem * 100.0) / 100.0) + " MB")
			
			if Settings.misc.show_more_ram:
				lines.append("Peak RAM: " + str(roundf(_cached_mem_peak * 100.0) / 100.0) + " MB")

		if Settings.misc.show_draw_calls:
			lines.append("Draw Calls: " + str(_cached_draw_calls))

		if Settings.misc.show_vram:
			lines.append("Texture VRAM: " + str(roundf(_cached_tex_mem * 100.0) / 100.0) + " MB")

		if Settings.misc.show_audio_latency:
			lines.append("Audio Latency: " + str(roundf(_cached_audio_latency * 100.0) / 100.0) + " ms")

		if Settings.misc.show_mix_rate:
			lines.append("Mix Rate: " + str(_cached_mix_rate) + " Hz")

		if single_line_mode:
			text = " | ".join(lines)
		else:
			text = "\n".join(lines)
	else:
		text = ""
