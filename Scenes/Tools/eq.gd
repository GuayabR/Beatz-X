extends Control

var bus_index: int = 1
var effect_index: int = 1

const DEFAULT_PRESET_NAMES := ["Flat", "Bass", "Bass Compensate"]

# EQ10 frequency map (index → frequency label for saving)
const BAND_FREQS := {
	0: "31",
	1: "62",
	2: "125",
	3: "250",
	4: "500",
	5: "1000",
	6: "2000",
	7: "4000",
	8: "8000",
	9: "16000"
}

func _ready() -> void:
	#print("EQ settings loaded for bus: ", AudioServer.get_bus_name(bus_index))
	_load_current_eq_to_sliders()
	_init_presets_list()
	$eq_to_menu_song_toggle.set_pressed_no_signal(Settings.misc.eq_applies_to_menu_song)


# --- INITIALIZATION ---

func _load_current_eq_to_sliders() -> void:
	for band_index in BAND_FREQS.keys():
		var freq_key = BAND_FREQS[band_index]
		if Settings.eq.has(freq_key):
			var saved_val = Settings.eq[freq_key]
			var slider_path := "eq_cont/eq_slider%d" % [band_index + 1]
			if has_node(slider_path):
				var slider: VSlider = get_node(slider_path)
				slider.set_value_no_signal(saved_val)
				_set_eq_band(band_index, saved_val)

func _init_presets_list() -> void:
	var presets: OptionButton = $presets
	presets.clear()

	# Built-in presets first
	for preset_name in DEFAULT_PRESET_NAMES:
		presets.add_item(preset_name)

	presets.add_separator("Custom")

	# Add user-created presets (any not in built-ins)
	for p_name in Settings.eq_presets.keys():
		if p_name not in DEFAULT_PRESET_NAMES:
			presets.add_item(p_name)
	
	if Settings.misc.selected_eq_preset in DEFAULT_PRESET_NAMES:
		$remove_preset.disabled = true
		$rename_preset.disabled = true
	else:
		$remove_preset.disabled = false
		$rename_preset.disabled = false
	
	# Select the loaded in $presets
	for i in range(presets.item_count):
		if presets.get_item_text(i) == Settings.misc.selected_eq_preset:
			presets.select(i)
			break
	
	$presets.size = Vector2(336.5, 43)


# --- EQ LOGIC ---

func _set_eq_band(band_index: int, gain_db: float) -> void:
	var bus_indices := [bus_index]
	if Settings.misc.eq_applies_to_menu_song:
		bus_indices.append(3) # Menu bus

	for b_idx in bus_indices:
		var eq := AudioServer.get_bus_effect(b_idx, effect_index)
		if eq and eq is AudioEffectEQ10:
			eq.set_band_gain_db(band_index, gain_db)

	var value_label_path := "eq_cont/eq_slider%d/eq_value%d" % [band_index + 1, band_index + 2]
	if has_node(value_label_path):
		var value_label: RichTextLabel = get_node(value_label_path)
		value_label.text = str(gain_db).pad_decimals(1)

func _apply_eq_preset(preset_name: String) -> void:
	if not Settings.eq_presets.has(preset_name):
		push_warning("Preset '%s' not found!" % preset_name)
		return

	var preset = Settings.eq_presets[preset_name]
	for band_index in BAND_FREQS.keys():
		var freq_key = BAND_FREQS[band_index]
		if preset.has(freq_key):
			var val = preset[freq_key]
			var slider_path := "eq_cont/eq_slider%d" % [band_index + 1]
			if has_node(slider_path):
				var slider: VSlider = get_node(slider_path)
				slider.set_value_no_signal(val)
			Settings.eq[freq_key] = val
			_set_eq_band(band_index, val)

	Settings._save()
	#print("Applied EQ preset:", preset_name)


# --- SIGNALS: SLIDERS & SAVING ---

func _on_eq_slider_1_value_changed(value: float) -> void: _set_eq_band(0, value)
func _on_eq_slider_2_value_changed(value: float) -> void: _set_eq_band(1, value)
func _on_eq_slider_3_value_changed(value: float) -> void: _set_eq_band(2, value)
func _on_eq_slider_4_value_changed(value: float) -> void: _set_eq_band(3, value)
func _on_eq_slider_5_value_changed(value: float) -> void: _set_eq_band(4, value)
func _on_eq_slider_6_value_changed(value: float) -> void: _set_eq_band(5, value)
func _on_eq_slider_7_value_changed(value: float) -> void: _set_eq_band(6, value)
func _on_eq_slider_8_value_changed(value: float) -> void: _set_eq_band(7, value)
func _on_eq_slider_9_value_changed(value: float) -> void: _set_eq_band(8, value)
func _on_eq_slider_10_value_changed(value: float) -> void: _set_eq_band(9, value)


func _on_eq_slider_1_drag_ended(v: bool) -> void: _save_band_if_changed(0, v)
func _on_eq_slider_2_drag_ended(v: bool) -> void: _save_band_if_changed(1, v)
func _on_eq_slider_3_drag_ended(v: bool) -> void: _save_band_if_changed(2, v)
func _on_eq_slider_4_drag_ended(v: bool) -> void: _save_band_if_changed(3, v)
func _on_eq_slider_5_drag_ended(v: bool) -> void: _save_band_if_changed(4, v)
func _on_eq_slider_6_drag_ended(v: bool) -> void: _save_band_if_changed(5, v)
func _on_eq_slider_7_drag_ended(v: bool) -> void: _save_band_if_changed(6, v)
func _on_eq_slider_8_drag_ended(v: bool) -> void: _save_band_if_changed(7, v)
func _on_eq_slider_9_drag_ended(v: bool) -> void: _save_band_if_changed(8, v)
func _on_eq_slider_10_drag_ended(v: bool) -> void: _save_band_if_changed(9, v)


func _save_band_if_changed(band_index: int, value_changed: bool) -> void:
	if not value_changed:
		return

	var freq_key = BAND_FREQS[band_index]
	var slider_path := "eq_cont/eq_slider%d" % [band_index + 1]
	if not has_node(slider_path):
		return

	var slider: VSlider = get_node(slider_path)
	var val := slider.value
	Settings.eq[freq_key] = val
	Settings._save()


# --- PRESET MANAGEMENT ---

func _on_save_preset_pressed() -> void:
	$save_preset.release_focus()
	
	$save_preset.hide()
	$preset_name.show()
	$cancel.show()

func _on_preset_name_text_submitted(new_text: String) -> void:
	var p_name: String = new_text.strip_edges()
	if p_name == "":
		return

	# ❌ Prevent overwriting built-in presets
	if p_name in DEFAULT_PRESET_NAMES:
		$preset_name.text = ""
		$preset_name.placeholder_text = "Cannot overwrite built-in presets."
		return

	# ✅ Capture current EQ values
	var new_preset := {}
	for band_index in BAND_FREQS.keys():
		var freq_key = BAND_FREQS[band_index]
		new_preset[freq_key] = Settings.eq[freq_key]

	# Save to General and persist
	var ps: Dictionary = Settings.eq_presets
	ps[p_name] = new_preset
	Settings.eq_presets = ps
	Settings.misc.selected_eq_preset = p_name
	Settings._save()
	

	# Refresh preset list
	_init_presets_list()
	
	# Reset UI
	$save_preset.show()
	$preset_name.hide()
	$cancel.hide()
	$preset_name.text = ""
	$preset_name.placeholder_text = "Preset name..."

func _on_cancel_pressed() -> void:
	$cancel.release_focus()
	
	$save_preset.show()
	$preset_name.hide()
	$cancel.hide()
	$preset_name.text = ""
	$preset_name.placeholder_text = "Preset name..."
	
	$remove_preset.show()
	$rename_preset.show()

func _on_presets_item_selected(index: int) -> void:
	var p_name = $presets.get_item_text(index)
	if p_name == "":
		return
	if p_name in DEFAULT_PRESET_NAMES:
		$remove_preset.disabled = true
		$rename_preset.disabled = true
	else:
		$remove_preset.disabled = false
		$rename_preset.disabled = false
	_apply_eq_preset(p_name)


# --- EQ TO MENU SONG TOGGLE ---

func _on_eq_to_menu_song_toggle_toggled(toggled_on: bool) -> void:
	$eq_to_menu_song_toggle.release_focus()
	
	Settings.misc.eq_applies_to_menu_song = toggled_on
	var menu_bus_index := 3
	var eq := AudioServer.get_bus_effect(menu_bus_index, effect_index)
	if eq and eq is AudioEffectEQ10:
		if toggled_on:
			for band_index in BAND_FREQS.keys():
				var freq_key = BAND_FREQS[band_index]
				eq.set_band_gain_db(band_index, Settings.eq[freq_key])
		else:
			for band_index in BAND_FREQS.keys():
				eq.set_band_gain_db(band_index, 0.0)
	Settings._save()

# --- PRESET REMOVAL & RENAMING ---

func _on_remove_preset_pressed() -> void:
	$remove_preset.release_focus()
	
	var p_id = $presets.get_selected_id()
	var p_name = $presets.get_item_text(p_id)

	# Prevent removing built-ins
	if p_name in DEFAULT_PRESET_NAMES:
		return
	
	$remove_preset.add_theme_font_size_override("font_size", 38)
	$remove_preset.add_theme_constant_override("outline_size", 16)
	
	# Show confirmation prompt
	$confirm_remove.show()
	$confirm_remove.text = "Confirm remove '%s'?" % p_name
	$rename_preset.hide()
	$presets.hide()
	
	$remove_preset.disconnect("pressed", _on_confirm_remove_pressed)
	$remove_preset.connect("pressed", _on_cancel_remove_pressed)
	
	# Connect confirm button
	$confirm_remove.disconnect("pressed", _on_confirm_remove_pressed)
	$confirm_remove.connect("pressed", _on_confirm_remove_pressed.bind(p_name))

func _on_cancel_remove_pressed():
	$confirm_remove.hide()
	$rename_preset.show()
	$remove_preset.show()
	$cancel.hide()
	$presets.show()
	
	$remove_preset.release_focus()
	
	$remove_preset.add_theme_font_size_override("font_size", 34)
	$remove_preset.add_theme_constant_override("outline_size", 10)
	
	$remove_preset.disconnect("pressed", _on_cancel_remove_pressed)
	$remove_preset.connect("pressed", _on_remove_preset_pressed)

func _on_confirm_remove_pressed(p_name: String) -> void:
	$confirm_remove.hide()
	$rename_preset.show()
	$remove_preset.show()
	$cancel.hide()
	$presets.show()
	
	$remove_preset.add_theme_font_size_override("font_size", 34)
	$remove_preset.add_theme_constant_override("outline_size", 10)

	if p_name in DEFAULT_PRESET_NAMES:
		return

	# Remove the preset
	var ps: Dictionary = Settings.eq_presets
	if ps.has(p_name):
		ps.erase(p_name)
		Settings.eq_presets = ps

	# Default back to Flat
	Settings.misc.selected_eq_preset = "Flat"
	Settings._save()

	# Refresh and select Flat
	_init_presets_list()
	var presets: OptionButton = $presets
	for i in range(presets.item_count):
		if presets.get_item_text(i) == "Flat":
			presets.select(i)
			break

func _on_rename_preset_pressed() -> void:
	$rename_preset.release_focus()
	var p_id = $presets.get_selected_id()
	var old_name = $presets.get_item_text(p_id)
	if old_name in DEFAULT_PRESET_NAMES:
		return

	# Prepare rename UI
	$preset_name.show()
	$preset_name.placeholder_text = "Rename '%s' to..." % old_name
	$save_preset.hide()
	$cancel.show()
	$remove_preset.hide()
	$rename_preset.hide()

	# Connect rename submit handler
	$preset_name.disconnect("text_submitted", _on_preset_name_text_submitted)
	$preset_name.connect("text_submitted", _on_preset_rename_submitted.bind(old_name))

func _on_preset_rename_submitted(new_name: String, old_name: String) -> void:
	var p_name := new_name.strip_edges()
	if p_name == "" or p_name in DEFAULT_PRESET_NAMES:
		return

	if Settings.eq_presets.has(p_name):
		return

	# Rename preset
	var ps: Dictionary = Settings.eq_presets
	if ps.has(old_name):
		ps[p_name] = ps[old_name]
		ps.erase(old_name)
	Settings.eq_presets = ps
	Settings.misc.selected_eq_preset = p_name
	Settings._save()

	# Refresh list and select new name
	_init_presets_list()
	var presets: OptionButton = $presets
	for i in range(presets.item_count):
		if presets.get_item_text(i) == p_name:
			presets.select(i)
			break

	# Reset UI
	$preset_name.hide()
	$save_preset.show()
	$cancel.hide()
	$rename_preset.show()
	$remove_preset.show()
	$preset_name.text = ""
	$preset_name.placeholder_text = "Preset name..."
	
	# Connect rename submit handler
	$preset_name.disconnect("text_submitted", _on_preset_rename_submitted)
	$preset_name.connect("text_submitted", _on_preset_name_text_submitted)
