class_name PieceView
extends Control
## Draws a piece as a small grid of glossy tiles and maps points inside it to
## piece cells. Used both by the tray and, enlarged, as the drag ghost.

var piece: Piece
var _cell_size := 24.0
var _gap := 3.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func build(for_piece: Piece, cell_size: float, gap: float) -> void:
	piece = for_piece
	_cell_size = cell_size
	_gap = gap
	for child in get_children():
		child.queue_free()
	var extent := piece.size()
	var total := Vector2(extent.x * pitch() - _gap, extent.y * pitch() - _gap)
	for offset in piece.cells:
		var tile := Panel.new()
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_theme_stylebox_override("panel", NeonStyle.tile(piece.color))
		tile.size = Vector2.ONE * _cell_size
		tile.position = Vector2(offset.x * pitch(), offset.y * pitch())
		add_child(tile)
	custom_minimum_size = total
	size = total

func pitch() -> float:
	return _cell_size + _gap

## Local centre of one of the piece's cells.
func cell_local_center(at: Vector2i) -> Vector2:
	return Vector2(at.x * pitch() + _cell_size * 0.5, at.y * pitch() + _cell_size * 0.5)

## The piece cell the given screen point is closest to.
func cell_at(point: Vector2) -> Vector2i:
	var local := get_global_transform().affine_inverse() * point
	var guess := Vector2i(floori(local.x / pitch()), floori(local.y / pitch()))
	if piece.has_cell(guess):
		return guess
	var best := piece.cells[0]
	var best_distance := INF
	for candidate in piece.cells:
		var distance := cell_local_center(candidate).distance_to(local)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
