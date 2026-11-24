extends Node

signal external_media_changed(active: bool, media_info: Dictionary, artwork_bytes: PackedByteArray)
signal playback_status_changed(status: String)
signal media_position_changed(position_ms: int, duration_ms: int)
signal playback_command_state_changed(command: String)
signal playback_command_completed(command: String, succeeded: bool)

var media_available: bool = false
var media_info: Dictionary = {}
var artwork_bytes: PackedByteArray = PackedByteArray()
var playback_status: String = ""
var outstanding_command: String = ""

var _media_monitor: Node
var _monitoring: bool = false
var _is_main_menu: bool = false
var _active_scene_path: String = ""
var _extension_warning_issued: bool = false
var _position_timer: Timer
var _artwork_retry_timer: Timer
var _last_position_ms: int = -1
var _last_duration_ms: int = -1
var _artwork_retry_attempts: int = 0
var _pending_main_menu_unpause: bool = false


func _ready() -> void:
	_create_media_monitor()
	_position_timer = Timer.new()
	_position_timer.wait_time = 1.0
	_position_timer.one_shot = false
	_position_timer.timeout.connect(_refresh_position)
	add_child(_position_timer)
	_artwork_retry_timer = Timer.new()
	_artwork_retry_timer.wait_time = 0.35
	_artwork_retry_timer.one_shot = true
	_artwork_retry_timer.timeout.connect(_retry_album_art)
	add_child(_artwork_retry_timer)
	SceneLoader.scene_transition_requested.connect(_on_scene_transition_requested)
	get_tree().node_added.connect(_on_scene_tree_node_added)
	call_deferred("_initialize_scene_state")


func _create_media_monitor() -> void:
	if OS.get_name() != "Windows" or not ClassDB.class_exists(&"WindowsMediaMonitor"):
		return

	var monitor_object: Object = ClassDB.instantiate(&"WindowsMediaMonitor")
	_media_monitor = monitor_object as Node
	if _media_monitor == null:
		push_error("WindowsMediaMonitor could not be instantiated as a Node.")
		return

	add_child(_media_monitor)
	_media_monitor.connect("media_changed", _on_monitor_media_changed)
	_media_monitor.connect("playback_status_changed", _on_monitor_playback_status_changed)
	_media_monitor.connect("media_session_changed", _on_monitor_media_session_changed)
	_media_monitor.connect("media_unavailable", _on_monitor_media_unavailable)
	_media_monitor.connect("playback_command_completed", _on_monitor_playback_command_completed)


func _initialize_scene_state() -> void:
	var current_scene: Node = get_tree().current_scene
	_active_scene_path = current_scene.scene_file_path if current_scene != null else ""
	_is_main_menu = _active_scene_path == General.MENU
	apply_settings()


func _on_scene_tree_node_added(node: Node) -> void:
	if node.get_parent() != get_tree().root or node.scene_file_path.is_empty():
		return
	_handle_scene_transition(node.scene_file_path)


func apply_settings() -> void:
	var enabled: bool = bool(Settings.game.get("monitor_windows_media", false))
	var main_menu_only: bool = bool(Settings.game.get("only_monitor_on_main_menu", false))
	_pending_main_menu_unpause = (
		enabled
		and main_menu_only
		and _is_main_menu
		and bool(Settings.game.get("unpause_external_media_on_main_menu", false))
	)

	if not enabled:
		_pending_main_menu_unpause = false
		_stop_monitoring()
	elif main_menu_only and not _is_main_menu:
		if _monitoring:
			_pause_then_stop_monitoring()
		else:
			_stop_monitoring()
	else:
		_start_monitoring()
		_try_unpause_for_main_menu()


func _on_scene_transition_requested(destination_path: String) -> void:
	_handle_scene_transition(destination_path)


func _handle_scene_transition(destination_path: String) -> void:
	if destination_path == _active_scene_path:
		return

	var was_main_menu: bool = _is_main_menu
	_active_scene_path = destination_path
	_is_main_menu = destination_path == General.MENU

	var enabled: bool = bool(Settings.game.get("monitor_windows_media", false))
	var main_menu_only: bool = bool(Settings.game.get("only_monitor_on_main_menu", false))
	_pending_main_menu_unpause = (
		_is_main_menu
		and enabled
		and main_menu_only
		and bool(Settings.game.get("unpause_external_media_on_main_menu", false))
	)

	if not enabled:
		_pending_main_menu_unpause = false
		_stop_monitoring()
	elif _is_main_menu or not main_menu_only:
		_start_monitoring()
		_try_unpause_for_main_menu()
	elif was_main_menu:
		_pause_then_stop_monitoring()
	else:
		_pending_main_menu_unpause = false
		_stop_monitoring()


func _pause_then_stop_monitoring() -> void:
	var pause_submitted: bool = media_available and playback_status == "playing" and _request_playback_command("pause")
	if pause_submitted:
		_clear_media_state()
		call_deferred("_stop_monitoring_after_pause_request")
	else:
		_stop_monitoring()


func _stop_monitoring_after_pause_request() -> void:
	await get_tree().process_frame
	if not bool(Settings.game.get("monitor_windows_media", false)):
		_stop_monitoring()
	elif bool(Settings.game.get("only_monitor_on_main_menu", false)) and not _is_main_menu:
		_stop_monitoring()
	elif not media_available:
		_refresh_media()


func _start_monitoring() -> void:
	if _media_monitor == null:
		if OS.get_name() == "Windows" and not _extension_warning_issued:
			push_warning("Windows media monitoring is enabled, but WindowsMediaMonitor is unavailable.")
			_extension_warning_issued = true
		return
	if _monitoring:
		return

	_media_monitor.call("start_monitoring")
	_monitoring = true
	_position_timer.start()
	call_deferred("_refresh_media")


func _stop_monitoring() -> void:
	_clear_media_state()
	_position_timer.stop()
	_artwork_retry_timer.stop()
	_artwork_retry_attempts = 0
	_last_position_ms = -1
	_last_duration_ms = -1
	if _media_monitor == null or not _monitoring:
		return

	_monitoring = false
	_media_monitor.call("stop_monitoring")


func _refresh_media() -> void:
	if not _monitoring or _media_monitor == null:
		_clear_media_state()
		return
	if not bool(_media_monitor.call("is_monitoring")) or not bool(_media_monitor.call("is_available")) or not bool(_media_monitor.call("has_media")):
		_clear_media_state()
		return

	var refreshed_info: Dictionary = _media_monitor.call("get_media_info")
	_publish_media(refreshed_info)


func _publish_media(updated_info: Dictionary) -> void:
	if not _monitoring or _media_monitor == null:
		return
	if not bool(_media_monitor.call("is_available")) or not bool(_media_monitor.call("has_media")):
		_clear_media_state()
		return

	media_available = true
	media_info = updated_info.duplicate(true)
	playback_status = str(media_info.get("playback_status", "")).to_lower()
	var refreshed_artwork: PackedByteArray = _media_monitor.call("get_album_art")
	artwork_bytes = refreshed_artwork
	if artwork_bytes.is_empty():
		_schedule_album_art_retry()
	else:
		_artwork_retry_timer.stop()
		_artwork_retry_attempts = 0
	external_media_changed.emit(true, media_info, artwork_bytes)
	playback_status_changed.emit(playback_status)
	_try_unpause_for_main_menu()
	_publish_position_from_info(media_info)

func _schedule_album_art_retry() -> void:
	_artwork_retry_attempts = 6
	_artwork_retry_timer.start()

func _retry_album_art() -> void:
	if not _monitoring or not media_available or _media_monitor == null:
		_artwork_retry_attempts = 0
		return
	if not bool(_media_monitor.call("is_monitoring")) or not bool(_media_monitor.call("has_media")):
		_artwork_retry_attempts = 0
		return

	var current_info: Dictionary = _media_monitor.call("get_media_info")
	if not _is_same_media(current_info, media_info):
		_publish_media(current_info)
		return

	var refreshed_artwork: PackedByteArray = _media_monitor.call("get_album_art")
	if not refreshed_artwork.is_empty():
		artwork_bytes = refreshed_artwork
		media_info = current_info.duplicate(true)
		_artwork_retry_attempts = 0
		external_media_changed.emit(true, media_info, artwork_bytes)
		_publish_position_from_info(media_info)
		return

	_artwork_retry_attempts -= 1
	if _artwork_retry_attempts > 0:
		_artwork_retry_timer.start()

func _is_same_media(first: Dictionary, second: Dictionary) -> bool:
	for key: String in ["title", "artist", "album", "source_app_id", "duration_ms"]:
		if first.get(key, "") != second.get(key, ""):
			return false
	return true

func _refresh_position() -> void:
	if not _monitoring or _media_monitor == null:
		return
	if not bool(_media_monitor.call("is_monitoring")) or not bool(_media_monitor.call("has_media")):
		return

	var refreshed_info: Dictionary = _media_monitor.call("get_media_info")
	_publish_position_from_info(refreshed_info)

func _publish_position_from_info(info: Dictionary) -> void:
	var position_ms: int = int(info.get("position_ms", 0))
	var duration_ms: int = int(info.get("duration_ms", 0))
	position_ms = maxi(position_ms, 0)
	duration_ms = maxi(duration_ms, 0)

	media_info["position_ms"] = position_ms
	media_info["duration_ms"] = duration_ms
	if position_ms != _last_position_ms or duration_ms != _last_duration_ms:
		_last_position_ms = position_ms
		_last_duration_ms = duration_ms
		media_position_changed.emit(position_ms, duration_ms)


func _clear_media_state() -> void:
	var state_changed: bool = media_available or not media_info.is_empty() or not artwork_bytes.is_empty() or not playback_status.is_empty()
	media_available = false
	media_info.clear()
	artwork_bytes = PackedByteArray()
	playback_status = ""
	_last_position_ms = -1
	_last_duration_ms = -1
	_artwork_retry_timer.stop()
	_artwork_retry_attempts = 0
	if state_changed:
		external_media_changed.emit(false, {}, PackedByteArray())
		playback_status_changed.emit("")


func _on_monitor_media_changed(updated_info: Dictionary) -> void:
	_publish_media(updated_info)


func _on_monitor_playback_status_changed(status: String) -> void:
	playback_status = status.to_lower()
	if media_available:
		media_info["playback_status"] = status
	playback_status_changed.emit(playback_status)
	_try_unpause_for_main_menu()


func _on_monitor_media_session_changed(_source_app_id: String) -> void:
	_refresh_media()


func _on_monitor_media_unavailable() -> void:
	_clear_media_state()


func _on_monitor_playback_command_completed(command: String, succeeded: bool) -> void:
	if outstanding_command == command:
		outstanding_command = ""
		playback_command_state_changed.emit(outstanding_command)
	if not succeeded:
		push_warning("Windows media command '%s' was not accepted." % command)
	playback_command_completed.emit(command, succeeded)
	_try_unpause_for_main_menu()


func _try_unpause_for_main_menu() -> void:
	if not _pending_main_menu_unpause or not _is_main_menu:
		return
	if not bool(Settings.game.get("monitor_windows_media", false)) or not bool(Settings.game.get("only_monitor_on_main_menu", false)):
		_pending_main_menu_unpause = false
		return
	if not media_available:
		return
	if playback_status == "playing":
		_pending_main_menu_unpause = false
		return
	if playback_status != "paused" or not outstanding_command.is_empty():
		return
	if request_play_pause():
		_pending_main_menu_unpause = false


func request_previous() -> bool:
	return _request_playback_command("skip_previous")


func request_play_pause() -> bool:
	if playback_status == "playing":
		return _request_playback_command("pause")
	if playback_status == "paused":
		return _request_playback_command("play")
	return false


func request_next() -> bool:
	return _request_playback_command("skip_next")

func request_seek(position_ms: int) -> bool:
	if position_ms < 0:
		return false
	if not outstanding_command.is_empty():
		return false
	return _request_playback_command("seek", position_ms)


func _request_playback_command(command: String, position_ms: int = -1) -> bool:
	if _media_monitor == null or not _monitoring or not media_available or not outstanding_command.is_empty():
		return false

	outstanding_command = command
	playback_command_state_changed.emit(outstanding_command)

	match command:
		"pause":
			_media_monitor.call("try_pause")
		"play":
			_media_monitor.call("try_play")
		"skip_previous":
			_media_monitor.call("try_skip_previous")
		"skip_next":
			_media_monitor.call("try_skip_next")
		"seek":
			_media_monitor.call("try_seek", position_ms)
		_:
			outstanding_command = ""
			playback_command_state_changed.emit(outstanding_command)
			return false

	return true
