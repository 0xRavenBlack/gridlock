extends Node
## Integration smoke test: loads the real game scene and drives one full drag
## (grab -> move -> snap -> release) to prove the rendering, input plumbing and
## rules are actually connected. Runs headless and exits non-zero on failure.

var _failed := 0

func _ready() -> void:
	print("\n" + "=".repeat(68))
	print("  GRIDLOCK - Drag Integration Smoke Test")
	print("=".repeat(68))
	await _run()
	print("\n" + "=".repeat(68))
	print("  " + ("SMOKE TEST PASSED!" if _failed == 0 else "SMOKE TEST FAILED!"))
	print("=".repeat(68) + "\n")
	get_tree().quit(0 if _failed == 0 else 1)

func _run() -> void:
	var scene := load("res://scenes/game.tscn") as PackedScene
	var game: Node = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	var board: Board = game._board
	var tray: Tray = game._tray
	_check(tray.views().size() == GameConstants.PIECES_PER_TRAY, "tray shows three pieces")
	_check(board.pitch() > 0.0, "board laid out with a positive cell pitch")

	var board_rect := board.get_global_rect()
	var tray_rect := tray.get_global_rect()
	var screen_width: float = get_viewport().get_visible_rect().size.x
	_check(board_rect.size.x > 300.0 and board_rect.size.y > 300.0, "board is a reasonable size")
	_check(board_rect.end.y <= tray_rect.position.y + 1.0, "board sits above the tray")
	for piece_view in tray.views():
		var rect := piece_view.get_global_rect()
		_check(rect.size.x > 0.0 and rect.size.y > 0.0, "tray piece is hit-testable")
		_check(rect.position.x >= -1.0 and rect.end.x <= screen_width + 1.0, "tray piece stays within the screen width")

	var view: PieceView = tray.views()[0]
	var piece := view.piece
	var target := _first_valid_origin(piece)
	_check(target != GameConstants.NO_CELL, "tray piece has a legal placement")

	var grab_point := view.get_global_rect().get_center()
	game._try_grab(grab_point)
	_check(game._dragging != null, "grabbing a tray piece by its rect starts a drag")
	_check(game._ghost != null, "drag ghost created")

	var drop_point := board.grid_to_world(target + game._grab_cell)
	await game._release(drop_point)

	var filled := true
	for cell in piece.cells:
		if not board.cell(target + cell).is_filled():
			filled = false
	_check(filled, "placed tile is drawn on the board")
	_check(Game.rules.is_filled(target + piece.cells[0]), "rules recorded the placement")
	_check(tray.views().size() == GameConstants.PIECES_PER_TRAY - 1, "used piece left the tray")
	_check(Game.rules.clearing_candidates() is Array, "rules expose near-complete line hints")
	game._refresh_hints()
	_check(game._board._hint_pins.size() == Game.rules.clearing_candidates().size(), "board pins refresh from the rules")

	game._show_pause()
	_check(game._overlay_open and get_tree().paused, "pause overlay opens and pauses time")
	game._resume()
	_check(not get_tree().paused, "resume clears the pause")

	game._show_game_over()
	_check(game._overlay_open, "game over overlay builds")
	game._on_overlay_action("restart")
	_check(not game._overlay_open, "restart closes the overlay")
	_check(int(Game.stats.get("games_started", 0)) >= 1, "games played tracked across restarts")

	game.queue_free()
	await get_tree().process_frame

func _first_valid_origin(piece: Piece) -> Vector2i:
	for x in range(GameConstants.GRID_SIZE):
		for y in range(GameConstants.GRID_SIZE):
			if Game.rules.is_valid(piece, Vector2i(x, y)):
				return Vector2i(x, y)
	return GameConstants.NO_CELL

func _check(condition: bool, message: String) -> void:
	if condition:
		print("    PASS  %s" % message)
	else:
		_failed += 1
		print("    FAIL  %s" % message)
