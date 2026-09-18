class_name UIKit
extends RefCounted
## Shared mobile-friendly wood/cream HUD widgets.


static func cream() -> Color:
	return Color(0.96, 0.91, 0.82)


static func wood() -> Color:
	return Color(0.38, 0.22, 0.11)


static func ink() -> Color:
	return Color(0.18, 0.10, 0.06)


static func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.content_margin_left = 20
	s.content_margin_right = 20
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


static func make_button(text: String, min_size: Vector2 = Vector2(420, 70)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", cream())
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.93, 0.75))
	b.add_theme_stylebox_override("normal", panel_style(wood(), Color(0.62, 0.42, 0.22)))
	b.add_theme_stylebox_override("hover", panel_style(Color(0.48, 0.28, 0.14), Color(0.85, 0.65, 0.32)))
	b.add_theme_stylebox_override("pressed", panel_style(Color(0.28, 0.15, 0.08), Color(0.85, 0.65, 0.32)))
	b.add_theme_stylebox_override("disabled", panel_style(Color(0.22, 0.16, 0.12, 0.7), Color(0.35, 0.25, 0.16)))
	return b


static func make_title(text: String, size: int = 46) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", cream())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l


static func make_body(text: String, size: int = 22) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.9, 0.84, 0.74))
	return l
