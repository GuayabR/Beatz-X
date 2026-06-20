extends Panel

func popup(title: String, code: int):
	$notice_title.text = title
	$notice_code.text = str(code)
	await get_tree().create_timer(7.5).timeout
	queue_free()
