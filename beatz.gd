extends Node

const BASE_REC_TIME_MS := 1080
const BASE_REC_TIME := 1.08

var lifetime_points := 0.0

const SCORES_PATH := "user://.scores_data"
const POINTS_PW := "8YouAreNOTsupposedToBeHereThisKeyIsVerySecureDoNOTeditYourScoresItsBetterWhenYouAchieveAFullPerfectOnYourOwnÑ"

const LIST_CACHE_PATH := "user://song_list_cache.json"

func _get_lifetime_points():
	print("Getting points")

	if FileAccess.file_exists(General.POINTS_PATH):
		var file := FileAccess.open_encrypted_with_pass(General.POINTS_PATH, FileAccess.READ, POINTS_PW)
		if file:
			var text := file.get_as_text()
			lifetime_points = text.to_float()
			file.close()
			print("Lifetime points loaded: ", lifetime_points)
		else:
			push_warning("Failed to read encrypted .points file!")
	else:
		print("Points file not found, creating from scores...")
		_collect_lifetime_points()

func _collect_lifetime_points():
	print("Collecting from .scores_data")

	if FileAccess.file_exists(SCORES_PATH):
		var file := FileAccess.open_encrypted_with_pass(SCORES_PATH, FileAccess.READ, POINTS_PW)
		if file:
			var text := file.get_as_text()
			var scores = JSON.parse_string(text)
			file.close()

			if scores is Array:
				lifetime_points = 0.0  # reset before summing
				for entry in scores:
					if entry.has("score"):
						var score_val := float(entry["score"])
						if score_val > 0.0: # ✅ Ignore zero and negative scores
							lifetime_points += score_val
						else:
							print("Ignoring invalid or negative score: ", score_val, " from ", entry.get("file", "<unknown>"))

				# Save lifetime points encrypted
				var enc_points := FileAccess.open_encrypted_with_pass(General.POINTS_PATH, FileAccess.WRITE, POINTS_PW)
				enc_points.store_string(str(lifetime_points))
				enc_points.close()

				print("✅ Rebuilt lifetime points from scores: ", lifetime_points)
			else:
				push_warning("Invalid .scores_data structure.")
		else:
			push_warning("Failed to open encrypted .scores_data.")
	else:
		print("No .scores_data file found; lifetime points is 0")
		lifetime_points = 0.0

func _ready() -> void:
	print("Beatz Global node loaded")
	_get_lifetime_points()

## The song list array, excluding covers. Used if "Keep list in memory" is toggled on.
var LIST: Dictionary

var playback_speed: float = 1.0



const ARBITRARY_WEIRD_HOLD_BAR_MOVEMENT_MULTIPLIER: float = 1.5385

var OFFSET: float:
	get: return Settings.misc.note_offset
var note_speed: float:
	get: return Settings.game.note_speed

var zoom: float = 10.0

## Returns a Y position based on saved note speed and set timestamp.
func time_to_y(time_ms: float, edit: bool = false) -> float:
	#var displacement = OFFSET
	var timestamp = time_ms
	if not edit: return (timestamp * zoom * note_speed / 100.0) / playback_speed
	else: return (timestamp * zoom * 15.0 / 100.0)

## Returns a time in milliseconds based on saved note speed and set Y position.
func y_to_time(y: float, edit: bool = false) -> float:
	if not edit: return ((-y) * zoom / note_speed) * playback_speed # - OFFSET
	else: return ((-y) * zoom / 15.0)
