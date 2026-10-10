extends Control
## Game scene controller. Builds the screen, turns drags into GameRules calls,
## and plays the resulting feedback. It holds no rules of its own.

const BOARD_SIZE := GameConstants.BOARD_SIZE
const SPAWN_DELAY := 0.45

var _content: Control
var _board: Board
var _tray: Tray
var _drag_layer: Control
var _fx_layer: Control

var _score_label: Label
var _best_label: Label
var _streak_label: Label

var _overlay: Overlay
var _overlay_open := false
var _paused := false
var _busy := false

var _dragging: Piece = null
var _dragging_view: PieceView = null
var _ghost: PieceView = null
var _grab_cell := Vector2i.ZERO
var _pending_origin := GameConstants.NO_CELL

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_background()
	_build_content()
	_build_layers()
	_build_overlay()
	_connect_signals()
	DisplayUtil.apply_saved()
	Game.start_new_game()
	_refresh_tray(Game.rules.tray)
	_refresh_hud()
	_refresh_hints()

# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build_background() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/background.gdshader")
	background.material = material
	add_child(background)

func _build_content() -> void:
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_build_hud()
	_build_board()
	_build_tray()

func _build_hud() -> void:
	var bar := Panel.new()
	bar.anchor_right = 1.0
	bar.offset_bottom = GameConstants.HUD_HEIGHT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", NeonStyle.hud_panel())
	_content.add_child(bar)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var score_box := VBoxContainer.new()
	score_box.add_theme_constant_override("separation", 0)
	_score_label = UiKit.label("0", 46, GameConstants.TEXT_PRIMARY)
	_best_label = UiKit.label("BEST 0   ·   LINES 0", 16, GameConstants.TEXT_MUTED)
	score_box.add_child(_score_label)
	score_box.add_child(_best_label)
	row.add_child(score_box)
	row.add_child(UiKit.spacer())

	_streak_label = UiKit.label("", 28, GameConstants.ACCENT_HOT)
	_streak_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_streak_label)
	row.add_child(UiKit.spacer())

	var pause := UiKit.button("II", GameConstants.ACCENT)
	pause.custom_minimum_size = Vector2(64, 56)
	pause.pressed.connect(_toggle_pause)
	row.add_child(pause)

func _build_board() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(center)
	_board = Board.new()
	_board.custom_minimum_size = Vector2(BOARD_SIZE, BOARD_SIZE)
	center.add_child(_board)

func _build_tray() -> void:
	var panel := Panel.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_top = -GameConstants.TRAY_HEIGHT
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", NeonStyle.tray_panel())
	_content.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	_tray = Tray.new()
	margin.add_child(_tray)

func _build_layers() -> void:
	_drag_layer = Control.new()
	_drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_drag_layer)

	_fx_layer = Control.new()
	_fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

func _build_overlay() -> void:
	_overlay = Overlay.new()
	add_child(_overlay)
	_overlay.action.connect(_on_overlay_action)

func _connect_signals() -> void:
	Game.rules.tray_changed.connect(_refresh_tray)
	Game.rules.score_changed.connect(func(_value: int) -> void: _refresh_hud())
	Game.rules.streak_changed.connect(func(_value: int) -> void: _refresh_hud())
	Game.best_score_changed.connect(func(_value: int) -> void: _refresh_hud())

# ---------------------------------------------------------------------------
# Input & dragging
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event.keycode)
		return
	if _busy or _overlay_open or Game.rules.is_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		if event.pressed:
			_try_grab(point)
		else:
			_release(point)
	elif event is InputEventMouseMotion and _dragging != null:
		_update_drag(get_global_mouse_position())

func _handle_key(keycode: int) -> void:
	if keycode == KEY_ESCAPE:
		_toggle_pause()
	elif keycode == KEY_F11:
		DisplayUtil.toggle_fullscreen()

func _try_grab(point: Vector2) -> void:
	for view in _tray.views():
		if view.get_global_rect().has_point(point):
			_begin_drag(view, point)
			return

func _begin_drag(view: PieceView, point: Vector2) -> void:
	AudioManager.play("pickup")
	_dragging = view.piece
	_dragging_view = view
	_grab_cell = view.cell_at(point)
	view.visible = false
	_ghost = PieceView.new()
	_ghost.build(_dragging, _board.cell_size(), GameConstants.CELL_GAP)
	_ghost.modulate = Color(1, 1, 1, 0.92)
	_drag_layer.add_child(_ghost)
	_update_drag(point)

func _update_drag(point: Vector2) -> void:
	if _ghost == null or _dragging == null:
		return
	_ghost.global_position = point - _ghost.cell_local_center(_grab_cell)
	var origin := _board.world_to_grid(point) - _grab_cell
	_board.clear_preview()
	var cells := _dragging.shifted(origin)
	var valid := Game.rules.is_valid(_dragging, origin)
	_board.show_preview(cells, valid)
	_pending_origin = origin if valid else GameConstants.NO_CELL

func _release(point: Vector2) -> void:
	if _dragging == null:
		return
	_update_drag(point)
	var piece := _dragging
	var origin := _pending_origin
	var view := _dragging_view
	_end_drag()

	if origin == GameConstants.NO_CELL:
		AudioManager.play("invalid")
		if view != null:
			view.visible = true
		return

	_busy = true
	AudioManager.play("place")
	var result := Game.resolve_placement(piece, origin)
	await _play_placement(result)
	_busy = false

func _end_drag() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = null
	_board.clear_preview()
	_dragging = null
	_dragging_view = null
	_pending_origin = GameConstants.NO_CELL

# ---------------------------------------------------------------------------
# Feedback
# ---------------------------------------------------------------------------

func _play_placement(result: Dictionary) -> void:
	var piece: Piece = result.piece
	var cleared_cells: Array = result.cleared_cells
	var cleared_lines: Array = result.cleared_lines
	for at in result.placed_cells:
		_board.set_filled(at, piece.color)
		_board.cell(at).animate_pop()
	_refresh_hud()

	if cleared_cells.is_empty():
		_refresh_hints()
		await _settle_game_over(result)
		return

	_play_clear_sound(cleared_lines.size(), result.streak)
	_float_score(result)
	_shake()
	if result.streak > 1:
		_show_combo(result.streak)
	if cleared_lines.size() >= 2:
		_show_multiline(cleared_lines.size())
	_spawn_beams(cleared_lines)
	for at in cleared_cells:
		_board.cell(at).set_flash()
		_spawn_sparks(at, piece.color)
	await get_tree().create_timer(GameConstants.CLEAR_FLASH_TIME).timeout
	for at in cleared_cells:
		_board.set_empty(at)
	await get_tree().create_timer(GameConstants.CLEAR_FADE_TIME).timeout
	_refresh_hints()
	await _settle_game_over(result)

## Clear sound scales with the size of the moment: multi-line megas and rising
## streak pitches make a big clear audibly bigger than a single line.
func _play_clear_sound(line_count: int, streak: int) -> void:
	if line_count >= 3:
		AudioManager.play("mega")
		return
	if line_count == 2:
		AudioManager.play("clear", 1.18)
		return
	if streak > 1:
		AudioManager.play("combo", 1.0 + 0.08 * maxi(streak - 1, 0))
	else:
		AudioManager.play("clear")

func _show_multiline(line_count: int) -> void:
	var tier := mini(line_count, 4) - 1
	var banner := UiKit.label(
		GameConstants.BANNERS[tier],
		GameConstants.BANNER_FONT,
		GameConstants.BANNER_COLORS[tier])
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(_content.size.x, 70)
	_fx_layer.add_child(banner)
	banner.position = Vector2(0, _content.size.y * 0.42)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(banner, "scale", Vector2(1.05, 1.05), 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(banner, "modulate:a", 0.0, 0.55).set_delay(0.45)
	tween.tween_callback(banner.queue_free)

## A light beam sweeps across each cleared line before the tiles vanish.
func _spawn_beams(lines: Array) -> void:
	for line in lines:
		_spawn_beam(line)

func _spawn_beam(line: Dictionary) -> void:
	var tint := GameConstants.PREVIEW_VALID.lightened(0.35) \
		if line["index"] % 2 == 0 else GameConstants.ACCENT_HOT.lightened(0.25)
	var beam := Panel.new()
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beam.add_theme_stylebox_override("panel", NeonStyle.beam(tint))
	_fx_layer.add_child(beam)

	var cell := _board.cell_size()
	var is_row: bool = line["type"] == "row"
	var edge_a := _board.grid_to_world(Vector2i(0, line["index"])) if is_row \
		else _board.grid_to_world(Vector2i(line["index"], 0))
	var edge_b := _board.grid_to_world(Vector2i(GameConstants.GRID_SIZE - 1, line["index"])) if is_row \
		else _board.grid_to_world(Vector2i(line["index"], GameConstants.GRID_SIZE - 1))
	var length := edge_b.distance_to(edge_a) + cell * 0.6
	var thickness := cell * 0.5
	if is_row:
		beam.size = Vector2(length, thickness)
		beam.position = Vector2(edge_a.x - cell * 0.3, edge_a.y - thickness * 0.5)
		beam.pivot_offset = Vector2(0, thickness * 0.5)
		beam.scale = Vector2(0.12, 1.0)
	else:
		beam.size = Vector2(thickness, length)
		beam.position = Vector2(edge_a.x - thickness * 0.5, edge_a.y - cell * 0.3)
		beam.pivot_offset = Vector2(thickness * 0.5, 0)
		beam.scale = Vector2(1.0, 0.12)

	beam.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(beam, "scale", Vector2.ONE, GameConstants.BEAM_TIME * 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(beam, "modulate:a", 0.95, 0.05)
	tween.tween_property(beam, "modulate:a", 0.0, 0.28).set_delay(0.1)
	tween.chain().tween_callback(beam.queue_free)

func _settle_game_over(result: Dictionary) -> void:
	if not result.game_over:
		return
	Game.submit_final_score()
	Game.commit_stats()
	AudioManager.play("new_best" if Game.is_new_best() else "game_over")
	await get_tree().create_timer(SPAWN_DELAY).timeout
	_show_game_over()

func _float_score(result: Dictionary) -> void:
	var center := _cleared_center(result.cleared_cells)
	var label := UiKit.label("+%d" % result.points, 42, GameConstants.ACCENT_HOT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(220, 50)
	_fx_layer.add_child(label)
	label.global_position = center - Vector2(110, 40)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 70, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

func _show_combo(streak: int) -> void:
	var banner := UiKit.label("COMBO x%d" % streak, 54, GameConstants.ACCENT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(_content.size.x, 70)
	_fx_layer.add_child(banner)
	banner.position = Vector2(0, _content.size.y * 0.32)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(banner, "modulate:a", 0.0, 0.5).set_delay(0.5)
	tween.tween_callback(banner.queue_free)

func _spawn_sparks(at: Vector2i, color: Color) -> void:
	var sparks := CPUParticles2D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.amount = 12
	sparks.lifetime = 0.5
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 60.0
	sparks.initial_velocity_max = 150.0
	sparks.gravity = Vector2(0, 420)
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 4.0
	sparks.color = color
	_fx_layer.add_child(sparks)
	sparks.global_position = _board.grid_to_world(at)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)

func _cleared_center(cells: Array) -> Vector2:
	var sum := Vector2.ZERO
	for at in cells:
		sum += _board.grid_to_world(at)
	return sum / float(cells.size())

func _shake() -> void:
	var base := _content.position
	var tween := create_tween()
	for _i in range(4):
		var jitter := Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0))
		tween.tween_property(_content, "position", base + jitter, 0.03)
	tween.tween_property(_content, "position", base, 0.06)

# ---------------------------------------------------------------------------
# Menus
# ---------------------------------------------------------------------------

func _toggle_pause() -> void:
	if Game.rules.is_over:
		return
	if _paused:
		_resume()
	else:
		_show_pause()

func _show_pause() -> void:
	_paused = true
	_overlay_open = true
	_overlay.open("PAUSED")
	_overlay.add_stat("Score", str(Game.rules.score))
	_overlay.add_stat("Lines", str(Game.rules.total_lines_cleared))
	_overlay.add_button("RESUME", "resume", GameConstants.ACCENT_HOT)
	_overlay.add_button("RESTART", "restart", GameConstants.ACCENT)
	_overlay.add_button("MAIN MENU", "menu", Color("4e4a4e"))
	get_tree().paused = true

func _show_game_over() -> void:
	_overlay_open = true
	_overlay.open("GAME OVER")
	_overlay.add_stat("Score", str(Game.rules.score))
	_overlay.add_stat("Best", str(Game.best_score))
	_overlay.add_stat("Lines", str(Game.rules.total_lines_cleared))
	_overlay.add_stat("Blocks", str(Game.rules.total_blocks_placed))
	_overlay.add_stat("Best Streak", str(int(Game.stats.get("best_streak", 0))))
	_overlay.add_stat("Games Played", str(Game.stats.get("games_started", 0)))
	if Game.is_new_best():
		_overlay.add_note("NEW BEST!", GameConstants.ACCENT_HOT)
		_overlay.add_button("PLAY AGAIN", "restart", GameConstants.ACCENT_HOT)
	else:
		_overlay.add_button("PLAY AGAIN", "restart", GameConstants.ACCENT)
	_overlay.add_button("MAIN MENU", "menu", Color("4e4a4e"))

func _on_overlay_action(id: String) -> void:
	match id:
		"resume":
			_resume()
		"restart":
			_restart()
		"menu":
			_go_to_menu()

func _resume() -> void:
	get_tree().paused = false
	_paused = false
	_overlay_open = false
	_overlay.close()

func _restart() -> void:
	get_tree().paused = false
	_paused = false
	_overlay_open = false
	_overlay.close()
	_board.reset()
	Game.start_new_game()
	_refresh_tray(Game.rules.tray)
	_refresh_hud()
	_refresh_hints()

func _go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# ---------------------------------------------------------------------------
# Refresh helpers
# ---------------------------------------------------------------------------

func _refresh_tray(pieces: Array) -> void:
	_tray.set_pieces(pieces)

## Re-pins the missing cell of every near-complete line from the rules.
func _refresh_hints() -> void:
	var pins: Array[Vector2i] = []
	for candidate in Game.rules.clearing_candidates():
		pins.append(candidate["missing"])
	_board.show_hints(pins)

func _refresh_hud() -> void:
	_score_label.text = str(Game.rules.score)
	_best_label.text = "BEST %d   ·   LINES %d" % [
		maxi(Game.best_score, Game.rules.score),
		Game.rules.total_lines_cleared,
	]
	if Game.rules.streak > 1:
		_streak_label.text = "COMBO x%d" % Game.rules.streak
	else:
		_streak_label.text = ""
