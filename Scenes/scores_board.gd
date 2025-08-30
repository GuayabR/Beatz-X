extends ScrollContainer

var beatz_file

func _set_items():
	var best_score = _get_best_score(beatz_file)
	if best_score:
		$scores_cont/best_cont/best_label.text = "BEST SCORE:"
		$scores_cont/best_cont/best.text = format_number_with_commas(int(best_score.score)) + "!"
		$scores_cont/best_cont/best_date_achieved.text = str(best_score.date)
		$scores_cont/best_cont/best_exacts.text = "Exacts: " + str(int(best_score.exacts))
		$scores_cont/best_cont/best_insanes.text = "Insanes: " + str(int(best_score.insanes))
		$scores_cont/best_cont/best_perfects.text = "Perfects: " + str(int(best_score.perfects))
		$scores_cont/best_cont/best_most_misses.text = "Misses: " + str(int(best_score.misses))
	else:
		$scores_cont/best_cont/best_label.text = "No score yet for this song"
		$scores_cont/best_cont/best.text = "-"
		$scores_cont/best_cont/best_date_achieved.text = "-"
		$scores_cont/best_cont/best_exacts.text = "-"
		$scores_cont/best_cont/best_insanes.text = "-"
		$scores_cont/best_cont/best_perfects.text = "-"
		$scores_cont/best_cont/best_most_misses.text = "-"

func _get_best_score(file_path: String) -> Dictionary:
	var pw = "8YouAreNOTsupposedToBeHereThisKeyIsVerySecureDoNOTeditYourScoresItsBetterWhenYouAchieveAFullPerfectOnYourOwnÑ"
	var dotfile_path = "user://.scores_data"
	if not FileAccess.file_exists(dotfile_path):
		return {}
	
	var scores: Array = []
	var file := FileAccess.open_encrypted_with_pass(dotfile_path, FileAccess.READ, pw)
	if file:
		var text = file.get_as_text()
		var json = JSON.parse_string(text)
		if json is Array:
			scores = json
		file.close()

	var best = null
	for s in scores:
		if s.has("file") and s["file"] == file_path:
			if best == null or s["score"] > best["score"]:
				best = s
	
	return best if best != null else {}

func format_number_with_commas(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		result = s[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "," + result
	return result
