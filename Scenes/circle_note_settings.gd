extends Control

var page: int = 1 # 3 is max

func picker_color_changed(color: Color, type: String):
	print("args: ", color, " ", type)
	
	Settings.circles[type] = color.to_html()   # saves "#ff0000ff"
	print(Settings.circles[type])
	if not get_parent().name == "settings":
		Settings._save()
	else:
		get_parent().save_stgs()

func _connect_popup(btn: ColorPickerButton) -> void:
	print("Connected ", btn.name)
	
	var popup: PopupPanel = btn.get_popup()

	popup.about_to_popup.connect(func():
		General.is_popup_open = true
	)

	popup.popup_hide.connect(func():
		General.is_popup_open = false
	)

func _ready() -> void:
	$press_use_idle.set_pressed_no_signal(Settings.circles.pressed_uses_idle_colors)
	$chart_use_idle_toggle.set_pressed_no_signal(Settings.circles.chart_notes_use_idle_colors)
	
	$size_value.text = "Circle Size: " + str(Settings.circles.size).pad_decimals(2)
	
	$size_slider.set_value_no_signal(Settings.circles.size)
	
	for node in $cols_cont/vcols/updl_idle.get_children():
		var picker: ColorPickerButton = node if node is ColorPickerButton else null
		
		if not picker: continue
		
		picker.color = Settings.parse_any_color(Settings.circles[picker.name])
		
		picker.connect("color_changed", Callable(self, "picker_color_changed").bind(picker.name))
		
		_connect_popup(picker)
		
		print("idle ", picker.name)
		print("col = ", Settings.circles[picker.name])
		print("==")
		
	
	for node in $cols_cont/vcols/diag_idle.get_children():
		var picker: ColorPickerButton = node if node is ColorPickerButton else null
			
		if not picker: continue
			
		picker.color = Settings.parse_any_color(Settings.circles[picker.name])
		picker.connect("color_changed", Callable(self, "picker_color_changed").bind(picker.name))
		_connect_popup(picker)
		
		print("diag idle ", picker.name)
		print("col = ", Settings.circles[picker.name])
		print("==")
	
	for node in $cols_cont/vcols/updl_pressed.get_children():
		var picker: ColorPickerButton = node if node is ColorPickerButton else null
			
		if not picker: continue
			
		picker.color = Settings.parse_any_color(Settings.circles[picker.name])
		picker.connect("color_changed", Callable(self, "picker_color_changed").bind(picker.name))
		_connect_popup(picker)
		
		print("pressed ", picker.name)
		print("col = ", Settings.circles[picker.name])
		print("==")
	
	for node in $cols_cont/vcols/diag_pressed.get_children():
		var picker: ColorPickerButton = node if node is ColorPickerButton else null
			
		if not picker: continue
			
		picker.color = Settings.parse_any_color(Settings.circles[picker.name])
		picker.connect("color_changed", Callable(self, "picker_color_changed").bind(picker.name))
		_connect_popup(picker)
		
		print("diag pressed ", picker.name)
		print("col = ", Settings.circles[picker.name])
		print("==")
	
	for node in $cols_cont/vcols/updl_chart.get_children():
		var picker: ColorPickerButton = node if node is ColorPickerButton else null
			
		if not picker: continue
			
		picker.color = Settings.parse_any_color(Settings.circles[picker.name])
		picker.connect("color_changed", Callable(self, "picker_color_changed").bind(picker.name))
		_connect_popup(picker)
		
		print("chart ", picker.name)
		print("col = ", Settings.circles[picker.name])
		print("==")
	
	for node in $cols_cont/vcols/diag_chart.get_children():
		var picker: ColorPickerButton = node if node is ColorPickerButton else null
			
		if not picker: continue
			
		picker.color = Settings.parse_any_color(Settings.circles[picker.name])
		picker.connect("color_changed", Callable(self, "picker_color_changed").bind(picker.name))
		_connect_popup(picker)
		
		print("diag chart ", picker.name)
		print("col = ", Settings.circles[picker.name])
		print("==")
	
	apply_page()

const MAX_PAGES: int = 3

func _on_next_page_pressed() -> void:
	$page_btns/next_page.release_focus()
	page += 1
	if page > MAX_PAGES:
		page = 1
	apply_page()

func _on_prev_page_pressed() -> void:
	$page_btns/prev_page.release_focus()
	page -= 1
	if page < 1:
		page = MAX_PAGES
	apply_page()

func apply_page() -> void:
	match page:
		1:
			$cols.text = "Colors (Idle)"
			$cols_cont/vcols/updl_idle.show()
			$cols_cont/vcols/diag_idle.show()
			for cont in [$cols_cont/vcols/updl_pressed, $cols_cont/vcols/diag_pressed, $cols_cont/vcols/updl_chart, $cols_cont/vcols/diag_chart]:
				cont.hide()
		2:
			$cols.text = "Colors (Pressed)"
			$cols_cont/vcols/updl_pressed.show()
			$cols_cont/vcols/diag_pressed.show()
			for cont in [$cols_cont/vcols/updl_idle, $cols_cont/vcols/diag_idle, $cols_cont/vcols/updl_chart, $cols_cont/vcols/diag_chart]:
				cont.hide()
		3:
			$cols.text = "Colors (Chart)"
			$cols_cont/vcols/updl_chart.show()
			$cols_cont/vcols/diag_chart.show()
			for cont in [$cols_cont/vcols/updl_idle, $cols_cont/vcols/diag_idle, $cols_cont/vcols/updl_pressed, $cols_cont/vcols/diag_pressed]:
				cont.hide()
	
	$page_lbl.text = str(page)


func _on_press_use_idle_toggled(toggled_on: bool) -> void:
	Settings.circles.pressed_uses_idle_colors = toggled_on
	if not get_parent().name == "settings":
		Settings._save()
	else:
		get_parent().save_stgs()
	
	for picker in $cols_cont/vcols/updl_pressed.get_children():
		if picker is ColorPickerButton: picker.disabled = toggled_on
	
	for picker in $cols_cont/vcols/diag_pressed.get_children():
		if picker is ColorPickerButton: picker.disabled = toggled_on


func _on_chart_use_idle_toggle_toggled(toggled_on: bool) -> void:
	Settings.circles.chart_notes_use_idle_colors = toggled_on
	if not get_parent().name == "settings":
		Settings._save()
	else:
		get_parent().save_stgs()
	
	for picker in $cols_cont/vcols/updl_chart.get_children():
		if picker is ColorPickerButton: picker.disabled = toggled_on
	
	for picker in $cols_cont/vcols/diag_chart.get_children():
		if picker is ColorPickerButton: picker.disabled = toggled_on


func _on_size_slider_value_changed(value: float) -> void:
	Settings.circles.size = value
	Settings._save()
	$size_value.text = "Circle Size: " + str(value).pad_decimals(2)
