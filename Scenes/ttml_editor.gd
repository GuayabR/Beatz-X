class_name TTMLEditor
extends Control


# ============================================================
# WordTiming — holds timing data for each word
# ============================================================
class WordTiming:
	var text: String = ""
	var start_time: float = -1.0
	var end_time: float = -1.0
	var line_index: int = 0


	func has_start() -> bool:
		return start_time >= 0.0


	func has_end() -> bool:
		return end_time >= 0.0


	func is_complete() -> bool:
		return has_start() and has_end()


	func start_str() -> String:
		return _fmt(start_time) if has_start() else "--:--.---"


	func end_str() -> String:
		return _fmt(end_time) if has_end() else "--:--.---"


	static func _fmt(t: float) -> String:
		var minutes: int = int(t) / 60
		var seconds: int = int(t) % 60
		var millis: int = int((t - int(t)) * 1000.0)
		return "%02d:%02d.%03d" % [minutes, seconds, millis]


# ============================================================
# Nodes
# ============================================================
@onready var load_audio_btn: Button = $VBoxContainer/Toolbar/LoadAudio
@onready var load_lyrics_btn: Button = $VBoxContainer/Toolbar/LoadLyrics
@onready var save_ttml_btn: Button = $VBoxContainer/Toolbar/SaveTTML
@onready var current_time_label: Label = $VBoxContainer/Toolbar/CurrentTime
@onready var audio_progress: HSlider = $VBoxContainer/AudioProgress
@onready var current_word_label: Label = $VBoxContainer/CurrentWordLabel
@onready var word_display: RichTextLabel = $VBoxContainer/WordDisplay
@onready var start_label: Label = $VBoxContainer/TimeLabels/StartLabel
@onready var end_label: Label = $VBoxContainer/TimeLabels/EndLabel
@onready var word_list: ItemList = $VBoxContainer/WordList
@onready var audio_player: AudioStreamPlayer = $VBoxContainer/AudioStreamPlayer
@onready var file_dialog_audio: FileDialog = $FileDialogAudio
@onready var file_dialog_lyrics: FileDialog = $FileDialogLyrics
@onready var file_dialog_save: FileDialog = $FileDialogSave
@onready var song_name_edit: LineEdit = $VBoxContainer/Metadata/SongNameContainer/SongName
@onready var artist_edit: LineEdit = $VBoxContainer/Metadata/ArtistContainer/Artist
@onready var album_edit: LineEdit = $VBoxContainer/Metadata/AlbumContainer/Album
@onready var songwriters_edit: LineEdit = $VBoxContainer/Metadata/WritersContainer/Songwriters


# ============================================================
# State
# ============================================================
var words: Array[WordTiming] = []
var current_word_index: int = -1
var is_playing: bool = false
var is_seeking: bool = false
var history: Array[Dictionary] = []  # undo stack


# ============================================================
# Lifecycle
# ============================================================
func _ready() -> void:
	# Button signals
	load_audio_btn.pressed.connect(_on_load_audio_pressed)
	load_lyrics_btn.pressed.connect(_on_load_lyrics_pressed)
	save_ttml_btn.pressed.connect(_on_save_ttml_pressed)

	# File dialog signals
	file_dialog_audio.file_selected.connect(_on_audio_file_selected)
	file_dialog_lyrics.file_selected.connect(_on_lyrics_file_selected)
	file_dialog_save.file_selected.connect(_on_save_file_selected)

	# Slider
	audio_progress.value_changed.connect(_on_progress_changed)
	audio_progress.gui_input.connect(_on_progress_gui)

	# Word list selection
	word_list.item_selected.connect(_on_word_selected)

	# Disable button focus so they don't steal keybinds
	for btn: Button in [$VBoxContainer/Toolbar/LoadAudio, $VBoxContainer/Toolbar/LoadLyrics, $VBoxContainer/Toolbar/SaveTTML]:
		btn.focus_mode = Control.FOCUS_NONE

	audio_progress.focus_mode = Control.FOCUS_NONE
	word_list.focus_mode = Control.FOCUS_NONE

	_update_display()
	_update_word_list()


func _process(_delta: float) -> void:
	if not audio_player.playing:
		return

	var pos: float = audio_player.get_playback_position()
	# Update time label
	current_time_label.text = WordTiming._fmt(pos)

	# Update slider without triggering signal
	if not is_seeking:
		audio_progress.set_block_signals(true)
		audio_progress.value = pos
		audio_progress.set_block_signals(false)

	# Update word highlight
	_update_word_highlight_for_time(pos)

	# Check if song ended
	if pos >= audio_player.stream.get_length() - 0.01:
		_stop_playback()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				_toggle_play_pause()
				get_viewport().set_input_as_handled()
			KEY_S:
				_mark_start()
				get_viewport().set_input_as_handled()
			KEY_D:
				_mark_end()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				_seek_offset(-2.0)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_seek_offset(2.0)
				get_viewport().set_input_as_handled()
			KEY_Z:
				if event.is_command_or_control_pressed():
					_undo()
					get_viewport().set_input_as_handled()


# ============================================================
# Audio loading
# ============================================================
func _on_load_audio_pressed() -> void:
	file_dialog_audio.popup_centered()


func _on_audio_file_selected(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Failed to open audio file: ", path)
		return

	var ext: String = path.get_extension().to_lower()
	var stream: AudioStream = null

	match ext:
		"mp3":
			stream = AudioStreamMP3.new()
			stream.data = file.get_buffer(file.get_length())
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(path)
		"wav":
			stream = AudioStreamWAV.load_from_file(path)
		_:
			# Try generic import
			stream = AudioStreamOggVorbis.load_from_file(path)
			if stream == null:
				printerr("Unsupported audio format: ", ext)
				return

	file.close()

	if stream == null:
		printerr("Failed to load audio stream from: ", path)
		return

	audio_player.stream = stream
	audio_progress.max_value = stream.get_length()
	audio_progress.value = 0.0
	current_time_label.text = "00:00.000"
	print("Loaded audio: ", path.get_file(), " (", "%.1f" % stream.get_length(), "s)")


# ============================================================
# Lyrics loading
# ============================================================
func _on_load_lyrics_pressed() -> void:
	file_dialog_lyrics.popup_centered()


func _on_lyrics_file_selected(path: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("Failed to open lyrics file: ", path)
		return

	var text: String = file.get_as_text()
	file.close()

	words.clear()
	history.clear()

	var lines: PackedStringArray = text.split("\n")
	var line_idx: int = 0

	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.is_empty():
			line_idx += 1
			continue

		# Split line into individual words
		var tokens: PackedStringArray = stripped.split(" ", false)
		for token: String in tokens:
			var wt: WordTiming = WordTiming.new()
			wt.text = token
			wt.line_index = line_idx
			words.append(wt)

		line_idx += 1

	current_word_index = -1
	if words.size() > 0:
		current_word_index = 0

	_update_word_list()
	_update_display()
	print("Loaded ", words.size(), " words from ", path.get_file())


# ============================================================
# Playback
# ============================================================
func _toggle_play_pause() -> void:
	if audio_player.stream == null:
		return

	if audio_player.playing:
		audio_player.stop()
		is_playing = false
	else:
		audio_player.play(_get_playback_position())
		is_playing = true


func _stop_playback() -> void:
	audio_player.stop()
	is_playing = false
	audio_progress.value = 0.0
	current_time_label.text = "00:00.000"


func _get_playback_position() -> float:
	if audio_player.playing:
		return audio_player.get_playback_position()
	return audio_progress.value


func _seek_offset(delta: float) -> void:
	var new_pos: float = clampf(audio_progress.value + delta, 0.0, audio_progress.max_value)
	audio_progress.value = new_pos
	if audio_player.playing:
		audio_player.stop()
		audio_player.play(new_pos)


# ============================================================
# Slider
# ============================================================
func _on_progress_gui(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			is_seeking = true
		else:
			is_seeking = false
			_seek_to(audio_progress.value)


func _on_progress_changed(value: float) -> void:
	if is_seeking:
		current_time_label.text = WordTiming._fmt(value)
		_update_word_highlight_for_time(value)


func _seek_to(pos: float) -> void:
	if audio_player.playing:
		audio_player.stop()
		audio_player.play(pos)
	current_time_label.text = WordTiming._fmt(pos)


# ============================================================
# Marking timestamps
# ============================================================
func _mark_start() -> void:
	if words.is_empty() or current_word_index < 0:
		return

	var pos: float = _get_playback_position()
	var wt: WordTiming = words[current_word_index]

	# Save for undo
	_save_history("start", current_word_index, wt.start_time)

	wt.start_time = pos
	if wt.end_time >= 0.0 and wt.end_time < pos:
		wt.end_time = -1.0  # clear end if it's before new start

	_update_word_list()
	_update_display()
	print("Start: [", current_word_index, "] \"", wt.text, "\" @ ", WordTiming._fmt(pos))


func _mark_end() -> void:
	if words.is_empty() or current_word_index < 0:
		return

	var pos: float = _get_playback_position()
	var wt: WordTiming = words[current_word_index]

	# Require start to exist first
	if not wt.has_start():
		print("Set start time first (press S)")
		return

	if pos <= wt.start_time:
		print("End time must be after start time")
		return

	_save_history("end", current_word_index, wt.end_time)

	wt.end_time = pos
	print("End:   [", current_word_index, "] \"", wt.text, "\" @ ", WordTiming._fmt(pos))

	_update_word_list()
	_update_display()

	# Auto-advance to next word
	_advance_to_next_word()


func _advance_to_next_word() -> void:
	if current_word_index < words.size() - 1:
		current_word_index += 1
		word_list.select(current_word_index)
		word_list.ensure_current_is_visible()
		_update_display()
	else:
		print("All words timed!")


# ============================================================
# Undo
# ============================================================
func _save_history(field: String, index: int, old_value: float) -> void:
	history.append({
		"field": field,
		"index": index,
		"old_value": old_value,
	})


func _undo() -> void:
	if history.is_empty():
		return

	var action: Dictionary = history.pop_back()
	var idx: int = action["index"]
	var field: String = action["field"]
	var old_val: float = action["old_value"]

	if idx < 0 or idx >= words.size():
		return

	var wt: WordTiming = words[idx]

	if field == "start":
		wt.start_time = old_val
		# Also go back to this word
		current_word_index = idx
	elif field == "end":
		wt.end_time = old_val
		current_word_index = idx

	print("Undo: ", field, " of word [", idx, "] \"", wt.text, "\"")
	_update_word_list()
	_update_display()


# ============================================================
# Word list display
# ============================================================
func _update_word_list() -> void:
	word_list.clear()

	for i: int in words.size():
		var wt: WordTiming = words[i]
		var prefix: String = "[✓]" if wt.is_complete() else ("[S ]" if wt.has_start() else "[  ]")
		word_list.add_item("%s %s" % [prefix, wt.text])

	if current_word_index >= 0 and current_word_index < word_list.item_count:
		word_list.select(current_word_index)


func _on_word_selected(index: int) -> void:
	current_word_index = index
	_update_display()


func _update_display() -> void:
	if words.is_empty() or current_word_index < 0 or current_word_index >= words.size():
		current_word_label.text = "---"
		word_display.text = "[center][color=gray]No words loaded[/color][/center]"
		start_label.text = "Start: --:--.---"
		end_label.text = "End: --:--.---"
		return

	var wt: WordTiming = words[current_word_index]
	current_word_label.text = wt.text
	start_label.text = "Start: " + wt.start_str()
	end_label.text = "End: " + wt.end_str()

	# Build word display: previous | CURRENT | next
	var prev_text: String = words[current_word_index - 1].text if current_word_index > 0 else ""
	var next_text: String = words[current_word_index + 1].text if current_word_index < words.size() - 1 else ""

	word_display.text = "[center][color=gray]%s[/color]   [b][color=yellow]%s[/color][/b]   [color=gray]%s[/color][/center]" % [prev_text, wt.text, next_text]


func _update_word_highlight_for_time(pos: float) -> void:
	# Find the word whose timing range contains this position
	for i: int in words.size():
		var wt: WordTiming = words[i]
		if wt.has_start() and wt.has_end():
			if pos >= wt.start_time and pos <= wt.end_time:
				if current_word_index != i:
					current_word_index = i
					word_list.select(i)
					word_list.ensure_current_is_visible()
					_update_display()
				return


# ============================================================
# Save TTML
# ============================================================
func _on_save_ttml_pressed() -> void:
	var untimed_count: int = 0
	for wt: WordTiming in words:
		if not wt.is_complete():
			untimed_count += 1

	if untimed_count > 0:
		print("Warning: %d word(s) have incomplete timing" % untimed_count)

	file_dialog_save.popup_centered()


func _on_save_file_selected(path: String) -> void:
	if not path.ends_with(".ttml"):
		path += ".ttml"

	var xml: String = _generate_ttml()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("Failed to write TTML: ", path)
		return

	file.store_string(xml)
	file.close()
	print("Saved TTML to: ", path)


func _generate_ttml() -> String:
	var body_duration: float = 0.0
	if audio_player.stream != null:
		body_duration = audio_player.stream.get_length()

	# Calculate line groupings
	var lines: Dictionary = {}  # line_index -> [word indices]
	for i: int in words.size():
		var li: int = words[i].line_index
		if not lines.has(li):
			lines[li] = []
		lines[li].append(i)

	var song_name: String = song_name_edit.text.strip_edges()
	var artist: String = artist_edit.text.strip_edges()
	var album: String = album_edit.text.strip_edges()
	var songwriters: String = songwriters_edit.text.strip_edges()

	var out: String = "<tt xmlns=\"http://www.w3.org/ns/ttml\" xmlns:ttm=\"http://www.w3.org/ns/ttml#metadata\" xmlns:amll=\"http://www.example.com/ns/amll\" xmlns:itunes=\"http://music.apple.com/lyric-ttml-internal\" itunes:timing=\"Word\">\n"

	# Head
	out += "<head>\n"
	out += "<metadata>\n"
	out += "<ttm:agent type=\"person\" xml:id=\"v1\"/>\n"
	out += "<iTunesMetadata xmlns=\"http://music.apple.com/lyric-ttml-internal\">\n"
	if not songwriters.is_empty():
		out += "<songwriters>\n"
		out += "<songwriter>%s</songwriter>\n" % songwriters.xml_escape()
		out += "</songwriters>\n"
	out += "</iTunesMetadata>\n"
	out += "<amll:meta key=\"musicName\" value=\"%s\"/>\n" % song_name.xml_escape()
	if not artist.is_empty():
		out += "<amll:meta key=\"artists\" value=\"%s\"/>\n" % artist.xml_escape()
	if not album.is_empty():
		out += "<amll:meta key=\"album\" value=\"%s\"/>\n" % album.xml_escape()
	out += "</metadata>\n"
	out += "</head>\n"

	# Body
	out += "<body dur=\"%s\">\n" % WordTiming._fmt(body_duration)

	# Get sorted line indices
	var sorted_lines: Array = []
	for li: int in lines:
		sorted_lines.append(li)
	sorted_lines.sort()

	# Calculate div bounds
	var first_word_idx: int = lines[sorted_lines[0]][0]
	var last_word_idx: int = lines[sorted_lines[-1]][-1]
	var div_begin: float = words[first_word_idx].start_time if words[first_word_idx].has_start() else 0.0
	var div_end: float = words[last_word_idx].end_time if words[last_word_idx].has_end() else body_duration

	out += "<div begin=\"%s\" end=\"%s\">\n" % [WordTiming._fmt(div_begin), WordTiming._fmt(div_end)]

	var line_num: int = 1
	for li: int in sorted_lines:
		var word_indices: Array = lines[li]
		var first_w: WordTiming = words[word_indices[0]]
		var last_w: WordTiming = words[word_indices[-1]]

		var line_begin: float = first_w.start_time if first_w.has_start() else 0.0
		var line_end: float = last_w.end_time if last_w.has_end() else line_begin + 0.1

		out += "<p begin=\"%s\" end=\"%s\" ttm:agent=\"v1\" itunes:key=\"L%d\">" % [WordTiming._fmt(line_begin), WordTiming._fmt(line_end), line_num]

		for idx: int in word_indices:
			var w: WordTiming = words[idx]
			var w_begin: float = w.start_time if w.has_start() else line_begin
			var w_end: float = w.end_time if w.has_end() else w_begin + 0.1
			out += "<span begin=\"%s\" end=\"%s\">%s</span>" % [WordTiming._fmt(w_begin), WordTiming._fmt(w_end), w.text.xml_escape()]
			if idx != word_indices[-1]:
				out += " "

		out += "</p>\n"
		line_num += 1

	out += "</div>\n"
	out += "</body>\n"
	out += "</tt>\n"

	return out


# ============================================================
# Shortcut hints
# ============================================================
func _get_tooltip_text() -> String:
	return """Shortcuts:
  Space — Play / Pause
  S     — Mark start time for current word
  D     — Mark end time for current word (auto-advances)
  ← →   — Seek ±2s
  Ctrl+Z — Undo last timing"""
