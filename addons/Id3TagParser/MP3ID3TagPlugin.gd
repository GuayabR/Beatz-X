@tool
extends EditorPlugin

const AUTOLOAD_NAME = "Id3TagParser"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/Id3TagParser/MP3ID3Tag.gd")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
