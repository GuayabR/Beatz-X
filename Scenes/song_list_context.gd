extends Panel

signal play_as_bg_song(path: String, idx: int)

signal play(idx: int, path: String, from_album: bool)

signal delete(idx: int, path: String, from_album: bool)

signal edit(idx: int, path: String, from_album: bool)

signal go_to_album_pressed(idx: int, album_name: String, album_artist: String, album_year: int, album_cover: Image)

var path: String
var metadata: Dictionary
var index: int

var from_album: bool = false

func _ready() -> void:
	if OS.get_name() == "Android": 
		$buttons/open_explorer.disabled = true
		
		for b in $buttons.get_children():
			if b is not Button: continue
			
			var btn: Button = b
			
			btn.custom_minimum_size.y = 29.0
			
		
		for lbl: Label in $text.get_children():
			
			lbl.custom_minimum_size.y = 18.0
			
			lbl.add_theme_font_size_override("font_size", 15)
			

func appear(item_name: String, meta: Dictionary, idx: int, from_album_view: bool = false):
	$text/item_song_name.text = item_name
	metadata = meta
	
	index = idx
	
	#$item_meta.text = JSON.stringify(meta, "	", false)
	
	$text/item_artist.text = meta.artist
	$text/item_album.text = meta.album
	$text/item_year.text = str(int(meta.year))
	
	$buttons/play_as_bg_song.set_meta("song_path", meta.stream)
	path = ProjectSettings.globalize_path(meta.beatz_path)
	
	if from_album_view:
		$buttons/go_to_album.disabled = true
		from_album = true
	else:
		$buttons/go_to_album.disabled = false
		from_album = false

func _on_play_as_bg_song_pressed() -> void:
	$buttons/play_as_bg_song.release_focus()
	var p = $buttons/play_as_bg_song.get_meta("song_path")
	play_as_bg_song.emit(p, index)
	hide()
	$buttons/play_as_bg_song.release_focus()

func _on_open_explorer_pressed() -> void:
	$buttons/open_explorer.release_focus()
	General.explorer(path.get_base_dir())
	hide()

func _on_play_pressed() -> void:
	$buttons/play.release_focus()
	play.emit(index, path, from_album)
	hide()

func _on_delete_pressed() -> void:
	$buttons/delete.release_focus()
	delete.emit(index, path, from_album)
	hide()

func _on_edit_pressed() -> void:
	$buttons/edit.release_focus()
	edit.emit(index, path, from_album)
	hide()

func _on_go_to_album_pressed() -> void:
	$buttons/go_to_album.release_focus()
	go_to_album_pressed.emit(index, metadata.album, metadata.artist, metadata.year, Image.load_from_file(metadata.cover_path))
	hide()
