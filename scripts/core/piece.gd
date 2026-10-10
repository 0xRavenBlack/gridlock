class_name Piece
extends RefCounted
## A single GRIDLOCK piece: its identity, colour and normalised cell offsets.
## Cell offsets are always >= (0, 0) with the shape's minimum at the origin.

var id: String
var cells: Array[Vector2i]
var color: Color

func _init(piece_id: String, piece_cells: Array[Vector2i], piece_color: Color) -> void:
	id = piece_id
	cells = piece_cells
	color = piece_color

func size() -> Vector2i:
	var extent := Vector2i.ZERO
	for cell in cells:
		extent.x = maxi(extent.x, cell.x)
		extent.y = maxi(extent.y, cell.y)
	return extent + Vector2i.ONE

func cell_count() -> int:
	return cells.size()

func has_cell(target: Vector2i) -> bool:
	return cells.has(target)

## Returns the piece's cells translated by an origin offset.
func shifted(offset: Vector2i) -> Array[Vector2i]:
	var moved: Array[Vector2i] = []
	for cell in cells:
		moved.append(cell + offset)
	return moved
