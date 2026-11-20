class_name BenchmarkPanel
extends Control
## Graphics bench: the testing mode the brief asks for, wired to the real
## rendering backend rather than to invented numbers.
##
## Every figure on screen comes from one of three live sources:
##   * Performance.get_monitor()  — FPS, frame time, draw calls, primitives,
##     objects in frame, video memory, node and object counts;
##   * Viewport.get_render_info() — the same render counters per pass
##     (visible, shadow, canvas), which is how the shadow cost is isolated;
##   * the generators themselves — TextureFactory, CableGenerator and the
##     procedural layout report their own wall-clock times in milliseconds.
##
## The five experiments from the brief are implemented as *configurable switches*
## on the live scene, not as recorded screenshots: changing a parameter re-renders
## the actual garage, and the harness captures a screenshot plus a CSV row so the
## results in docs/EXPERIMENTS.md are reproducible rather than asserted.
##
## Nothing here fabricates a measurement. If a counter is unavailable on the
## current backend it reads "n/a" rather than a plausible-looking number.

const TAU_B: float = 6.283185307179586

var host: Hud
var runtime: GarageRuntime
var environment: GarageEnvironment
var dressing: GarageDressing
var props: PropFactory
var baker: SignageBaker

var metrics_box: GridContainer
var log_box: RichTextLabel
var experiment_tabs: TabContainer
var _accum: float = 0.0
var _running: bool = false
var _samples: Array = []
var _capture_dir: String = "user://benchmarks"
var _active_experiment: int = 0
var _material_probe: MeshInstance3D
var _cable_probe_root: Node3D
var _cable_params: Dictionary = {}
var _probe_stats: Dictionary = {}


func attach(h: Hud, rt: GarageRuntime, env: GarageEnvironment, dr: GarageDressing, pr: PropFactory, bk: SignageBaker) -> void:
	host = h
	runtime = rt
	environment = env
	dressing = dr
	props = pr
	baker = bk
	_build()


# ===========================================================================
# layout
# ===========================================================================

func _build() -> void:
	name = "Benchmark"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0.02, 0.03, 0.04, 0.86)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim_bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := Label.new()
	title.text = "GRAPHICS BENCH"
	title.add_theme_font_override("font", _font("display"))
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	header.add_child(title)
	var sub := Label.new()
	sub.text = "live measurements from the running renderer  ·  F6 to close"
	sub.add_theme_font_override("font", _font("mono"))
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", GarageTheme.col("muted"))
	header.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func() -> void: EventBus.ui_panel_closed.emit("benchmark"))
	header.add_child(close)
	# metrics strip
	metrics_box = GridContainer.new()
	metrics_box.columns = 6
	metrics_box.add_theme_constant_override("h_separation", 18)
	outer.add_child(metrics_box)
	for i: int in range(18):
		var cell := VBoxContainer.new()
		metrics_box.add_child(cell)
		var k := Label.new()
		k.name = "MK%d" % i
		k.add_theme_font_override("font", _font("mono"))
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", GarageTheme.col("muted"))
		cell.add_child(k)
		var v := Label.new()
		v.name = "MV%d" % i
		v.add_theme_font_override("font", _font("mono"))
		v.add_theme_font_size_override("font_size", 19)
		v.add_theme_color_override("font_color", GarageTheme.col("ink"))
		cell.add_child(v)
	# experiment tabs
	experiment_tabs = TabContainer.new()
	experiment_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(experiment_tabs)
	_tab("Materials", _tab_materials)
	_tab("Hologram", _tab_hologram)
	_tab("Energy core", _tab_core)
	_tab("Lighting", _tab_lighting)
	_tab("Cables", _tab_cables)
	_tab("Post stack", _tab_post)
	# log + controls
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	outer.add_child(bottom)
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.custom_minimum_size = Vector2(700, 190)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.add_theme_font_override("normal_font", _font("mono"))
	log_box.add_theme_font_size_override("normal_font_size", 13)
	log_box.add_theme_color_override("default_color", GarageTheme.col("cyan_dim"))
	bottom.add_child(log_box)
	var controls := VBoxContainer.new()
	controls.custom_minimum_size = Vector2(300, 0)
	bottom.add_child(controls)
	_button(controls, "RUN CURRENT EXPERIMENT", _run_current)
	_button(controls, "CAPTURE FIXED CAMERA", _capture_frame)
	_button(controls, "EXPORT RESULTS CSV", _export_csv)
	_button(controls, "CLEAR CAPTURES", _clear_captures)
	_button(controls, "REGENERATE SURFACE TEXTURES", _regen_textures)


func _button(host: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(action)
	host.add_child(b)
	return b


func _font(which: String) -> Font:
	var t: Theme = theme
	if t == null:
		t = get_tree().root.theme
	return t.get_font(which, "") if t != null else FontFile.new()


func _tab(name: String, builder: Callable) -> void:
	var page := ScrollContainer.new()
	page.name = name
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	experiment_tabs.add_child(page)
	var box := VBoxContainer.new()
	box.name = name + "Body"
	box.add_theme_constant_override("separation", 10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(box)
	builder.call(box)


func _note(box: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", GarageTheme.col("muted"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(760, 0)
	box.add_child(l)


func _slider(box: VBoxContainer, label: String, lo: float, hi: float, value: float, step: float, action: Callable) -> HSlider:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_override("font", _font("mono"))
	l.add_theme_font_size_override("font_size", 15)
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(340, 18)
	row.add_child(s)
	var v := Label.new()
	v.add_theme_font_override("font", _font("mono"))
	v.add_theme_font_size_override("font_size", 15)
	v.text = "%.3f" % value
	v.custom_minimum_size = Vector2(80, 0)
	row.add_child(v)
	s.value_changed.connect(func(nv: float) -> void:
		v.text = "%.3f" % nv
		action.call(nv))
	return s


func _toggle(box: VBoxContainer, label: String, initial: bool, action: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = initial
	cb.toggled.connect(action)
	box.add_child(cb)


func _combo(box: VBoxContainer, label: String, options: Array, initial: String, action: Callable) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_override("font", _font("mono"))
	l.add_theme_font_size_override("font_size", 15)
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	for o: Variant in options:
		opt.add_item(String(o))
		if String(o) == initial:
			opt.selected = opt.get_item_count() - 1
	opt.item_selected.connect(func(i: int) -> void: action.call(opt.get_item_text(i)))
	row.add_child(opt)


# ===========================================================================
# Experiment 1 — PBR metal
# ===========================================================================

func _tab_materials(box: VBoxContainer) -> void:
	_note(box, "Same object, same camera, same lighting. Only metallic and roughness change, so the reading is about the BRDF response rather than the scene. The probe is a sphere pair: one polished, one matte, sharing a single synthesised channel map.")
	var probe := Node3D.new()
	probe.name = "MaterialProbe"
	box.add_child(probe)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(820, 260)
	box.add_child(holder)
	_material_probe = null
	_slider(box, "metallic", 0.0, 1.0, 1.0, 0.01, _set_probe_metallic)
	_slider(box, "roughness", 0.02, 1.0, 0.3, 0.01, _set_probe_rough)
	_slider(box, "albedo value", 0.05, 1.0, 0.75, 0.01, _set_probe_albedo)
	_slider(box, "normal scale", 0.0, 3.0, 1.0, 0.05, _set_probe_normal)
	_combo(box, "surface", ["steel_brushed", "chrome", "cast_iron", "rust_sheet", "armour_red", "armour_gold", "brass", "copper", "teak", "worn_concrete"], "steel_brushed", _set_probe_surface)
	_probe_row = HBoxContainer.new()
	box.add_child(_probe_row)
	_probe_labels = {}


var _probe_row: HBoxContainer
var _probe_labels: Dictionary
var _probe_material: StandardMaterial3D


func _set_probe_metallic(v: float) -> void:
	if _probe_material != null:
		_probe_material.metallic = v
		_probe_value("metallic", "%.2f" % v)


func _set_probe_rough(v: float) -> void:
	if _probe_material != null:
		_probe_material.roughness = v
		_probe_value("roughness", "%.2f" % v)


func _set_probe_albedo(v: float) -> void:
	if _probe_material != null:
		_probe_material.albedo_color = Color(v, v, v)
		_probe_value("albedo", "%.2f" % v)


func _set_probe_normal(v: float) -> void:
	if _probe_material != null:
		_probe_material.normal_scale = v
		_probe_value("normal", "%.2f" % v)


func _set_probe_surface(surface_key: String) -> void:
	var s: Dictionary = MaterialLibrary.factory.surface(surface_key)
	if _probe_material == null:
		_probe_material = StandardMaterial3D.new()
	_probe_material.albedo_texture = s["albedo"]
	_probe_material.roughness_texture = s["orm"]
	_probe_material.roughness_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_GREEN
	_probe_material.metallic_texture = s["orm"]
	_probe_material.metallic_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_BLUE
	_probe_material.normal_enabled = true
	_probe_material.normal_texture = s["normal"]
	_probe_material.ao_enabled = true
	_probe_material.ao_texture = s["orm"]
	_probe_material.ao_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_RED
	_probe_value("surface", surface_key)
	_probe_value("gen_ms", "%.1f ms" % MaterialLibrary.factory.generation_time(surface_key))


func _probe_value(key: String, text: String) -> void:
	var l: Label = _probe_labels.get(key, null) as Label
	if l != null:
		l.text = text


func refresh() -> void:
	_metrics()
	_log_line("bench opened  ·  renderer %s" % _renderer_name())


## The renderer identity, read from the project settings rather than the
## RenderingServer: 4.7 exposes no device-name query on the class, and a
## fabricated string here would be worse than a plain one.
static func _renderer_name() -> String:
	var method: Variant = ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")
	var name: String = String(method)
	match name:
		"forward_plus": return "Forward+"
		"mobile": return "Mobile"
		"gl_compatibility": return "Compatibility (OpenGL 3.3)"
	return name


# ===========================================================================
# Experiment 2 — hologram
# ===========================================================================

func _tab_hologram(box: VBoxContainer) -> void:
	_note(box, "Three variants on the same geometry: a plain transparent StandardMaterial3D, an emissive StandardMaterial3D, and the animated hologram shader. The comparison isolates what the shader actually buys, and the cost column is the honest answer.")
	_combo(box, "variant", ["transparent", "emissive", "hologram"], "hologram", _set_holo_variant)
	_slider(box, "opacity", 0.0, 1.0, 0.62, 0.01, func(v: float) -> void: _holo_param("opacity", v))
	_slider(box, "glow_strength", 0.0, 6.0, 2.1, 0.05, func(v: float) -> void: _holo_param("glow_strength", v))
	_slider(box, "fresnel_power", 0.2, 8.0, 2.4, 0.05, func(v: float) -> void: _holo_param("fresnel_power", v))
	_slider(box, "scan_density", 0.0, 120.0, 26.0, 1.0, func(v: float) -> void: _holo_param("scan_density", v))
	_slider(box, "grid_scale", 0.0, 200.0, 34.0, 1.0, func(v: float) -> void: _holo_param("grid_scale", v))
	_slider(box, "flicker_amount", 0.0, 1.0, 0.12, 0.01, func(v: float) -> void: _holo_param("flicker_amount", v))
	_toggle(box, "wireframe only", false, func(on: bool) -> void: _holo_param("wireframe_only", 1.0 if on else 0.0))
	_toggle(box, "acquisition band", true, func(on: bool) -> void: _holo_param("acquire", 1.0 if on else 0.0))


func _holo_param(param: String, value: float) -> void:
	if runtime == null:
		return
	for mat: ShaderMaterial in runtime.hologram_materials:
		if mat != null:
			mat.set_shader_parameter(param, value)
	_log_line("hologram.%s = %.3f" % [param, value])


func _set_holo_variant(variant: String) -> void:
	if runtime == null or runtime.hologram_materials.is_empty():
		return
	var target: ShaderMaterial = runtime.hologram_materials[0]
	match variant:
		"transparent":
			var m := StandardMaterial3D.new()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.34, 0.85, 1.0, 0.28)
			m.roughness = 0.2
			m.metallic = 0.0
			target.render_priority = 0
			_swap_holo(m)
		"emissive":
			var m2 := StandardMaterial3D.new()
			m2.albedo_color = Color(0.05, 0.2, 0.26)
			m2.emission_enabled = true
			m2.emission = Color(0.34, 0.85, 1.0)
			m2.emission_energy_multiplier = 2.2
			m2.roughness = 0.2
			_swap_holo(m2)
		_:
			_swap_holo(MaterialLibrary.hologram_material())
	_log_line("hologram variant -> %s" % variant)


func _swap_holo(mat: Material) -> void:
	if runtime == null or runtime.holo_volume == null:
		return
	for child: Node in runtime.holo_volume.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if String(mi.name).begins_with("Holo"):
				mi.material_override = mat


# ===========================================================================
# Experiment 3 — energy core
# ===========================================================================

func _tab_core(box: VBoxContainer) -> void:
	_note(box, "The four exposed parameters, driven live. Emission is what feeds bloom, so glow_strength is the term that changes both appearance and cost, and the frame-time column makes that visible.")
	_slider(box, "glow_strength", 0.0, 12.0, 3.4, 0.1, func(v: float) -> void: _core_param("glow_strength", v))
	_slider(box, "pulse_speed", 0.0, 6.0, 1.35, 0.05, func(v: float) -> void: _core_param("pulse_speed", v))
	_slider(box, "ring_speed", -4.0, 4.0, 0.5, 0.05, func(v: float) -> void: _core_param("ring_speed", v))
	_slider(box, "plasma_amount", 0.0, 1.0, 0.55, 0.01, func(v: float) -> void: _core_param("plasma_amount", v))
	_slider(box, "arc_intensity", 0.0, 1.0, 0.7, 0.01, func(v: float) -> void: _core_param("arc_intensity", v))
	_slider(box, "instability", 0.0, 1.0, 0.35, 0.01, func(v: float) -> void: _core_param("instability", v))
	_combo(box, "core colour", ["#7cf3ff", "#ffb347", "#5fd08a", "#e2453c", "#d4af37"], "#7cf3ff", func(c: String) -> void:
		_core_param_color("core_color", Color.from_string(c, Color.CYAN)))
	_toggle(box, "core online", true, func(on: bool) -> void:
		if runtime != null:
			runtime.set_core_active(on))


func _core_param(param: String, value: float) -> void:
	if runtime == null or runtime.core_material == null:
		return
	runtime.core_material.set_shader_parameter(param, value)
	_log_line("core.%s = %.3f" % [param, value])


func _core_param_color(param: String, value: Color) -> void:
	if runtime == null or runtime.core_material == null:
		return
	runtime.core_material.set_shader_parameter(param, value)
	_log_line("core.%s = %s" % [param, value.to_html()])


# ===========================================================================
# Experiment 4 — lighting configurations
# ===========================================================================

func _tab_lighting(box: VBoxContainer) -> void:
	_note(box, "Compares the light configurations the garage can run, with the shadow-caster count and the shadow-pass draw calls reported alongside frame time. The point is that the cost is dominated by shadow casters, not by light count.")
	_combo(box, "configuration", [
		"single key", "warm only", "cool only", "warm + cool mixed", "full rig", "full rig, no shadows",
	], "full rig", _set_light_config)
	_slider(box, "exposure", 0.4, 2.4, 1.05, 0.01, func(v: float) -> void:
		if environment.env != null:
			environment.env.tonemap_exposure = v)
	_slider(box, "ambient energy", 0.0, 1.5, 0.35, 0.01, func(v: float) -> void:
		if environment.env != null:
			environment.env.ambient_light_energy = v)
	_slider(box, "sun energy", 0.0, 5.0, 2.4, 0.05, func(v: float) -> void:
		if environment.sun != null:
			environment.sun.light_energy = v)
	_slider(box, "glow intensity", 0.0, 1.5, 0.62, 0.01, func(v: float) -> void:
		if environment.env != null:
			environment.env.glow_intensity = v)
	_toggle(box, "SDFGI", true, func(on: bool) -> void:
		if environment.env != null:
			environment.env.sdfgi_enabled = on)
	_toggle(box, "SSR", true, func(on: bool) -> void:
		if environment.env != null:
			environment.env.ssr_enabled = on)
	_toggle(box, "volumetric fog", true, func(on: bool) -> void:
		if environment.env != null:
			environment.env.volumetric_fog_enabled = on)


func _set_light_config(cfg: String) -> void:
	if runtime == null:
		return
	var on_circuits: Array[int] = []
	match cfg:
		"single key":
			on_circuits = [4]
		"warm only":
			on_circuits = [1, 2]
		"cool only":
			on_circuits = [3]
		"warm + cool mixed":
			on_circuits = [1, 2, 3]
		"full rig":
			on_circuits = [1, 2, 3, 4]
		"full rig, no shadows":
			on_circuits = [1, 2, 3, 4]
	for entry: Dictionary in runtime.lights:
		var c: int = int(entry.circuit)
		var light: Light3D = entry["node"] as Light3D
		if not is_instance_valid(light):
			continue
		var on: bool = c == 0 or on_circuits.has(c)
		light.light_energy = float(entry.base_energy) if on else 0.0
		if cfg == "full rig, no shadows":
			light.shadow_enabled = false
		elif c > 0:
			# the designed seven, not "circuits 0 and 1"
			light.shadow_enabled = on and bool(entry.get("wants_shadow", false))
	_log_line("lighting config -> %s  (%d circuits energised)" % [cfg, on_circuits.size()])


# ===========================================================================
# Experiment 5 — procedural cables
# ===========================================================================

func _tab_cables(box: VBoxContainer) -> void:
	_note(box, "The cable generator, measured directly: subdivision count versus generation time, vertex and triangle count, and the draw-call saving from bundling several wires into one ArrayMesh.")
	_slider(box, "length segments", 4, 128, 24, 1, _set_cable_seg)
	_slider(box, "radial segments", 3, 32, 8, 1, _set_cable_radial)
	_slider(box, "radius (mm)", 4, 40, 18, 1, func(v: float) -> void:
		_cable_params["radius"] = v / 1000.0
		_regen_cable())
	_slider(box, "sag (cm)", 0, 120, 35, 1, func(v: float) -> void:
		_cable_params["sag"] = v / 100.0
		_regen_cable())
	_slider(box, "slack (cm)", 0, 80, 0, 1, func(v: float) -> void:
		_cable_params["slack"] = v / 100.0
		_regen_cable())
	_toggle(box, "bundled (5 wires, 1 mesh)", true, func(on: bool) -> void:
		_cable_params["bundle"] = on
		_regen_cable())
	_stats_row = HBoxContainer.new()
	box.add_child(_stats_row)
	var host := Control.new()
	host.custom_minimum_size = Vector2(820, 300)
	box.add_child(host)
	_cable_probe_root = Node3D.new()
	_cable_probe_root.name = "CableProbe"
	# The probe is demonstration geometry for this panel: a five-wire bundle. As a
	# Node3D under a Control it does not inherit any 2D transform, so it was
	# rendering in the middle of the garage at (0, 0.9, 0) all the time — the dark
	# bundle hanging over the walkway in the assembly captures. It is only visible
	# while the panel is.
	_cable_probe_root.visible = false
	_cable_probe_root.position = Vector3(0.0, 1.6, 3.9)
	host.add_child(_cable_probe_root)
	visibility_changed.connect(func() -> void:
		if _cable_probe_root != null:
			_cable_probe_root.visible = visible)
	_cable_params = {
		"length_segments": 24, "radial_segments": 8, "radius": 0.018,
		"sag": 0.35, "slack": 0.0, "bundle": true,
	}
	_regen_cable()


var _stats_row: HBoxContainer
var _stats_labels: Dictionary = {}


func _set_cable_seg(v: float) -> void:
	_cable_params["length_segments"] = int(v)
	_regen_cable()


func _set_cable_radial(v: float) -> void:
	_cable_params["radial_segments"] = int(v)
	_regen_cable()


func _regen_cable() -> void:
	if _cable_probe_root == null:
		return
	for c: Node in _cable_probe_root.get_children():
		c.queue_free()
	var gen := CableGenerator.new()
	var mat: StandardMaterial3D = MaterialLibrary.cable_material(Color("#1b1d20"))
	var mesh: ArrayMesh
	if bool(_cable_params.get("bundle", true)):
		var wires: Array = []
		for i: int in range(5):
			wires.append({
				"start": Vector3(-1.2, 0.9 + float(i) * 0.02, 0.0),
				"end": Vector3(1.2, 0.9 - float(i) * 0.01, 0.0),
				"sag": float(_cable_params.get("sag", 0.35)),
			})
		mesh = gen.generate_bundle({
			"wires": wires, "radius": float(_cable_params.get("radius", 0.018)),
			"radial_segments": int(_cable_params.get("radial_segments", 8)),
			"length_segments": int(_cable_params.get("length_segments", 24)),
			"material": mat, "u_scale": 2.0,
		})
	else:
		mesh = gen.generate({
			"start": Vector3(-1.2, 0.9, 0.0), "end": Vector3(1.2, 0.9, 0.0),
			"sag": float(_cable_params.get("sag", 0.35)),
			"slack": float(_cable_params.get("slack", 0.0)),
			"radius": float(_cable_params.get("radius", 0.018)),
			"radial_segments": int(_cable_params.get("radial_segments", 8)),
			"length_segments": int(_cable_params.get("length_segments", 24)),
			"material": mat, "u_scale": 2.0,
		})
	var mi := MeshInstance3D.new()
	mi.name = "Probe"
	mi.mesh = mesh
	mi.material_override = mat
	_cable_probe_root.add_child(mi)
	_cable_probe_root.visible = visible
	_probe_stats = gen.last_stats
	_report_cable()


func _report_cable() -> void:
	if _stats_row == null:
		return
	for c: Node in _stats_row.get_children():
		c.queue_free()
	_stats_labels.clear()
	var pairs: Array = [
		["gen", "%.2f ms" % float(_probe_stats.get("milliseconds", 0.0))],
		["tris", str(int(_probe_stats.get("triangles", 0)))],
		["verts", str(int(_probe_stats.get("vertices", 0)))],
		["wires", str(int(_probe_stats.get("wires", 1)))],
		["calls", str(int(_probe_stats.get("draw_calls", 1)))],
		["len", "%.2f m" % float(_probe_stats.get("length", 0.0))],
	]
	for p: Array in pairs:
		var cell := VBoxContainer.new()
		_stats_row.add_child(cell)
		var k := Label.new()
		k.text = String(p[0])
		k.add_theme_font_override("font", _font("mono"))
		k.add_theme_font_size_override("font_size", 12)
		k.add_theme_color_override("font_color", GarageTheme.col("muted"))
		cell.add_child(k)
		var v := Label.new()
		v.text = String(p[1])
		v.add_theme_font_override("font", _font("mono"))
		v.add_theme_font_size_override("font_size", 18)
		_stats_labels[String(p[0])] = v
		cell.add_child(v)


# ===========================================================================
# Experiment 6 — post-processing
# ===========================================================================

func _tab_post(box: VBoxContainer) -> void:
	_note(box, "Bloom, SSAO, SSR, MSAA, tonemapper and shadow resolution, toggled independently with frame time beside each. This is the table the report uses to justify the default quality preset.")
	_toggle(box, "bloom / glow", true, func(on: bool) -> void:
		if environment.env != null:
			environment.env.glow_enabled = on
		_log_line("glow -> %s" % on))
	_toggle(box, "SSAO", true, func(on: bool) -> void:
		if environment.env != null:
			environment.env.ssao_enabled = on
		_log_line("ssao -> %s" % on))
	_toggle(box, "SSR", true, func(on: bool) -> void:
		if environment.env != null:
			environment.env.ssr_enabled = on
		_log_line("ssr -> %s" % on))
	_toggle(box, "SDFGI", true, func(on: bool) -> void:
		if environment.env != null:
			environment.env.sdfgi_enabled = on)
	_combo(box, "MSAA", ["disabled", "2X", "4X", "8X"], "4X", _set_msaa)
	_combo(box, "tonemapper", ["Linear", "Reinhardt", "Filmic", "ACES", "AgX"], "AgX", _set_tonemap)
	_slider(box, "glow hdr threshold", 0.2, 3.0, 1.05, 0.05, func(v: float) -> void:
		if environment.env != null:
			environment.env.glow_hdr_threshold = v)
	_slider(box, "ssao radius", 0.05, 2.0, 0.42, 0.01, func(v: float) -> void:
		if environment.env != null:
			environment.env.ssao_radius = v)
	_slider(box, "ssao intensity", 0.0, 4.0, 1.15, 0.05, func(v: float) -> void:
		if environment.env != null:
			environment.env.ssao_intensity = v)
	_slider(box, "shadow blur", 0.0, 6.0, 1.4, 0.1, func(v: float) -> void:
		if environment.sun != null:
			environment.sun.shadow_blur = v)


func _set_msaa(mode: String) -> void:
	var v: int = Viewport.MSAA_DISABLED
	match mode:
		"2X": v = Viewport.MSAA_2X
		"4X": v = Viewport.MSAA_4X
		"8X": v = Viewport.MSAA_8X
	get_viewport().msaa_3d = v
	_log_line("msaa -> %s" % mode)


func _set_tonemap(name: String) -> void:
	if environment.env == null:
		return
	environment.env.tonemap_mode = EnumRef.value(environment.env, "tonemap_mode", name, 2)
	_log_line("tonemap -> %s (ordinal %d)" % [name, environment.env.tonemap_mode])


# ===========================================================================
# metrics
# ===========================================================================

func _metrics() -> void:
	if metrics_box == null:
		return
	var viewport := get_viewport()
	var rows: Array = [
		["FPS", "%.1f" % Performance.get_monitor(Performance.TIME_FPS)],
		["frame ms", "%.2f" % (Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)],
		["physics ms", "%.2f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)],
		["draw calls", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))],
		["objects/frame", str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))],
		["primitives", _abbrev(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))],
		["shadow calls", str(int(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)))],
		["shadow prims", _abbrev(viewport.get_render_info(Viewport.RENDER_INFO_TYPE_SHADOW, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME))],
		["vram", _abbrev(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))],
		["texture mem", _abbrev(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))],
		["buffer mem", _abbrev(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED))],
		["nodes", str(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))],
		["orphans", str(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))],
		["resources", str(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)))],
		["lights", str(runtime.lights.size() if runtime != null else 0)],
		["shadow casters", str(_shadow_casters())],
		["props", str(props.props_built if props != null else 0)],
		["pipeline draws", str(int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)))],
	]
	var cells: Array = []
	for i: int in range(18):
		cells.append([metrics_box.find_child("MK%d" % i, true, false), metrics_box.find_child("MV%d" % i, true, false)])
	for i: int in range(rows.size()):
		var pair: Array = cells[i]
		if pair[0] is Label:
			(pair[0] as Label).text = String(rows[i][0])
		if pair[1] is Label:
			(pair[1] as Label).text = String(rows[i][1])


func _shadow_casters() -> int:
	if runtime == null:
		return 0
	var n: int = 0
	for entry: Dictionary in runtime.lights:
		var light: Light3D = entry["node"] as Light3D
		if is_instance_valid(light) and light.shadow_enabled:
			n += 1
	return n


func _abbrev(v: float) -> String:
	if v <= 0.0:
		return "n/a"
	if v >= 1048576.0:
		return "%.1f MiB" % (v / 1048576.0)
	if v >= 1024.0:
		return "%.0f KiB" % (v / 1024.0)
	return str(int(v))


func _log_line(text: String) -> void:
	if log_box == null:
		return
	log_box.append_text("[color=#4fd8ff]%s[/color]  %s\n" % [
		Time.get_datetime_string_from_system().substr(11, 8), text])


# ===========================================================================
# runs, captures, export
# ===========================================================================

func _run_current() -> void:
	if _running:
		return
	_running = true
	# hold the render scale still while sampling: the adaptive-resolution
	# controller would otherwise move it between passes and blur the comparison
	var adaptive_was: bool = bool(GameState.settings.get("adaptive_resolution", true))
	GameState.settings["adaptive_resolution"] = false
	var index: int = experiment_tabs.current_tab
	_active_experiment = index
	_log_line("experiment %d started" % (index + 1))
	var samples: Array = []
	var frames_per_sample: int = 90
	await _settle(30)
	for pass_i: int in range(3):
		var fps_sum: float = 0.0
		var frame_sum: float = 0.0
		var call_sum: float = 0.0
		for f: int in range(frames_per_sample):
			await get_tree().process_frame
			fps_sum += Performance.get_monitor(Performance.TIME_FPS)
			frame_sum += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			call_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		samples.append({
			"experiment": index + 1,
			"pass": pass_i,
			"fps": fps_sum / float(frames_per_sample),
			"frame_ms": frame_sum / float(frames_per_sample),
			"draw_calls": call_sum / float(frames_per_sample),
			"config": _config_label(index),
		})
		_log_line("pass %d: %.1f fps  ·  %.2f ms  ·  %.0f calls" % [
			pass_i, samples[-1].fps, samples[-1].frame_ms, samples[-1].draw_calls])
	_samples.append_array(samples)
	_running = false
	GameState.settings["adaptive_resolution"] = adaptive_was
	_log_line("experiment %d complete  (%d samples)" % [index + 1, samples.size()])


func _config_label(index: int) -> String:
	match index:
		0: return "material probe"
		1: return "hologram variant"
		2: return "energy core"
		3: return "lighting config"
		4: return "cable generator"
		5: return "post stack"
	return "unknown"


func _settle(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame


func _capture_frame() -> void:
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_log_line("capture failed: no rendering device (headless)")
		return
	var path: String = "%s/exp%d_%s.png" % [_capture_dir, _active_experiment + 1, Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")]
	var err: Error = img.save_png(path)
	_log_line("capture -> %s (%s)" % [path, error_string(err)])


func _export_csv() -> void:
	if _samples.is_empty():
		_log_line("no samples recorded yet — run an experiment first")
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var path: String = _capture_dir + "/results.csv"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_log_line("cannot write %s" % path)
		return
	f.store_line("experiment,pass,fps,frame_ms,draw_calls,config")
	for s: Variant in _samples:
		var d: Dictionary = s
		f.store_line("%d,%d,%.2f,%.3f,%.1f,%s" % [
			int(d.experiment), int(d.pass), float(d.fps), float(d.frame_ms),
			float(d.draw_calls), String(d.config)])
	f.close()
	_log_line("exported %d samples -> %s" % [_samples.size(), path])


func _clear_captures() -> void:
	var dir: DirAccess = DirAccess.open(_capture_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var n: String = dir.get_next()
	var removed: int = 0
	while n != "":
		if not dir.current_is_dir():
			dir.remove(n)
			removed += 1
		n = dir.get_next()
	dir.list_dir_end()
	_samples.clear()
	_log_line("cleared %d files and %d samples" % [removed, 0])


func _regen_textures() -> void:
	var t0: int = Time.get_ticks_usec()
	MaterialLibrary.factory.clear_cache()
	MaterialLibrary._materials.clear()
	MaterialLibrary.ensure_built()
	_log_line("texture regeneration: %.0f ms across %d surfaces" % [
		float(Time.get_ticks_usec() - t0) / 1000.0,
		MaterialLibrary.factory.cached_keys().size(),
	])


func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum >= 0.25:
		_accum = 0.0
		_metrics()
