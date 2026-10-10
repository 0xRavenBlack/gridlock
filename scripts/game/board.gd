class_name Board
extends Control
## Renders the 10x10 play field and converts between grid cells and screen
## space. It mirrors the rules' grid for drawing but makes no decisions.

const GRID := GameConstants.GRID_SIZE

var _cells: Array[BoardCell] = []
var _filled: Dictionary = {}
var _preview_cells: Array[Vector2i] = []
var _hint_pins: Array[Vector2i] = []
var _hint_glow: Panel
var _glow_tween: Tween
var _grid: GridContainer
var _cell_size := 40.0
var _pitch := 44.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_layout()

func cell(at: Vector2i) -> BoardCell:
	return _cells[at.y * GRID + at.x]

func is_inside(at: Vector2i) -> bool:
	return at.x >= 0 and at.x < GRID and at.y >= 0 and at.y < GRID

func cell_size() -> float:
	return _cell_size

func pitch() -> float:
	return _pitch

func set_filled(at: Vector2i, color: Color) -> void:
	if not is_inside(at):
		return
	_filled[at] = true
	cell(at).set_filled(color)

func set_empty(at: Vector2i) -> void:
	if not is_inside(at):
		return
	_filled.erase(at)
	cell(at).set_empty()

func reset() -> void:
	_filled.clear()
	_preview_cells.clear()
	clear_hints()
	for cell in _cells:
		cell.set_empty()

## Pins the single missing cell of every near-complete line and lights up the
## board frame so the player can plan the next clear at a glance.
func show_hints(pins: Array[Vector2i]) -> void:
	clear_hints()
	for at in pins:
		if is_inside(at) and not _filled.has(at):
			cell(at).set_hint_pin(true)
			_hint_pins.append(at)
	_set_hint_glow(not _hint_pins.is_empty())

func clear_hints() -> void:
	for at in _hint_pins:
		if is_inside(at):
			cell(at).set_hint_pin(false)
	_hint_pins.clear()
	_set_hint_glow(false)

func show_preview(cells: Array[Vector2i], valid: bool) -> void:
	clear_preview()
	for at in cells:
		if is_inside(at) and not _filled.has(at):
			cell(at).set_preview(valid)
			_preview_cells.append(at)

func clear_preview() -> void:
	for at in _preview_cells:
		if not _filled.has(at):
			cell(at).set_empty()
	_preview_cells.clear()

## Screen point -> grid cell (may be out of bounds; callers validate).
func world_to_grid(point: Vector2) -> Vector2i:
	var local: Vector2 = _grid.get_global_transform().affine_inverse() * point
	return Vector2i(floori(local.x / _pitch), floori(local.y / _pitch))

## Grid cell -> centre of that cell in screen space.
func grid_to_world(at: Vector2i) -> Vector2:
	var local := Vector2(at.x * _pitch + _cell_size * 0.5, at.y * _pitch + _cell_size * 0.5)
	return _grid.get_global_transform() * local

func _build() -> void:
	var backdrop := Panel.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_theme_stylebox_override("panel", NeonStyle.board_panel())
	add_child(backdrop)

	_hint_glow = Panel.new()
	_hint_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hint_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_glow.modulate = Color(1, 1, 1, 0)
	_hint_glow.add_theme_stylebox_override("panel", NeonStyle.hint_glow())
	add_child(_hint_glow)

	_grid = GridContainer.new()
	_grid.columns = GRID
	_grid.add_theme_constant_override("h_separation", int(GameConstants.CELL_GAP))
	_grid.add_theme_constant_override("v_separation", int(GameConstants.CELL_GAP))
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	for _i in GRID * GRID:
		var cell := BoardCell.new()
		_cells.append(cell)
		_grid.add_child(cell)

func _layout() -> void:
	var available := size - Vector2.ONE * GameConstants.BOARD_PADDING * 2.0
	_pitch = floor(minf(available.x, available.y) / GRID)
	_cell_size = maxf(_pitch - GameConstants.CELL_GAP, 1.0)
	for cell in _cells:
		cell.custom_minimum_size = Vector2.ONE * _cell_size
	var grid_size := Vector2.ONE * (_pitch * GRID - GameConstants.CELL_GAP)
	_grid.size = grid_size
	_grid.position = (size - grid_size) * 0.5

func _set_hint_glow(active: bool) -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
		_glow_tween = null
	if not active:
		_hint_glow.modulate = Color(1, 1, 1, 0)
		return
	_hint_glow.modulate = Color(1, 1, 1, 0.5)
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_hint_glow, "modulate:a", 0.85, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_glow_tween.tween_property(_hint_glow, "modulate:a", 0.35, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
