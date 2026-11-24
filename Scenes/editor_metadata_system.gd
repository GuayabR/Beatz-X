extends Node

var System: Variant

func _ready() -> void:
	System = get_parent()

func refresh_song_detail_marquees() -> void:
	for node_name in ["song_title", "song_artist", "album", "song_path"]:
		System.get_node("Control/song_details/" + node_name).call("refresh")

var mandatory := []
var use_meta_check := false
var album_cover_path: String
var album_cover_mime: String
var background_img_path: String
var removed_bg: bool = false
var diff_texture_path: String
var removed_diff_texture: bool = false
var background_vid_path: String
var removed_bg_vid: bool = false
var cover_loop_vid_path: String
var removed_cover_loop_vid: bool = false
var songbpm_url: String = ""
var songbpm_url_exists: bool = true
var _request_cooldown := false
var _pending_request_url := ""
var legacy_artist_needs_split := false

func refresh_artist_added_label(panel_name: String) -> void:
	var label: RichTextLabel = System.get_node("Control/" + panel_name + "/artist_added_label")
	label.text = ", ".join(System.selected_artists) if not System.selected_artists.is_empty() else "No artists added"
	var remove_button: Button = System.get_node("Control/" + panel_name + "/rm_artist")
	remove_button.disabled = System.selected_artists.is_empty()

	var split_button: Button = System.get_node("Control/" + panel_name + "/split_artists")
	split_button.visible = panel_name == "edit_meta_cont" and legacy_artist_needs_split
	if not split_button.visible:
		label.size.x = 247.0
		label.position.x = -429.0

func refresh_all_artist_controls() -> void:
	refresh_artist_added_label("edit_meta_cont")
	refresh_artist_added_label("create_map_panel")

func _add_artist_to_list(artist_name: String) -> void:
	var normalized_name := artist_name.strip_edges()
	if normalized_name == "":
		return

	for existing_artist in System.selected_artists:
		if existing_artist.to_lower() == normalized_name.to_lower():
			refresh_all_artist_controls()
			return

	System.selected_artists.append(normalized_name)
	refresh_all_artist_controls()

func _add_artist_from_panel(panel_name: String) -> void:
	var panel: Node = System.get_node("Control/" + panel_name)
	var artist_edit: LineEdit = panel.get_node("artist_edit")
	var artist_name := artist_edit.text.strip_edges()
	artist_edit.clear()
	_add_artist_to_list(artist_name)

func _remove_last_artist() -> void:
	if not System.selected_artists.is_empty():
		System.selected_artists.pop_back()
	refresh_all_artist_controls()

func _split_legacy_artists() -> void:
	var artist_credit := str(System.selected_artist).strip_edges()
	if artist_credit == "":
		return

	var split_artists: Array[String] = []
	var normalized_credit := artist_credit.replace("&", ",").replace("/", ",")
	for artist_part in normalized_credit.split(",", false):
		var artist_name := artist_part.strip_edges()
		if artist_name == "":
			continue
		var already_added := false
		for existing_artist in split_artists:
			if existing_artist.to_lower() == artist_name.to_lower():
				already_added = true
				break
		if not already_added:
			split_artists.append(artist_name)

	for existing_artist in System.selected_artists:
		if existing_artist.to_lower() != artist_credit.to_lower():
			var already_added := false
			for split_artist in split_artists:
				if split_artist.to_lower() == existing_artist.to_lower():
					already_added = true
					break
			if not already_added:
				split_artists.append(existing_artist)

	System.selected_artists = split_artists
	legacy_artist_needs_split = false
	refresh_all_artist_controls()

func _on_edit_meta_artist_edit_text_submitted(_text: String) -> void:
	_add_artist_from_panel("edit_meta_cont")

func _on_create_map_artist_edit_text_submitted(_text: String) -> void:
	_add_artist_from_panel("create_map_panel")

func _on_edit_meta_add_artist_pressed() -> void:
	_add_artist_from_panel("edit_meta_cont")

func _on_create_map_add_artist_pressed() -> void:
	_add_artist_from_panel("create_map_panel")

func _on_edit_meta_rm_artist_pressed() -> void:
	_remove_last_artist()

func _on_create_map_rm_artist_pressed() -> void:
	_remove_last_artist()

func _on_edit_meta_split_artists_pressed() -> void:
	_split_legacy_artists()

func _on_create_map_split_artists_pressed() -> void:
	_split_legacy_artists()

func _on_save_meta_btn_pressed() -> void:
	System.restore_editor_mode()
	System.transition(System.get_node("Control/edit_meta_cont"), "scale", Vector2.ZERO, .2, true)
	System.get_node("Control/edit_meta_cont/save_btn").release_focus()

	System.get_node("Control/chart_details/chart_name").text = '"' + System.get_node("Control/edit_meta_cont/chart_name_edit").text + '"'
	System.selected_chart_name = System.get_node("Control/edit_meta_cont/chart_name_edit").text

	System.get_node("Control/song_details/song_title/Text").text = System.get_node("Control/edit_meta_cont/song_name_edit").text
	System.selected_title = System.get_node("Control/edit_meta_cont/song_name_edit").text

	System.get_node("Control/chart_details/charter").text = System.get_node("Control/edit_meta_cont/charter_edit").text
	System.selected_charter = System.get_node("Control/edit_meta_cont/charter_edit").text

	var diff_text: String = System.get_node("Control/edit_meta_cont/diff_edit").text.strip_edges()
	System.get_node("Control/chart_details/diff").text = "Difficulty: " + diff_text.to_pascal_case() if diff_text != "" else "Easy"
	System.selected_difficulty = System.get_node("Control/edit_meta_cont/diff_edit").text

	System.get_node("Control/chart_details/diff_tex").texture = System.get_node("Control/edit_meta_cont/diff_texture_edit").icon
	System.selected_diff_texture = System.get_node("Control/edit_meta_cont/diff_texture_edit").icon

	var bpm_text: String = System.get_node("Control/edit_meta_cont/bpm_edit").text.strip_edges()
	System.get_node("Control/chart_details/bpm").text = "BPM: " + bpm_text if bpm_text != "" else "BPM: 120"
	System.selected_bpm = float(System.get_node("Control/edit_meta_cont/bpm_edit").text)

	System.ChartDisplaySystem._update_visible_beatlines()

	System.selected_artist = ", ".join(System.selected_artists)
	System.selected_artists_before_edit = System.selected_artists.duplicate()
	System.legacy_artist_needs_split_before_edit = false
	legacy_artist_needs_split = false
	refresh_all_artist_controls()
	System.get_node("Control/song_details/song_artist/Text").text = System.selected_artist

	if System.selected_artist.to_upper() == "LINKIN PARK":
		System.get_node("Control/song_details/song_artist/Text").text = "[b]" + System.selected_artist.to_upper() + "[/b]"
		System.get_node("Control/song_details/song_artist").position.y = 56.0
	else:
		System.get_node("Control/song_details/song_artist/Text").text = System.selected_artist
		#$Control/song_details/song_artist.position.y = 62.0

	System.get_node("Control/song_details/album/Text").text = System.get_node("Control/edit_meta_cont/album_edit").text
	System.selected_album = System.get_node("Control/edit_meta_cont/album_edit").text

	var cov: ImageTexture = System.get_node("Control/edit_meta_cont/album_cover_edit").icon
	if cov:
		System.selected_cover = cov.get_image()
		System.get_node("Control/song_details/sha").show()
	else:
		System.selected_cover = preload("res://Resources/misc/noCover.png").get_image()
		System.get_node("Control/song_details/sha").hide()

	System.selected_background_name = System.get_node("Control/edit_meta_cont/bg_img_details").get_meta("background_name")

	var bg: ImageTexture

	if System.get_node("Control/edit_meta_cont/bg_img_edit").icon:
		bg = System.get_node("Control/edit_meta_cont/bg_img_edit").icon
		System.selected_background = bg.get_image()

	if bg and removed_bg:
		System.selected_background = null
		System.selected_background_name = ""

	if not bg:
		var t = load("res://Resources/defaultBG.png")
		bg = ImageTexture.create_from_image(t.get_image())

	System.get_node("Control/bg").texture = bg

	System.get_node("Control/song_details/sha/cover_spin").texture = ImageTexture.create_from_image(System.selected_cover)

	System.get_node("Control/song_details/year").text = System.get_node("Control/edit_meta_cont/year_edit").text
	System.selected_year = int(System.get_node("Control/edit_meta_cont/year_edit").text)

	System.get_node("Control/song_details/song_path/Text").text = "Path: " + System.song_path
	refresh_song_detail_marquees()

	DisplayServer.window_set_title("Editing %s - %s | Beatz! X" % [System.selected_title, System.selected_artist])

	System.set_save_warn()

	System.set_discord_rpc()

func _on_complete_setup_btn_pressed() -> void:
	System.get_node("Control/create_map_panel/complete_setup_btn").release_focus()

	System.restore_editor_mode()
	System.get_node("Control/chart_details/chart_name").text = '"' + System.get_node("Control/create_map_panel/chart_name_edit").text + '"'
	System.selected_chart_name = System.get_node("Control/create_map_panel/chart_name_edit").text

	System.get_node("Control/song_details/song_title/Text").text = System.get_node("Control/create_map_panel/song_name_edit").text
	System.selected_title = System.get_node("Control/create_map_panel/song_name_edit").text

	System.get_node("Control/chart_details/charter").text = System.get_node("Control/create_map_panel/charter_edit").text
	System.selected_charter = System.get_node("Control/create_map_panel/charter_edit").text

	var diff_text: String = System.get_node("Control/create_map_panel/diff_edit").text.strip_edges()
	System.get_node("Control/chart_details/diff").text = "Difficulty: " + diff_text if diff_text != "" else "Easy"
	System.selected_difficulty = System.get_node("Control/create_map_panel/diff_edit").text

	System.get_node("Control/chart_details/diff_tex").texture = System.get_node("Control/create_map_panel/diff_texture_edit").icon
	System.selected_diff_texture = System.get_node("Control/create_map_panel/diff_texture_edit").icon

	var bpm_text: String = "BPM: " + System.get_node("Control/create_map_panel/bpm_edit").text.strip_edges()
	System.get_node("Control/chart_details/bpm").text = bpm_text
	System.selected_bpm = float(System.get_node("Control/create_map_panel/bpm_edit").text)

	System.selected_artist = ", ".join(System.selected_artists)
	legacy_artist_needs_split = false
	refresh_all_artist_controls()
	System.get_node("Control/song_details/song_artist/Text").text = System.selected_artist

	if System.selected_artist.to_upper() == "LINKIN PARK":
		System.get_node("Control/song_details/song_artist/Text").text = "[b]" + System.selected_artist.to_upper() + "[/b]"
		System.get_node("Control/song_details/song_artist").position.y = 56.0
	else:
		System.get_node("Control/song_details/song_artist/Text").text = System.selected_artist
		#$Control/song_details/song_artist.position.y = 62.0

	System.get_node("Control/song_details/album/Text").text = System.get_node("Control/create_map_panel/album_edit").text
	System.selected_album = System.get_node("Control/create_map_panel/album_edit").text

	var cov: ImageTexture = System.get_node("Control/create_map_panel/album_cover_edit").icon
	if cov:
		System.selected_cover = cov.get_image()

		System.get_node("Control/song_details/sha/cover_spin").texture = cov

		System.get_node("Control/song_details/sha").show()
	else:
		System.selected_cover = preload("res://Resources/misc/noCover.png").get_image()

	System.selected_background_name = System.get_node("Control/edit_meta_cont/bg_img_details").get_meta("background_name")

	var bg: ImageTexture

	if System.get_node("Control/edit_meta_cont/bg_img_edit").icon:
		bg = System.get_node("Control/edit_meta_cont/bg_img_edit").icon
		System.selected_background = bg.get_image()

	if bg and removed_bg:
		System.selected_background = null
		System.selected_background_name = ""

	if not bg:
		var t = load("res://Resources/defaultBG.png")
		bg = ImageTexture.create_from_image(t.get_image())

	System.get_node("Control/bg").texture = bg

	System.selected_background_name = System.get_node("Control/edit_meta_cont/bg_img_details").get_meta("background_name")

	System.get_node("Control/song_details/year").text = System.get_node("Control/create_map_panel/year_edit").text
	System.selected_year = int(System.get_node("Control/create_map_panel/year_edit").text)

	System.get_node("Control/song_details/song_path/Text").text = "Path: " + System.song_path
	refresh_song_detail_marquees()

	System.get_node("Control/edit_meta_cont/explorer_open_btn").tooltip_text = "Open " + System.song_path.get_base_dir() + " in your explorer."

	System.setting_up = false

	DisplayServer.window_set_title("Editing %s - %s | Beatz! X" % [System.selected_title, System.selected_artist])

	System.transition(System.get_node("Control/create_map_panel"), "scale", Vector2.ZERO, .2, true)

	System._on_reload_pressed()
	System.set_discord_rpc()

func _on_song_file_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .mp3, .wav or .ogg file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.AUDIO_FORMATS,   # File filters
		Callable(self, "_on_song_select_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("create_song_file", err, error_string(err))

func _on_edit_song_file_select_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Open .mp3, .wav or .ogg file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.AUDIO_FORMATS,   # File filters
		Callable(self, "_on_edit_song_select_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("edit_song_file", err, error_string(err))

func _on_song_select_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("song select file status", status)
	print("song select paths ", paths)
	print("song select filter idx", _filter_idx)

	if not status or paths.is_empty():
		return

	if paths[0].get_extension() not in ["mp3", "ogg", "wav"]:
		System.get_node("Control/create_map_panel/song_file_label").text = "Song has to be an mp3, ogg or wav file."
		return

	System.song_path = paths[0]
	System.get_node("Control/create_map_panel/song_file_label").text = "Song: " + str(paths[0])

	var song_didnt_fail := true
	if System.song_path.ends_with(".mp3") or System.song_path.ends_with(".ogg") or System.song_path.ends_with(".wav"):
		if System.song_path.ends_with(".mp3"):
			System.selected_stream = AudioStreamMP3.load_from_file(System.song_path)
			print("Song created as mp3 ", System.selected_stream)
		elif System.song_path.ends_with(".ogg"):
			System.selected_stream = AudioStreamOggVorbis.load_from_file(System.song_path)
			print("Song created as ogg ", System.selected_stream)
		elif System.song_path.ends_with(".wav"):
			System.selected_stream = AudioStreamWAV.load_from_file(System.song_path)
			print("Song created as wav ", System.selected_stream)
		else:
			song_didnt_fail = false
			print("Unsupported audio format in: %s" % System.song_path)
			System.selected_stream = null

	if song_didnt_fail:
		System.get_node("song").stream = System.selected_stream
		if "song_file" not in mandatory:
			mandatory.append("song_file")
		_check_mandatory()

		General._set_rpc(str(System.song_path.get_file()), "Creating a Beatzmap...", "beatzroundcover", "Download now at beatzx.com!", "beatzroundcover", "FEEL. YOUR RHYTHM.", System.edit_start_time, 0)

		print("Song saved ", System.get_node("song").stream)
		System.get_node("Control/create_map_panel/song_file_select").text = "Change song file..."

	if not System.song_path.get_extension() == "mp3":
		System.get_node("Control/create_map_panel/metadata_use_check").button_pressed = false
		System.get_node("Control/create_map_panel/metadata_use_check").text = "File is not an mp3."
	else:
		System.get_node("Control/create_map_panel/metadata_use_check").disabled = false
		System.get_node("Control/create_map_panel/metadata_use_check").text = "Use Song Metadata"

	if System.get_node("Control/create_map_panel/metadata_use_check").button_pressed: _on_metadata_use_check_toggled(true)

func _on_edit_song_select_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("edit song select sta", status)
	print("edit song select paths ", paths)
	print("edit song select filter idx", _filter_idx)

	if not status or paths.is_empty():
		return

	if paths[0].get_extension() not in ["mp3", "ogg", "wav"]:
		System.get_node("Control/edit_meta_cont/song_file_label").text = "Song has to be an mp3, ogg or wav file."
		return

	System.song_path = paths[0]
	System.get_node("Control/edit_meta_cont/song_file_label").text = "Song: " + str(paths[0])
	System.get_node("Control/song_details/song_path/Text").text = "Path: " + System.song_path
	System.get_node("Control/song_details/song_path").call("refresh")

	var song_didnt_fail := true
	if System.song_path.ends_with(".mp3") or System.song_path.ends_with(".ogg") or System.song_path.ends_with(".wav"):
		if System.song_path.ends_with(".mp3"):
			System.selected_stream = AudioStreamMP3.load_from_file(System.song_path)
			print("Song created as mp3 ", System.selected_stream)
		elif System.song_path.ends_with(".ogg"):
			System.selected_stream = AudioStreamOggVorbis.load_from_file(System.song_path)
			print("Song created as ogg ", System.selected_stream)
		elif System.song_path.ends_with(".wav"):
			System.selected_stream = AudioStreamWAV.load_from_file(System.song_path)
			print("Song created as wav ", System.selected_stream)
		else:
			song_didnt_fail = false
			print("Unsupported audio format in: %s" % System.song_path)
			System.selected_stream = null

	if song_didnt_fail:
		System.get_node("song").stream = System.selected_stream
		print("Song saved ", System.get_node("song").stream)

		System.get_node("Control/edit_meta_cont/song_file_select").text = "Change song file..."

	if not System.song_path.get_extension() == "mp3":
		System.get_node("Control/edit_meta_cont/metadata_use_check").button_pressed = false
		System.get_node("Control/edit_meta_cont/metadata_use_check").text = "File is not an mp3."
	else:
		System.get_node("Control/edit_meta_cont/metadata_use_check").disabled = false
		System.get_node("Control/edit_meta_cont/metadata_use_check").text = "Use Song Metadata"

	if System.get_node("Control/edit_meta_cont/metadata_use_check").button_pressed: _on_edit_metadata_use_check_toggled(true)

func _on_metadata_use_check_toggled(toggled_on: bool) -> void:
	use_meta_check = toggled_on

	if not toggled_on or not System.song_path:
		return

	# Make sure it's an MP3
	if System.song_path.get_extension().to_lower() != "mp3":
		System.get_node("Control/create_map_panel/metadata_use_check").button_pressed = false
		System.get_node("Control/create_map_panel/metadata_use_check").text = "File is not an mp3."
		System.get_node("Control/create_map_panel/metadata_use_check").release_focus()
		return

	# Parse ID3 from file
	var metaRead := MP3ID3Tag.new()
	var loaded_ok := metaRead.load_file(System.song_path)
	if not loaded_ok:
		print("Failed to load ID3 tags for ", System.song_path)
		return

	# Track name
	var track := metaRead.getTrackName()
	if track and track.strip_edges() != "":
		System.get_node("Control/create_map_panel/song_name_edit").text = track
		System.get_node("Control/create_map_panel/chart_name_edit").text = track
		System.get_node("Control/create_map_panel/chart_name_edit").text_changed.emit()
	else:
		print("Track name not in metadata")

	# Artist
	var artist := metaRead.getArtist()
	if artist and artist.strip_edges() != "":
		System.get_node("Control/create_map_panel/artist_edit").text = artist
	else:
		print("Artist not in metadata")

	# Album
	var album := metaRead.getAlbum()
	if album and album.strip_edges() != "":
		System.get_node("Control/create_map_panel/album_edit").text = album
	else:
		print("Album not in metadata")

	# Year
	var year := metaRead.getYear()
	if year and year.strip_edges() != "":
		System.get_node("Control/create_map_panel/year_edit").text = year
	else:
		print("Year not in metadata")

	# Cover (first attached picture)
	var response: Array = metaRead.getAttachedPictureAndMime(0)
	if not response.is_empty() and response[0]:
		var tex: ImageTexture
		if response[0] is Image: tex = ImageTexture.create_from_image(response[0])
		album_cover_mime = response[1]
		if tex:
			System.get_node("Control/create_map_panel/album_cover_edit").icon = tex
			System.get_node("Control/create_map_panel/cover_img_details").text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + "Attached Album Cover " + response[1] + "\n" + General.format_file_size(response[0].get_data_size())
	else:
		System.get_node("Control/create_map_panel/album_cover_edit").icon = null
		System.get_node("Control/create_map_panel/cover_img_details").text = "No Cover Found"
		print("Cover image not in metadata")


func _on_edit_metadata_use_check_toggled(toggled_on: bool) -> void:
	use_meta_check = toggled_on
	if not toggled_on or not System.song_path:
		return
	if System.song_path.get_extension().to_lower() != "mp3":
		System.get_node("Control/edit_meta_cont/metadata_use_check").button_pressed = false
		System.get_node("Control/edit_meta_cont/metadata_use_check").text = "File is not an mp3."
		System.get_node("Control/edit_meta_cont/metadata_use_check").release_focus()
		return

	var meta_read := MP3ID3Tag.new()
	if not meta_read.load_file(System.song_path):
		print("Failed to load ID3 tags for ", System.song_path)
		return

	var track := meta_read.getTrackName()
	if track and track.strip_edges() != "":
		System.get_node("Control/edit_meta_cont/song_name_edit").text = track

	var artist := meta_read.getArtist()
	if artist and artist.strip_edges() != "":
		System.get_node("Control/edit_meta_cont/artist_edit").text = artist

	var album := meta_read.getAlbum()
	if album and album.strip_edges() != "":
		System.get_node("Control/edit_meta_cont/album_edit").text = album

	var year := meta_read.getYear()
	if year and year.strip_edges() != "":
		System.get_node("Control/edit_meta_cont/year_edit").text = year

	var response: Array = meta_read.getAttachedPictureAndMime(0)
	if not response.is_empty() and response[0] is Image:
		var texture := ImageTexture.create_from_image(response[0])
		album_cover_mime = response[1]
		System.get_node("Control/edit_meta_cont/album_cover_edit").icon = texture
		System.get_node("Control/edit_meta_cont/cover_img_details").text = str(texture.get_width()) + "x" + str(texture.get_height()) + "\nAttached Album Cover " + response[1] + "\n" + General.format_file_size(response[0].get_data_size())
	else:
		System.get_node("Control/edit_meta_cont/album_cover_edit").icon = null
		System.get_node("Control/edit_meta_cont/cover_img_details").text = "No Cover Found"

func _on_album_cover_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		Settings.game.last_editor_path,             # Initial path (empty means default)
		"",
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_album_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("create_album", err, error_string(err))

func _on_album_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("album file sta", status)
	print("album file paths ", paths)
	print("album file filter idx", _filter_idx)

	if not status or paths.is_empty():
		return

	album_cover_path = paths[0]
	Settings.game.last_editor_path = album_cover_path.get_base_dir()

	var image := Image.new()
	var err := image.load(album_cover_path)

	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		System.get_node("Control/edit_meta_cont/album_cover_edit").icon = tex
		System.get_node("Control/create_map_panel/album_cover_edit").icon = tex
		var text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + paths[0].get_file() + "\n" + General.format_file_size(FileAccess.get_size(paths[0]))
		System.get_node("Control/edit_meta_cont/cover_img_details").text = text
		System.get_node("Control/create_map_panel/cover_img_details").text = text
	else:
		print("Failed to load image: ", album_cover_path)

func _on_remove_album_pressed():
	album_cover_path = ""

	System.get_node("Control/edit_meta_cont/album_cover_edit").icon = null
	System.get_node("Control/create_map_panel/album_cover_edit").icon = null
	System.get_node("Control/edit_meta_cont/cover_img_details").text = ""
	System.get_node("Control/create_map_panel/cover_img_details").text = ""

func _on_rotate_cover_pressed() -> void:
	if System.selected_cover == null:
		print("No cover loaded yet.")
		return

	# Get the underlying image data
	var image := Image.new()
	image.copy_from(System.selected_cover)

	if image == null:
		print("Failed to get image from texture.")
		return

	# Rotate and recreate texture
	image.rotate_90(CLOCKWISE)

	System.selected_cover = image

	System.get_node("Control/edit_meta_cont/album_cover_edit").icon = ImageTexture.create_from_image(image)
	System.get_node("Control/create_map_panel/album_cover_edit").icon = ImageTexture.create_from_image(image)

func _on_bg_img_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		Settings.game.last_editor_path,             # Initial path (empty means default)
		"",
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_bg_img_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("create_bg_img", err, error_string(err))

func _on_bg_img_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("bg img sta ", status)
	print("bg img paths ", paths)
	print("bg img filter idx ", _filter_idx)

	if not status or paths.is_empty():
		return

	background_img_path = paths[0]
	Settings.game.last_editor_path = background_img_path.get_base_dir()

	var image := Image.new()
	var err := image.load(background_img_path)

	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		System.get_node("Control/edit_meta_cont/bg_img_edit").icon = tex
		System.get_node("Control/create_map_panel/bg_img_edit").icon = tex
		var text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + paths[0].get_file() + "\n" + General.format_file_size(FileAccess.get_size(paths[0]))
		System.get_node("Control/edit_meta_cont/bg_img_details").text = text
		System.get_node("Control/create_map_panel/bg_img_details").text = text

		System.get_node("Control/edit_meta_cont/bg_img_details").set_meta("background_name", paths[0].get_file())

		removed_bg = false
	else:
		print("Failed to load background image: ", background_img_path, " ", err, " ", error_string(err))

func _on_clear_bg_pressed() -> void:
	System.get_node("Control/edit_meta_cont/clear_bg").release_focus()
	System.get_node("Control/create_map_panel/clear_bg").release_focus()
	removed_bg = true
	background_img_path = ""
	System.get_node("Control/edit_meta_cont/bg_img_details").text = "No Background"
	System.get_node("Control/edit_meta_cont/bg_img_edit").icon = null
	System.get_node("Control/create_map_panel/bg_img_edit").icon = null

func nat_file_dialog_fail(which: String, err: Error, err_string: String):
	const BASE_CONTACT = "\nPlease contact playbeatzx@gmail.com\nthis error message and screen."
	print("Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT)
	match which:
		"share":
			System.get_node("Control/save_to_list/saving_to_lbl").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"create_cover":
			System.get_node("Control/create_map_panel/album_cover_edit").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"create_song_file":
			System.get_node("Control/create_map_panel/song_file_label").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"diff_texture":
			System.get_node("Control/create_map_panel/diff_texture_edit").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
			System.get_node("Control/edit_meta_cont/diff_texture_edit").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"edit_cover":
			System.get_node("Control/edit_meta_cont/album_cover_edit").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"edit_song_file":
			System.get_node("Control/edit_meta_cont/song_file_label").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT
		"create_bg_img":
			System.get_node("Control/edit_meta_cont/bg_img_details").text = "Failed to show native file dialog.\n" + str(err) + " - " + err_string + BASE_CONTACT

func _on_chart_name_edit_text_changed() -> void:
	print("na")
	if "chart_name" not in mandatory:
		mandatory.append("chart_name")
	_check_mandatory()

func _on_bpm_edit_text_changed(_new_text: String) -> void:
	if "bpm" not in mandatory:
		mandatory.append("bpm")
	_check_mandatory()

func _check_mandatory() -> void:
	var required = ["song_file", "chart_name", "bpm"]
	if required.all(func(x): return x in mandatory):
		System.get_node("Control/create_map_panel/mandatory_notice").hide()
		System.get_node("Control/create_map_panel/complete_setup_btn").disabled = false
		System.get_node("Control/create_map_panel/complete_setup_btn").mouse_default_cursor_shape = Input.CURSOR_POINTING_HAND
	else:
		print("no ", mandatory)

func _on_diff_texture_edit_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
		"Select an image file.",          # Title
		"",
		"",                                            # Initial path (empty means default)
		true,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,    # Mode: open multiple files
		General.IMG_FORMATS,   # File filters
		Callable(self, "_on_diff_texture_file_selected")
	)
	if err != OK:
		nat_file_dialog_fail("diff_texture", err, error_string(err))

func _on_diff_texture_file_selected(status, paths: PackedStringArray, _filter_idx: int):
	print("sta", status)
	print("paths ", paths)
	print("filter idx", _filter_idx)

	if not status or paths.is_empty():
		return

	diff_texture_path = paths[0]

	var image := Image.new()
	var err := image.load(diff_texture_path)
	if err == OK:
		var tex := ImageTexture.create_from_image(image)
		System.get_node("Control/edit_meta_cont/diff_texture_edit").icon = tex
		System.get_node("Control/create_map_panel/diff_texture_edit").icon = tex
		removed_diff_texture = false
	else:
		print("Failed to load image: ", diff_texture_path)

func _on_clear_diff_texture_pressed() -> void:
	System.get_node("Control/edit_meta_cont/clear_diff").release_focus()
	System.get_node("Control/create_map_panel/clear_diff").release_focus()
	removed_diff_texture = true
	diff_texture_path = ""
	System.get_node("Control/edit_meta_cont/diff_texture_edit").icon = null
	System.get_node("Control/create_map_panel/diff_texture_edit").icon = null

func _on_bg_vid_edit_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Select a video file"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = General.VIDEO_FORMATS
	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.connect("file_selected", Callable(self, "_on_bg_vid_file_selected"))
	System.add_child(dialog)
	dialog.popup_centered()

func _on_bg_vid_file_selected(path: String) -> void:
	background_vid_path = ProjectSettings.globalize_path(path)
	Settings.game.last_editor_path = background_vid_path.get_base_dir()

	print("Selected video: ", background_vid_path)

	if Settings.misc.editor_bg_videos:
		var video_node: VideoPlayback = System.get_node("Control/VideoPlayback")
		video_node.enable_audio = false
		video_node.enable_auto_play = false

		video_node.close()

		print("loading vid")
		video_node.set_video_path(background_vid_path)
		System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").set_video_path(background_vid_path)
		System.get_node("Control/create_map_panel/bg_vid_edit/VideoPlayback").set_video_path(background_vid_path)
		print("After load")

		video_node.show()

		System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").show()
		System.get_node("Control/create_map_panel/bg_vid_edit/VideoPlayback").show()

		# Wait until the GoZen video finishes loading
		video_node.video_loaded.connect(func():
			print("Video loaded, generating preview...")

			var total_frames = video_node.get_video_frame_count()
			var fps = video_node.get_video_framerate()
			var res = video_node.video.get_actual_resolution()

			# Calculate duration in seconds
			var duration_sec: float = 0.0
			if fps > 0:
				duration_sec = total_frames / fps

			# Format duration as mm:ss
			@warning_ignore("integer_division")
			var minutes = int(duration_sec) / 60
			var seconds = int(duration_sec) % 60
			var duration_str = "%02d:%02d" % [minutes, seconds]

			# Seek middle frame for preview
			@warning_ignore("integer_division")
			var mid_frame = int(total_frames / 2)
			video_node.seek_frame(mid_frame)

			# File size
			var file_size := FileAccess.get_size(path)
			var file_size_str := General.format_file_size(file_size)

			# Combine all details
			var details_text = (
				str(res.x) + "x" + str(res.y) + "\n" +
				str(round(fps)) + " FPS\n" +
				"Length: " + duration_str + "\n" +
				file_size_str + "\n" +
				path.get_file()
			)

			System.get_node("Control/edit_meta_cont/bg_vid_details").text = details_text
			System.get_node("Control/create_map_panel/bg_vid_details").text = details_text
		)
	else:
		var disabled_text: String = "Your video has been saved but\nyou have disabled BG Videos\nin the editor.\n(%s)" % background_vid_path.get_file() if background_vid_path != "" else ""
		System.get_node("Control/edit_meta_cont/bg_vid_details").text = disabled_text
		System.get_node("Control/create_map_panel/bg_vid_details").text = disabled_text

func _on_clear_bg_vid_pressed() -> void:
	System.get_node("Control/edit_meta_cont/clear_bg_vid").release_focus()
	System.get_node("Control/create_map_panel/clear_bg_vid").release_focus()

	removed_bg_vid = true
	background_vid_path = ""
	System.get_node("Control/VideoPlayback").close()

	System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").close()
	System.get_node("Control/create_map_panel/bg_vid_edit/VideoPlayback").close()

	System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").hide()
	System.get_node("Control/create_map_panel/bg_vid_edit/VideoPlayback").hide()

	System.get_node("Control/VideoPlayback").hide()

	System.get_node("Control/edit_meta_cont/bg_vid_details").text = "No Background"
	System.get_node("Control/edit_meta_cont/bg_vid_edit").icon = null
	System.get_node("Control/create_map_panel/bg_vid_details").text = "No Background"
	System.get_node("Control/create_map_panel/bg_vid_edit").icon = null

func _on_settings_editor_bg_vids_toggled(toggled_on: bool) -> void:
	if toggled_on:
		System.get_node("Control/VideoPlayback").process_mode = Node.PROCESS_MODE_ALWAYS
		System.get_node("Control/VideoPlayback").show()

		System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").process_mode = Node.PROCESS_MODE_ALWAYS
		System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").show()

		if background_vid_path:
			print("Setting bg vid as ", background_vid_path)
			_on_bg_vid_file_selected(background_vid_path)
	else:
		print("Closing bg vid ", background_vid_path)
		System.get_node("Control/VideoPlayback").close()
		System.get_node("Control/VideoPlayback").process_mode = Node.PROCESS_MODE_DISABLED
		System.get_node("Control/VideoPlayback").hide()

		System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").close()
		System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").process_mode = Node.PROCESS_MODE_DISABLED
		System.get_node("Control/edit_meta_cont/bg_vid_edit/VideoPlayback").hide()

		var disabled_text: String = "Your video has been saved but\nyou have disabled BG Videos\nin the editor.\n(%s)" % background_vid_path.get_file() if background_vid_path != "" else ""
		System.get_node("Control/edit_meta_cont/bg_vid_details").text = disabled_text
		System.get_node("Control/create_map_panel/bg_vid_details").text = disabled_text

func _on_settings_editor_cover_loops_toggled(toggled_on: bool) -> void:
	if toggled_on and cover_loop_vid_path:
		System.get_node("Control/song_details/sha/cover_loop").process_mode = Node.PROCESS_MODE_ALWAYS
		System.get_node("Control/song_details/sha/cover_loop").show()

		System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").process_mode = Node.PROCESS_MODE_ALWAYS
		System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").show()

		System.get_node("Control/song_details/sha/cover_spin").hide()

		print("Setting cover loop as ", cover_loop_vid_path)
		_on_cover_loop_vid_file_selected(cover_loop_vid_path)
	else:
		print("Closing bg vid ", cover_loop_vid_path)
		System.get_node("Control/song_details/sha/cover_loop").close()
		System.get_node("Control/song_details/sha/cover_loop").process_mode = Node.PROCESS_MODE_DISABLED
		System.get_node("Control/song_details/sha/cover_loop").hide()

		System.get_node("Control/song_details/sha/cover_spin").show()

		System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").close()
		System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").process_mode = Node.PROCESS_MODE_DISABLED
		System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").hide()


		var disabled_text: String = "Your video has been saved but\nyou have disabled Cover Loop Videos\nin the editor.\n(%s)" % cover_loop_vid_path.get_file() if cover_loop_vid_path != "" else ""
		System.get_node("Control/edit_meta_cont/cover_loop_details").text = disabled_text
		System.get_node("Control/create_map_panel/bg_vid_details").text = disabled_text

func _on_cover_loop_edit_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Select a video file"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = General.VIDEO_FORMATS
	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.connect("file_selected", Callable(self, "_on_cover_loop_vid_file_selected"))
	System.add_child(dialog)
	dialog.popup_centered()

func _on_cover_loop_vid_file_selected(path: String) -> void:
	cover_loop_vid_path = ProjectSettings.globalize_path(path)
	Settings.game.last_editor_path = cover_loop_vid_path.get_base_dir()

	print("Selected cover loop video: ", cover_loop_vid_path)

	if Settings.misc.editor_cover_loops:
		var video_node: VideoPlayback = System.get_node("Control/song_details/sha/cover_loop")
		video_node.enable_audio = false

		video_node.close()

		print("loading vid")
		video_node.set_video_path(cover_loop_vid_path)
		System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").set_video_path(cover_loop_vid_path)
		System.get_node("Control/create_map_panel/cover_loop_edit/VideoPlayback").set_video_path(cover_loop_vid_path)
		print("After load")

		video_node.show()
		System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").show()
		System.get_node("Control/create_map_panel/cover_loop_edit/VideoPlayback").show()

		System.get_node("Control/song_details/sha/cover_spin").hide()

		## Wait until the GoZen video finishes loading
		video_node.video_loaded.connect(func():
			print("Video loaded, generating preview...")
#
			var total_frames: int = video_node.get_video_frame_count()
			var fps: float  = video_node.get_video_framerate()
			var res = video_node.video.get_actual_resolution()
#
			# Calculate duration in seconds
			var duration_sec: float = 0.0
			if fps > 0:
				duration_sec = total_frames / fps
#
			# Format duration as mm:ss
			@warning_ignore("integer_division")
			var minutes = int(duration_sec) / 60
			var seconds = int(duration_sec) % 60
			var duration_str = "%02d:%02d" % [minutes, seconds]
#
			# Seek middle frame for preview
			@warning_ignore("integer_division")
			var mid_frame = int(total_frames / 2)
			video_node.seek_frame(mid_frame)

			# File size
			var file_size := FileAccess.get_size(path)
			var file_size_str := General.format_file_size(file_size)

			# Combine all details
			var details_text = (
				str(res.x) + "x" + str(res.y) + "\n" +
				str(round(fps)) + " FPS\n" +
				"Length: " + duration_str + "\n" +
				file_size_str + "\n" +
				path.get_file()
			)

			System.get_node("Control/edit_meta_cont/cover_loop_details").text = details_text
			System.get_node("Control/create_map_panel/cover_loop_details").text = details_text
		)
	else:
		var disabled_text: String = "Your video has been saved but\nyou have disabled Cover Loop Videos\nin the editor.\n(%s)" % cover_loop_vid_path.get_file() if cover_loop_vid_path != "" else ""
		System.get_node("Control/edit_meta_cont/cover_loop_details").text = disabled_text
		System.get_node("Control/create_map_panel/cover_loop_details").text = disabled_text

func _on_clear_loop_pressed() -> void:
	System.get_node("Control/edit_meta_cont/clear_loop").release_focus()
	System.get_node("Control/create_map_panel/clear_loop").release_focus()

	removed_cover_loop_vid = true
	cover_loop_vid_path = ""
	System.get_node("Control/song_details/sha/cover_loop").close()
	System.get_node("Control/song_details/sha/cover_loop").hide()

	System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").close()
	System.get_node("Control/create_map_panel/cover_loop_edit/VideoPlayback").close()

	System.get_node("Control/edit_meta_cont/cover_loop_edit/VideoPlayback").hide()
	System.get_node("Control/create_map_panel/cover_loop_edit/VideoPlayback").hide()

	System.get_node("Control/song_details/sha/cover_spin").show()

	System.get_node("Control/edit_meta_cont/cover_loop_details").text = "No Cover Loop Video"
	System.get_node("Control/edit_meta_cont/cover_loop_edit").icon = null
	System.get_node("Control/create_map_panel/cover_loop_details").text = "No Cover Loop Video"
	System.get_node("Control/create_map_panel/cover_loop_edit").icon = null

func _on_fetch_cover_pressed() -> void:
	print("Fetch cover pressed")

	var exe_path = "res://covit.exe"
	print("Executable path:", exe_path)

	var temp_dir = "user://Temp/Covers"
	print("Temp directory:", temp_dir)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(temp_dir))
	print("Temp directory ensured:", ProjectSettings.globalize_path(temp_dir))

	var args = [
		"--address", "https://covers.musichoarders.xyz/",
		"--input", System.song_path,
		"--query-sources", "applemusic",
		"--primary-output", ProjectSettings.globalize_path(temp_dir + "/cover"),
		"--secondary-output", ProjectSettings.globalize_path(temp_dir + "/cover.mp4"),
		"--primary-overwrite",
		"--secondary-overwrite",
		"--remote-agent", "BeatzX 1.6.0",
		"--remote-text", "Beatz X uses covers.musichoarders.xyz to fetch artwork."
	]

	print("Arguments:", args)

	var pid = OS.create_process(ProjectSettings.globalize_path(exe_path), args)
	print("Process started with PID:", pid)

	await _wait_for_process(pid)
	print("Process finished")

	await get_tree().create_timer(2.0).timeout
	_load_temp_cover(temp_dir)

func _wait_for_process(pid: int) -> void:
	print("Waiting for process:", pid)

	while OS.is_process_running(pid):
		await get_tree().process_frame

	print("Process is no longer running:", pid)

func _load_temp_cover(temp_dir: String) -> void:
	print("Loading temp cover from:", temp_dir)

	var jpg_path = temp_dir + "/cover.jpg"
	var png_path = temp_dir + "/cover.png"
	var mp4_path = temp_dir + "/cover.mp4"

	print("Checking JPG path:", jpg_path)
	print("Checking PNG path:", png_path)
	print("Checking MP4 path:", mp4_path)

	var image_path := ""

	if FileAccess.file_exists(jpg_path):
		print("JPG cover found")
		image_path = jpg_path
	elif FileAccess.file_exists(png_path):
		print("PNG cover found")
		image_path = png_path
	else:
		print("No JPG or PNG cover found")

	if image_path != "":
		var img = Image.new()
		var err = img.load(image_path)
		print("Image load result:", err)

		var tex = ImageTexture.create_from_image(img)
		print("Texture created from image")

		if err == OK:
			System.get_node("Control/edit_meta_cont/album_cover_edit").icon = tex
			System.get_node("Control/create_map_panel/album_cover_edit").icon = tex
			var text = str(tex.get_width()) + "x" + str(tex.get_height()) + "\n" + image_path.get_file() + "\n" + General.format_file_size(FileAccess.get_size(image_path))
			System.get_node("Control/edit_meta_cont/cover_img_details").text = text
			System.get_node("Control/create_map_panel/cover_img_details").text = text
		print("Assigned texture to album_cover_edit")

		var remove_err = DirAccess.remove_absolute(ProjectSettings.globalize_path(image_path))
		print("Removed image file, result:", remove_err)

	if FileAccess.file_exists(mp4_path):
		print("MP4 cover found")

		cover_loop_vid_path = ProjectSettings.globalize_path(mp4_path)

		print("Selected cover loop video: ", mp4_path)

		if Settings.misc.editor_cover_loops:
			var video_node: VideoPlayback = System.get_node("Control/song_details/sha/cover_loop")
			video_node.enable_audio = false

			video_node.close()

			print("loading vid")
			video_node.set_video_path(mp4_path)
			print("After load")

			video_node.show()

			## Wait until the GoZen video finishes loading
			video_node.video_loaded.connect(func():
				print("Video loaded, generating preview...")
	#
				var total_frames: int = video_node.get_video_frame_count()
				var fps: float  = video_node.get_video_framerate()
				var res = video_node.video.get_actual_resolution()
	#
				# Calculate duration in seconds
				var duration_sec: float = 0.0
				if fps > 0:
					duration_sec = total_frames / fps
	#
				# Format duration as mm:ss
				@warning_ignore("integer_division")
				var minutes = int(duration_sec) / 60
				var seconds = int(duration_sec) % 60
				var duration_str = "%02d:%02d" % [minutes, seconds]

				# Seek middle frame for preview
				@warning_ignore("integer_division")
				var mid_frame = int(total_frames / 2)
				video_node.seek_frame(mid_frame)
				await get_tree().process_frame

				# Capture current frame as preview image
				var tex = video_node.video_texture.get_texture()

				# Apply to icon
				System.get_node("Control/edit_meta_cont/cover_loop_edit").icon = tex
				System.get_node("Control/create_map_panel/cover_loop_edit").icon = tex

				# File size
				var file_size := FileAccess.get_size(mp4_path)
				var file_size_str := General.format_file_size(file_size)

				# Combine all details
				var details_text = (
					str(res.x) + "x" + str(res.y) + "\n" +
					str(round(fps)) + " FPS\n" +
					"Length: " + duration_str + "\n" +
					file_size_str + "\n" +
					mp4_path.get_file()
				)

				System.get_node("Control/edit_meta_cont/cover_loop_details").text = details_text
				System.get_node("Control/create_map_panel/cover_loop_details").text = details_text
			)
		else:
			var disabled_text: String = "Your Cover Loop Video has been saved but\nyou have disabled Cover Loop Videos\nin the editor.\n(%s)" % cover_loop_vid_path.get_file() if cover_loop_vid_path != "" else ""
			System.get_node("Control/edit_meta_cont/cover_loop_details").text = disabled_text
			System.get_node("Control/create_map_panel/cover_loop_details").text = disabled_text
	else:
		print("No MP4 cover found")

func _on_search_bg_vid_pressed() -> void:
	var query = _get_artist_search_text("edit_meta_cont").replace(" ", "+") + "+" + System.get_node("Control/edit_meta_cont/song_name_edit").text.replace(" ", "+")

	OS.shell_open("https://cobalt.meowing.de")
	await get_tree().process_frame
	OS.shell_open("https://youtube.com/results?search_query=" + query)

func clean_song_title(song: String) -> String:
	# remove anything in parentheses first
	song = song.replace(".", "")
	song = song.replace("(", "").replace(")", "")
	return song.strip_edges()

func _on_search_bpm_pressed() -> void:
	if songbpm_url_exists:
		OS.shell_open(songbpm_url)
	else:
		var query = (
			System.get_node("Control/edit_meta_cont/song_name_edit").text + " " +
			_get_artist_search_text("edit_meta_cont") + " bpm"
		).uri_encode()

		OS.shell_open("https://www.google.com/search?q=" + query)

func _on_search_bpm_mouse_entered() -> void:
	var artist: String = _get_artist_search_text("edit_meta_cont")
	var song: String = clean_song_title(System.get_node("Control/edit_meta_cont/song_name_edit").text)

	var artist_slug: String = artist.replace(" ", "-").to_lower()
	var song_slug: String = song.replace(" ", "-").to_lower()

	if song.strip_edges().is_empty():
		songbpm_url = "https://songbpm.com/@%s" % artist_slug
	else:
		songbpm_url = "https://songbpm.com/@%s/%s" % [artist_slug, song_slug]

	if song.strip_edges().is_empty():
		System.get_node("Control/edit_meta_cont/search_bpm").tooltip_text = 'This will open SongBPM.com and search for "%s" as "%s"' % [artist, songbpm_url]
	else:
		System.get_node("Control/edit_meta_cont/search_bpm").tooltip_text = 'This will open SongBPM.com and search for "%s %s" as "%s"' % [artist, song, songbpm_url]

	# debounce logic
	_pending_request_url = songbpm_url

	if _request_cooldown:
		return

	_request_cooldown = true
	System.get_node("HTTPRequest").cancel_request()
	System.get_node("HTTPRequest").request(songbpm_url, [], HTTPClient.METHOD_HEAD)

	await get_tree().create_timer(0.75).timeout
	_request_cooldown = false

	# if user hovered again during cooldown, re-request latest URL once
	if _pending_request_url != songbpm_url:
		_on_search_bpm_mouse_entered()

func _get_artist_search_text(panel_name: String) -> String:
	var artist_edit: LineEdit = System.get_node("Control/" + panel_name + "/artist_edit")
	var pending_artist := artist_edit.text.strip_edges()
	if pending_artist != "":
		return pending_artist
	if not System.selected_artists.is_empty():
		return ", ".join(System.selected_artists)
	return System.selected_artist

func _on_search_bpm_focus_entered() -> void:
	_on_search_bpm_mouse_entered()

func _on_http_request_request_completed(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	print(response_code)

	songbpm_url_exists = (
		result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 400
	)

	if songbpm_url_exists:
		print("%s Exists" % songbpm_url)
	else:
		print("%s Not found" % songbpm_url)
