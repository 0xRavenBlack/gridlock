class_name PieceBag
extends RefCounted
## Draws pieces using a weighted shuffle bag. Because the bag is exhausted
## before reshuffling, the player never gets long unlucky runs of one shape.

var _rng: RandomNumberGenerator
var _queue: Array[String] = []

func _init(rng: RandomNumberGenerator = null) -> void:
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()

func next() -> Piece:
	if _queue.is_empty():
		_refill()
	var id: String = _queue.pop_back()
	return PieceLibrary.create(id)

func _refill() -> void:
	_queue.clear()
	for id in PieceLibrary.ids():
		for _copy in range(PieceLibrary.weight(id)):
			_queue.append(id)
	_shuffle(_queue)

func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap = items[i]
		items[i] = items[j]
		items[j] = swap
