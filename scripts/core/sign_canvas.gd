class_name SignCanvas
extends Control
## Draws a declarative "spec" into a Control, used as the content of a
## SubViewport that is then either baked to a static texture (signboards,
## notebook pages, calendars) or kept live as an animated screen (the
## workstation monitor, the diagnostic panels, the hologram overlays).
##
## Text goes through Label/RichTextLabel nodes rather than Font.render so that
## Bengali conjuncts are shaped by the engine's HarfBuzz integration. This is the
## reason the Bangla signage in the garage renders correctly instead of as
## separated characters.

const FONT_BANGLA: StringName = &"bangla"
const FONT_LATIN: StringName = &"latin"
const FONT_MONO: StringName = &"mono"

var spec: Dictionary = {}
var _labels: Array[Control] = []


func setup(a_spec: Dictionary) -> void:
	spec = a_spec
	custom_minimum_size = Vector2(spec.get("size", Vector2i(512, 256)))
	size = custom_minimum_size
	for l: Control in _labels:
		if is_instance_valid(l):
			l.queue_free()
	_labels.clear()
	_build_labels()
	queue_redraw()


func _theme_font(which: String) -> Font:
	var f: Font = get_theme_font(which)
	return f if f != null else get_theme_default_font()


func _build_labels() -> void:
	var layers: Array = spec.get("layers", [])
	for entry: Variant in layers:
		var d: Dictionary = entry
		match String(d.get("type", "")):
			"text":
				_labels.append(_make_text(d))
			"rich":
				_labels.append(_make_rich(d))
			_:
				pass


func _make_text(d: Dictionary) -> Control:
	var lbl := Label.new()
	lbl.text = String(d.get("text", ""))
	lbl.position = Vector2(d.get("pos", Vector2.ZERO))
	lbl.add_theme_font_size_override("font_size", int(d.get("size", 24)))
	lbl.add_theme_color_override("font_color", _col(d.get("color", "#ffffff")))
	var font_kind: String = String(d.get("font", "latin"))
	if font_kind != "latin":
		lbl.add_theme_font_override("font", _theme_font(font_kind))
	var w: float = float(d.get("width", -1.0))
	if w > 0.0:
		# autowrap must be on BEFORE the size is set: a Label clamps its size up to
		# its minimum, and with wrapping still off the minimum width is the whole
		# unwrapped line — so a wrapped note ended up laid out at ~3x its stated
		# width and ran off the plaque it was supposed to sit inside.
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.horizontal_alignment = _align(d.get("align", "left"))
		lbl.vertical_alignment = _valign(d.get("valign", "top"))
		lbl.size = Vector2(w, float(d.get("height", 0.0)))
	if bool(d.get("shadow", false)):
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
	if d.has("modulate"):
		lbl.modulate = _col(d.get("modulate", "#ffffff"))
	lbl.rotation_degrees = float(d.get("rotation", 0.0))
	lbl.name = String(d.get("name", "text"))
	add_child(lbl)
	if w > 0.0:
		# The width is applied once the label is inside the tree, and again on the
		# next frame: this engine build clamps a Label's size up to its minimum
		# while it is still parentless, and with `min` not yet reflecting autowrap
		# the label came back 759 px wide for a 340 px box. Inside the tree — and
		# again after one deferred pass, when the theme is resolvable — the size
		# sticks and the wrap width is what the spec asked for.
		lbl.size = Vector2(w, float(d.get("height", 0.0)))
		lbl.set_deferred("size", Vector2(w, float(d.get("height", 0.0))))
	return lbl


func _make_rich(d: Dictionary) -> Control:
	var rtl := RichTextLabel.new()
	rtl.position = Vector2(d.get("pos", Vector2.ZERO))
	rtl.size = Vector2(float(d.get("width", 300.0)), float(d.get("height", 100.0)))
	rtl.bbcode_enabled = true
	rtl.fit_content = false
	rtl.scroll_active = false
	rtl.add_theme_font_size_override("normal_font_size", int(d.get("size", 20)))
	rtl.add_theme_color_override("default_color", _col(d.get("color", "#ffffff")))
	var font_kind: String = String(d.get("font", "latin"))
	if font_kind != "latin":
		rtl.add_theme_font_override("normal_font", _theme_font(font_kind))
	rtl.add_theme_font_override("bold_font", _theme_font(font_kind))
	rtl.text = String(d.get("bbcode", ""))
	rtl.name = String(d.get("name", "rich"))
	add_child(rtl)
	return rtl


func _align(a: Variant) -> int:
	match String(a):
		"center": return HORIZONTAL_ALIGNMENT_CENTER
		"right": return HORIZONTAL_ALIGNMENT_RIGHT
		_: return HORIZONTAL_ALIGNMENT_LEFT


func _valign(a: Variant) -> int:
	match String(a):
		"center": return VERTICAL_ALIGNMENT_CENTER
		"bottom": return VERTICAL_ALIGNMENT_BOTTOM
		_: return VERTICAL_ALIGNMENT_TOP


func _col(c: Variant) -> Color:
	if c is Color:
		return c
	return Color.from_string(String(c), Color.WHITE)


# ===========================================================================
# Immediate drawing of the geometric layers
# ===========================================================================

func _draw() -> void:
	var sz: Vector2 = size
	var bg: Variant = spec.get("bg", null)
	if bg != null:
		draw_rect(Rect2(Vector2.ZERO, sz), _col(bg), true)
	var border: Dictionary = spec.get("border", {})
	if not border.is_empty():
		var bw: float = float(border.get("width", 2.0))
		draw_rect(Rect2(Vector2.ZERO, sz).grow(-bw * 0.5), _col(border.get("color", "#4fd8ff")), false, bw)
	var layers: Array = spec.get("layers", [])
	for entry: Variant in layers:
		var d: Dictionary = entry
		match String(d.get("type", "")):
			"rect":
				_d_rect(d)
			"roundrect":
				_d_round(d)
			"line":
				_d_line(d)
			"circle":
				_d_circle(d)
			"arc":
				_d_arc(d)
			"poly":
				_d_poly(d)
			"progress":
				_d_progress(d)
			"bars":
				_d_bars(d)
			"grid":
				_d_grid(d)
			"corner":
				_d_corner(d)
			_:
				pass


func _d_rect(d: Dictionary) -> void:
	var r := Rect2(Vector2(d.get("pos", Vector2.ZERO)), Vector2(d.get("sz", d.get("size", Vector2.ZERO))))
	draw_rect(r, _col(d.get("color", "#ffffff")), bool(d.get("filled", true)))


func _d_round(d: Dictionary) -> void:
	var r := Rect2(Vector2(d.get("pos", Vector2.ZERO)), Vector2(d.get("sz", Vector2.ZERO)))
	var rad: float = float(d.get("radius", 6.0))
	var pts: PackedVector2Array = _rounded_points(r, rad)
	draw_polygon(pts, PackedColorArray([_col(d.get("color", "#ffffff"))]))
	if d.has("stroke"):
		var closed: PackedVector2Array = pts
		closed.append(pts[0])
		draw_polyline(closed, _col(d.get("stroke", "#ffffff")), float(d.get("stroke_width", 1.0)))


func _rounded_points(r: Rect2, rad: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var rr: float = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var segs: int = 5
	var corners: Array = [
		Vector2(r.end.x - rr, r.end.y - rr), Vector2(r.position.x + rr, r.end.y - rr),
		Vector2(r.position.x + rr, r.position.y + rr), Vector2(r.end.x - rr, r.position.y + rr),
	]
	var starts: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
	for cidx: int in range(4):
		var ctr: Vector2 = corners[cidx]
		var a0: float = starts[cidx]
		for s: int in range(segs + 1):
			var a: float = a0 + float(s) / float(segs) * (PI * 0.5)
			out.append(ctr + Vector2(cos(a), sin(a)) * rr)
	return out


func _d_line(d: Dictionary) -> void:
	draw_line(
		Vector2(d.get("from", Vector2.ZERO)), Vector2(d.get("to", Vector2.ZERO)),
		_col(d.get("color", "#ffffff")), float(d.get("width", 1.0)),
		bool(d.get("antialiased", true)),
	)


func _d_circle(d: Dictionary) -> void:
	var ctr: Vector2 = Vector2(d.get("center", Vector2.ZERO))
	var rad: float = float(d.get("radius", 10.0))
	if bool(d.get("filled", true)):
		draw_circle(ctr, rad, _col(d.get("color", "#ffffff")))
	else:
		var pts: PackedVector2Array = PackedVector2Array()
		var n: int = 48
		for i: int in range(n + 1):
			var a: float = TAU * float(i) / float(n)
			pts.append(ctr + Vector2(cos(a), sin(a)) * rad)
		draw_polyline(pts, _col(d.get("color", "#ffffff")), float(d.get("width", 2.0)), true)


func _d_arc(d: Dictionary) -> void:
	var ctr: Vector2 = Vector2(d.get("center", Vector2.ZERO))
	var rad: float = float(d.get("radius", 40.0))
	var a0: float = float(d.get("start", 0.0))
	var a1: float = float(d.get("end", PI))
	var pts: PackedVector2Array = PackedVector2Array()
	var n: int = int(d.get("segments", 32))
	for i: int in range(n + 1):
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(ctr + Vector2(cos(a), sin(a)) * rad)
	draw_polyline(pts, _col(d.get("color", "#4fd8ff")), float(d.get("width", 3.0)), true)


func _d_poly(d: Dictionary) -> void:
	var raw: Array = d.get("points", [])
	var pts: PackedVector2Array = PackedVector2Array()
	for p: Variant in raw:
		pts.append(Vector2(p))
	if pts.is_empty():
		return
	if bool(d.get("filled", true)):
		draw_polygon(pts, PackedColorArray([_col(d.get("color", "#ffffff"))]))
	else:
		var closed: PackedVector2Array = pts
		closed.append(pts[0])
		draw_polyline(closed, _col(d.get("color", "#ffffff")), float(d.get("width", 1.5)), true)


func _d_progress(d: Dictionary) -> void:
	var pos: Vector2 = Vector2(d.get("pos", Vector2.ZERO))
	var sz: Vector2 = Vector2(d.get("sz", Vector2(200, 10)))
	var value: float = clampf(float(d.get("value", 0.5)), 0.0, 1.0)
	draw_rect(Rect2(pos, sz), _col(d.get("track", "#1b2730")), true)
	draw_rect(Rect2(pos, Vector2(sz.x * value, sz.y)), _col(d.get("color", "#4fd8ff")), true)
	draw_rect(Rect2(pos, sz), _col(d.get("border", "#2c4250")), false, 1.0)


func _d_bars(d: Dictionary) -> void:
	var pos: Vector2 = Vector2(d.get("pos", Vector2.ZERO))
	var values: Array = d.get("values", [])
	var bw: float = float(d.get("bar_width", 6.0))
	var gap: float = float(d.get("gap", 3.0))
	var maxh: float = float(d.get("max_height", 40.0))
	var col: Color = _col(d.get("color", "#4fd8ff"))
	for i: int in range(values.size()):
		var h: float = clampf(float(values[i]), 0.0, 1.0) * maxh
		draw_rect(Rect2(pos + Vector2(float(i) * (bw + gap), maxh - h), Vector2(bw, h)), col, true)


func _d_grid(d: Dictionary) -> void:
	var r := Rect2(Vector2(d.get("pos", Vector2.ZERO)), Vector2(d.get("sz", Vector2(200, 200))))
	var step: float = float(d.get("step", 20.0))
	var col: Color = _col(d.get("color", "#1d3a46"))
	var x: float = r.position.x
	while x <= r.end.x + 0.01:
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), col, 1.0)
		x += step
	var y: float = r.position.y
	while y <= r.end.y + 0.01:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), col, 1.0)
		y += step


func _d_corner(d: Dictionary) -> void:
	## L-shaped bracket, the sci-fi HUD motif used on every futuristic panel.
	var pos: Vector2 = Vector2(d.get("pos", Vector2.ZERO))
	var length: float = float(d.get("length", 24.0))
	var thick: float = float(d.get("width", 3.0))
	var col: Color = _col(d.get("color", "#4fd8ff"))
	var flip: Vector2 = Vector2(d.get("flip", Vector2.ONE))
	draw_rect(Rect2(pos, Vector2(thick * flip.x, length)), col, true)
	draw_rect(Rect2(pos, Vector2(length, thick * flip.y)), col, true)
