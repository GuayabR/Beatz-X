extends Node

var System: Variant

func _ready() -> void:
	System = get_parent()

var _encode_thread: Thread
var _encode_result := {}

func _get_save_path(overwrite: bool = true, only_file: bool = false) -> String:
	var username = System.selected_charter.strip_edges()
	if username == "":
		username = "Unknown"

	var user_chart_name = System.selected_chart_name.strip_edges()
	if user_chart_name == "":
		user_chart_name = "Untitled"

	# Base filename
	var base_filename := "%s-%s" % [General._sanitize(user_chart_name), username]
	var base_title := General._sanitize(System.selected_title, true)
	var folder_path: String
	var save_path: String
	if not System.selected_beatz_path:
		if OS.get_name() == "Windows":
			folder_path = "user://Custom/" + base_title + "/"
			if only_file: save_path = base_filename + ".beatz"
			else: save_path = folder_path + base_filename + ".beatz"
		elif OS.get_name() == "Android":
			folder_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/" + base_title + "/"
			if only_file: save_path = base_filename + ".beatz"
			else: save_path = folder_path + base_filename + ".beatz"
	else: save_path = System.selected_beatz_path

	# Song (1), Song (2), ...
	if not overwrite:
		var i := 0
		@warning_ignore("unused_variable")
		var copy_folder := base_title + "/"

		while true:
			var test_name: String
			if i == 0:
				test_name = base_title
			else:
				test_name = "%s (%d)" % [base_title, i]

			var test_path: String

			if OS.get_name() == "Windows":
				test_path = "user://Custom/" + test_name + "/"
			elif OS.get_name() == "Android":
				test_path = "storage/emulated/0/Android/data/com.guayabr.beatzx/Custom/" + test_name + "/"
			else:
				test_path = "user://Custom/" + test_name + "/"

			if not DirAccess.dir_exists_absolute(test_path):
				folder_path = test_path
				copy_folder = test_name + "/"
				break

			i += 1

		if only_file:
			save_path = base_filename + ".beatz"
		else:
			save_path = folder_path + base_filename + ".beatz"

	return save_path

func _on_save_pressed() -> void:
	var save_path := _get_save_path()
	System.get_node("Control/save_to_list/saving_to_lbl").text = "Saving to: " + ProjectSettings.globalize_path(save_path)

	System.save_editor_mode()

	System.transition(System.get_node("Control/save_to_list"), "scale", Vector2.ONE, .2, false)
	System.get_node("Control/chart_controls/save").release_focus()

func _on_save_to_list_pressed() -> void:
	System.get_node("Control/save_to_list/save_to_list").release_focus()
	_start_encode_thread(System.notes, System.song_path)

	System.get_node("Control/chart_controls/save").add_theme_color_override("font_color", Color.GRAY)

	System.get_node("Control/chart_controls/saved_to_popup").text = "Saving..."
	System.get_node("Control/chart_controls/saved_to_popup").size = Vector2(121.0, 40.0)
	System.get_node("popups").stop()
	System.get_node("popups").play("saved_popup")

func _on_save_copy_to_list_pressed() -> void:
	System.get_node("Control/save_to_list/save_copy_to_list").release_focus()
	_start_encode_thread(System.notes, System.song_path, false)

	System.get_node("Control/chart_controls/saved_to_popup").text = "Saving\ncopy..."
	System.get_node("Control/chart_controls/saved_to_popup").size = Vector2(121.0, 40.0)
	System.get_node("popups").stop()
	System.get_node("popups").play("saved_popup")

func _on_share_chart_pressed() -> void:
	System.get_node("Control/save_to_list/share_to_bx").release_focus()

	var err := DisplayServer.file_dialog_show(
		"SHARE your Beatzmap!",
		"", # starting dir
		System.selected_title + " by " + System.selected_charter, # starting file
		true,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		["*.bx"],
		Callable(self, "_on_share_chart_file_selected")
	)
	if err != OK:
		System.MetadataSystem.nat_file_dialog_fail("share", err, error_string(err))

func _on_share_chart_file_selected(status: bool, paths: PackedStringArray, filter_idx: int) -> void:
	print("sta", status)
	print("paths ", paths)
	print("filter idx", filter_idx)

	if paths.is_empty():
		return

	var save_path = paths[0]
	if not save_path.ends_with(".bx"):
		save_path += ".bx"

	_start_encode_thread(System.notes, System.song_path, true, true, save_path)

func _start_encode_thread(decoded_notes, current_song_path: String, overwrite: bool = true, share_mode: bool = false, share_save_path: String = "") -> void:
	if _encode_thread and _encode_thread.is_started():
		print("Encode already running")
		return

	_encode_thread = Thread.new()
	_encode_thread.start(Callable(self, "_encode_beatz_file_threaded").bind(
		decoded_notes,
		current_song_path,
		overwrite,
		share_mode,
		share_save_path
	))

func _encode_beatz_file_threaded(decoded_notes, current_song_path: String, overwrite: bool, share_mode: bool, share_save_path: String) -> void:
	_encode_beatz_file(decoded_notes, current_song_path, overwrite, share_mode, share_save_path)

	call_deferred("_on_encode_finished")

func _on_encode_finished():
	if _encode_thread:
		_encode_thread.wait_to_finish()
		_encode_thread = null

func _encode_beatz_file(decoded_notes, current_song_path: String, overwrite: bool = true, share_mode: bool = false, share_save_path: String = "") -> void:
	_thread_report("progress", 0)
	# Make sure we have notes
	if decoded_notes.is_empty():
		_thread_report("status_text", "No custom notes found. Record some!")
		return

	# Encode notes
	var encoded_notes := General.encode_notes(decoded_notes)

	# Determine note mode based on note types
	var user_note_mode := 4
	for note_str in encoded_notes.split(","):
		if note_str.find("DL") != -1 or note_str.find("DR") != -1:
			user_note_mode = 6
		elif note_str.find("UL") != -1 or note_str.find("UR") != -1:
			user_note_mode = 8

	# Prompt the user for metadata
	var username = System.selected_charter.strip_edges()
	if username == "":
		username = "Unknown"

	var user_chart_name = System.selected_chart_name.strip_edges()
	if user_chart_name == "":
		user_chart_name = "Untitled"

	var song_name := current_song_path.get_file()

	# Find lowest negative timestamp for start_wait
	@warning_ignore("unused_variable")
	var wait := 0.0
	var negatives: Array = []
	for n in decoded_notes:
		if n.has("timestamp") and n.timestamp < 0:
			negatives.append(n.timestamp)
	if not negatives.is_empty():
		wait = -float(negatives.min())  # Convert negative to positive

	# Format the content for the .beatz file
	var content := "Song: %s\\" % song_name
	content += "Charter: %s\\" % username
	content += "ChartName: %s\\" % user_chart_name
	content += "noteMode: %d\\" % user_note_mode
	content += "BPM: %f.3\\" % System.selected_bpm
	content += "noteSpeed: %d\\" % 5
	content += "noteSpawnY: %d\\" % 360
	content += "Difficulty: %s\\" % System.selected_difficulty
	content += "StartWait: %f.2\\" % System.start_wait
	content += "PrevStart: 0.0\\PrevEnd: 99999.0\\"
	content += "BeatOffset: %f.4\\" % System.local_beat_offset
	content += "Notes:%s" % encoded_notes

	var artists: Array[String] = System.selected_artists.duplicate()
	var artist_credit: String = System.selected_artist

	# Save info.json
	var info_dict := {
		"info": {
			"title": System.selected_title,
			"artist": artist_credit,
			"artists": artists,
			"album": System.selected_album,
			"year": System.selected_year,
			"chart": _get_save_path(overwrite, true),
			"audio": General._sanitize(song_name),
			"cover": General._sanitize(System.selected_album) + ".png",
			"background": System.MetadataSystem.background_img_path.get_file(),
			"video": System.MetadataSystem.background_vid_path.get_file(),
			"cover_loop": System.MetadataSystem.cover_loop_vid_path.get_file(),
			"difficulty_texture": General._sanitize(System.selected_difficulty) + ".png"
		}
	}

	_thread_report("progress", 10)

	# ----- SHARE MODE (no saving to disk) -----
	if share_mode:
		_thread_report("status_text", "Sharing...")

		var zip_path = share_save_path
		var zipper := ZIPPacker.new()
		if zipper.open(zip_path) != OK:
			push_error("Could not create zip: %s" % zip_path)
			_thread_report("error", "Could not create zip at %s" % zip_path)
			return

		# Add .beatz (in-memory string)
		var chart_file_name := _get_save_path(overwrite, true).get_file()
		zipper.start_file(chart_file_name)
		zipper.write_file(content.to_utf8_buffer())
		zipper.close_file()

		# Add info.json (in-memory string)
		zipper.start_file("info.json")
		zipper.write_file(JSON.stringify(info_dict, "\t").to_utf8_buffer())
		zipper.close_file()

		# Add audio (if possible)
		if System.selected_stream and "data" in System.selected_stream:
			zipper.start_file(info_dict["info"]["audio"])
			zipper.write_file(System.selected_stream.data)
			zipper.close_file()

		# Add cover image
		if System.selected_cover and System.selected_cover is Image:
			var img = System.selected_cover
			if img:
				var cover_name = info_dict["info"]["album"]
				var ext = cover_name.get_extension().to_lower()

				var buffer: PackedByteArray

				if ext == "":
					if System.MetadataSystem.album_cover_mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
						buffer = img.save_jpg_to_buffer(1.0)
					elif System.MetadataSystem.album_cover_mime == "image/png":
						buffer = img.save_png_to_buffer()
					else: # save as png if mime from attached cover is not recognized
						buffer = img.save_png_to_buffer()


				match ext:
					"png":
						buffer = img.save_png_to_buffer()
					"jpg", "jpeg":
						buffer = img.save_jpg_to_buffer(1.0)
					"webp":
						buffer = img.save_webp_to_buffer(false, 1.0)
					"exr":
						buffer = img.save_exr_to_buffer()
					"hdr":
						buffer = img.save_hdr_to_buffer()
					_:
						push_warning("Unsupported background format '%s', saving as PNG instead." % ext)
						cover_name = cover_name.get_basename() + ".png"
						buffer = img.save_png_to_buffer()

				zipper.start_file(cover_name)
				zipper.write_file(buffer)
				zipper.close_file()

		# Add background image with correct format
		if System.selected_background and System.selected_background is Image:
			var img = System.selected_background
			if img:
				var bg_name = info_dict["info"]["background"]
				var ext = bg_name.get_extension().to_lower()

				var buffer: PackedByteArray
				match ext:
					"png":
						buffer = img.save_png_to_buffer()
					"jpg", "jpeg":
						buffer = img.save_jpg_to_buffer(1.0)
					"webp":
						buffer = img.save_webp_to_buffer(false, 1.0)
					"exr":
						buffer = img.save_exr_to_buffer()
					"hdr":
						buffer = img.save_hdr_to_buffer()
					_:
						push_warning("Unsupported background format '%s', saving as PNG instead." % ext)
						bg_name = bg_name.get_basename() + ".png"
						buffer = img.save_png_to_buffer()

				zipper.start_file(bg_name)
				zipper.write_file(buffer)
				zipper.close_file()


		# Add difficulty texture
		if System.selected_diff_texture and System.selected_diff_texture is Texture2D:
			var img = System.selected_diff_texture.get_image()
			if img:
				zipper.start_file(info_dict["info"]["difficulty_texture"])
				zipper.write_file(img.save_png_to_buffer())
				zipper.close_file()

		# Add video background if one is set
		if System.MetadataSystem.background_vid_path != "" and FileAccess.file_exists(System.MetadataSystem.background_vid_path):
			var video_file_name: String = System.MetadataSystem.background_vid_path.get_file()
			info_dict["info"]["video"] = video_file_name

			var video_bytes := FileAccess.get_file_as_bytes(System.MetadataSystem.background_vid_path)
			if not video_bytes.is_empty():
				print("Adding background video to .bx:", video_file_name)
				zipper.start_file(video_file_name)
				zipper.write_file(video_bytes)
				zipper.close_file()
			else:
				push_warning("Video file could not be read or is empty: %s" % System.MetadataSystem.background_vid_path)
		else:
			print("No background video set or file missing skipping video")

		# Add cover loop video if one is set
		if System.MetadataSystem.cover_loop_vid_path != "" and FileAccess.file_exists(System.MetadataSystem.cover_loop_vid_path):
			var video_file_name: String = System.MetadataSystem.cover_loop_vid_path.get_file()
			info_dict["info"]["cover_loop"] = video_file_name

			var video_bytes := FileAccess.get_file_as_bytes(System.MetadataSystem.cover_loop_vid_path)
			if not video_bytes.is_empty():
				print("Adding cover loop video to .bx:", video_file_name)
				zipper.start_file(video_file_name)
				zipper.write_file(video_bytes)
				zipper.close_file()
			else:
				push_warning("Video file could not be read or is empty: %s" % System.MetadataSystem.cover_loop_vid_path)
		else:
			print("No cover loop video set or file missing skipping video")


		zipper.close()

		# Rename zip to .bx
		if not zip_path.ends_with(".bx"):
			var final_path = zip_path.get_basename() + ".bx"
			DirAccess.rename_absolute(zip_path, final_path)
			print("Shared chart packaged to %s" % final_path)
		else:
			print("Shared chart packaged to %s" % zip_path)

		_thread_report("status_text", "Shared succesfully!")
		_thread_report("done", true)
		return

	# Build base save path and folder
	var save_path := _get_save_path(overwrite)
	var folder_path := save_path.get_base_dir()

	var already_exists := FileAccess.file_exists(save_path)

	# Make sure folder exists
	DirAccess.make_dir_recursive_absolute(folder_path)

	# Save the .beatz file
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("Notes exported to %s successfully." % save_path)
		System.saved = true
		_thread_report("save_text", "Saved")
		_thread_report("song_path", "Path: " + ProjectSettings.globalize_path(folder_path).path_join(System.song_path.get_file()))

		_thread_report("progress", 20)

		_thread_report("tooltip", "Open " + ProjectSettings.globalize_path(System.selected_beatz_path.get_base_dir()) + " in your explorer.")
	else:
		push_error("Failed to save file: %s, due to %s" % [save_path, error_string(FileAccess.get_open_error())] )
		_thread_report("error", "Failed to save.")
		return

	# Save audio
	if System.selected_stream and System.selected_stream is AudioStream:
		var audio_save_path := folder_path + "/" + General._sanitize(song_name)
		var audio_file := FileAccess.open(audio_save_path, FileAccess.WRITE)
		if audio_file:
			# Save raw data (works if stream has `data` property, like AudioStreamMP3/WAV)
			if System.selected_stream.has_method("save_to_wav"):
				# safer if it’s a generated stream
				System.selected_stream.save_to_wav(audio_save_path)
				_thread_report("progress", 30)
			elif "data" in System.selected_stream:
				audio_file.store_buffer(System.selected_stream.data)
				_thread_report("progress", 30)
				audio_file.close()
			print("Saved audio to %s" % audio_save_path)

	# Save cover image
	if System.selected_cover and System.selected_cover is Image:
		var img = System.selected_cover
		var ext = System.MetadataSystem.album_cover_path.get_extension()

		if ext == "":
			if System.MetadataSystem.album_cover_mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
				ext = "jpg"
			elif System.MetadataSystem.album_cover_mime == "image/png":
				ext = "png"
			else: # save as png if mime from attached cover is not recognized
				ext = "png"

		if img:
			var cover_save_path: String = folder_path + "/" + General._sanitize(System.selected_album) + "." + ext
			General.save_image_with_correct_extension(img, cover_save_path)
			_thread_report("progress", 40)
			print("Saved cover image to %s" % cover_save_path)

	# Save background image
	if System.selected_background and System.selected_background is Image:
		var img = System.selected_background
		var bg_save_path: String = folder_path + "/" + System.MetadataSystem.background_img_path.get_file()
		if img and not System.MetadataSystem.removed_bg:
			General.save_image_with_correct_extension(img, bg_save_path)
			print("Saved background image to %s" % bg_save_path)
		elif System.MetadataSystem.removed_bg:
			if FileAccess.file_exists(bg_save_path):
				var err := DirAccess.remove_absolute(bg_save_path)
				if err == OK:
					print("Removed difficulty texture: %s" % bg_save_path)
				else:
					print("Failed to remove difficulty texture: %s (error %s, %s)" % [bg_save_path, err, error_string(err)])

		_thread_report("progress", 50)


	# Save difficulty texture
	if System.selected_diff_texture and System.selected_diff_texture is Texture2D:
		var img = System.selected_diff_texture.get_image()
		var ext = System.MetadataSystem.diff_texture_path.get_extension()
		var diff_tex_save_path: String = folder_path + "/" + General._sanitize(System.selected_difficulty) + "." + ext
		if img and not System.MetadataSystem.removed_diff_texture:
			General.save_image_with_correct_extension(img, diff_tex_save_path)
			print("Saved difficulty texture to %s" % diff_tex_save_path)
		elif System.MetadataSystem.removed_diff_texture:
			if FileAccess.file_exists(diff_tex_save_path):
				var err := DirAccess.remove_absolute(diff_tex_save_path)
				if err == OK:
					print("Removed difficulty texture: %s" % diff_tex_save_path)
				else:
					print("Failed to remove difficulty texture: %s (error %s, %s)" % [diff_tex_save_path, err, error_string(err)])

		_thread_report("progress", 60)


	# Save video background if one is set
	if System.MetadataSystem.background_vid_path != "" and FileAccess.file_exists(System.MetadataSystem.background_vid_path):
		print("Copying video to chart folder ", System.MetadataSystem.background_vid_path)
		var video_file_name: String = System.MetadataSystem.background_vid_path.get_file()
		var video_save_path := folder_path.path_join(video_file_name)

		# Copy video file into the chart folder using OS.execute wrapper
		General.copy_video(System.MetadataSystem.background_vid_path, video_save_path)

		# Store the filename in info.json
		info_dict["info"]["video"] = video_file_name
		print("Copied and saved background video to %s" % video_save_path)
	else:
		print("No background video set or file missing")

	_thread_report("progress", 70)

	# Save cover loop background if one is set
	if System.MetadataSystem.cover_loop_vid_path != "" and FileAccess.file_exists(System.MetadataSystem.cover_loop_vid_path):
		print("Copying cover loop video to chart folder ", System.MetadataSystem.cover_loop_vid_path)
		var video_file_name: String = System.MetadataSystem.cover_loop_vid_path.get_file()
		var video_save_path := folder_path.path_join(video_file_name)

		# Copy video file into the chart folder using OS.execute wrapper
		General.copy_video(System.MetadataSystem.cover_loop_vid_path, video_save_path)

		# Store the filename in info.json
		info_dict["info"]["cover_loop"] = video_file_name
		print("Copied and saved cover loop video to %s" % video_save_path)
	else:
		print("No cover loop video set or file missing")

	_thread_report("progress", 80)

	var info_save_path := folder_path + "/info.json"
	var info_file := FileAccess.open(info_save_path, FileAccess.WRITE)
	if info_file:
		info_file.store_string(JSON.stringify(info_dict, "\t"))
		info_file.close()
		print("Saved info.json to %s" % info_save_path)

		var song_id = "SONGID " + System.selected_title + " " + str(Time.get_unix_time_from_system(), "_", randi())
		var id_file := FileAccess.open(folder_path.path_join(".songid"), FileAccess.WRITE)
		id_file.store_string(song_id)
		id_file.close()

		General.save_or_replace_song_id(song_id)
		print("Made unique ID: ", song_id)

		var text = "%s | %s, by %s | %d\n\nChart: %s | \"%s\" by %s | Custom" % [
			System.selected_album,
			System.selected_title,
			artist_credit,
			System.selected_year,
			System.selected_difficulty.to_pascal_case(),
			System.selected_chart_name,
			System.selected_charter
		]

		var ext = System.MetadataSystem.album_cover_path.get_extension()
		if ext == "":
			if System.MetadataSystem.album_cover_mime in ["image/jpeg", "image/jpg", "image/pjpeg"]:
				ext = "jpg"
			elif System.MetadataSystem.album_cover_mime == "image/png":
				ext = "png"
			else: # save as png if mime from attached cover is not recognized
				ext = "png"

		var list_entry: Dictionary = {
			"text": text,
			"disabled": false,
			"metadata": {
				"beatz_path": ProjectSettings.globalize_path(save_path),
				"id": song_id,
				"song_name": System.selected_title if System.selected_title != null and System.selected_title != "" else "",
				"album": System.selected_album if System.selected_album != null and System.selected_album != "" else "",
				"artist": artist_credit,
				"artists": artists,
				"year": System.selected_year if System.selected_year != null else 1980,
				"diff_texture": System.selected_diff_texture,
				"diff_texture_path": System.MetadataSystem.diff_texture_path if System.MetadataSystem.diff_texture_path != null and System.MetadataSystem.diff_texture_path != "" else "",
				"bpm": System.selected_bpm if System.selected_bpm != null else 120.0,
				"charter": System.selected_charter if System.selected_charter != null and System.selected_charter != "" else "",
				"difficulty": System.selected_difficulty if System.selected_difficulty != null and System.selected_difficulty != "" else "",
				"speed": System.note_speed,
				"cover_path": ProjectSettings.globalize_path(folder_path + "/" + General._sanitize(System.selected_album) + "." + ext),
				"stream": ProjectSettings.globalize_path(folder_path + "/" + General._sanitize(song_name)),
				"date_modified": Time.get_unix_time_from_system(),
				"local_beat_offset": System.local_beat_offset if System.local_beat_offset != null else 0.0,
				"selected_background": System.selected_background,
				"background_vid": System.MetadataSystem.background_vid_path if System.MetadataSystem.background_vid_path != null and System.MetadataSystem.background_vid_path != "" else "",
				"cover_loop": System.MetadataSystem.cover_loop_vid_path if System.MetadataSystem.cover_loop_vid_path != null and System.MetadataSystem.cover_loop_vid_path != "" else ""
			}
		}

		System.selected_beatz_path = ProjectSettings.globalize_path(save_path)
		current_song_path = folder_path + "/" + General._sanitize(song_name)

		if System.MetadataSystem.album_cover_path: System.MetadataSystem.album_cover_path = folder_path + "/" + General._sanitize(System.selected_album) + "." + ext

		if System.MetadataSystem.diff_texture_path: System.MetadataSystem.diff_texture_path = folder_path + "/" + General._sanitize(System.selected_difficulty) + "." + System.MetadataSystem.diff_texture_path.get_extension()

		if System.MetadataSystem.background_img_path: System.MetadataSystem.background_img_path = folder_path + "/" + General._sanitize(System.MetadataSystem.background_img_path.get_file())
		if System.MetadataSystem.background_vid_path: System.MetadataSystem.background_vid_path = folder_path.path_join(System.MetadataSystem.background_vid_path.get_file())
		if System.MetadataSystem.cover_loop_vid_path:
			var saved_cover_loop_path := folder_path.path_join(System.MetadataSystem.cover_loop_vid_path.get_file())
			if FileAccess.file_exists(saved_cover_loop_path):
				System.MetadataSystem.cover_loop_vid_path = saved_cover_loop_path
				list_entry["metadata"]["cover_loop"] = saved_cover_loop_path

		if (
			not (overwrite and already_exists)
			and Settings.game.keep_list_in_ram
		):
			print("Adding to list as")
			print(JSON.stringify(list_entry, "\t", false))

			var inserted := false
			var new_title = System.selected_title.to_lower()

			var keys := Beatz.LIST.keys()
			keys.sort()

			for key in keys:
				var existing = Beatz.LIST[key]

				if not existing.has("metadata"):
					continue

				var existing_title := str(
					existing["metadata"].get("song_name", "")
				).to_lower()

				if new_title < existing_title:
					var rebuilt := {}
					var inserted_index := false

					for rebuild_key in keys:
						if rebuild_key == key and not inserted_index:
							rebuilt[rebuilt.size() + 1] = list_entry
							inserted_index = true

						rebuilt[rebuilt.size() + 1] = Beatz.LIST[rebuild_key]

					Beatz.LIST = rebuilt
					inserted = true
					break

			if not inserted:
				Beatz.LIST[Beatz.LIST.size() + 1] = list_entry

		General.delete_folder_recursive("user://Temp/Covers")

		_thread_report("done", true)
		_thread_report("status_text", "Saved succesfully!")

func _thread_report(key: String, value):
	_encode_result[key] = value
	call_deferred("_apply_encode_update", key, value)

func _apply_encode_update(key: String, value):
	var tb = null
	if OS.get_name() == "Windows" and Engine.has_singleton("TBProgress"):
		tb = Engine.get_singleton("TBProgress")

	match key:
		"progress":
			if tb: tb.set_progress(value, 90)
			System.get_node("Control/chart_controls/save").text = str(value) + "%"

			System.get_node("Control/chart_controls/exit").disabled = true
			System.get_node("Control/exit_warn/exit").disabled = true

			System.get_node("Control/save_to_list/save_to_list").disabled = true
			System.get_node("Control/save_to_list/save_copy_to_list").disabled = true
			System.get_node("Control/save_to_list/share_to_bx").disabled = true

		"status_text":
			System.get_node("Control/save_to_list/saving_to_lbl").text = value

		"save_text":
			System.get_node("Control/chart_controls/save").text = value

		"song_path":
			System.get_node("Control/song_details/song_path/Text").text = value
			System.get_node("Control/song_details/song_path").call("refresh")

		"tooltip":
			System.get_node("Control/edit_meta_cont/explorer_open_btn").tooltip_text = value

		"error":
			if tb: tb.set_error()
			System.get_node("Control/save_to_list/saving_to_lbl").text = value

			System.set_save_warn()

			System.get_node("Control/chart_controls/saved_to_popup").text = "Error!"
			System.get_node("Control/chart_controls/saved_to_popup").size = Vector2(121.0, 40.0)
			System.get_node("popups").stop()
			System.get_node("popups").play("saved_popup")

			System.get_node("Control/chart_controls/exit").disabled = false
			System.get_node("Control/exit_warn/exit").disabled = false

			System.get_node("Control/save_to_list/save_to_list").disabled = false
			System.get_node("Control/save_to_list/save_copy_to_list").disabled = false
			System.get_node("Control/save_to_list/share_to_bx").disabled = false

		"done":
			if tb: tb.clear()
			System.saved = true
			System.save.emit()
			System.get_node("Control/chart_controls/save").text = "Saved"

			if System.menu_open: System.get_node("Control/chart_controls/save").add_theme_color_override("font_color", Color.GREEN)
			else:  System.get_node("Control/chart_controls/save").add_theme_color_override("font_color", Color.WHITE)

			System.get_node("Control/chart_controls/saved_to_popup").text = "Saved!"
			System.get_node("Control/chart_controls/saved_to_popup").size = Vector2(121.0, 40.0)
			System.get_node("popups").stop()
			System.get_node("popups").play("saved_popup")

			System.get_node("Control/chart_controls/exit").disabled = false
			System.get_node("Control/exit_warn/exit").disabled = false

			System.get_node("Control/save_to_list/save_to_list").disabled = false
			System.get_node("Control/save_to_list/save_copy_to_list").disabled = false
			System.get_node("Control/save_to_list/share_to_bx").disabled = false

func _on_saving_back_pressed() -> void:
	System.get_node("Control/save_to_list/back").release_focus()
	System.restore_editor_mode()

	System.transition(System.get_node("Control/save_to_list"), "scale", Vector2.ZERO, .2, true)

func _on_save_to_list_mouse_entered() -> void:
	System.get_node("Control/save_to_list/saving_to_lbl").text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(true))

func _on_save_copy_to_list_mouse_entered() -> void:
	System.get_node("Control/save_to_list/saving_to_lbl").text = "Saving to: " + ProjectSettings.globalize_path(_get_save_path(false))

func _on_import_from_beatz_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.title = "Select a .beatz file"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = [".beatz", ".chart", ".osu", ".qua", "*"]
	dialog.force_native = true
	dialog.use_native_dialog = true
	dialog.connect("file_selected", Callable(self, "_on_dotbeatz_file_selected"))
	System.add_child(dialog)
	dialog.popup_centered()

func _on_dotbeatz_file_selected(path: String):
	var file: String = ProjectSettings.globalize_path(path)
	var as_text = FileAccess.open(file, FileAccess.READ).get_as_text()
	var imported = General.import_beatz_file(as_text)
	System.notes = imported.notes as Array
	System.selected_bpm = imported.bpm
	System.selected_difficulty = imported.difficulty
	System.local_beat_offset = imported.local_beat_offset
	System.selected_charter = imported.charter
	System.selected_chart_name = imported.chart_name

	System.get_node("Control/create_map_panel/diff_edit").text = imported.difficulty
	System.get_node("Control/create_map_panel/chart_name_edit").text = imported.chart_name
	System.get_node("Control/create_map_panel/charter_edit").text = imported.charter
	System.get_node("Control/create_map_panel/bpm_edit").text = str(imported.bpm)

	var t: String = "Imported %s\nTotal notes: %d | BPM %0.2f" % [file.get_file(), imported.note_count, System.selected_bpm]
	System.get_node("Control/create_map_panel/beatz_details").text = t
	System.get_node("Control/tools/beatz_details").text = t

func _on_clear_imported_notes_pressed(reimported: bool = false) -> void:
	System.notes = []
	if not reimported: System.selected_bpm = 120.0
	if not reimported: System.selected_difficulty = "Hard"
	if not reimported: System.local_beat_offset = 0.0

	System.get_node("Control/create_map_panel/beatz_details").text = "No Imported Notes"
