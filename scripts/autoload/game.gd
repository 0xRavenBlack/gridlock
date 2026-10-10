extends Node
## Game (autoload) - the global game service. Owns the authoritative GameRules
## instance, the persisted best score and lifetime statistics. UI talks to this,
## never to disk.

signal best_score_changed(best_score: int)

var rules: GameRules
var best_score: int = 0
var stats: Dictionary = {}

func _ready() -> void:
	rules = GameRules.new()
	best_score = int(SaveManager.get_value("progress", "best_score", 0))
	stats = _load_stats()

func start_new_game() -> void:
	rules.new_game()
	stats["games_started"] = int(stats.get("games_started", 0)) + 1
	_save_stats()

## Resolves a placement and persists a new best score when one is set.
func resolve_placement(piece: Piece, origin: Vector2i) -> Dictionary:
	var result := rules.place(piece, origin)
	if rules.score > best_score:
		_update_best_score(rules.score)
	return result

## Call once when a run ends so the best score is never lost.
func submit_final_score() -> void:
	if rules.score > best_score:
		_update_best_score(rules.score)

## Folds the finished run's tell-tale stats into the lifetime record.
func commit_stats() -> void:
	stats["best_streak"] = maxi(int(stats.get("best_streak", 0)), rules.best_streak)
	stats["total_lines"] = int(stats.get("total_lines", 0)) + rules.total_lines_cleared
	stats["total_blocks"] = int(stats.get("total_blocks", 0)) + rules.total_blocks_placed
	_save_stats()

func is_new_best() -> bool:
	return rules.score > 0 and rules.score >= best_score

func _update_best_score(value: int) -> void:
	best_score = value
	SaveManager.set_value("progress", "best_score", best_score)
	best_score_changed.emit(best_score)

func _load_stats() -> Dictionary:
	return {
		"games_started": int(SaveManager.get_value("stats", "games_started", 0)),
		"best_streak": int(SaveManager.get_value("stats", "best_streak", 0)),
		"total_lines": int(SaveManager.get_value("stats", "total_lines", 0)),
		"total_blocks": int(SaveManager.get_value("stats", "total_blocks", 0)),
	}

func _save_stats() -> void:
	SaveManager.set_value("stats", "games_started", int(stats.get("games_started", 0)))
	SaveManager.set_value("stats", "best_streak", int(stats.get("best_streak", 0)))
	SaveManager.set_value("stats", "total_lines", int(stats.get("total_lines", 0)))
	SaveManager.set_value("stats", "total_blocks", int(stats.get("total_blocks", 0)))