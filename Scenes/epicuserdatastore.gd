extends Node

signal file_loaded(filename: String, data)
signal file_saved(filename: String, success: bool)
signal sync_completed()

var pending_writes: Dictionary = {}
var cached_files: Dictionary = {}
var is_syncing := false


func _log(message: String) -> void:
	print("SDK EpicUserDataStore at %s: %s" % [Time.get_unix_time_from_system(), message])


# ----------------------------------------------------------------------
# INIT (IMPORTANT: hook EOS callbacks like demo)
# ----------------------------------------------------------------------

func _ready() -> void:
	var eos = EOS.get_instance()

	eos.playerdatastorage_interface_write_file_callback.connect(_on_write_done)
	eos.playerdatastorage_interface_write_file_data_callback.connect(_on_write_data)
	eos.playerdatastorage_interface_read_file_callback.connect(_on_read_done)
	eos.playerdatastorage_interface_read_file_data_callback.connect(_on_read_data)
	eos.playerdatastorage_interface_file_transfer_progress_callback.connect(_on_transfer_progress)


# ----------------------------------------------------------------------
# PUBLIC API
# ----------------------------------------------------------------------

func save_file(filename: String, data) -> void:
	_log("queue save %s" % filename)

	pending_writes[filename] = data
	_process_write_queue()


func load_file(filename: String) -> void:
	_log("loading file %s" % filename)

	var options = EOS.PlayerDataStorage.ReadFileOptions.new()
	options.local_user_id = EOSGRuntime.local_product_user_id
	options.filename = filename

	var request = EOS.PlayerDataStorage.PlayerDataStorageInterface.read_file(options)

	if request == null:
		_log("READ FAILED IMMEDIATELY %s" % filename)
		return


func delete_file(filename: String) -> void:
	_log("deleting file %s" % filename)

	var options = EOS.PlayerDataStorage.DeleteFileOptions.new()
	options.local_user_id = EOSGRuntime.local_product_user_id
	options.filename = filename

	EOS.PlayerDataStorage.PlayerDataStorageInterface.delete_file(options)

	cached_files.erase(filename)


func get_cached(filename: String):
	return cached_files.get(filename, null)


# ----------------------------------------------------------------------
# SYNC
# ----------------------------------------------------------------------

func sync_cloud() -> void:
	_log("querying file list from EOS")

	is_syncing = true

	var options = EOS.PlayerDataStorage.QueryFileListOptions.new()
	options.local_user_id = EOSGRuntime.local_product_user_id

	EOS.PlayerDataStorage.PlayerDataStorageInterface.query_file_list(options)


func _on_sync_complete() -> void:
	is_syncing = false
	_log("cloud sync complete")
	sync_completed.emit()


# ----------------------------------------------------------------------
# WRITE SYSTEM
# ----------------------------------------------------------------------

func _process_write_queue() -> void:
	if pending_writes.is_empty():
		return

	for filename in pending_writes.keys():
		var data = pending_writes[filename]

		var options = EOS.PlayerDataStorage.WriteFileOptions.new()
		options.local_user_id = EOSGRuntime.local_product_user_id
		options.filename = filename

		# IMPORTANT: match EOS demo style (bytes only)
		options.data = var_to_bytes(data)

		_log("writing %s" % filename)

		var request: EOSGFileTransferRequest = EOS.PlayerDataStorage.PlayerDataStorageInterface.write_file(options)

		if request == null:
			_log("WRITE FAILED TO START %s" % filename)
			file_saved.emit(filename, false)
			continue

		_log("WRITE STARTED %s" % filename)

		cached_files[filename] = data

	pending_writes.clear()


# ----------------------------------------------------------------------
# CALLBACKS (THIS IS THE IMPORTANT PART)
# ----------------------------------------------------------------------

func _on_write_done(data) -> void:
	_log("WRITE CALLBACK: %s" % str(data))

	# EOS usually returns filename/status in this struct
	if typeof(data) == TYPE_DICTIONARY and data.has("filename"):
		file_saved.emit(data["filename"], true)
	else:
		file_saved.emit("", true)


func _on_write_data(data) -> void:
	_log("WRITE PROGRESS: %s" % str(data))


func _on_read_done(data) -> void:
	_log("READ CALLBACK: %s" % str(data))


func _on_read_data(data) -> void:
	_log("READ DATA CALLBACK: %s" % str(data))

	# Try decode safely
	if data is PackedByteArray:
		var text = data.get_string_from_utf8()
		var parsed = JSON.parse_string(text)

		if parsed != null:
			cached_files["last_loaded"] = parsed
			file_loaded.emit("last_loaded", parsed)


func _on_transfer_progress(data) -> void:
	_log("TRANSFER PROGRESS: %s" % str(data))


# ----------------------------------------------------------------------
# UTILITIES
# ----------------------------------------------------------------------

func file_exists_cached(filename: String) -> bool:
	return cached_files.has(filename)


func force_save_all() -> void:
	_log("forcing save all")
	_process_write_queue()
