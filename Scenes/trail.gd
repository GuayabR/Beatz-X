extends Line2D

var queue: Array
@export var MAX_LENGTH: int

func _process(delta: float) -> void:
	var pos = get_global_mouse_position()
	
	queue.push_front(pos)
	
	if queue.size() > MAX_LENGTH:
		queue.pop_back()
	
	clear_points()
	
	for p in queue:
		add_point(p)
