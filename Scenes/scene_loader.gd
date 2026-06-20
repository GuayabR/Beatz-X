extends Node

signal loading_status(status: ResourceLoader.ThreadLoadStatus, progress: float)
signal scene_loaded(scene: PackedScene)

var _loading_path := ""
var _is_loading := false
var loaded_scene: PackedScene

func load_scene(path: String) -> void:
	if _is_loading:
		push_warning("SceneLoader is already loading a scene.")
		return

	_loading_path = path
	_is_loading = true

	var err := ResourceLoader.load_threaded_request(path)

	if err != OK:
		push_error("Failed to start loading scene: %s" % path)

		_loading_path = ""
		_is_loading = false

func get_progress() -> float:
	var progress := []
	ResourceLoader.load_threaded_get_status(_loading_path, progress)

	if progress.is_empty():
		return 0.0

	return progress[0]

func is_loading() -> bool:
	return _is_loading

func _process(_delta: float) -> void:
	if !_is_loading:
		return

	var progress := []

	var status := ResourceLoader.load_threaded_get_status(
		_loading_path,
		progress
	)

	loading_status.emit(
		status,
		progress[0] if !progress.is_empty() else 0.0
	)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			loaded_scene = ResourceLoader.load_threaded_get(_loading_path)

			_loading_path = ""
			_is_loading = false

			scene_loaded.emit(loaded_scene)

		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Failed loading scene.")

			_loading_path = ""
			_is_loading = false
