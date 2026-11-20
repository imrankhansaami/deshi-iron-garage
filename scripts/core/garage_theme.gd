class_name GarageTheme
extends RefCounted
## Builds the project-wide Theme in code so every Control (and every
## SubViewport screen) inherits the same four families:
##
##   latin  -> Rubik            UI body text
##   display-> Oswald           titles, signboards
##   mono   -> JetBrains Mono   technical readouts, logs, telemetry
##   bangla -> Noto Sans Bengali  all Bengali strings (HarfBuzz-shaped)
##
## Palette follows the brief: charcoal, industrial grey, warm amber, cyan,
## deep blue, metallic gold.

const PAL := {
	"charcoal": "#14171b",
	"panel": "#1b2026",
	"panel_hi": "#232a32",
	"line": "#2f3a44",
	"ink": "#e8ecef",
	"muted": "#94a0ab",
	"amber": "#ffb347",
	"amber_dim": "#8a5f22",
	"cyan": "#4fd8ff",
	"cyan_dim": "#1d5f75",
	"deep": "#0d1b2a",
	"gold": "#d4af37",
	"red": "#e2453c",
	"green": "#5fd08a",
	"rust": "#b5623a",
}

const FONT_DIR: String = "res://assets/fonts/"

static func build() -> Theme:
	var t := Theme.new()
	var latin: Font = _font("Rubik.ttf")
	var display: Font = _font("Oswald.ttf")
	var mono: Font = _font("JetBrainsMono.ttf")
	var bangla: Font = _font("NotoSansBengali.ttf")

	t.default_font = latin
	t.default_font_size = 18
	t.set_font("latin", "", latin)
	t.set_font("display", "", display)
	t.set_font("mono", "", mono)
	t.set_font("bangla", "", bangla)
	t.set_font("bold", "", latin)
	# Bengali needs a taller line box than Latin at the same point size.
	t.set_font_size("bangla_line_spacing", "", 8)

	# --- colours ---------------------------------------------------------
	for pair: Array in [
		["font_color", "ink"], ["font_hover_color", "cyan"], ["font_pressed_color", "amber"],
		["font_focus_color", "cyan"], ["font_disabled_color", "line"],
	]:
		t.set_color(pair[0], "Label", PAL[pair[1]])
	t.set_color("font_color", "Button", PAL["ink"])
	t.set_color("font_hover_color", "Button", PAL["charcoal"])
	t.set_color("font_pressed_color", "Button", PAL["charcoal"])
	t.set_color("font_focus_color", "Button", PAL["charcoal"])
	t.set_color("font_disabled_color", "Button", PAL["muted"])
	t.set_color("font_color", "LineEdit", PAL["ink"])
	t.set_color("selection_color", "LineEdit", PAL["cyan_dim"])
	t.set_color("font_color", "ProgressBar", PAL["cyan"])
	t.set_color("font_placeholder_color", "TextEdit", PAL["muted"])

	# --- styles ----------------------------------------------------------
	t.set_stylebox("normal", "Button", _sb(PAL["panel_hi"], PAL["line"], 1.0, 4.0, Vector2(18, 9)))
	t.set_stylebox("hover", "Button", _sb(PAL["cyan"], PAL["cyan"], 1.0, 4.0, Vector2(18, 9)))
	t.set_stylebox("pressed", "Button", _sb(PAL["amber"], PAL["amber"], 1.0, 4.0, Vector2(18, 9)))
	t.set_stylebox("focus", "Button", _focus())
	t.set_stylebox("disabled", "Button", _sb(PAL["panel"], PAL["line"], 1.0, 4.0, Vector2(18, 9), true))

	t.set_stylebox("panel", "PanelContainer", _sb(PAL["panel"], PAL["line"], 1.0, 6.0, Vector2(14, 12)))
	t.set_stylebox("panel", "Panel", _sb(PAL["panel"], PAL["line"], 1.0, 6.0, Vector2(0, 0)))
	t.set_stylebox("normal", "Panel", _sb(PAL["panel"], PAL["line"], 1.0, 6.0, Vector2(0, 0)))
	t.set_stylebox("background", "ProgressBar", _sb(PAL["deep"], PAL["line"], 1.0, 3.0, Vector2(0, 0)))
	t.set_stylebox("fill", "ProgressBar", _sb(PAL["cyan"], PAL["cyan"], 0.0, 3.0, Vector2(0, 0)))
	t.set_stylebox("normal", "LineEdit", _sb(PAL["deep"], PAL["line"], 1.0, 4.0, Vector2(8, 6)))
	t.set_stylebox("focus", "LineEdit", _focus())
	t.set_stylebox("panel", "ScrollContainer", _sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0.0, 0.0, Vector2(0, 0)))
	t.set_stylebox("panel", "GraphEdit", _sb(PAL["deep"], PAL["line"], 1.0, 4.0, Vector2(0, 0)))

	var grab := _sb(PAL["line"], PAL["line"], 0.0, 3.0, Vector2(0, 0))
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", _sb(PAL["cyan"], PAL["cyan"], 0.0, 3.0, Vector2(0, 0)))
	t.set_stylebox("grabber", "HScrollBar", grab)
	t.set_stylebox("grabber_highlight", "HScrollBar", _sb(PAL["cyan"], PAL["cyan"], 0.0, 3.0, Vector2(0, 0)))
	t.set_stylebox("slider", "HSlider", _sb(PAL["line"], PAL["line"], 0.0, 2.0, Vector2(0, 0)))
	t.set_stylebox("grabber_area", "HSlider", _sb(PAL["cyan_dim"], PAL["cyan_dim"], 0.0, 2.0, Vector2(0, 0)))
	t.set_stylebox("grabber_area_highlight", "HSlider", _sb(PAL["cyan"], PAL["cyan"], 0.0, 2.0, Vector2(0, 0)))

	# --- sizes -----------------------------------------------------------
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 8)
	t.set_constant("margin_left", "MarginContainer", 14)
	t.set_constant("margin_right", "MarginContainer", 14)
	t.set_constant("margin_top", "MarginContainer", 12)
	t.set_constant("margin_bottom", "MarginContainer", 12)
	t.set_constant("indent", "Tree", 18)
	t.set_font_size("font_size", "Button", 18)
	t.set_font_size("font_size", "Label", 18)
	t.set_font_size("mini_font_size", "Label", 14)
	t.set_stylebox("panel", "TooltipPanel", _sb(PAL["charcoal"], PAL["cyan_dim"], 1.0, 3.0, Vector2(8, 5)))
	return t


static func _font(file: String) -> Font:
	var path: String = FONT_DIR + file
	if not ResourceLoader.exists(path):
		push_warning("GarageTheme: missing font %s" % path)
		return FontFile.new()
	var res: Resource = load(path) as Resource
	return res as Font if res is Font else FontFile.new()


static func _sb(bg: Variant, border_col: Variant, border_w: float, radius: float, content_margin: Vector2, flat: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg if bg is Color else Color.from_string(String(bg), Color.BLACK)
	if border_w > 0.0:
		s.border_color = border_col if border_col is Color else Color.from_string(String(border_col), Color.WHITE)
		s.set_border_width_all(int(border_w))
	s.set_corner_radius_all(int(radius))
	s.content_margin_left = content_margin.x
	s.content_margin_right = content_margin.x
	s.content_margin_top = content_margin.y
	s.content_margin_bottom = content_margin.y
	s.anti_aliasing = true
	s.draw_center = not flat
	return s


static func _focus() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color.from_string(PAL["amber"], Color.WHITE)
	s.set_border_width_all(2)
	s.set_expand_margin_all(2.0)
	s.set_corner_radius_all(5)
	return s


static func col(name: String) -> Color:
	return Color.from_string(String(PAL.get(name, "#ffffff")), Color.WHITE)
