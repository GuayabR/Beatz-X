extends Node

signal achievement_unlocked(id: String)
signal achievements_unlocked(ids: Array[String])
signal achievements_synced()
signal cache_reset()

var unlocked_cache: Dictionary = {}
var synced := false

func _log(message: String) -> void:
	print("SDK AchieveMan at %s: %s" % [Time.get_unix_time_from_system(), message])

func _ready() -> void:
	_log("Initializing achievement manager")
	HAuth.logged_in.connect(sync)


func unlock(id: String) -> bool:
	if id == "":
		_log("Attempted to unlock empty achievement ID")
		return false

	if unlocked_cache.has(id):
		_log("Achievement already unlocked: %s" % id)
		return false

	_log("Unlocking achievement: %s" % id)

	var options = EOS.Achievements.UnlockAchievementsOptions.new()
	options.user_id = EOSGRuntime.local_product_user_id
	options.achievement_ids = [id]

	EOS.Achievements.AchievementsInterface.unlock_achievements(options)

	unlocked_cache[id] = true

	achievement_unlocked.emit(id)

	_log("Achievement unlock request sent: %s" % id)

	return true

func unlock_many(ids: Array[String]) -> Array[String]:
	_log("Unlocking %s achievements" % ids.size())

	var unlocked_ids: Array[String] = []

	for id in ids:
		if unlock(id):
			unlocked_ids.append(id)

	if not unlocked_ids.is_empty():
		achievements_unlocked.emit(unlocked_ids)
		_log("Successfully queued %s achievements" % unlocked_ids.size())

	return unlocked_ids

func sync() -> void:
	_log("Beginning EOS achievement sync")

	synced = false
	unlocked_cache.clear()

	query_player_achievements()

	var count := get_player_achievement_count()

	_log("EOS returned %s achievement entries" % count)

	for i in count:
		var achievement := get_player_achievement_by_index(i)

		if achievement.is_empty():
			_log("Achievement index %s returned empty data" % i)
			continue

		var id: String = achievement.get("achievement_id", "")

		if id != "":
			unlocked_cache[id] = true
			_log("Cached achievement: %s" % id)

	synced = true

	_log(
		"Achievement sync complete. Cached %s achievements"
		% unlocked_cache.size()
	)

	achievements_synced.emit()


func is_synced() -> bool:
	return synced


func is_unlocked(id: String) -> bool:
	return unlocked_cache.has(id)


func get_unlocked_ids() -> Array[String]:
	var ids: Array[String] = []

	for id in unlocked_cache:
		ids.append(id)

	return ids


func get_unlocked_count() -> int:
	return unlocked_cache.size()


func has_any(ids: Array[String]) -> bool:
	for id in ids:
		if is_unlocked(id):
			return true

	return false


func has_all(ids: Array[String]) -> bool:
	for id in ids:
		if not is_unlocked(id):
			return false

	return true


func reset_local_cache() -> void:
	_log("Resetting achievement cache")

	unlocked_cache.clear()
	synced = false

	cache_reset.emit()


# --------------------------------------------------------------------------
# EOS queries
# --------------------------------------------------------------------------

func query_player_achievements(user_id: String = EOSGRuntime.local_product_user_id) -> void:
	_log("Querying player achievements for user %s" % user_id)

	var options = EOS.Achievements.QueryPlayerAchievementsOptions.new()

	options.local_user_id = EOSGRuntime.local_product_user_id
	options.target_user_id = user_id

	EOS.Achievements.AchievementsInterface.query_player_achievements(options)


func get_player_achievement_count(user_id: String = EOSGRuntime.local_product_user_id) -> int:
	var options = EOS.Achievements.GetPlayerAchievementCountOptions.new()

	options.user_id = user_id

	var count := EOS.Achievements.AchievementsInterface.get_player_achievement_count(
		options
	)

	_log("Player achievement count requested, result: %s" % count)

	return count


func get_player_achievement_by_id(
	achievement_id: String,
	user_id: String = EOSGRuntime.local_product_user_id
) -> Dictionary:
	_log("Getting player achievement by ID: %s" % achievement_id)

	var options = EOS.Achievements.CopyPlayerAchievementByAchievementIdOptions.new()

	options.achievement_id = achievement_id
	options.local_user_id = EOSGRuntime.local_product_user_id
	options.target_user_id = user_id

	return EOS.Achievements.AchievementsInterface.copy_player_achievement_by_achievement_id(
		options
	)


func get_player_achievement_by_index(index: int) -> Dictionary:
	_log("Getting player achievement by index: %s" % index)

	var options = EOS.Achievements.CopyPlayerAchievementByIndexOptions.new()

	options.achievement_index = index
	options.local_user_id = EOSGRuntime.local_product_user_id
	options.target_user_id = EOSGRuntime.local_product_user_id

	return EOS.Achievements.AchievementsInterface.copy_player_achievement_by_index(options)


# --------------------------------------------------------------------------
# Achievement definitions
# --------------------------------------------------------------------------

func query_definitions() -> void:
	_log("Querying achievement definitions")

	var options = EOS.Achievements.QueryDefinitionsOptions.new()

	EOS.Achievements.AchievementsInterface.query_definitions(options)


func get_definition_count() -> int:
	var options = EOS.Achievements.GetAchievementDefinitionCountOptions.new()

	var count := EOS.Achievements.AchievementsInterface.get_achievement_definition_count(
		options
	)

	_log("Achievement definition count requested, result: %s" % count)

	return count


func get_definition_by_id(achievement_id: String) -> Dictionary:
	_log("Getting achievement definition by ID: %s" % achievement_id)

	var options = EOS.Achievements.CopyAchievementDefinitionV2ByAchievementIdOptions.new()

	options.achievement_id = achievement_id

	return EOS.Achievements.AchievementsInterface.copy_achievement_definition_v2_by_achievement_id(
		options
	)


func get_definition_by_index(index: int) -> Dictionary:
	_log("Getting achievement definition by index: %s" % index)

	var options = EOS.Achievements.CopyAchievementDefinitionV2ByIndexOptions.new()

	options.achievement_index = index

	return EOS.Achievements.AchievementsInterface.copy_achievement_definition_v2_by_index(
		options
	)
