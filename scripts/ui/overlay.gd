class_name Overlay
extends Control
## Reusable modal: a dim layer plus a centred card with a title, stat rows and
## a stack of buttons. Emits action(id) when a button is pressed.

signal action(id: String)

var _title: Label
var _rows: VBoxContainer
var _buttons: VBoxContainer
var _card: PanelContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func open(title: String) -> void:
	_title.text = title
	_clear(_rows)
	_clear(_buttons)
	visible = true
	_animate_in()

func add_stat(name: String, value: String) -> void:
	var row := HBoxContainer.new()
	var left := UiKit.label(name, 22, GameConstants.TEXT_MUTED)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := UiKit.label(value, 30, GameConstants.TEXT_PRIMARY)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(left)
	row.add_child(right)
	_rows.add_child(row)

func add_button(text: String, id: String, fill: Color = GameConstants.ACCENT) -> void:
	var button := UiKit.button(text, fill)
	button.pressed.connect(func() -> void: action.emit(id))
	_buttons.add_child(button)

func add_note(text: String, color: Color) -> void:
	var note := UiKit.label(text, 24, color)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_child(note)

func close() -> void:
	visible = false

func _build() -> void:
	var dim := Panel.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_theme_stylebox_override("panel", NeonStyle.dim())
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(360, 0)
	_card.add_theme_stylebox_override("panel", NeonStyle.card())
	center.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	_card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)

	_title = UiKit.label("", 40, GameConstants.TEXT_PRIMARY)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	column.add_child(_rows)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 12)
	column.add_child(_buttons)

func _animate_in() -> void:
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.7, 0.7)
	_card.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "modulate:a", 1.0, 0.2)

func _clear(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()
