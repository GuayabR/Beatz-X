extends Control

@onready var pitch_lbl: RichTextLabel = $RichTextLabel
@onready var vis: ColorRect = $ColorRect

var effect: AudioEffectCapture

func _ready() -> void:
	print("=== Input Devices ===")

	for device in AudioServer.get_input_device_list():
		print(device)

	print("Current input device: ", AudioServer.input_device)

	$RichTextLabel2.text = "Input: %s" % AudioServer.input_device

	var idx := AudioServer.get_bus_index("Record")
	effect = AudioServer.get_bus_effect(idx, 0)

func _process(_delta: float) -> void:
	if effect == null:
		return

	var frames := effect.get_frames_available()
	if frames < 2048:
		return

	var buffer := effect.get_buffer(2048)

	var samples: PackedFloat32Array
	samples.resize(buffer.size())

	var peak := 0.0
	var energy := 0.0

	for i in buffer.size():
		var v := (buffer[i].x + buffer[i].y) * 0.5
		samples[i] = v

		peak = max(peak, absf(v))
		energy += v * v

	energy /= samples.size()

	if energy < 0.0005:
		pitch_lbl.text = "Peak: %.5f\nNo pitch" % peak
		return

	var frequency := detect_pitch_autocorrelation(samples)

	pitch_lbl.text = "Peak: %.5f\n%s\n%.1f Hz" % [
		peak,
		frequency_to_note(frequency),
		frequency
	]
	
	$RichTextLabel2.text = "Input: %s" % AudioServer.get_input_device()

func detect_pitch_autocorrelation(samples: PackedFloat32Array) -> float:
	var sample_rate := AudioServer.get_mix_rate()

	var best_lag := -1
	var best_corr := 0.0

	var min_freq := 80.0
	var max_freq := 1000.0

	var min_lag := int(sample_rate / max_freq)
	var max_lag := int(sample_rate / min_freq)

	for lag in range(min_lag, max_lag):
		var corr := 0.0

		for i in range(samples.size() - lag):
			corr += samples[i] * samples[i + lag]

		if corr > best_corr:
			best_corr = corr
			best_lag = lag

	if best_lag <= 0:
		return -1.0

	return sample_rate / float(best_lag)

func frequency_to_note(freq: float) -> String:
	var notes := [
		"C", "C#", "D", "D#",
		"E", "F", "F#", "G",
		"G#", "A", "A#", "B"
	]

	var midi := roundi(69 + 12.0 * log(freq / 440.0) / log(2.0))

	var note_name = notes[posmod(midi, 12)]
	var octave = int(midi / 12) - 1

	return "%s%d" % [note_name, octave]
