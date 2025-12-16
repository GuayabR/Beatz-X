extends Control

func set_user(user: String):
	$name_side/username.text = "[" + Settings.game.clan + "]" + " [b]%s[/b]" % user

func set_title(title: String):
	$name_side/title.text = title

func set_clan(clan: String):
	$name_side/username.text = "[" + clan + "]" + " [b]%s[/b]" % Settings.game.username

func set_profile(profile: ImageTexture):
	$circle_mask/profile.texture = profile

func set_banner(banner: ImageTexture):
	$banner.texture = banner
	$banner.modulate = Color.GRAY

func _ready() -> void:
	$name_side/username.text = "[" + Settings.game.clan + "] [b]%s[/b]" % Settings.game.username
	$name_side/title.text = Settings.game.title

	var profile_path = Settings.game.profile_path
	var banner_path = Settings.game.banner_path

	if profile_path != "":
		print("Profile path:", profile_path)
		if FileAccess.file_exists(profile_path):
			var img := Image.new()
			var err := img.load(profile_path)
			if err != OK:
				push_warning("Failed to load profile image (%s): %s" % [profile_path, error_string(err)])
			elif img.is_empty():
				push_warning("Profile image is empty (zero size).")
			else:
				$circle_mask/profile.texture = ImageTexture.create_from_image(img)
		else:
			push_warning("Profile path does not exist: " + profile_path)

	if banner_path != "":
		print("Banner path:", banner_path)
		if FileAccess.file_exists(banner_path):
			var img := Image.new()
			var err := img.load(banner_path)
			if err != OK:
				push_warning("Failed to load banner image (%s): %s" % [banner_path, error_string(err)])
			elif img.is_empty():
				push_warning("Banner image is empty (zero size).")
			else:
				$banner.texture = ImageTexture.create_from_image(img)
				$banner.modulate = Color.GRAY
		else:
			push_warning("Banner path does not exist: " + banner_path)
