extends Control
## Settings screen: audio levels and full-screen toggle, persisted immediately.

var _fullscreen_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_background()
	_build_panel()

func _build_background() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/background.gdshader")
	background.material = material
	add_child(background)

func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	card.add_theme_stylebox_override("panel", NeonStyle.card())
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)

	var title := UiKit.label("SETTINGS", 38, GameConstants.TEXT_PRIMARY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	column.add_child(_slider_row(
		"Sound",
		float(SaveManager.get_value("audio", "sfx", 0.8)),
		func(value: float) -> void: AudioManager.set_sfx_volume(value)
	))
	column.add_child(_slider_row(
		"Music",
		float(SaveManager.get_value("audio", "music", 0.6)),
		func(value: float) -> void: AudioManager.set_music_volume(value)
	))

	_fullscreen_button = UiKit.button(_fullscreen_text(), GameConstants.ACCENT)
	_fullscreen_button.pressed.connect(_toggle_fullscreen)
	column.add_child(_fullscreen_button)

	var back := UiKit.button("BACK", Color("4e4a4e"))
	back.pressed.connect(_go_back)
	column.add_child(back)

func _slider_row(name: String, value: float, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := UiKit.label(name, 22, GameConstants.TEXT_MUTED)
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(new_value: float) -> void: on_change.call(new_value))
	row.add_child(slider)
	return row

func _toggle_fullscreen() -> void:
	var enabled := DisplayUtil.toggle_fullscreen()
	_fullscreen_button.text = _fullscreen_text()
	AudioManager.play("click", 0.9 if enabled else 1.1)

func _fullscreen_text() -> String:
	return "Full-screen: ON" if DisplayUtil.is_fullscreen() else "Full-screen: OFF"

func _go_back() -> void:
	AudioManager.play("click")
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
