class_name MainMenu
extends Control
## Title screen, and the only place the player chooses how to enter the garage.
##
## The backdrop is drawn procedurally in _draw() rather than being a static image:
## a perspective floor grid, a rotating reactor ring, a scanline sweep and the
## energy-core bloom, all in the project's palette. It costs one canvas item, it
## animates, and it tells the garage's story in Bangla before a single 3D frame
## is rendered — the menu is the garage's identity, not a placeholder behind it.
##
## Every button is functional. "Continue" is disabled when there is no save, and
## "Garage Tour" parks the player controller and drives a camera rail through the
## finished space, which is the mode the viva demonstration uses.

const TAU_M: float = 6.283185307179586

var _phase: float = 0.0
var _ring: float = 0.0
var _buttons: Array[Button] = []
var _credits: Control
var _settings: Control
var _status: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# the project's music, from the title screen on: the courtyard's nature bed.
	# Instrument-free by construction — wind, leaves and sparrows, synthesised.
	# Started one frame late so the menu paints before the synth runs.
	await get_tree().process_frame
	AudioBank.start_bed("nature", 6.0)


func _process(delta: float) -> void:
	_phase += delta
	_ring += delta * 0.22
	queue_redraw()


# ===========================================================================
# construction
# ===========================================================================

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_bottom", 50)
	root.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 60)
	margin.add_child(h)
	# --- left: title and menu ------------------------------------------
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(560, 0)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var kicker := Label.new()
	kicker.text = "A COMPUTER GRAPHICS THESIS  ·  GODOT 4.x  ·  REAL-TIME 3D"
	kicker.add_theme_font_override("font", _font("mono"))
	kicker.add_theme_font_size_override("font_size", 14)
	kicker.add_theme_color_override("font_color", GarageTheme.col("amber"))
	left.add_child(kicker)
	left.add_child(_spacer(10))
	var title_bn := Label.new()
	title_bn.text = "স্বপ্নের গ্যারেজ"
	title_bn.add_theme_font_override("font", _font("bangla"))
	title_bn.add_theme_font_size_override("font_size", 96)
	title_bn.add_theme_color_override("font_color", GarageTheme.col("ink"))
	left.add_child(title_bn)
	var title_en := Label.new()
	title_en.text = "DESHI IRON GARAGE"
	title_en.add_theme_font_override("font", _font("display"))
	title_en.add_theme_font_size_override("font_size", 68)
	title_en.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	left.add_child(title_en)
	var sub := Label.new()
	sub.text = "THE DREAM OF A BANGLADESHI INVENTOR"
	sub.add_theme_font_override("font", _font("mono"))
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", GarageTheme.col("gold"))
	left.add_child(sub)
	var tagline := Label.new()
	tagline.text = "নিজের প্রযুক্তি, নিজের শক্তি   ·   own technology, own strength"
	tagline.add_theme_font_override("font", _font("bangla"))
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.add_theme_color_override("font_color", GarageTheme.col("muted"))
	left.add_child(tagline)
	left.add_child(_spacer(26))
	_button_row(left)
	left.add_child(_spacer(18))
	_status = Label.new()
	_status.add_theme_font_override("font", _font("mono"))
	_status.add_theme_font_size_override("font_size", 15)
	_status.add_theme_color_override("font_color", GarageTheme.col("cyan_dim"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(540, 0)
	left.add_child(_status)
	# --- right: the premise -------------------------------------------
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	var premise := PanelContainer.new()
	premise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(premise)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	premise.add_child(pv)
	var head := Label.new()
	head.text = "আমার গল্প"
	head.add_theme_font_override("font", _font("bangla"))
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", GarageTheme.col("amber"))
	pv.add_child(head)
	var body := Label.new()
	body.text = """বাংলাদেশের এক মেরামতের গ্যারেজ। টিনের চাল। বেঞ্চে উনিশ বছরের দাগ। একটা বাতিল মোটরসাইকেল, দুটো মরা আইপিএস সেল, চারবার সারানো একটা কম্পিউটার।

তার পাশে ছাত্রটা গড়ে বাকি অর্ধেক — হলোগ্রাফিক ডিজাইন টেবিল, গোল অ্যাসেম্বলি স্টেজ, চারটা ম্যানিপুলেটর আর্ম। আর একটা পাওয়ারড এক্সোস্যুট — স্ট্যান্ড ছাড়ে না।

পার্থক্যটাই আসল কথা। আবিষ্কারকের মতো ভাবতে দামি ল্যাব লাগে না।"""
	body.add_theme_font_override("font", _font("bangla"))
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", GarageTheme.col("ink"))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	pv.add_child(body)
	pv.add_child(_rule())
	var tech := Label.new()
	tech.text = "GRAPHICS CONTENTS"
	tech.add_theme_font_override("font", _font("mono"))
	tech.add_theme_font_size_override("font_size", 15)
	tech.add_theme_color_override("font_color", GarageTheme.col("amber"))
	pv.add_child(tech)
	var list := Label.new()
	list.text = """·  procedurally synthesised PBR channel maps (albedo / ORM / normal)
·  holographic spatial shader: fresnel, world-space scanlines, grid, flicker
·  energy-core emissive shader: plasma fBm, rings, spokes, arcs
·  procedural cable geometry: catenary path, parallel-transport frames, bundling
·  procedural prop and layout generation, seeded and reproducible
·  runtime-synthesised audio, no external sound packs
·  instrument-free ambience: wind, leaves, sparrows, the street
·  live SubViewport interfaces shaped through the engine's Bengali text stack"""
	list.add_theme_font_override("font", _font("mono"))
	list.add_theme_font_size_override("font_size", 14)
	list.add_theme_color_override("font_color", GarageTheme.col("muted"))
	pv.add_child(list)


func _button_row(left: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	left.add_child(grid)
	var has_save: bool = GameState.has_save()
	var entries: Array = [
		["START", _on_start, false],
		["CONTINUE", _on_continue, not has_save],
		["GARAGE TOUR", _on_tour, false],
		["SETTINGS", func() -> void: _show(_settings), false],
		["CREDITS", func() -> void: _show(_credits), false],
		["GRAPHICS BENCH", _on_bench, false],
		["EXIT", func() -> void: get_tree().quit(), false],
	]
	for e: Array in entries:
		var b := Button.new()
		b.text = String(e[0])
		b.custom_minimum_size = Vector2(260, 52)
		b.add_theme_font_size_override("font_size", 20)
		b.disabled = bool(e[2])
		b.pressed.connect(e[1] as Callable)
		b.mouse_entered.connect(func() -> void: AudioBank.play("ui_hover", -6.0))
		grid.add_child(b)
		_buttons.append(b)


func _rule() -> Control:
	var c := ColorRect.new()
	c.color = GarageTheme.col("line")
	c.custom_minimum_size = Vector2(0, 2)
	return c


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _font(which: String) -> Font:
	var t: Theme = theme
	if t == null:
		t = get_tree().root.theme
	return t.get_font(which, "") if t != null else FontFile.new()


# ===========================================================================
# panels
# ===========================================================================

func _show(which: Control) -> void:
	if which == null:
		return
	which.visible = true
	AudioBank.play("ui_confirm")


func _build_credits() -> void:
	_credits = _overlay("CREDITS", [
		["DESIGN, CODE, ART DIRECTION, AUDIO", "the student, alone, in a garage"],
		["ENGINE", "Godot Engine 4.7.2 (GPL) — Forward+ renderer"],
		["GEOMETRY", "all meshes generated at runtime from ShapeKit primitives: boxes, lathes, gears, tubes"],
		["TEXTURES", "all surfaces synthesised from noise in TextureFactory; no downloaded image pack"],
		["SHADERS", "hologram.gdshader, energy_core.gdshader, holo_grid.gdshader, screen.gdshader, metal_emission.gdshader, cable_material.gdshader"],
		["AUDIO", "every sound synthesised at load in AudioSynth: additive partials, Karplus-Strong plucks, filtered noise"],
		["FONTS", "Noto Sans Bengali, Rubik, Oswald, JetBrains Mono — SIL Open Font License 1.1"],
		["REFERENCES", "photographs of Bangladeshi motorcycle, electronics and rickshaw workshops"],
		["DOMAIN", "computer graphics: real-time 3D indoor environment rendering and interaction"],
	], func() -> void: _credits.visible = false)


func _build_settings() -> void:
	var rows: Array = [
		["quality", "QUALITY PRESET", "combo", ["low", "medium", "high"]],
		["fov", "FIELD OF VIEW", "slider", [65.0, 100.0, 1.0]],
		["walk_speed", "WALK SPEED", "slider", [1.6, 6.0, 0.05]],
		["mouse_sensitivity", "MOUSE SENSITIVITY", "slider", [0.0006, 0.006, 0.0001]],
		["invert_y", "INVERT VERTICAL LOOK", "toggle", []],
		["bloom", "BLOOM / GLOW", "toggle", []],
		["ssao", "AMBIENT OCCLUSION", "toggle", []],
		["shadows", "REAL-TIME SHADOWS", "toggle", []],
		["rain", "RAIN ON THE TIN ROOF", "toggle", []],
		["show_fps", "SHOW FRAME COUNTER", "toggle", []],
		["master_volume", "MASTER VOLUME", "slider", [0.0, 1.0, 0.01]],
		["ambience_volume", "AMBIENCE VOLUME", "slider", [0.0, 1.0, 0.01]],
		["effects_volume", "EFFECTS VOLUME", "slider", [0.0, 1.0, 0.01]],
		["ui_volume", "INTERFACE VOLUME", "slider", [0.0, 1.0, 0.01]],
	]
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	for r: Array in rows:
		var key: String = String(r[0])
		match String(r[2]):
			"slider":
				var spec: Array = r[3]
				var row := HBoxContainer.new()
				body.add_child(row)
				var l := Label.new()
				l.text = String(r[1])
				l.add_theme_font_override("font", _font("mono"))
				l.add_theme_font_size_override("font_size", 15)
				l.custom_minimum_size = Vector2(280, 0)
				row.add_child(l)
				var s := HSlider.new()
				s.min_value = float(spec[0])
				s.max_value = float(spec[1])
				s.step = float(spec[2])
				s.value = float(GameState.settings.get(key, s.value))
				s.custom_minimum_size = Vector2(320, 18)
				s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(s)
				var v := Label.new()
				v.add_theme_font_override("font", _font("mono"))
				v.add_theme_font_size_override("font_size", 14)
				v.text = "%.3f" % s.value
				v.custom_minimum_size = Vector2(70, 0)
				row.add_child(v)
				s.value_changed.connect(func(nv: float) -> void:
					GameState.settings[key] = nv
					v.text = "%.3f" % nv
					_apply_setting(key))
			"toggle":
				var cb := CheckBox.new()
				cb.text = String(r[1])
				cb.button_pressed = bool(GameState.settings.get(key, true))
				cb.toggled.connect(func(on: bool) -> void:
					GameState.settings[key] = on
					_apply_setting(key))
				body.add_child(cb)
			"combo":
				var row2 := HBoxContainer.new()
				body.add_child(row2)
				var l2 := Label.new()
				l2.text = String(r[1])
				l2.add_theme_font_override("font", _font("mono"))
				l2.add_theme_font_size_override("font_size", 15)
				l2.custom_minimum_size = Vector2(280, 0)
				row2.add_child(l2)
				var opt := OptionButton.new()
				for o: Variant in r[3]:
					opt.add_item(String(o))
					if String(o) == String(GameState.settings.get(key, "high")):
						opt.selected = opt.get_item_count() - 1
				opt.item_selected.connect(func(i: int) -> void:
					GameState.settings[key] = opt.get_item_text(i)
					_apply_setting(key))
				row2.add_child(opt)
	body.add_child(_rule())
	var save := Button.new()
	save.text = "SAVE AND APPLY"
	save.pressed.connect(func() -> void:
		GameState.save_settings()
		AudioBank.play("ui_confirm")
		_settings.visible = false)
	body.add_child(save)
	_settings = _overlay("SETTINGS", [], func() -> void: _settings.visible = false, body)


func _overlay(title: String, rows: Array, closer: Callable, extra: Control = null) -> Control:
	var shell := Control.new()
	shell.name = title
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.visible = false
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shell)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			closer.call())
	shell.add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(centre)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(900, 0)
	centre.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", _font("display"))
	t.add_theme_font_size_override("font_size", 32)
	t.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	head.add_child(t)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(closer)
	head.add_child(close)
	v.add_child(_rule())
	for r: Array in rows:
		var row := HBoxContainer.new()
		v.add_child(row)
		var k := Label.new()
		k.text = String(r[0])
		k.add_theme_font_override("font", _font("mono"))
		k.add_theme_font_size_override("font_size", 14)
		k.add_theme_color_override("font_color", GarageTheme.col("amber"))
		k.custom_minimum_size = Vector2(320, 0)
		row.add_child(k)
		var val := Label.new()
		val.text = String(r[1])
		val.add_theme_font_size_override("font_size", 16)
		val.add_theme_color_override("font_color", GarageTheme.col("ink"))
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val.custom_minimum_size = Vector2(520, 0)
		row.add_child(val)
	if extra != null:
		v.add_child(extra)
	return shell


func _apply_setting(key: String) -> void:
	match key:
		"master_volume", "ambience_volume", "effects_volume", "ui_volume":
			AudioBank.refresh_settings()
		"quality", "bloom", "ssao", "shadows", "rain":
			AudioBank.play("ui_confirm", -6.0)


# ===========================================================================
# actions
# ===========================================================================

func _on_start() -> void:
	GameState.reset_run()
	GameState.tour_mode = false
	_enter()


func _on_continue() -> void:
	if not GameState.load_run():
		_status.text = "no compatible save found — starting a new run"
		GameState.reset_run()
	GameState.tour_mode = false
	_enter()


func _on_tour() -> void:
	if not GameState.load_run():
		GameState.reset_run()
		# the tour is meant to show the finished garage, so a cold save is
		## promoted to the completed state rather than touring a dark room
		_complete_for_tour()
	GameState.tour_mode = true
	_enter()


func _complete_for_tour() -> void:
	GameState.shutter_open = true
	GameState.power_on = true
	GameState.computer_on = true
	GameState.notebook_read = true
	GameState.hologram_used = true
	GameState.diagnostics_run = true
	for c: String in GameConfig.component_order():
		GameState.collected_components[c] = true
	GameState.assembly_stage = GameState.AssemblyStage.ACTIVE
	GameState.has_started = true


func _on_bench() -> void:
	if not GameState.load_run():
		GameState.reset_run()
		_complete_for_tour()
	GameState.tour_mode = false
	_enter("benchmark")


func _enter(open_panel: String = "") -> void:
	AudioBank.play("ui_confirm")
	GameState.has_started = true
	GameState.save_run()
	var tree := get_tree()
	tree.paused = false
	var err: Error = tree.change_scene_to_file("res://scenes/main/garage_world.tscn")
	if err != OK:
		_status.text = "scene load failed: %s" % error_string(err)
		return
	if open_panel != "":
		# defer one frame so the world has finished building before the panel opens
		await tree.process_frame
		await tree.process_frame
		EventBus.ui_panel_opened.emit(open_panel)


func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		_build_credits()
		_build_settings()


# ===========================================================================
# backdrop
# ===========================================================================

func _draw() -> void:
	var sz: Vector2 = size
	if sz.x < 1.0 or sz.y < 1.0:
		return
	# ground wash
	draw_rect(Rect2(Vector2.ZERO, sz), Color("0a0e12"), true)
	# perspective floor grid, vanishing at the horizon line
	var horizon: float = sz.y * 0.62
	var vp := Vector2(sz.x * 0.72, horizon)
	var grid_col := Color(0.12, 0.34, 0.42, 0.55)
	for i: int in range(-14, 15):
		var x: float = vp.x + float(i) * 64.0
		draw_line(vp, Vector2(x, sz.y), grid_col, 1.0)
	for j: int in range(1, 16):
		var t: float = float(j) / 16.0
		var y: float = horizon + pow(t, 2.4) * (sz.y - horizon)
		var half_w: float = pow(t, 1.3) * sz.x * 1.2
		draw_line(Vector2(vp.x - half_w, y), Vector2(vp.x + half_w, y), grid_col, 1.0)
	# the reactor ring, the same silhouette the core shader draws
	var centre := Vector2(sz.x * 0.72, sz.y * 0.42)
	var base_r: float = minf(sz.x, sz.y) * 0.16
	for k: int in range(3):
		var r: float = base_r * (1.0 + float(k) * 0.22)
		var a0: float = _ring * (1.0 + float(k) * 0.4)
		var col: Color = Color(0.31, 0.85, 1.0, 0.5 - float(k) * 0.12)
		var pts := PackedVector2Array()
		var steps: int = 64
		for s: int in range(steps + 1):
			var a: float = a0 + TAU_M * float(s) / float(steps)
			# a travelling gap in each ring, so it reads as machinery not a halo
			var frac: float = float(s) / float(steps)
			if fposmod(frac + _ring * 0.2, 1.0) < 0.08:
				if pts.size() > 1:
					draw_polyline(pts, col, 2.5 + float(2 - k) * 1.5, true)
				pts = PackedVector2Array()
				continue
			pts.append(centre + Vector2(cos(a), sin(a) * 0.62) * r)
		if pts.size() > 1:
			draw_polyline(pts, col, 2.5 + float(2 - k) * 1.5, true)
	# the core bloom at the centre
	for k: int in range(14, 0, -1):
		var rr: float = base_r * 0.42 * float(k) / 14.0
		var alpha: float = 0.055 * float(15 - k) / 14.0
		draw_circle(centre, rr, Color(0.49, 0.95, 1.0, alpha))
	var pulse: float = 0.5 + 0.5 * sin(_phase * 1.35 * TAU_M)
	draw_circle(centre, base_r * 0.16 * (1.0 + pulse * 0.12), Color(0.85, 0.99, 1.0, 0.9))
	# the scanline sweep, matching the hologram shader's band
	var band_y: float = horizon - fposmod(_phase * 0.18, 1.0) * base_r * 2.4
	draw_rect(Rect2(centre.x - base_r * 1.6, band_y, base_r * 3.2, 2.0), Color(0.62, 0.95, 1.0, 0.35), true)
	# the tin-roof silhouette across the top, so the menu is inside a shed
	var roof_col := Color("12171d")
	for i: int in range(int(sz.x / 26.0) + 1):
		var x: float = float(i) * 26.0
		var h: float = 42.0 + sin(x * 0.24) * 9.0
		draw_rect(Rect2(x, 0, 24.0, h), roof_col, true)
	draw_rect(Rect2(0, 44, sz.x, 3.0), Color(0.18, 0.24, 0.28, 1.0), true)
	# the shutter slats at the left edge, half-open, echoing the first interaction
	for i: int in range(26):
		var y: float = float(i) * 16.0
		draw_rect(Rect2(0, sz.y - y - 16.0, 26.0, 14.0), Color(0.14, 0.19, 0.24, 0.9), true)
	# the corner brackets, the reticle motif
	var bracket := Color(0.31, 0.85, 1.0, 0.7)
	var m: float = 26.0
	var ln: float = 44.0
	for corner: Array in [[Vector2(m, m), Vector2(1, 1)], [Vector2(sz.x - m, m), Vector2(-1, 1)],
			[Vector2(m, sz.y - m), Vector2(1, -1)], [Vector2(sz.x - m, sz.y - m), Vector2(-1, -1)]]:
		var pos: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		draw_rect(Rect2(pos, Vector2(ln * dir.x, 3.0 * dir.y)), bracket, true)
		draw_rect(Rect2(pos, Vector2(3.0 * dir.x, ln * dir.y)), bracket, true)
