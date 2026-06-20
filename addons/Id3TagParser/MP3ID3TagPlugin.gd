@tool
extends EditorPlugin

const AUTOLOAD_NAME = "Id3TagParser"

func _enter_tree():
	add_autoload_singleton(AUTOLOAD_NAME, "res://addons/Id3TagParser/improved_mp3id3_tag_parser.gd")

func _exit_tree():
	remove_autoload_singleton(AUTOLOAD_NAME)
