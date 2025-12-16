extends Label

var current_fps := 0.0

func _process(delta):
	if Settings.misc.show_fps:
		if Settings.misc.accurate_fps and delta > 0.0:
			current_fps = 1.0 / delta
			text = "FPS: " + General.format_number_with_commas(roundf(current_fps))
		else: 
			text = "FPS: " + General.format_number_with_commas(Engine.get_frames_per_second())
	else: text = ""
