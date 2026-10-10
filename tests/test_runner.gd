extends Node
## Headless test runner for the pure GameRules logic. Exits non-zero when any
## check fails so run_tests.sh reports the result correctly.

var _passed := 0
var _failed := 0

func _ready() -> void:
	print("\n" + "=".repeat(68))
	print("  GRIDLOCK - Rules Test Suite")
	print("=".repeat(68))
	_test_piece_library()
	_test_placement()
	_test_line_clearing()
	_test_scoring_and_streaks()
	_test_hints()
	_test_tray()
	_test_game_over()
	_test_best_streak()
	print("\n" + "=".repeat(68))
	print("  %d passed / %d total" % [_passed, _passed + _failed])
	print("  " + ("ALL TESTS PASSED!" if _failed == 0 else "SOME TESTS FAILED!"))
	print("=".repeat(68) + "\n")
	get_tree().quit(0 if _failed == 0 else 1)

func _test_piece_library() -> void:
	_begin("Piece Library")
	for id in PieceLibrary.ids():
		var piece := PieceLibrary.create(id)
		var min_x := 999
		var min_y := 999
		for cell in piece.cells:
			min_x = mini(min_x, cell.x)
			min_y = mini(min_y, cell.y)
		_check(min_x == 0 and min_y == 0, "%s is normalised to the origin" % id)
		_check(piece.cell_count() > 0, "%s has at least one cell" % id)
	_check(PieceLibrary.weight("dot") >= 1, "dot has a positive weight")

func _test_placement() -> void:
	_begin("Placement")
	var rules := _fresh()
	_check(rules.grid.size() == 10, "grid has 10 columns")
	_check(rules.grid[0].size() == 10, "grid has 10 rows")
	_check(rules.is_valid(PieceLibrary.create("line3h"), Vector2i(0, 0)), "line fits at the origin")
	_check(not rules.is_valid(PieceLibrary.create("line3h"), Vector2i(8, 0)), "line rejected past the right edge")
	_check(not rules.is_valid(PieceLibrary.create("line3h"), Vector2i(-1, 0)), "line rejected past the left edge")
	var dot := PieceLibrary.create("dot")
	rules.place(dot, Vector2i(2, 3))
	_check(rules.is_filled(Vector2i(2, 3)), "a placed dot fills its cell")
	_check(not rules.is_valid(dot, Vector2i(2, 3)), "a filled cell blocks placement")

func _test_line_clearing() -> void:
	_begin("Line Clearing")
	var rows := _fresh()
	_fill_row_except(rows, 4, 9)
	_check(rows.completed_lines().size() == 0, "a row with a gap is not complete")
	rows.place(PieceLibrary.create("dot"), Vector2i(9, 4))
	_check(rows.completed_lines().size() == 0, "a completed row is cleared at once")
	for x in range(10):
		_check(not rows.is_filled(Vector2i(x, 4)), "cell (%d, 4) was emptied" % x)

	var columns := _fresh()
	_fill_column_except(columns, 6, 9)
	columns.place(PieceLibrary.create("dot"), Vector2i(6, 9))
	for y in range(10):
		_check(not columns.is_filled(Vector2i(6, y)), "cell (6, %d) was emptied" % y)

func _test_scoring_and_streaks() -> void:
	_begin("Scoring and Streaks")
	var single := _fresh()
	_fill_row_except(single, 0, 9)
	single.place(PieceLibrary.create("dot"), Vector2i(9, 0))
	_check(single.score == GameConstants.POINTS_PER_LINE, "one line scores 100")
	_check(single.streak == 1, "the streak starts at 1 after a clear")

	var double := _fresh()
	_fill_row_except(double, 0, 9)
	_fill_row_except(double, 1, 9)
	double.place(PieceLibrary.create("line2v"), Vector2i(9, 0))
	var expected_double := int(round(GameConstants.POINTS_PER_LINE * 2 * 1.5))
	_check(double.score == expected_double, "two lines score 300 with the multi-line bonus")

	var combo := _fresh()
	_fill_row_except(combo, 0, 9)
	combo.place(PieceLibrary.create("dot"), Vector2i(9, 0))
	_fill_row_except(combo, 1, 9)
	combo.place(PieceLibrary.create("dot"), Vector2i(9, 1))
	_check(combo.streak == 2, "the streak grows on a consecutive clear")
	var expected_combo := GameConstants.POINTS_PER_LINE + int(round(GameConstants.POINTS_PER_LINE * 1.25))
	_check(combo.score == expected_combo, "the second clear earns the streak bonus")

	var reset := _fresh()
	_fill_row_except(reset, 0, 9)
	reset.place(PieceLibrary.create("dot"), Vector2i(9, 0))
	reset.place(PieceLibrary.create("dot"), Vector2i(0, 2))
	_check(reset.streak == 0, "a non-clearing move resets the streak")

func _test_best_streak() -> void:
	_begin("Best Streak")
	var rules := _fresh()
	_check(rules.best_streak == 0, "best streak starts at zero")
	_fill_row_except(rules, 0, 9)
	rules.place(PieceLibrary.create("dot"), Vector2i(9, 0))
	_check(rules.best_streak == 1, "one clear records a best streak of 1")
	_fill_row_except(rules, 1, 9)
	rules.place(PieceLibrary.create("dot"), Vector2i(9, 1))
	_check(rules.best_streak == 2, "a consecutive clear grows the best streak")
	rules.place(PieceLibrary.create("dot"), Vector2i(0, 4))
	_check(rules.streak == 0 and rules.best_streak == 2, "best streak survives a reset")

func _test_hints() -> void:
	_begin("Near-Complete Hints")
	var empty := _fresh()
	empty.new_game()
	_check(empty.clearing_candidates().is_empty(), "an empty grid has no near-complete lines")

	var single := _fresh()
	_fill_row_except(single, 2, 5)
	var candidates := single.clearing_candidates()
	_check(candidates.size() == 1, "a one-cell row gap reports one candidate")
	if candidates.size() == 1:
		_check(candidates[0]["type"] == "row" and candidates[0]["index"] == 2, "the candidate names the row")
		_check(candidates[0]["missing"] == Vector2i(5, 2), "the candidate pins the missing cell")

	var mixed := _fresh()
	_fill_row_except(mixed, 2, 5)
	_fill_column_except(mixed, 7, 3)
	var types: Array = []
	for entry in mixed.clearing_candidates():
		types.append(entry["type"])
	_check(types.has("row") and types.has("column"), "row and column gaps both report candidates")

	var rows := _fresh()
	_fill_row_except(rows, 2, 5)
	_fill_row_except(rows, 6, 4)
	_check(rows.clearing_candidates().size() == 2, "two near-complete rows both report candidates")
	rows.place(PieceLibrary.create("dot"), Vector2i(5, 2))
	_check(rows.clearing_candidates().size() == 1, "completing a row removes its candidate")

	var two_gaps := _fresh()
	for x in range(10):
		if x != 3 and x != 8:
			two_gaps.grid[x][4] = true
	_check(two_gaps.clearing_candidates().is_empty(), "a row with two gaps has no candidate")

func _test_tray() -> void:
	_begin("Tray")
	var rules := _fresh()
	rules.new_game()
	_check(rules.tray.size() == GameConstants.PIECES_PER_TRAY, "a new game deals three pieces")
	rules.tray = _dots(3)
	rules.place(rules.tray[0], Vector2i(0, 0))
	rules.place(rules.tray[0], Vector2i(1, 0))
	_check(rules.tray.size() == 1, "placed pieces leave the tray")
	rules.place(rules.tray[0], Vector2i(2, 0))
	_check(rules.tray.size() == GameConstants.PIECES_PER_TRAY, "an empty tray refills to three")

func _test_game_over() -> void:
	_begin("Game Over")
	var dot_case := _fresh()
	dot_case.tray = _dots(1)
	_fill_all_except(dot_case, Vector2i(5, 5))
	_check(dot_case.has_any_move(), "a single gap still allows a dot")
	_check(dot_case.can_place_anywhere(PieceLibrary.create("line2h")) == false, "a line needs two adjacent cells")

	var blocked := _fresh()
	blocked.tray = [PieceLibrary.create("line2h")]
	_fill_checkerboard(blocked)
	_check(not blocked.has_any_move(), "a checkerboard blocks every line piece")

	var placed := _fresh()
	placed.tray = _dots(1)
	placed.place(PieceLibrary.create("dot"), Vector2i(3, 3))
	_check(placed.is_over == (not placed.has_any_move()), "is_over always mirrors has_any_move")

# ---------------------------------------------------------------------------
# Arrange helpers
# ---------------------------------------------------------------------------

func _fresh() -> GameRules:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261010
	return GameRules.new(rng)

func _dots(count: int) -> Array:
	var pieces: Array = []
	for _i in range(count):
		pieces.append(PieceLibrary.create("dot"))
	return pieces

func _fill_row_except(rules: GameRules, row: int, except_column: int) -> void:
	for x in range(10):
		if x != except_column:
			rules.grid[x][row] = true

func _fill_column_except(rules: GameRules, column: int, except_row: int) -> void:
	for y in range(10):
		if y != except_row:
			rules.grid[column][y] = true

func _fill_all_except(rules: GameRules, empty: Vector2i) -> void:
	for x in range(10):
		for y in range(10):
			rules.grid[x][y] = (x != empty.x or y != empty.y)

func _fill_checkerboard(rules: GameRules) -> void:
	for x in range(10):
		for y in range(10):
			rules.grid[x][y] = (x + y) % 2 == 0

# ---------------------------------------------------------------------------
# Assertions
# ---------------------------------------------------------------------------

func _begin(suite: String) -> void:
	print("\n  [%s]" % suite)

func _check(condition: bool, message: String) -> void:
	if condition:
		_passed += 1
		print("    PASS  %s" % message)
	else:
		_failed += 1
		print("    FAIL  %s" % message)
