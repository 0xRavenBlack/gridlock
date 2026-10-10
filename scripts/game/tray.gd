class_name Tray
extends HBoxContainer
## Holds the three draggable piece views. It only builds/replaces views; the
## game controller resolves what a drag means.

const SLOTS := GameConstants.PIECES_PER_TRAY

var _views: Array[PieceView] = []

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in SLOTS:
		var slot := CenterContainer.new()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(slot)

func set_pieces(pieces: Array) -> void:
	_clear_views()
	for index in range(mini(pieces.size(), SLOTS)):
		var view := PieceView.new()
		view.build(pieces[index], GameConstants.TRAY_CELL_SIZE, GameConstants.TRAY_CELL_GAP)
		var slot := get_child(index) as CenterContainer
		slot.add_child(view)
		_views.append(view)

func views() -> Array[PieceView]:
	return _views

func _clear_views() -> void:
	for slot in get_children():
		for child in slot.get_children():
			child.queue_free()
	_views.clear()
