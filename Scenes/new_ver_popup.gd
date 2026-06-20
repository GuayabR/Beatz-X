extends Panel

@onready var request: HTTPRequest = $HTTPRequest

signal new_version
signal close

var voluntary: bool = false

func _ready() -> void:
	check_for_update()

func check_for_update(user_wanted_to: bool = false):
	voluntary = user_wanted_to
	request.request(General.GITHUB_REL_URL)

@warning_ignore("unused_parameter")
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if not Settings.game.show_vpopup and not voluntary: 
		print("User has already seen the popup and chose to not show again")
		return
	
	#print(result)
	#print(response_code)
	#print(headers)
	
	if response_code != 200:
		$changelog.text = "Failed to fetch changelog (Error %d)" % response_code
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		$changelog.text = "Invalid response."
		return
	
	var new_ver = json.tag_name.trim_prefix("v")
	var _new_ver_int = float(new_ver)
	
	if new_ver == General.VERSION and not voluntary:
		print("User already has this version")
		return
	elif new_ver == Settings.game.version and new_ver != General.VERSION:
		if new_ver > General.VERSION: 
			print("User does not have this version but has already seen the popup")
		elif new_ver < General.VERSION and not voluntary: 
			print("Users version is somehow higher than the release version but has already seen the popup")
			return
	elif new_ver != Settings.game.version and new_ver != General.VERSION:
		if new_ver > General.VERSION: print("User hasn't seen the popup nor do they have this version")
		elif new_ver < General.VERSION: print("Users version is somehow higher than the release version but has not seen the popup")
	
	$title.text = "[b]" + json.name + "[/b]"
	
	var datetime = Time.get_datetime_dict_from_datetime_string("2025-09-06T15:33:48Z", false)
	var formatted = "%02d/%02d/%d" % [datetime.month, datetime.day, datetime.year]
	
	$date.text = new_ver + " " + formatted
	
	Settings.game.version = new_ver
	Settings._save()
	
	# Extract changelog text
	var changelog: String = json.get("body", "No changelog found.")
	#var bbcode = General.md_to_bb(changelog)
	$changelog._set_markdown_text(changelog)
	
	$HBoxContainer/download.set_meta("down_url", json.html_url as String)
	$HBoxContainer/download.tooltip_text = "Open " + json.html_url + " in your browser"
	
	new_version.emit()

func _on_ok_pressed() -> void:
	$HBoxContainer/ok.release_focus()
	close.emit()

func _on_changelog_meta_clicked(meta: Variant) -> void:
	$changelog.release_focus()
	OS.shell_open(meta)

func _on_download_pressed() -> void:
	$HBoxContainer/download.release_focus()
	var url = $HBoxContainer/download.get_meta("down_url", "https://github.com/GuayabR/Beatz-X/releases/latest")
	OS.shell_open(url)

func _on_do_not_show_pressed() -> void:
	$HBoxContainer/do_not_show.release_focus()
	Settings.game.show_vpopup = false
	Settings._save()
	_on_ok_pressed()
