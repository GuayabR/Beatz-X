extends Node

signal loading_status(status: ResourceLoader.ThreadLoadStatus, progress: float)
signal scene_loaded(scene: PackedScene)

class SceneLoadRequest extends RefCounted:
	signal completed(scene: PackedScene)

	var path: String
	var scene: PackedScene
	var progress := 0.0
	var is_completed := false

	func _init(requested_path: String) -> void:
		path = requested_path

	func finish(result: PackedScene) -> void:
		scene = result
		if scene != null:
			progress = 1.0
		is_completed = true
		completed.emit(scene)

	func wait() -> PackedScene:
		if not is_completed:
			await completed
		return scene

var loaded_scene: PackedScene
var _loading_path := ""
var _is_loading := false
var _active_request: SceneLoadRequest
var _request_queue: Array[SceneLoadRequest] = []


func load_scene(path: String) -> SceneLoadRequest:
	var request := SceneLoadRequest.new(path)
	_request_queue.append(request)
	_start_next_request()
	return request


func _start_next_request() -> void:
	if _active_request != null:
		return

	while not _request_queue.is_empty():
		var request: SceneLoadRequest = _request_queue.pop_front()
		_loading_path = request.path
		loaded_scene = null

		var error := ResourceLoader.load_threaded_request(_loading_path)
		if error != OK:
			push_error("Failed to start loading scene: %s (error %d)" % [_loading_path, error])
			request.finish(null)
			continue

		_active_request = request
		_is_loading = true
		return

	_loading_path = ""
	_is_loading = false


func get_progress() -> float:
	if _active_request == null:
		return 0.0
	return _active_request.progress


func is_loading() -> bool:
	return _active_request != null or not _request_queue.is_empty()


func _process(_delta: float) -> void:
	if _active_request == null:
		return

	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_loading_path, progress)
	var progress_value: float = progress[0] if not progress.is_empty() else 0.0
	_active_request.progress = progress_value
	loading_status.emit(status, progress_value)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(_loading_path) as PackedScene
			if scene == null:
				push_error("Loaded resource is not a PackedScene: %s" % _loading_path)
			_finish_active_request(scene)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Failed loading scene: %s" % _loading_path)
			_finish_active_request(null)


func _finish_active_request(scene: PackedScene) -> void:
	var request := _active_request
	_active_request = null
	_is_loading = false
	_loading_path = ""
	loaded_scene = scene

	request.finish(scene)
	if scene != null:
		scene_loaded.emit(scene)

	_start_next_request()
