extends Control
## Main menu: animated title, floating blocks and navigation to play/settings.

const BLOCK_COUNT := 16

var _high_score_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DisplayUtil.apply_saved()
	_build_background()
	_build_decorative_blocks()
	_build_foreground()

func _build_background() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/background.gdshader")
	background.material = material
	add_child(background)

func _build_decorative_blocks() -> void:
	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	var colors := [
		Color("2be0e0"), Color("a25bff"), Color("ff5fa2"),
		Color("3be08b"), Color("ff9f2b"), Color("ffd23f"),
	]
	for i in range(BLOCK_COUNT):
		var size := randf_range(22.0, 58.0)
		var block := Panel.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.size = Vector2(size, size)
		block.pivot_offset = Vector2(size, size) * 0.5
		block.add_theme_stylebox_override("panel", NeonStyle.tile(colors[i % colors.size()]))
		block.set_meta("drift", randf_range(18.0, 60.0))
		layer.add_child(block)
		block.position = Vector2(randf_range(0.0, 540.0), randf_range(0.0, 960.0))
		_drift(block)

func _drift(block: Panel) -> void:
	var distance: float = block.get_meta("drift")
	block.modulate.a = randf_range(0.35, 0.8)
	var sway := randf_range(-0.35, 0.35)
	var tween := create_tween().set_loops()
	tween.tween_property(block, "position:y", block.position.y - distance, randf_range(2.5, 4.5)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(block, "rotation", sway, randf_range(2.0, 3.0)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(block, "position:y", block.position.y, randf_range(2.5, 4.5)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(block, "rotation", -sway, randf_range(2.0, 3.0)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _build_foreground() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)

	var title := UiKit.label("GRIDLOCK", 86, GameConstants.ACCENT_HOT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color("ff5fa2", 0.45))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 14)
	_pulse(title)
	column.add_child(title)

	var subtitle := UiKit.label("CHAIN THE LIGHTS", 22, GameConstants.PREVIEW_VALID)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)

	var tagline := UiKit.label("A NEON BLOCK PUZZLE", 14, GameConstants.TEXT_MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	_high_score_label = UiKit.label("BEST %d" % Game.best_score, 28, GameConstants.ACCENT)
	_high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_high_score_label)

	column.add_child(_gap(24))

	var play := UiKit.button("PLAY", GameConstants.ACCENT_HOT)
	play.custom_minimum_size = Vector2(280, 72)
	play.add_theme_font_size_override("font_size", 32)
	play.pressed.connect(_on_play)
	column.add_child(play)

	var settings := UiKit.button("SETTINGS", GameConstants.ACCENT)
	settings.custom_minimum_size = Vector2(280, 60)
	settings.pressed.connect(_on_settings)
	column.add_child(settings)

	var quit := UiKit.button("QUIT", Color("4e4a4e"))
	quit.custom_minimum_size = Vector2(280, 52)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)

	play.grab_focus()

func _pulse(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	node.resized.connect(func() -> void: node.pivot_offset = node.size * 0.5)
	var tween := create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2(1.04, 1.04), 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer

func _on_play() -> void:
	AudioManager.play("click")
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_settings() -> void:
	AudioManager.play("click")
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")
