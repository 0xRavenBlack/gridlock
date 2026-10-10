class_name UiKit
extends RefCounted
## Small factory for consistently themed widgets. Keeps style decisions in one
## place so menu, HUD and overlays stay visually identical.

static func label(text: String, font_size: int, color: Color) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node

static func button(text: String, fill: Color) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_size_override("font_size", 26)
	node.add_theme_stylebox_override("normal", NeonStyle.button(fill))
	node.add_theme_stylebox_override("hover", NeonStyle.button_hover(fill))
	node.add_theme_stylebox_override("pressed", NeonStyle.button(fill.darkened(0.15)))
	node.add_theme_stylebox_override("focus", NeonStyle.button(fill))
	node.custom_minimum_size = Vector2(0, 56)
	return node

static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
