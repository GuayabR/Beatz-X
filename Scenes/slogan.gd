extends RichTextLabel

var last: String
var _running := true

func _ready() -> void:
	_run_loop()

func _exit_tree() -> void:
	_running = false

func _run_loop() -> void:
	await get_tree().process_frame  # give a frame for setup
	while _running and is_inside_tree():
		var t = General.MESSAGES.pick_random()
		while t == last and General.MESSAGES.size() > 1:
			t = General.MESSAGES.pick_random()
		
		text = t
		last = t
		
		await get_tree().create_timer(1.31 * 2.0).timeout
