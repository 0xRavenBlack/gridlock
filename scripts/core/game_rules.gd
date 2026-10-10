class_name GameRules
extends RefCounted
## The authoritative GRIDLOCK rules. This is pure logic: it owns the grid, the
## piece tray, scoring and game-over detection, and knows nothing about nodes,
## input or rendering.
##
## Emits signals so presentation layers can react without polling:
##   score_changed, streak_changed, tray_changed, placement_resolved.

signal score_changed(score: int)
signal streak_changed(streak: int)
signal tray_changed(tray: Array)
signal placement_resolved(result: Dictionary)

const GRID_SIZE := GameConstants.GRID_SIZE

var grid: Array = []
var tray: Array = []
var score: int = 0
var streak: int = 0
var best_streak: int = 0
var is_over: bool = false
var total_lines_cleared: int = 0
var total_blocks_placed: int = 0

var _bag: PieceBag

func _init(rng: RandomNumberGenerator = null) -> void:
	_bag = PieceBag.new(rng)
	_clear_grid()

## Resets every stat and deals a fresh tray.
func new_game() -> void:
	score = 0
	streak = 0
	best_streak = 0
	is_over = false
	total_lines_cleared = 0
	total_blocks_placed = 0
	_clear_grid()
	tray.clear()
	_refill_tray()
	score_changed.emit(score)
	streak_changed.emit(streak)
	tray_changed.emit(tray.duplicate())

func is_filled(at: Vector2i) -> bool:
	return grid[at.x][at.y]

## True when the piece fits entirely on empty in-bounds cells.
func is_valid(piece: Piece, origin: Vector2i) -> bool:
	for cell in piece.cells:
		var at: Vector2i = origin + cell
		if not _in_bounds(at) or grid[at.x][at.y]:
			return false
	return true

## Places a piece, resolves clears and scoring, then reports the outcome.
## Returns a Dictionary describing what happened (see _build_result).
func place(piece: Piece, origin: Vector2i) -> Dictionary:
	if not is_valid(piece, origin):
		return {"ok": false}

	var placed := piece.shifted(origin)
	for at in placed:
		grid[at.x][at.y] = true
	total_blocks_placed += 1

	var lines := _completed_lines()
	var cleared := _cells_in_lines(lines)
	for at in cleared:
		grid[at.x][at.y] = false
	total_lines_cleared += lines.size()

	var streak_before := streak
	streak = streak + 1 if not lines.is_empty() else 0
	best_streak = maxi(best_streak, streak)
	var points := _award_points(lines.size())

	tray.erase(piece)
	if tray.is_empty():
		_refill_tray()

	is_over = not has_any_move()

	if streak != streak_before:
		streak_changed.emit(streak)
	tray_changed.emit(tray.duplicate())

	var result := _build_result(piece, origin, placed, lines, cleared, points)
	placement_resolved.emit(result)
	return result

## True when at least one tray piece can still be placed somewhere.
func has_any_move() -> bool:
	for piece in tray:
		if can_place_anywhere(piece):
			return true
	return false

func can_place_anywhere(piece: Piece) -> bool:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if is_valid(piece, Vector2i(x, y)):
				return true
	return false

## All complete rows/columns, each as { "type": "row"/"column", "index": int }.
func completed_lines() -> Array:
	return _completed_lines()

## Rows/columns exactly one cell short of clearing. Each entry carries the
## coordinates of the single missing cell so the UI can pin it for the player.
## Returns e.g. { "type": "row", "index": 3, "missing": Vector2i(7, 3) }.
func clearing_candidates() -> Array:
	var candidates: Array = []
	for x in range(GRID_SIZE):
		var miss := _column_missing_cell(x)
		if miss != GameConstants.NO_CELL:
			candidates.append({"type": "column", "index": x, "missing": miss})
	for y in range(GRID_SIZE):
		var miss := _row_missing_cell(y)
		if miss != GameConstants.NO_CELL:
			candidates.append({"type": "row", "index": y, "missing": miss})
	return candidates

func _row_missing_cell(y: int) -> Vector2i:
	var empty := Vector2i(-1, -1)
	for x in range(GRID_SIZE):
		if not grid[x][y]:
			if empty.x != -1:
				return GameConstants.NO_CELL
			empty = Vector2i(x, y)
	return empty if empty.x != -1 else GameConstants.NO_CELL

func _column_missing_cell(x: int) -> Vector2i:
	var empty := Vector2i(-1, -1)
	for y in range(GRID_SIZE):
		if not grid[x][y]:
			if empty.y != -1:
				return GameConstants.NO_CELL
			empty = Vector2i(x, y)
	return empty if empty.y != -1 else GameConstants.NO_CELL

func _award_points(line_count: int) -> int:
	if line_count == 0:
		return 0
	var base := float(line_count * GameConstants.POINTS_PER_LINE)
	var multiline := 1.0 + float(line_count - 1) * GameConstants.MULTILINE_BONUS
	var streak_multiplier := 1.0 + float(streak - 1) * GameConstants.STREAK_BONUS
	var gained := int(round(base * multiline * streak_multiplier))
	score += gained
	score_changed.emit(score)
	return gained

func _completed_lines() -> Array:
	var lines: Array = []
	for x in range(GRID_SIZE):
		if _is_column_full(x):
			lines.append({"type": "column", "index": x})
	for y in range(GRID_SIZE):
		if _is_row_full(y):
			lines.append({"type": "row", "index": y})
	return lines

func _is_row_full(y: int) -> bool:
	for x in range(GRID_SIZE):
		if not grid[x][y]:
			return false
	return true

func _is_column_full(x: int) -> bool:
	for y in range(GRID_SIZE):
		if not grid[x][y]:
			return false
	return true

func _cells_in_lines(lines: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for line in lines:
		if line["type"] == "row":
			for x in range(GRID_SIZE):
				cells.append(Vector2i(x, line["index"]))
		else:
			for y in range(GRID_SIZE):
				cells.append(Vector2i(line["index"], y))
	return cells

func _refill_tray() -> void:
	for _i in range(GameConstants.PIECES_PER_TRAY):
		tray.append(_bag.next())

func _clear_grid() -> void:
	grid = []
	for x in range(GRID_SIZE):
		var column: Array = []
		for y in range(GRID_SIZE):
			column.append(false)
		grid.append(column)

func _in_bounds(at: Vector2i) -> bool:
	return at.x >= 0 and at.x < GRID_SIZE and at.y >= 0 and at.y < GRID_SIZE

func _build_result(piece: Piece, origin: Vector2i, placed: Array[Vector2i],
		lines: Array, cleared: Array[Vector2i], points: int) -> Dictionary:
	return {
		"ok": true,
		"piece": piece,
		"origin": origin,
		"placed_cells": placed,
		"cleared_lines": lines,
		"cleared_cells": cleared,
		"points": points,
		"streak": streak,
		"game_over": is_over,
	}
