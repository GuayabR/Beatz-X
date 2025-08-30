extends Label

func _process(_delta):
	if Globals.settings.misc_settings.show_fps:
		text = "FPS: %d" % Engine.get_frames_per_second()
	else: text = ""
