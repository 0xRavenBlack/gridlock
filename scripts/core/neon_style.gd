class_name NeonStyle
extends RefCounted
## Builds the glossy neon StyleBoxes used across the UI.
## Every style is cached by key so repeated redraws never allocate.

static var _cache: Dictionary = {}

static func _cached(key: String, builder: Callable) -> StyleBoxFlat:
	if not _cache.has(key):
		_cache[key] = builder.call()
	return _cache[key]

static func tile(color: Color) -> StyleBoxFlat:
	return _cached("tile_" + color.to_html(), func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = color.darkened(0.12)
		box.set_corner_radius_all(7)
		box.border_width_left = 2
		box.border_width_top = 2
		box.border_width_right = 1
		box.border_width_bottom = 1
		box.border_color = color.lightened(0.45)
		box.shadow_color = Color(color.r, color.g, color.b, 0.35)
		box.shadow_size = 6
		box.anti_aliasing = true
		return box)

static func gloss(color: Color) -> StyleBoxFlat:
	return _cached("gloss_" + color.to_html(), func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		var sheen := color.lightened(0.6)
		sheen.a = 0.32
		box.bg_color = sheen
		box.corner_radius_top_left = 6
		box.corner_radius_top_right = 6
		box.corner_radius_bottom_left = 3
		box.corner_radius_bottom_right = 3
		box.anti_aliasing = true
		return box)

static func empty_cell() -> StyleBoxFlat:
	return _cached("empty", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.04)
		box.set_corner_radius_all(7)
		box.set_border_width_all(1)
		box.border_color = Color(1, 1, 1, 0.07)
		box.anti_aliasing = true
		return box)

static func preview(valid: bool) -> StyleBoxFlat:
	return _cached("preview_%s" % valid, func() -> StyleBoxFlat:
		var tint := GameConstants.PREVIEW_VALID if valid else GameConstants.PREVIEW_INVALID
		var box := StyleBoxFlat.new()
		var fill := tint
		fill.a = 0.30
		box.bg_color = fill
		box.set_corner_radius_all(7)
		box.set_border_width_all(2)
		box.border_color = tint
		box.anti_aliasing = true
		return box)

static func flash() -> StyleBoxFlat:
	return _cached("flash", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.92)
		box.set_corner_radius_all(7)
		box.anti_aliasing = true
		return box)

## Soft neon frame that pulses while a row/column is one cell short.
static func hint_glow() -> StyleBoxFlat:
	return _cached("hint_glow", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = GameConstants.HINT_GLOW
		box.bg_color.a = 0.03
		box.set_corner_radius_all(20)
		box.set_border_width_all(3)
		box.border_color = GameConstants.HINT_GLOW
		box.shadow_color = GameConstants.HINT_GLOW
		box.shadow_size = 24
		box.anti_aliasing = true
		return box)

## Bright beam swept across a cleared row/column.
static func beam(color: Color) -> StyleBoxFlat:
	var key := "beam_" + color.to_html()
	return _cached(key, func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(9)
		box.shadow_color = color
		box.shadow_size = 22
		box.anti_aliasing = true
		return box)

static func board_panel() -> StyleBoxFlat:
	return _cached("board_panel", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.086, 0.043, 0.16, 0.92)
		box.set_corner_radius_all(20)
		box.set_border_width_all(2)
		box.border_color = Color("3a1f5c")
		box.shadow_color = Color(0.45, 0.2, 0.75, 0.25)
		box.shadow_size = 18
		box.anti_aliasing = true
		return box)

static func tray_panel() -> StyleBoxFlat:
	return _cached("tray_panel", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.055, 0.027, 0.12, 0.9)
		box.corner_radius_top_left = 20
		box.corner_radius_top_right = 20
		box.set_border_width_all(1)
		box.border_color = Color("2a1747")
		box.anti_aliasing = true
		return box)

static func hud_panel() -> StyleBoxFlat:
	return _cached("hud_panel", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.07, 0.036, 0.14, 0.86)
		box.corner_radius_bottom_left = 20
		box.corner_radius_bottom_right = 20
		box.anti_aliasing = true
		return box)

static func card() -> StyleBoxFlat:
	return _cached("card", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.102, 0.055, 0.2, 0.98)
		box.set_corner_radius_all(24)
		box.set_border_width_all(2)
		box.border_color = GameConstants.ACCENT
		box.shadow_color = Color(0.5, 0.25, 0.85, 0.45)
		box.shadow_size = 24
		box.anti_aliasing = true
		return box)

static func dim() -> StyleBoxFlat:
	return _cached("dim", func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = GameConstants.OVERLAY_DIM
		return box)

static func button(fill: Color) -> StyleBoxFlat:
	return _cached("button_" + fill.to_html(), func() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.set_corner_radius_all(14)
		box.set_border_width_all(2)
		box.border_color = fill.lightened(0.35)
		box.shadow_color = Color(fill.r, fill.g, fill.b, 0.5)
		box.shadow_size = 8
		box.set_content_margin_all(16)
		box.anti_aliasing = true
		return box)

static func button_hover(fill: Color) -> StyleBoxFlat:
	return _cached("button_hover_" + fill.to_html(), func() -> StyleBoxFlat:
		var box := button(fill).duplicate() as StyleBoxFlat
		box.bg_color = fill.lightened(0.12)
		return box)
