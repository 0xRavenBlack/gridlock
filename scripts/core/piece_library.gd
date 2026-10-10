class_name PieceLibrary
extends RefCounted
## Canonical catalogue of GRIDLOCK shapes, their draw weights and stable colours.
## Shapes are written as (column, row) offsets and normalised on demand, so the
## definition can be written in the most readable orientation.

const SHAPES: Dictionary = {
	"dot": [[0, 0]],

	"line2h": [[0, 0], [1, 0]],
	"line3h": [[0, 0], [1, 0], [2, 0]],
	"line4h": [[0, 0], [1, 0], [2, 0], [3, 0]],
	"line5h": [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]],
	"line2v": [[0, 0], [0, 1]],
	"line3v": [[0, 0], [0, 1], [0, 2]],
	"line4v": [[0, 0], [0, 1], [0, 2], [0, 3]],
	"line5v": [[0, 0], [0, 1], [0, 2], [0, 3], [0, 4]],

	"square2": [[0, 0], [1, 0], [0, 1], [1, 1]],
	"square3": [
		[0, 0], [1, 0], [2, 0],
		[0, 1], [1, 1], [2, 1],
		[0, 2], [1, 2], [2, 2],
	],
	"rect2x3": [[0, 0], [1, 0], [0, 1], [1, 1], [0, 2], [1, 2]],
	"rect3x2": [[0, 0], [1, 0], [2, 0], [0, 1], [1, 1], [2, 1]],

	"corner_a": [[0, 0], [1, 0], [0, 1]],
	"corner_b": [[1, 0], [1, 1], [0, 1]],
	"corner_c": [[0, 0], [1, 0], [1, 1]],
	"corner_d": [[0, 0], [0, 1], [1, 1]],

	"ell_small_a": [[0, 0], [0, 1], [0, 2], [1, 2]],
	"ell_small_b": [[0, 0], [1, 0], [2, 0], [2, 1]],
	"ell_small_c": [[0, 0], [1, 0], [1, 1], [1, 2]],
	"ell_small_d": [[0, 0], [0, 1], [1, 0], [2, 0]],

	"ell_big_a": [[0, 0], [0, 1], [0, 2], [0, 3], [1, 3]],
	"ell_big_b": [[0, 0], [1, 0], [2, 0], [3, 0], [3, 1]],
	"ell_big_c": [[0, 0], [1, 0], [1, 1], [1, 2], [1, 3]],
	"ell_big_d": [[0, 0], [0, 1], [1, 1], [2, 1], [3, 1]],
}

## How many copies of each shape enter the shuffle bag (integer weights).
const WEIGHTS: Dictionary = {
	"dot": 1,
	"line2h": 3, "line2v": 3,
	"line3h": 2, "line3v": 2,
	"line4h": 1, "line4v": 1,
	"line5h": 1, "line5v": 1,
	"square2": 2, "square3": 1,
	"rect2x3": 2, "rect3x2": 2,
	"corner_a": 3, "corner_b": 3, "corner_c": 3, "corner_d": 3,
	"ell_small_a": 2, "ell_small_b": 2, "ell_small_c": 2, "ell_small_d": 2,
	"ell_big_a": 1, "ell_big_b": 1, "ell_big_c": 1, "ell_big_d": 1,
}

const _COLOR_LINES := "2be0e0"
const _COLOR_SQUARES := "a25bff"
const _COLOR_RECTS := "3be08b"
const _COLOR_CORNERS := "ff9f2b"
const _COLOR_ELL_SMALL := "ffd23f"
const _COLOR_ELL_BIG := "ff3b5c"
const _COLOR_DOT := "4c7dff"

static func ids() -> Array:
	return SHAPES.keys()

static func weight(id: String) -> int:
	return int(WEIGHTS.get(id, 1))

## Builds a runtime Piece from its catalogue id.
static func create(id: String) -> Piece:
	var raw: Array = SHAPES[id]
	var cells := _normalise(raw)
	return Piece.new(id, cells, color_for(id))

static func color_for(id: String) -> Color:
	var hex := _COLOR_DOT
	if id.begins_with("line"):
		hex = _COLOR_LINES
	elif id.begins_with("square"):
		hex = _COLOR_SQUARES
	elif id.begins_with("rect"):
		hex = _COLOR_RECTS
	elif id.begins_with("corner"):
		hex = _COLOR_CORNERS
	elif id.begins_with("ell_big"):
		hex = _COLOR_ELL_BIG
	elif id.begins_with("ell_small"):
		hex = _COLOR_ELL_SMALL
	return Color(hex)

## Shifts a shape so its smallest column/row become zero.
static func _normalise(raw: Array) -> Array[Vector2i]:
	var min_col := 0
	var min_row := 0
	for offset in raw:
		min_col = mini(min_col, int(offset[0]))
		min_row = mini(min_row, int(offset[1]))
	var cells: Array[Vector2i] = []
	for offset in raw:
		cells.append(Vector2i(int(offset[0]) - min_col, int(offset[1]) - min_row))
	return cells
