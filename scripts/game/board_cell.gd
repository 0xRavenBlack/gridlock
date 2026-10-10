class_name BoardCell
extends Control
## One square of the play field. Purely visual: it never captures input and
## only knows how to draw its current display state.

enum Display { EMPTY, FILLED, VALID, INVALID, FLASH }

var _display: int = Display.EMPTY
var _color: Color = Color.WHITE
var _hint_pin := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_empty() -> void:
	_display = Display.EMPTY
	queue_redraw()

## Marks the single cell a near-complete row/column still needs. Only drawn
## while the cell itself is empty, so filled and previewed cells never show it.
func set_hint_pin(enabled: bool) -> void:
	if _hint_pin == enabled:
		return
	_hint_pin = enabled
	queue_redraw()

func set_filled(color: Color) -> void:
	_color = color
	_display = Display.FILLED
	_hint_pin = false
	queue_redraw()

func set_preview(valid: bool) -> void:
	_display = Display.VALID if valid else Display.INVALID
	queue_redraw()

func set_flash() -> void:
	_display = Display.FLASH
	queue_redraw()

func is_filled() -> bool:
	return _display == Display.FILLED

## Small scale bounce used when a tile lands.
func animate_pop() -> void:
	pivot_offset = size * 0.5
	scale = Vector2(0.35, 0.35)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.08)

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	match _display:
		Display.EMPTY:
			draw_style_box(NeonStyle.empty_cell(), rect)
		Display.FILLED:
			draw_style_box(NeonStyle.tile(_color), rect)
			draw_style_box(NeonStyle.gloss(_color), _gloss_rect())
		Display.VALID:
			draw_style_box(NeonStyle.preview(true), rect)
		Display.INVALID:
			draw_style_box(NeonStyle.preview(false), rect)
		Display.FLASH:
			draw_style_box(NeonStyle.flash(), rect)
	if _hint_pin and _display == Display.EMPTY:
		_draw_hint_pin()

func _draw_hint_pin() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.72)
	var radius := maxf(size.x * 0.09, 1.5)
	var glow := GameConstants.HINT_PIN
	glow.a = 0.22
	draw_circle(center, radius * 2.2, glow)
	var core := GameConstants.HINT_PIN
	core.a = 0.95
	draw_circle(center, radius, core)

func _gloss_rect() -> Rect2:
	var inset := 3.0
	var width := maxf(size.x - inset * 2.0, 0.0)
	var height := maxf((size.y - inset * 2.0) * 0.42, 0.0)
	return Rect2(Vector2(inset, inset), Vector2(width, height))
