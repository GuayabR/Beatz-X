extends Control

func _ready() -> void:
	HAuth.logged_in.connect(on_logged_in)
	HAuth.logged_out.connect(on_logged_out)

var steam_t: Tween
var epic_t: Tween

var guest: bool = false

func _on_steam_focus_entered() -> void:
	#$switch_service.play("steam")
	
	$steam.release_focus()


func _on_steam_mouse_entered() -> void:
	pass
	#if steam_t and steam_t.is_valid(): steam_t.kill()
	#steam_t = create_tween()
	#steam_t.tween_property($steam, "modulate:a", 1.0, 0.3)


func _on_steam_mouse_exited() -> void:
	pass
	#if steam_t and steam_t.is_valid(): steam_t.kill()
	#steam_t = create_tween()
	#steam_t.tween_property($steam, "modulate:a", 0.6, 0.3)


func _on_epic_focus_entered() -> void:
	#$switch_service.play("epic")
	
	$epic.release_focus()


func _on_epic_mouse_entered() -> void:
	pass
	#if epic_t and epic_t.is_valid(): epic_t.kill()
	#epic_t = create_tween()
	#epic_t.tween_property($epic, "modulate:a", 1.0, 0.3)


func _on_epic_mouse_exited() -> void:
	pass
	#if epic_t and epic_t.is_valid(): epic_t.kill()
	#epic_t = create_tween()
	#epic_t.tween_property($epic, "modulate:a", 0.6, 0.3)


func _on_login_epic_guest_pressed() -> void:
	%login_epic_guest.release_focus()
	$switch_service.play("guest_pressed", 0.12)

func _on_login_epic_portal_pressed() -> void:
	%login_epic_portal.release_focus()
	HAuth.login_account_portal_async()
	guest = false

func _on_login_epic_existing_pressed() -> void:
	%login_epic_existing.release_focus()
	HAuth.login_persistent_auth_async()
	guest = false


func _on_guest_user_text_submitted(new_text: String) -> void:
	HAuth.login_anonymous_async(new_text)
	$switch_service.play("guest_requested_login")
	guest = true


func _on_back_pressed() -> void:
	$back.release_focus()
	$switch_service.play("from_guest_to_epic", 0.08)

func on_logged_in() -> void:
	if HAuth.display_name != "": $what_acc.text = "Logged in to: %s" % HAuth.display_name
	elif HAuth.display_name == "" and General.epic_user_info.get("display_name", "") != "": $what_acc.text = "Logged in to: %s" % General.epic_user_info["display_name"]
	
	if not guest: $switch_service.play("epic_logged_in", -1)
	else: $switch_service.play("guest_logged_in", 0.06)

func on_logged_out() -> void:
	$switch_service.play("epic_logged_out", -1)


func _on_logout_pressed() -> void:
	HAuth.logout_async()


func _on_open_social_pressed() -> void:
	%open_social.release_focus()
	var options = EOS.UI.ShowFriendsOptions.new()
	options.local_user_id = HAuth.epic_account_id
	EOS.UI.UIInterface.show_friends(options)
