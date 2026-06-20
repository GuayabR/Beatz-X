extends Control

@onready var noti_container: VBoxContainer = $noti_container

const NOTIFICATION_SCENE = preload("res://Scenes/notification.tscn")

func _ready() -> void:
	HAchievements.achievement_unlocked.connect(_on_achievement_unlocked)


func _on_achievement_unlocked(data: Dictionary) -> void:
	_spawn_notification(data)


func _spawn_notification(data: Dictionary) -> void:
	var noti = NOTIFICATION_SCENE.instantiate()
	noti.setup(data)

	noti_container.add_child(noti)

	# optional: keep it from overflowing
	_reorder_notifications()
	
	await get_tree().create_timer(5.0).timeout
	
	var noti_t = create_tween()
	noti_t.tween_property(noti, "modulate", Color.TRANSPARENT, 1.0).set_ease(Tween.EASE_IN_OUT)
	await get_tree().create_timer(1.0).timeout
	noti.queue_free()


func _reorder_notifications() -> void:
	for i in range(noti_container.get_child_count()):
		var child = noti_container.get_child(i)
		child.z_index = i
