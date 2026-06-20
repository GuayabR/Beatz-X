extends Panel

var http: HTTPRequest

func setup(achievement_data: Dictionary) -> void:
	var id: String = achievement_data.get("achievement_id", "")
	var icon_url: String = achievement_data.get("unlocked_icon_url", "")

	$title.text = "Achievement Unlocked!"
	$what.text = id

	if icon_url != "":
		_load_icon(icon_url)


func _load_icon(url: String) -> void:
	http = HTTPRequest.new()
	add_child(http)

	http.request_completed.connect(_on_icon_loaded)

	var err = http.request(url)
	if err != OK:
		print("Failed to request icon:", err)


@warning_ignore("unused_parameter")
func _on_icon_loaded(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("Icon download failed:", result, response_code)
		return

	var img = Image.new()

	# try detect format automatically
	var err = img.load_png_from_buffer(body)
	if err != OK:
		err = img.load_jpg_from_buffer(body)

	if err != OK:
		print("Failed to decode image")
		return

	var tex = ImageTexture.create_from_image(img)
	$achivement_tex.texture = tex

	http.queue_free()
