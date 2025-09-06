extends Label

var current_fps := 0.0

func _process(delta):
	if Globals.settings.misc_settings.show_fps:
		if Globals.settings.misc_settings.accurate_fps and delta > 0.0:
			current_fps = 1.0 / delta
			text = "FPS: " + str(roundf(current_fps)).trim_suffix(".0")
		else: 
			text = "FPS: %d" % Engine.get_frames_per_second()
	else: text = ""
