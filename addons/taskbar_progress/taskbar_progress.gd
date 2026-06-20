@tool
extends EditorPlugin
class_name TBProgress

## Sets a set progress value.
static func set_progress(value: int, max: int) -> void:
	TaskbarProgress.set_progress(value, max)

## Sets an undefined set progress value. Must call [code]TBProgress.clear()[/code] whenever your program finishes loading what you need it to. 
static func set_indeterminate() -> void:
	TaskbarProgress.set_indeterminate()

## Sets the progress bar to a loading state. A progresss value or an indeterminate value must have been set beforehand.
static func set_paused() -> void:
	TaskbarProgress.set_paused()

## Sets the progress bar to an error state.
static func set_error() -> void:
	TaskbarProgress.set_error()

## Clears any state the progress bar previously was to the default state.
static func clear() -> void:
	TaskbarProgress.clear()
