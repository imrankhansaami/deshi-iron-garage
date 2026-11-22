class_name Hud
extends CanvasLayer
## The interface layer: objective, prompts, status, notifications, and every
## panel the player can open.
##
## Built in code from the theme GarageTheme produces, so the HUD and the
## in-world screens share one palette and one set of fonts, and the Bengali
## strings in the panels shape correctly through the engine's text stack.
##
## Layout discipline from the brief: "avoid overly decorative UI elements that
## block the 3D environment". So the HUD keeps to the edges — objective top-left,
## status top-right, prompt bottom-centre, notifications bottom-left — and the
## centre of the frame is always the garage. Panels dim the world rather than
## covering it, and every panel is closable with the same key it opened with.

const TAU_H: float = 6.283185307179586

var player: Player
var runtime: GarageRuntime
var director: ObjectiveDirector
var environment: GarageEnvironment
var dressing: GarageDressing
var baker: SignageBaker
var props: PropFactory

var root: Control
var objective_panel: PanelContainer
var objective_label: Label
var objective_hint: Label
var _guide_box: VBoxContainer
var _suit_blk: Dictionary = {}
var _armor_blk: Dictionary = {}

## The guide rows read alike everywhere: [ ] not started / [~] half-way / [x] done.
const MARKS: Array = ["[ ]", "[~]", "[x]"]
const ROW_COLS: Array = ["ink", "amber", "green"]
var progress_bar: ProgressBar
var prompt_label: Label
var prompt_host: Label
var prompt_box: PanelContainer
var carry_hint_label: Label
var status_box: VBoxContainer
var fps_label: Label
var modules_box: VBoxContainer
var notice_stack: VBoxContainer
var crosshair: Control
var dim: ColorRect
var pause_menu: Control
var inventory_panel: Control
var computer_panel: Control
var assembly_panel: Control
var notebook_panel: Control
var inspect_panel: Control
var settings_panel: Control
var schematic_panel: Control
var diagnostics_panel: Control
var toolbox_panel: Control
var help_panel: Control
var thesis_panel: Control
var benchmark_panel: BenchmarkPanel
var open_panels: Array[String] = []
var _notices: Array[Dictionary] = []
var _fps_accum: float = 0.0
var _fps_frames: int = 0
var _fps: float = 0.0
var _show_fps: bool = false
var _last_prompt: String = ""




func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The panels need the baker, the runtime and the director, all of which arrive
	## through attach(). add_child fires _ready before the caller can attach, so
	## building here would construct every panel against null references and abort
	## the world's build coroutine before it ever reports completion.
	if player != null and runtime != null and baker != null:
		_build_all()


func attach(p: Player, rt: GarageRuntime, dir: ObjectiveDirector, env: GarageEnvironment, dr: GarageDressing, bk: SignageBaker, pr: PropFactory) -> void:
	player = p
	runtime = rt
	director = dir
	environment = env
	dressing = dr
	baker = bk
	props = pr
	if is_inside_tree():
		_build_all()


func _update_guides() -> void:
	## The assembly guides, straight on the HUD while each job is open: the
	## step banner, the rows with their states, and the one line that says
	## what to do next. All state lives in the guide modules; this renders it.
	_update_suit_guide()
	_update_armor_guide()


func _update_suit_guide() -> void:
	## The prototype suit's journey: recover → install → sequence → check.
	if _suit_blk.is_empty() or runtime == null:
		return
	var g: Node = runtime.assembly_guide
	var panel: PanelContainer = _suit_blk.get("panel")
	if g == null or not bool(g.tracker_visible()):
		panel.visible = false
		return
	panel.visible = true
	_set_guide_stage(_suit_blk, String(g.stage_line()), bool(g.is_complete()))
	var names: Array = ["frame module", "energy module", "shell module"]
	for i: int in range(3):
		var st: int = int(g.module_state(i))
		var row: Label = _suit_blk["rows"][i]
		row.text = "%s %-13s %s" % [String(MARKS[st]), String(names[i]), String(g.module_detail(i))]
		row.add_theme_color_override("font_color", GarageTheme.col(String(ROW_COLS[st])))
	_suit_blk["next"].text = String(g.next_line())


func _update_armor_guide() -> void:
	## The armour figure's two-stage hand-fitting.
	if _armor_blk.is_empty() or runtime == null:
		return
	var a: Node = runtime.armor
	var panel: PanelContainer = _armor_blk.get("panel")
	if a == null or not bool(a.tracker_visible()):
		panel.visible = false
		return
	panel.visible = true
	_set_guide_stage(_armor_blk, String(a.stage_line()), int(a.locked_count()) >= 4)
	var ids: Array = ["ArmorHelmet", "ArmorChestPlate", "ArmorGauntlet", "ArmorBoot"]
	var names: Array = ["helmet", "chest plate", "gauntlet", "boot"]
	for i: int in range(4):
		var st: int = int(a.part_state(String(ids[i])))
		var row: Label = _armor_blk["rows"][i]
		row.text = "%s %-11s %s" % [String(MARKS[st]), String(names[i]), String(a.part_detail(String(ids[i])))]
		row.add_theme_color_override("font_color", GarageTheme.col(String(ROW_COLS[st])))
	_armor_blk["next"].text = String(a.next_line())


func _set_guide_stage(blk: Dictionary, line: String, done: bool) -> void:
	var stage: Label = blk["stage"]
	stage.text = line
	stage.add_theme_color_override("font_color", GarageTheme.col("green" if done else "amber"))


func _make_guide_block(title: String, row_count: int) -> Dictionary:
	## One guide panel: title, the step banner, the rows, the next-step line.
	## Panel-styled like the objective so the corner reads as one column.
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	_guide_box.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vbox)
	var head := Label.new()
	head.text = title
	head.add_theme_font_override("font", _font("mono"))
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", GarageTheme.col("muted"))
	vbox.add_child(head)
	var stage := Label.new()
	stage.add_theme_font_override("font", _font("mono"))
	stage.add_theme_font_size_override("font_size", 13)
	stage.add_theme_color_override("font_color", GarageTheme.col("amber"))
	stage.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stage.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(stage)
	var rows: Array = []
	for i: int in range(row_count):
		var row := Label.new()
		row.add_theme_font_override("font", _font("mono"))
		row.add_theme_font_size_override("font_size", 14)
		row.add_theme_color_override("font_color", GarageTheme.col("ink"))
		vbox.add_child(row)
		rows.append(row)
	var next_label := Label.new()
	next_label.add_theme_font_override("font", _font("mono"))
	next_label.add_theme_font_size_override("font_size", 14)
	next_label.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next_label.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(next_label)
	return {"panel": panel, "stage": stage, "rows": rows, "next": next_label}


func _build_all() -> void:
	if root != null:
		return
	_build_root()
	_build_hud()
	_build_panels()
	# Guarded: attach() can land after _ready() has already built once, and a
	## duplicate connection fires every handler twice — doubled notifications and
	## doubled audio on a single hover.
	_connect_once(EventBus.objective_changed, _on_objective)
	_connect_once(EventBus.notification_requested, _on_notice)
	_connect_once(EventBus.carry_hint_changed, _on_carry_hint)
	_connect_once(EventBus.ui_panel_opened, open_panel)
	_connect_once(EventBus.ui_panel_closed, close_panel)
	_connect_once(EventBus.interactable_hovered, _on_hover)
	_connect_once(EventBus.interactable_unhovered, _on_unhover)
	_connect_once(EventBus.assembly_stage_changed, _on_stage)
	_connect_once(EventBus.component_collected, _on_component)
	_connect_once(EventBus.power_state_changed, func(_o: bool) -> void: _refresh_status())
	_connect_once(EventBus.computer_state_changed, func(_o: bool) -> void: _refresh_status())
	_connect_once(EventBus.prototype_activated, func() -> void: _on_notice("prototype active", "success"))
	_refresh_status()
	_refresh_modules()


func _connect_once(sig: Signal, handler: Callable) -> void:
	if not sig.is_connected(handler):
		sig.connect(handler)


# ===========================================================================
# root
# ===========================================================================

func _build_root() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	dim = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.03, 0.04, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)


func _build_hud() -> void:
	# --- objective, top left -------------------------------------------
	objective_panel = PanelContainer.new()
	objective_panel.name = "Objective"
	objective_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	objective_panel.position = Vector2(24, 22)
	objective_panel.custom_minimum_size = Vector2(430, 0)
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(objective_panel)
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_panel.add_child(vbox)
	var caption := Label.new()
	caption.text = "OBJECTIVE"
	caption.add_theme_font_override("font", _font("mono"))
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", GarageTheme.col("muted"))
	vbox.add_child(caption)
	objective_label = Label.new()
	objective_label.name = "ObjectiveText"
	objective_label.add_theme_font_size_override("font_size", 21)
	objective_label.add_theme_color_override("font_color", GarageTheme.col("ink"))
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(400, 0)
	vbox.add_child(objective_label)
	objective_hint = Label.new()
	objective_hint.name = "ObjectiveHint"
	objective_hint.add_theme_font_size_override("font_size", 14)
	objective_hint.add_theme_color_override("font_color", GarageTheme.col("cyan_dim"))
	objective_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_hint.custom_minimum_size = Vector2(400, 0)
	objective_hint.visible = false
	vbox.add_child(objective_hint)
	progress_bar = ProgressBar.new()
	progress_bar.name = "CompletionBar"
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.step = 1
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(400, 6)
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(progress_bar)

	# --- the assembly guides, under the objective -------------------------
	## Two panels, the suit's and the armour's, stacked in one column: each
	## appears while its job is open and hides when it is done.
	_guide_box = VBoxContainer.new()
	_guide_box.name = "Guides"
	_guide_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_guide_box.position = Vector2(24, 158)
	_guide_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guide_box.add_theme_constant_override("separation", 10)
	root.add_child(_guide_box)
	_suit_blk = _make_guide_block("EXOSUIT MK-I — ASSEMBLY GUIDE", 3)
	_armor_blk = _make_guide_block("ARMOUR MK-I — ASSEMBLY GUIDE", 4)

	# --- status, top right ----------------------------------------------
	status_box = VBoxContainer.new()
	status_box.name = "Status"
	status_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	status_box.position = Vector2(-260, 22)
	status_box.custom_minimum_size = Vector2(236, 0)
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_box)
	var stat_caption := Label.new()
	stat_caption.text = "WORKSHOP STATE"
	stat_caption.add_theme_font_override("font", _font("mono"))
	stat_caption.add_theme_font_size_override("font_size", 13)
	stat_caption.add_theme_color_override("font_color", GarageTheme.col("muted"))
	status_box.add_child(stat_caption)
	for key: String in ["power", "computer", "shutter", "core", "assembly"]:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.name = "Stat_" + key
		status_box.add_child(row)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.color = GarageTheme.col("line")
		dot.name = key + "_Dot"
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		var lbl := Label.new()
		lbl.text = key.to_upper()
		lbl.add_theme_font_override("font", _font("mono"))
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", GarageTheme.col("muted"))
		lbl.name = key + "_Label"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(lbl)
	fps_label = Label.new()
	fps_label.name = "Fps"
	fps_label.add_theme_font_override("font", _font("mono"))
	fps_label.add_theme_font_size_override("font_size", 14)
	fps_label.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	fps_label.text = ""
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_child(fps_label)

	# --- modules, bottom right ------------------------------------------
	modules_box = VBoxContainer.new()
	modules_box.name = "Modules"
	modules_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	modules_box.position = Vector2(-268, -150)
	modules_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modules_box)

	# --- prompt, bottom centre ------------------------------------------
	## The panel is hidden until something is hovered: an empty panel is a grey
	## bar across the bottom of every capture, which is exactly what the first
	## capture set showed.
	prompt_box = PanelContainer.new()
	prompt_box.name = "PromptBox"
	prompt_box.visible = false
	prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_box.position = Vector2(-220, -118)
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.self_modulate = Color(1, 1, 1, 0.92)
	root.add_child(prompt_box)
	prompt_label = Label.new()
	prompt_label.name = "Prompt"
	prompt_label.add_theme_font_size_override("font_size", 19)
	prompt_label.add_theme_color_override("font_color", GarageTheme.col("ink"))
	prompt_label.custom_minimum_size = Vector2(420, 0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.add_child(prompt_label)
	prompt_host = Label.new()
	prompt_host.name = "PromptHost"
	prompt_host.add_theme_font_size_override("font_size", 13)
	prompt_host.add_theme_color_override("font_color", GarageTheme.col("amber"))
	prompt_host.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.add_child(prompt_host)
	prompt_host.position = Vector2(0, 34)

	# --- carry hint, above the prompt ------------------------------------
	## The mouse controls (pick up, place, rotate, put back) live on their own
	## line so they can appear alongside an E prompt without either replacing the
	## other: "press E to inspect" and "left click to pick up" are both true of
	## the same spanner.
	carry_hint_label = Label.new()
	carry_hint_label.name = "CarryHint"
	carry_hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	carry_hint_label.position = Vector2(-300, -142)
	carry_hint_label.custom_minimum_size = Vector2(600, 0)
	carry_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carry_hint_label.add_theme_font_size_override("font_size", 15)
	carry_hint_label.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	carry_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(carry_hint_label)

	# --- notices, bottom left -------------------------------------------
	notice_stack = VBoxContainer.new()
	notice_stack.name = "Notices"
	notice_stack.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	notice_stack.position = Vector2(24, -190)
	notice_stack.custom_minimum_size = Vector2(460, 0)
	notice_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notice_stack)

	# --- crosshair -------------------------------------------------------
	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	var tick_h := ColorRect.new()
	tick_h.color = Color(0.31, 0.85, 1.0, 0.75)
	tick_h.size = Vector2(10, 2)
	tick_h.position = Vector2(-5, -1)
	tick_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(tick_h)
	var tick_v := ColorRect.new()
	tick_v.color = Color(0.31, 0.85, 1.0, 0.75)
	tick_v.size = Vector2(2, 10)
	tick_v.position = Vector2(-1, -5)
	tick_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.add_child(tick_v)


# ===========================================================================
# panels
# ===========================================================================

func _build_panels() -> void:
	computer_panel = _panel_shell("Computer", "ENGINEERING CONSOLE", "TAB", _computer_body)
	assembly_panel = _panel_shell("Assembly", "PROTOTYPE ASSEMBLY", "E at the platform", _assembly_body)
	inventory_panel = _panel_shell("Inventory", "RECOVERED MODULES", "I", _inventory_body)
	notebook_panel = _panel_shell("Notebook", "ENGINEERING NOTEBOOK", "E on the bench", _notebook_body)
	inspect_panel = _panel_shell("Inspect", "INSPECTION", "F", _inspect_body)
	settings_panel = _panel_shell("Settings", "SETTINGS", "from the pause menu", _settings_body)
	schematic_panel = _panel_shell("Schematic", "HOLOGRAPHIC SCHEMATIC", "E at the table", _schematic_body)
	diagnostics_panel = _panel_shell("Diagnostics", "DIAGNOSTIC PASS", "E at the console", _diagnostics_body)
	toolbox_panel = _panel_shell("Toolbox", "TOOLBOX", "E on the bench", _toolbox_body)
	help_panel = _panel_shell("Help", "CONTROLS", "F1", _help_body)
	thesis_panel = _panel_shell("Thesis", "THE PROJECT, MEASURED", "T", _thesis_body)
	pause_menu = _build_pause()
	benchmark_panel = BenchmarkPanel.new()
	benchmark_panel.name = "Benchmark"
	benchmark_panel.visible = false
	root.add_child(benchmark_panel)
	benchmark_panel.attach(self, runtime, environment, dressing, props, baker)


func _panel_shell(title: String, heading: String, opener: String, body_builder: Callable) -> Control:
	var shell := Control.new()
	shell.name = title
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.visible = false
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shell)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(centre)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(1180, 700)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	centre.add_child(box)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	box.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var header := HBoxContainer.new()
	outer.add_child(header)
	var head_lbl := Label.new()
	head_lbl.text = heading
	head_lbl.add_theme_font_override("font", _font("display"))
	head_lbl.add_theme_font_size_override("font_size", 34)
	head_lbl.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	header.add_child(head_lbl)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var key_lbl := Label.new()
	key_lbl.text = "close: %s / ESC" % opener
	key_lbl.add_theme_font_override("font", _font("mono"))
	key_lbl.add_theme_font_size_override("font_size", 15)
	key_lbl.add_theme_color_override("font_color", GarageTheme.col("muted"))
	header.add_child(key_lbl)
	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.pressed.connect(func() -> void: close_panel(title.to_lower()))
	header.add_child(close_btn)
	outer.add_child(_hr())
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	body_builder.call(body)
	return shell


func _hr() -> Control:
	var line := ColorRect.new()
	line.color = GarageTheme.col("line")
	line.custom_minimum_size = Vector2(0, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _font(which: String) -> Font:
	## CanvasLayer has no theme property of its own, so the theme is taken from the
	## window root, where GarageTheme installs it at boot.
	var t: Theme = get_tree().root.theme
	if t == null:
		t = GarageTheme.build()
		get_tree().root.theme = t
	return t.get_font(which, "") if t.has_font(which, "") else FontFile.new()


func _side_nav(body: HBoxContainer, entries: Array, target: VBoxContainer) -> void:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size = Vector2(230, 0)
	nav.add_theme_constant_override("separation", 8)
	body.add_child(nav)
	var caption := Label.new()
	caption.text = "SECTIONS"
	caption.add_theme_font_override("font", _font("mono"))
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", GarageTheme.col("muted"))
	nav.add_child(caption)
	for e: Array in entries:
		var b := Button.new()
		b.text = String(e[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		var page: VBoxContainer = target
		var section: String = String(e[1])
		b.pressed.connect(func() -> void: _show_section(page, section))
		nav.add_child(b)
		b.set_meta("section", section)


func _show_section(host: VBoxContainer, section: String) -> void:
	for c: Node in host.get_children():
		if c is Control and String(c.name).begins_with("Section"):
			c.visible = String(c.name) == "Section_" + section


func _section(host: VBoxContainer, id: String, title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Section_" + id
	v.add_theme_constant_override("separation", 8)
	host.add_child(v)
	if title != "":
		var lbl := Label.new()
		lbl.text = title
		lbl.add_theme_font_override("font", _font("display"))
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", GarageTheme.col("amber"))
		v.add_child(lbl)
	return v


# ===========================================================================
# panel bodies
# ===========================================================================

func _computer_body(body: HBoxContainer) -> void:
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.name = "ComputerPages"
	body.add_child(pages)
	_side_nav(body, [
		["STATUS", "status"], ["INVENTORY", "inventory"], ["BLUEPRINTS", "blueprints"],
		["DIAGNOSTICS", "diagnostics"], ["POWER", "power"], ["LOG", "log"],
	], pages)
	# status
	var s := _section(pages, "status", "Prototype status")
	_machine_readout(s, "stage", "Assembly stage")
	_machine_readout(s, "progress", "Completion")
	_machine_readout(s, "power", "Main supply")
	_machine_readout(s, "core", "Energy core")
	_machine_readout(s, "holo", "Holographic table")
	# inventory
	var inv := _section(pages, "inventory", "Component inventory")
	inv.add_child(_note("Three fictional modules. Each is a salvaged World A part, and each is described in the notebook."))
	for c: Variant in GameConfig.components:
		var cd: Dictionary = c
		var id: String = String(cd.get("id", ""))
		var row := HBoxContainer.new()
		inv.add_child(row)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(6, 40)
		swatch.color = GameConfig.component_slot_color(id)
		row.add_child(swatch)
		var txt := VBoxContainer.new()
		row.add_child(txt)
		var name_lbl := Label.new()
		name_lbl.text = String(cd.get("label", id))
		name_lbl.add_theme_font_size_override("font_size", 19)
		txt.add_child(name_lbl)
		var story := Label.new()
		story.text = String(cd.get("story", ""))
		story.add_theme_font_size_override("font_size", 14)
		story.add_theme_color_override("font_color", GarageTheme.col("muted"))
		story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story.custom_minimum_size = Vector2(560, 0)
		txt.add_child(story)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var state := Label.new()
		state.name = "InvState_" + id
		state.add_theme_font_override("font", _font("mono"))
		state.add_theme_font_size_override("font_size", 17)
		state.text = "RECOVERED" if GameState.has_component(id) else "MISSING"
		state.add_theme_color_override("font_color", GarageTheme.col("green") if GameState.has_component(id) else GarageTheme.col("red"))
		row.add_child(state)
	# blueprints
	var bp := _section(pages, "blueprints", "Blueprint previews")
	bp.add_child(_note("The schematic is the same part list the assembly station uses, so the drawing and the build agree."))
	var grid := GridContainer.new()
	grid.columns = 2
	bp.add_child(grid)
	for pid: String in ExosuitFactory.PART_IDS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(300, 96)
		grid.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var t := Label.new()
		t.text = pid.to_upper()
		t.add_theme_font_override("font", _font("mono"))
		t.add_theme_font_size_override("font_size", 17)
		t.add_theme_color_override("font_color", GarageTheme.col("cyan"))
		cv.add_child(t)
		var off: Vector3 = ExosuitFactory.home_offset(pid)
		var d := Label.new()
		d.text = "home  x %+0.2f  y %+0.2f  z %+0.2f" % [off.x, off.y, off.z]
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", GarageTheme.col("muted"))
		cv.add_child(d)
		var m := Label.new()
		var module_of: String = _module_for_part(pid)
		m.text = "module  %s" % module_of
		m.add_theme_font_size_override("font_size", 13)
		m.add_theme_color_override("font_color", GarageTheme.col("gold"))
		cv.add_child(m)
	# diagnostics
	var dg := _section(pages, "diagnostics", "Diagnostic information")
	dg.add_child(_note("Derived from the actual build state, so a loaded save reproduces the same figures."))
	for pair: Array in [
		["frame integrity", "frame"], ["core buffer", "core"], ["thermal envelope", "thermal"],
		["optics", "optics"], ["shell bonding", "shell"], ["joint backlash", "backlash"],
	]:
		_machine_readout(dg, String(pair[1]), String(pair[0]))
	# power
	var pw := _section(pages, "power", "Power status")
	pw.add_child(_note("The four circuits the switchboard and the MCB row can isolate."))
	for c: int in range(1, 5):
		var row := HBoxContainer.new()
		pw.add_child(row)
		var lbl := Label.new()
		lbl.text = "circuit %d   %s" % [c, _circuit_name(c)]
		lbl.add_theme_font_override("font", _font("mono"))
		lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(lbl)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		var tog := Button.new()
		tog.toggle_mode = true
		tog.text = "ENERGISE"
		tog.button_pressed = bool(runtime.circuits_on.get(c, false))
		tog.toggled.connect(func(on: bool) -> void:
			if runtime.power_on:
				runtime.toggle_circuit(c))
		row.add_child(tog)
	# log
	var lg := _section(pages, "log", "System logs")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 240)
	lg.add_child(scroll)
	var log_box := VBoxContainer.new()
	log_box.name = "LogBox"
	scroll.add_child(log_box)
	var refresh := Button.new()
	refresh.text = "REFRESH LOG"
	refresh.pressed.connect(func() -> void: _rebuild_log(log_box))
	lg.add_child(refresh)


func _machine_readout(host: VBoxContainer, key: String, label: String) -> void:
	var row := HBoxContainer.new()
	row.name = "Readout_" + key
	host.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_override("font", _font("mono"))
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", GarageTheme.col("muted"))
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var v := Label.new()
	v.name = "Value_" + key
	v.add_theme_font_override("font", _font("mono"))
	v.add_theme_font_size_override("font_size", 17)
	v.add_theme_color_override("font_color", GarageTheme.col("ink"))
	v.text = "--"
	row.add_child(v)


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", GarageTheme.col("muted"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(600, 0)
	return l


func _module_for_part(part_id: String) -> String:
	for mid: String in ["frame_module", "energy_module", "armour_shell"]:
		if part_id in ExosuitFactory.module_parts(mid):
			return GameConfig.component_short(mid)
	return "-"


func _rebuild_log(box: VBoxContainer) -> void:
	for c: Node in box.get_children():
		c.queue_free()
	if runtime == null:
		return
	var lines: PackedStringArray = runtime.log_lines
	for i: int in range(maxi(0, lines.size() - 60), lines.size()):
		var l := Label.new()
		l.text = "%03d  %s" % [i + 1, lines[i]]
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", GarageTheme.col("cyan_dim"))
		box.add_child(l)


func _circuit_name(c: int) -> String:
	match c:
		1: return "tube lights (World A)"
		2: return "bench task lamps"
		3: return "desk and bulb"
		4: return "reactor zone"
	return "unknown"


func _assembly_body(body: HBoxContainer) -> void:
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.name = "AssemblyPages"
	body.add_child(pages)
	_side_nav(body, [["MODULES", "modules"], ["ARMOUR", "armour"], ["SEQUENCE", "sequence"], ["SLOTS", "slots"]], pages)
	# modules: the three slots the player installs
	var mods := _section(pages, "modules", "Install the salvaged modules")
	_assembly_slots = VBoxContainer.new()
	mods.add_child(_assembly_slots)
	var run := Button.new()
	run.name = "RunAssembly"
	run.text = "START ASSEMBLY SEQUENCE"
	run.add_theme_font_size_override("font_size", 20)
	run.pressed.connect(_on_run_assembly)
	mods.add_child(run)
	var status_lbl := Label.new()
	status_lbl.name = "AssemblyStatus"
	status_lbl.add_theme_font_override("font", _font("mono"))
	status_lbl.add_theme_font_size_override("font_size", 17)
	status_lbl.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	mods.add_child(status_lbl)
	_assembly_status = status_lbl
	# sequence
	var seq := _section(pages, "sequence", "Attachment order")
	seq.add_child(_note("The order the assembly animation uses. Driven by one Tween chain in GarageRuntime.run_assembly()."))
	var order: Array[String] = ExosuitFactory.attach_order()
	var grid := GridContainer.new()
	grid.columns = 3
	seq.add_child(grid)
	for i: int in range(order.size()):
		var l := Label.new()
		l.text = "%02d  %s" % [i + 1, order[i]]
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", GarageTheme.col("ink"))
		grid.add_child(l)
	# armour: the four spares test-fitted onto the practice figure (plan A)
	var arm := _section(pages, "armour", "The armour figure's spares")
	arm.add_child(_note("Test-fit the spare shells by hand — carry one to the figure, E to seat it — then one more E bolts the kit down, one clack per part. The figure's base ring counts the bolts; the fourth lights the figure."))
	_armor_slots = VBoxContainer.new()
	arm.add_child(_armor_slots)
	# slots
	var slots := _section(pages, "slots", "Module to part map")
	for mid: String in ["frame_module", "energy_module", "armour_shell"]:
		var row := HBoxContainer.new()
		slots.add_child(row)
		var t := Label.new()
		t.text = "%-16s" % GameConfig.component_short(mid)
		t.add_theme_font_override("font", _font("mono"))
		t.add_theme_color_override("font_color", GameConfig.component_slot_color(mid))
		row.add_child(t)
		var p := Label.new()
		p.text = "  ->  " + ", ".join(ExosuitFactory.module_parts(mid))
		p.add_theme_font_size_override("font_size", 15)
		p.add_theme_color_override("font_color", GarageTheme.col("muted"))
		row.add_child(p)


var _assembly_slots: VBoxContainer
var _armor_slots: VBoxContainer
var _assembly_status: Label


func _on_run_assembly() -> void:
	if runtime == null:
		return
	if not GameState.all_components_collected():
		_on_notice("cannot start yet — three modules required before assembly; their crates are marked by the yellow arrows", "error")
		return
	if GameState.assembly_stage == GameState.AssemblyStage.ACTIVE:
		_on_notice("prototype already complete", "info")
		return
	runtime.run_assembly()


func _inventory_body(body: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(box)
	box.add_child(_note("Recovered modules. Nothing here is a weapon, a battery build, or a wiring instruction — the three items are fictional game components assembled by an interface."))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	box.add_child(grid)
	for c: Variant in GameConfig.components:
		var cd: Dictionary = c
		var id: String = String(cd.get("id", ""))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(340, 260)
		grid.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 5)
		bar.color = GameConfig.component_slot_color(id)
		cv.add_child(bar)
		var t := Label.new()
		t.text = String(cd.get("label", id))
		t.add_theme_font_override("font", _font("display"))
		t.add_theme_font_size_override("font_size", 20)
		t.add_theme_color_override("font_color", GarageTheme.col("ink"))
		cv.add_child(t)
		var s := Label.new()
		s.text = String(cd.get("story", ""))
		s.add_theme_font_size_override("font_size", 14)
		s.add_theme_color_override("font_color", GarageTheme.col("muted"))
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(320, 0)
		cv.add_child(s)
		for row: Variant in GameConfig.component_spec(id):
			var r: Array = row
			var l := Label.new()
			l.text = "%-22s %s" % [String(r[0]), String(r[1])]
			l.add_theme_font_override("font", _font("mono"))
			l.add_theme_font_size_override("font_size", 13)
			l.add_theme_color_override("font_color", GarageTheme.col("cyan_dim"))
			cv.add_child(l)


func _notebook_body(body: HBoxContainer) -> void:
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.name = "NotebookPages"
	body.add_child(pages)
	_side_nav(body, [["PAGE 4", "p4"], ["PARTS", "parts"], ["RULES", "rules"], ["LETTER", "letter"]], pages)
	var p4 := _section(pages, "p4", "প্রথম নকশা")
	var tex := TextureRect.new()
	tex.custom_minimum_size = Vector2(560, 420)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = baker.bake_placeholder(Vector2i(1024, 768), Color("efe7cf"))
	p4.add_child(tex)
	# the page is baked asynchronously: bake() needs two rendered frames and this
	## panel is built synchronously, so the placeholder holds the layout open
	baker.bake_async(_notebook_page_spec(), "notebook_page", func(baked: ImageTexture) -> void:
		if baked != null and is_instance_valid(tex):
			tex.texture = baked)
	var cap := Label.new()
	cap.text = "sheet 4 of 84  ·  tea ring over the margin  ·  the dimensions are the ones the stand uses"
	cap.add_theme_font_size_override("font_size", 14)
	cap.add_theme_color_override("font_color", GarageTheme.col("muted"))
	p4.add_child(cap)
	var parts := _section(pages, "parts", "Parts list")
	parts.add_child(_note("Fourteen named parts, three modules. The suit is posed on a static skeleton; there is no rig, which is the honest scope for one student."))
	var grid := GridContainer.new()
	grid.columns = 2
	parts.add_child(grid)
	for pid: String in ExosuitFactory.PART_IDS:
		var l := Label.new()
		l.text = "%-16s  %s" % [pid, _module_for_part(pid)]
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 15)
		grid.add_child(l)
	var rules := _section(pages, "rules", "What MK-I is allowed to do")
	for line: String in [
		"Standing test only. The suit is bolted to the stand and never leaves it.",
		"No flight, no load bearing, no weapon, no hydraulics under pressure.",
		"The core is a display model. There is no live high voltage anywhere in the build.",
		"The point of MK-I is that it exists, not that it works.",
	]:
		var l := Label.new()
		l.text = "·  " + line
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", GarageTheme.col("ink"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(620, 0)
		rules.add_child(l)
	var letter := _section(pages, "letter", "To whoever finds this")
	letter.add_child(_bengali_note("স্বপ্নের গ্যারেজ — এই ছাদেই শেখা শুরু হল।"))
	letter.add_child(_bengali_note("নিজের প্রযুক্তি, নিজের শক্তি।"))
	var l2 := Label.new()
	l2.text = "I do not have a laboratory. I have a roof, a bench, two dead IPS cells, a scrapped motorcycle and a computer that has been repaired four times. None of this is impressive as engineering. It is impressive as a beginning, and that is the whole argument: you do not need an expensive laboratory to start thinking like an inventor."
	l2.add_theme_font_size_override("font_size", 18)
	l2.add_theme_color_override("font_color", GarageTheme.col("ink"))
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(660, 0)
	letter.add_child(l2)


func _bengali_note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font("bangla"))
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", GarageTheme.col("amber"))
	return l


func _notebook_page_spec() -> Dictionary:
	return {
		"size": Vector2i(1024, 768), "transparent": false, "bg": "#efe7cf",
		"layers": [
			{"type": "grid", "pos": Vector2(30, 90), "sz": Vector2(964, 620), "step": 32.0, "color": Color(0.35, 0.45, 0.6, 0.2)},
			{"type": "text", "pos": Vector2(30, 20), "size": 56, "color": "#2a3a5a", "text": "প্রথম নকশা", "font": "bangla"},
			{"type": "text", "pos": Vector2(700, 34), "size": 26, "color": "#6a5a4a", "text": "MK-I  ·  sheet 4 of 84", "font": "mono"},
			{"type": "circle", "center": Vector2(512, 250), "radius": 52, "color": "#2a3a5a", "filled": false, "width": 3.0},
			{"type": "poly", "points": [Vector2(458, 306), Vector2(566, 306), Vector2(586, 448), Vector2(438, 448)], "color": "#2a3a5a", "filled": false, "width": 4.0},
			{"type": "line", "from": Vector2(438, 318), "to": Vector2(352, 470), "color": "#2a3a5a", "width": 3.0},
			{"type": "line", "from": Vector2(586, 318), "to": Vector2(672, 470), "color": "#2a3a5a", "width": 3.0},
			{"type": "line", "from": Vector2(466, 448), "to": Vector2(452, 660), "color": "#2a3a5a", "width": 3.0},
			{"type": "line", "from": Vector2(558, 448), "to": Vector2(572, 660), "color": "#2a3a5a", "width": 3.0},
			{"type": "circle", "center": Vector2(512, 372), "radius": 30, "color": "#8a2a1a", "filled": false, "width": 4.0},
			{"type": "circle", "center": Vector2(512, 372), "radius": 13, "color": "#8a2a1a", "filled": true},
			{"type": "line", "from": Vector2(700, 200), "to": Vector2(700, 660), "color": "#8a2a1a", "width": 2.0},
			{"type": "line", "from": Vector2(692, 200), "to": Vector2(708, 200), "color": "#8a2a1a", "width": 2.0},
			{"type": "line", "from": Vector2(692, 660), "to": Vector2(708, 660), "color": "#8a2a1a", "width": 2.0},
			{"type": "text", "pos": Vector2(712, 420), "size": 28, "color": "#8a2a1a", "text": "1860 mm", "font": "mono"},
			{"type": "line", "from": Vector2(352, 690), "to": Vector2(672, 690), "color": "#8a2a1a", "width": 2.0},
			{"type": "text", "pos": Vector2(470, 700), "size": 28, "color": "#8a2a1a", "text": "740 mm", "font": "mono"},
			{"type": "text", "pos": Vector2(40, 500), "size": 34, "color": "#2a3a5a", "text": "ফ্রেম: পুরনো বাইকের ঝালাই", "font": "bangla"},
			{"type": "text", "pos": Vector2(40, 545), "size": 34, "color": "#2a3a5a", "text": "শক্তি: আইপিসি ভাঙা খন্ড", "font": "bangla"},
			{"type": "text", "pos": Vector2(40, 590), "size": 34, "color": "#2a3a5a", "text": "খোলস: ছাদার কলজ পাথর", "font": "bangla"},
			{"type": "text", "pos": Vector2(40, 640), "size": 24, "color": "#6a5a4a", "text": "standing test only — no flight, no load", "font": "mono"},
			{"type": "circle", "center": Vector2(880, 620), "radius": 58, "color": Color(0.62, 0.44, 0.24, 0.35), "filled": false, "width": 9.0},
		],
	}


func _inspect_body(body: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(box)
	_inspect_title = Label.new()
	_inspect_title.add_theme_font_override("font", _font("display"))
	_inspect_title.add_theme_font_size_override("font_size", 30)
	_inspect_title.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	box.add_child(_inspect_title)
	_inspect_area = Label.new()
	_inspect_area.add_theme_font_override("font", _font("mono"))
	_inspect_area.add_theme_font_size_override("font_size", 15)
	_inspect_area.add_theme_color_override("font_color", GarageTheme.col("amber"))
	box.add_child(_inspect_area)
	box.add_child(_hr())
	_inspect_body_lbl = Label.new()
	_inspect_body_lbl.add_theme_font_size_override("font_size", 19)
	_inspect_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_body_lbl.custom_minimum_size = Vector2(700, 0)
	box.add_child(_inspect_body_lbl)
	_inspect_lore = Label.new()
	_inspect_lore.add_theme_font_size_override("font_size", 16)
	_inspect_lore.add_theme_color_override("font_color", GarageTheme.col("muted"))
	_inspect_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_lore.custom_minimum_size = Vector2(700, 0)
	box.add_child(_inspect_lore)
	box.add_child(_hr())
	_inspect_spec = GridContainer.new()
	_inspect_spec.columns = 2
	_inspect_spec.add_theme_constant_override("h_separation", 24)
	box.add_child(_inspect_spec)
	_inspect_progress = ProgressBar.new()
	_inspect_progress.name = "InspectProgress"
	_inspect_progress.min_value = 0
	_inspect_progress.max_value = 100
	_inspect_progress.show_percentage = true
	_inspect_progress.custom_minimum_size = Vector2(700, 22)
	_inspect_progress.visible = false
	box.add_child(_inspect_progress)


var _inspect_title: Label
var _inspect_area: Label
var _inspect_body_lbl: Label
var _inspect_lore: Label
var _inspect_spec: GridContainer
var _inspect_progress: ProgressBar


func _settings_body(body: HBoxContainer) -> void:
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.name = "SettingsPages"
	body.add_child(pages)
	_side_nav(body, [["CONTROLS", "controls"], ["GRAPHICS", "graphics"], ["AUDIO", "audio"], ["PRESETS", "presets"]], pages)
	var ctrl := _section(pages, "controls", "Controls")
	for pair: Array in [
		["mouse sensitivity", "mouse_sensitivity", 0.0006, 0.006, 0.0001],
		["walk speed", "walk_speed", 1.6, 6.0, 0.05],
		["field of view", "fov", 65.0, 100.0, 1.0],
	]:
		_slider_row(ctrl, pair)
	_toggle_row(ctrl, "invert_y", "invert vertical look")
	var gfx := _section(pages, "graphics", "Graphics")
	_combo_row(gfx, "quality", ["low", "medium", "high"], "quality preset")
	for pair: Array in [["bloom", "glow"], ["ssao", "ambient occlusion"], ["shadows", "real-time shadows"], ["rain", "rain on the tin roof"]]:
		_toggle_row(gfx, String(pair[0]), String(pair[1]))
	var aud := _section(pages, "audio", "Audio")
	for pair: Array in [
		["master_volume", "master"], ["ambience_volume", "ambience"],
		["effects_volume", "effects"], ["ui_volume", "interface"],
	]:
		_slider_row(aud, [String(pair[1]), String(pair[0]), 0.0, 1.0, 0.01])
	var pre := _section(pages, "presets", "Workshop presets")
	pre.add_child(_note("The garage is themed by data, not code: switching a preset rebuilds the shell dimensions, wall and roof style, exterior tint and signage from data/garage_config.json. Gameplay is untouched."))
	var opts: Array = []
	var presets: Dictionary = GameConfig.config.get("presets", {})
	for pid: String in presets:
		opts.append("%s  (%s)" % [pid, String((presets[pid] as Dictionary).get("label", ""))])
	_combo_row(pre, "preset", opts, "active preset")
	var apply := Button.new()
	apply.text = "WRITE PRESET TO CONFIG"
	apply.pressed.connect(_on_apply_preset)
	pre.add_child(apply)


var _setting_widgets: Dictionary = {}


func _slider_row(host: VBoxContainer, spec: Array) -> void:
	var row := HBoxContainer.new()
	host.add_child(row)
	var l := Label.new()
	l.text = String(spec[0])
	l.add_theme_font_override("font", _font("mono"))
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = float(spec[2])
	s.max_value = float(spec[3])
	s.step = float(spec[4])
	s.value = float(GameState.settings.get(String(spec[1]), s.value))
	s.custom_minimum_size = Vector2(300, 18)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	var v := Label.new()
	v.add_theme_font_override("font", _font("mono"))
	v.add_theme_font_size_override("font_size", 15)
	v.text = "%.3f" % s.value
	row.add_child(v)
	s.value_changed.connect(func(nv: float) -> void:
		GameState.settings[String(spec[1])] = nv
		v.text = "%.3f" % nv
		_on_setting_changed(String(spec[1])))
	_setting_widgets[String(spec[1])] = s


func _toggle_row(host: VBoxContainer, key: String, label: String) -> void:
	var row := HBoxContainer.new()
	host.add_child(row)
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = bool(GameState.settings.get(key, true))
	cb.toggled.connect(func(on: bool) -> void:
		GameState.settings[key] = on
		_on_setting_changed(key))
	row.add_child(cb)
	_setting_widgets[key] = cb


func _combo_row(host: VBoxContainer, key: String, options: Array, label: String) -> void:
	var row := HBoxContainer.new()
	host.add_child(row)
	var l := Label.new()
	l.text = label
	l.add_theme_font_override("font", _font("mono"))
	l.add_theme_font_size_override("font_size", 16)
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var opt := OptionButton.new()
	for o: Variant in options:
		opt.add_item(String(o))
	var want: String = String(GameState.settings.get(key, ""))
	var current: int = -1
	for oi: int in range(opt.get_item_count()):
		if opt.get_item_text(oi) == want:
			current = oi
			break
	opt.selected = maxi(current, 0)
	opt.item_selected.connect(func(i: int) -> void:
		GameState.settings[key] = opt.get_item_text(i)
		_on_setting_changed(key))
	row.add_child(opt)
	_setting_widgets[key] = opt


func _on_setting_changed(key: String) -> void:
	match key:
		"mouse_sensitivity", "invert_y", "walk_speed", "sprint_multiplier", "fov":
			if player != null:
				player.refresh_settings()
		"master_volume", "ambience_volume", "effects_volume", "ui_volume":
			AudioBank.refresh_settings()
		"quality", "bloom", "ssao", "shadows", "rain":
			if environment != null:
				environment.apply_quality()
				if runtime != null:
					runtime.set_rain(bool(GameState.settings.get("rain", true)))
	GameState.save_settings()


func _on_apply_preset() -> void:
	var widget: Variant = _setting_widgets.get("preset", null)
	if widget == null or not (widget is OptionButton):
		return
	var text: String = (widget as OptionButton).get_item_text((widget as OptionButton).selected)
	var pid: String = text.split(" ")[0]
	GameConfig.config["active_preset"] = pid
	GameState.save_settings()
	_on_notice("preset %s written — restart the garage to rebuild" % pid, "info")


func _schematic_body(body: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(box)
	box.add_child(_note("The hologram on the design table is a shader, not a video: four multiplied terms — fresnel shell, world-space scanlines, an object-space interference grid and a coarse temporal flicker — plus a travelling acquisition band."))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	box.add_child(grid)
	for pair: Array in [
		["fresnel_power", "grazing-angle glow exponent"],
		["scan_density", "scanlines per metre"],
		["scan_band_speed", "acquisition band rate"],
		["grid_scale", "interference grid density"],
		["flicker_amount", "projector instability"],
		["glow_strength", "emission into bloom"],
	]:
		var row := HBoxContainer.new()
		grid.add_child(row)
		var l := Label.new()
		l.text = String(pair[0])
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 15)
		l.custom_minimum_size = Vector2(180, 0)
		l.add_theme_color_override("font_color", GarageTheme.col("cyan_dim"))
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 4.0
		s.step = 0.01
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.value_changed.connect(func(v: float) -> void: _drive_hologram(String(pair[0]), v))
		row.add_child(s)
	var wire := CheckBox.new()
	wire.text = "wireframe-only mode"
	wire.toggled.connect(func(on: bool) -> void: _drive_hologram("wireframe_only", 1.0 if on else 0.0))
	box.add_child(wire)


func _drive_hologram(param: String, value: float) -> void:
	if runtime == null:
		return
	for mat: ShaderMaterial in runtime.hologram_materials:
		if mat != null:
			mat.set_shader_parameter(param, value)


func _diagnostics_body(body: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(box)
	box.add_child(_note("The testing corner console. Values are derived from the build state, so the panel cannot disagree with the assembly."))
	_diag_rows = VBoxContainer.new()
	box.add_child(_diag_rows)
	var run := Button.new()
	run.text = "RUN DIAGNOSTIC PASS"
	run.pressed.connect(func() -> void:
		if runtime != null:
			runtime.run_diagnostics())
	box.add_child(run)


var _diag_rows: VBoxContainer


func _help_body(body: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(box)
	var keys: Array = [
		["W A S D", "move"], ["Shift", "sprint"], ["Ctrl", "walk slowly"], ["Space", "step up"],
		["Mouse", "look"], ["E", "interact"], ["F", "inspect"], ["I", "modules"],
		["Tab", "engineering console"], ["Esc", "pause / close panel"],
		["F1", "this screen"], ["F6", "graphics bench"], ["F9", "jump to finished garage (demo)"],
		["T", "thesis panel — the measured claims"], ["R", "reset the demo to morning"],
		["1-9, 0, [ ]", "viewpoint tour"], ["\\", "return to where you stood"],
		["GUIDE", "big yellow arrows mark every assembly part — the next step's arrow rises on a light column"],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	box.add_child(grid)
	for k: Array in keys:
		var l := Label.new()
		l.text = "%-12s  %s" % [String(k[0]), String(k[1])]
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", GarageTheme.col("ink"))
		grid.add_child(l)
	box.add_child(_hr())
	box.add_child(_note("The experience is about 10-15 minutes. Everything is revisitable: restore power, read the notebook, recover the three modules, open the assembly interface, then run the diagnostic pass. The graphics bench (F6) holds the four shader and geometry experiments the project claims, with live parameter control and real Performance counters."))


func _thesis_body(body: HBoxContainer) -> void:
	## Plan D: the panel a viva asks for — what the project is, what it measured,
	## and the keys that drive the presentation. Live counts are read at open
	## time; the ranged figures are the published measurements from the capture
	## runs of 21-22 November 2026 (docs/EXPERIMENTS.md).
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	body.add_child(box)
	box.add_child(_note("স্বপ্নের গ্যারেজ · DESHI IRON GARAGE — a procedural Bangladeshi repair workshop built entirely from code: no imported art, every texture synthesised at load, every sound a PCM recipe."))
	box.add_child(_note("The workshop builds a powered exosuit from the machines it repairs — frame, energy and shell modules, tested on a deck with a real boundary and a real emergency stop. A load-bearing demonstration, not a weapon. The armour figure is the shop's own unbranded build, and the stations say so in-world."))
	box.add_child(_hr())
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	box.add_child(grid)
	var breakdown: Dictionary = dressing.dressing_breakdown()
	var rows: Array = [
		["build, full garage", "9.2–18.2 s by machine load (best measured 9 196 ms)"],
		["surface synthesis", "34 recipes; per-texel pass banded across the worker pool, output bit-identical (MD5)"],
		["props built", "%d in 140 kinds" % props.props_built],
		["placements / stations", "%d placed · %d interactable stations" % [int(breakdown.get("total", 0)), runtime.station_count()]],
		["lights / screens", "%d lights (7 shadow casters) · %d live SubViewports" % [runtime.lights.size(), runtime.screens.size()]],
		["carriable items", "213 — every loose thing, plus all 14 suit parts, one by one"],
		["overlap audit", "0 genuine clashes · 3 documented designed contacts"],
		["capture harness", "20 fixed viewpoints, all healthy, with luminance and perf logged per shot"],
		["rendering", "Forward+ · SDFGI · SSR · SSAO · volumetric fog · AgX — all live-switchable in the F6 bench"],
		["drive it with", "E use · F inspect · I modules · TAB console · F6 bench · T this panel · R demo reset"],
		["the tour", "1-9 and 0 jump to viewpoints · [ ] step through all 20 · \\ returns to your spot"],
	]
	for r: Array in rows:
		var l := Label.new()
		l.text = "%-22s  %s" % [String(r[0]), String(r[1])]
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", GarageTheme.col("ink"))
		grid.add_child(l)
	box.add_child(_hr())
	box.add_child(_note("The story of the room — its notebook, crates, walls and stand — is written twice, in English and Bengali: docs/STORY.md and docs/STORY_BN.md. Every photograph in the room is licence-cleared; docs/ASSET_LICENSES.md lists each one."))


func _build_pause() -> Control:
	var shell := Control.new()
	shell.name = "Pause"
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.visible = false
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(shell)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.78)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.add_child(centre)
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	centre.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	box.add_child(v)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_override("font", _font("display"))
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", GarageTheme.col("cyan"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = "দেেশি আয়রন গ্যারেজ"
	sub.add_theme_font_override("font", _font("bangla"))
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", GarageTheme.col("amber"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_hr())
	for pair: Array in [
		["RESUME", func() -> void: _resume()],
		["MODULES", func() -> void: open_panel("inventory")],
		["WORKSTATION", func() -> void: open_panel("computer")],
		["SETTINGS", func() -> void: open_panel("settings")],
		["GRAPHICS BENCH", func() -> void: open_panel("benchmark")],
		["RESTART GARAGE", func() -> void: _restart()],
		["MAIN MENU", func() -> void: _to_menu()],
		["QUIT", func() -> void: get_tree().quit()],
	]:
		var b := Button.new()
		b.text = String(pair[0])
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(pair[1] as Callable)
		v.add_child(b)
	return shell


func _resume() -> void:
	close_panel("pause")


func _restart() -> void:
	GameState.reset_run()
	GameState.save_run()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	GameState.save_run()
	get_tree().paused = false
	GameState.has_started = false
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")


# ===========================================================================
# panel management
# ===========================================================================

func open_panel(name: String) -> void:
	var target: Control = _panel_for(name)
	if target == null:
		return
	if name == "pause" and player != null:
		player.paused = true
		get_tree().paused = true
	target.visible = true
	if not open_panels.has(name):
		open_panels.append(name)
	dim.color = Color(0.02, 0.03, 0.04, 0.55)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_panel(name)
	EventBus.ui_panel_opened.emit(name)
	if name != "pause":
		AudioBank.play("ui_confirm")


func close_panel(name: String) -> void:
	var target: Control = _panel_for(name)
	if target == null:
		return
	target.visible = false
	open_panels.erase(name)
	if open_panels.is_empty():
		dim.color = Color(0.02, 0.03, 0.04, 0.0)
		if player != null and not player.paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if name == "pause" and player != null:
		player.paused = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.ui_panel_closed.emit(name)


func _panel_for(name: String) -> Control:
	match name:
		"computer", "workstation": return computer_panel
		"assembly": return assembly_panel
		"inventory", "modules": return inventory_panel
		"notebook": return notebook_panel
		"inspect": return inspect_panel
		"settings": return settings_panel
		"schematic", "monitor": return schematic_panel
		"diagnostics": return diagnostics_panel
		"toolbox": return toolbox_panel
		"help": return help_panel
		"thesis": return thesis_panel
		"benchmark": return benchmark_panel
		"pause": return pause_menu
	return null


func _refresh_panel(name: String) -> void:
	match name:
		"computer":
			_rebuild_log(computer_panel.find_child("LogBox", true, false) as VBoxContainer)
			_update_readouts()
			_update_inventory_states()
		"assembly":
			_rebuild_assembly_slots()
			_rebuild_armor_slots()
		"diagnostics":
			_rebuild_diag_rows()
		"inspect":
			_fill_inspect()
		"toolbox":
			_rebuild_toolbox()
		"benchmark":
			benchmark_panel.refresh()


func _rebuild_assembly_slots() -> void:
	if _assembly_slots == null:
		return
	for c: Node in _assembly_slots.get_children():
		c.queue_free()
	for c: Variant in GameConfig.components:
		var cd: Dictionary = c
		var id: String = String(cd.get("id", ""))
		var row := HBoxContainer.new()
		_assembly_slots.add_child(row)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(6, 44)
		swatch.color = GameConfig.component_slot_color(id)
		row.add_child(swatch)
		var v := VBoxContainer.new()
		row.add_child(v)
		var t := Label.new()
		t.text = String(cd.get("label", id))
		t.add_theme_font_size_override("font_size", 19)
		t.add_theme_color_override("font_color", GarageTheme.col("ink"))
		v.add_child(t)
		var s := Label.new()
		s.text = String(cd.get("story", ""))
		s.add_theme_font_size_override("font_size", 14)
		s.add_theme_color_override("font_color", GarageTheme.col("muted"))
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.custom_minimum_size = Vector2(520, 0)
		v.add_child(s)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		var installed: bool = GameState.component_installed(id)
		var stage_now: int = int(GameState.assembly_stage)
		var stage_needed: int = 1
		match id:
			"energy_module": stage_needed = 2
			"armour_shell": stage_needed = 3
		var btn := Button.new()
		btn.text = "INSTALLED" if installed else "INSTALL"
		btn.disabled = (not GameState.has_component(id)) or installed or stage_now < stage_needed - 1
		btn.add_theme_font_size_override("font_size", 17)
		btn.pressed.connect(func() -> void:
			if runtime != null:
				runtime.install_module(id)
				_rebuild_assembly_slots())
		row.add_child(btn)
	if _assembly_status != null:
		_assembly_status.text = "stage: %s   ·   modules: %d/3" % [
			GameState.ASSEMBLY_STAGE_NAMES[int(GameState.assembly_stage)],
			GameState.collected_components.size(),
		]


func _rebuild_armor_slots() -> void:
	## The armour checklist: one line per spare, read live from the assembly
	## module — at its place, seated, or bolted down.
	if _armor_slots == null:
		return
	for c: Node in _armor_slots.get_children():
		c.queue_free()
	if runtime == null or runtime.armor == null:
		_armor_slots.add_child(_note("no armour assembly registered"))
		return
	var rows: Array = [
		["ArmorHelmet", "helmet"],
		["ArmorChestPlate", "chest plate"],
		["ArmorGauntlet", "gauntlet"],
		["ArmorBoot", "boot"],
	]
	var marks: Array = ["—  at its place", "◐  seated, not bolted", "●  bolted down"]
	for r: Array in rows:
		var st: int = int(runtime.armor.part_state(String(r[0])))
		var l := Label.new()
		l.text = "%-12s  %s" % [String(r[1]), String(marks[st])]
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", GarageTheme.col("cyan" if st == 2 else "ink"))
		_armor_slots.add_child(l)
	var total: String = "seated %d · bolted %d of 4" % [int(runtime.armor.fitted_count()), int(runtime.armor.locked_count())]
	if int(runtime.armor.locked_count()) >= 4:
		total += "   ·   MK-I COMPLETE"
	_armor_slots.add_child(_note(total))


func _rebuild_diag_rows() -> void:
	if _diag_rows == null:
		return
	for c: Node in _diag_rows.get_children():
		c.queue_free()
	var snap: Dictionary = ScreenContent._snapshot()
	for pair: Array in [
		["frame integrity", snap.frame_integrity],
		["core buffer", snap.core_buffer],
		["thermal envelope", snap.thermal],
		["optics", snap.optics],
		["shell bonding", snap.shell_bonding],
		["joint backlash", 1.0 - float(snap.backlash)],
	]:
		var row := HBoxContainer.new()
		_diag_rows.add_child(row)
		var l := Label.new()
		l.text = String(pair[0])
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 16)
		l.custom_minimum_size = Vector2(220, 0)
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.min_value = 0
		pb.max_value = 100
		pb.value = int(float(pair[1]) * 100.0)
		pb.show_percentage = true
		pb.custom_minimum_size = Vector2(420, 20)
		row.add_child(pb)


func _toolbox_body(body: HBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.name = "ToolboxBody"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(box)


func _rebuild_toolbox() -> void:
	var box := toolbox_panel.find_child("ToolboxBody", true, false) as VBoxContainer
	if box == null:
		return
	for c: Node in box.get_children():
		c.queue_free()
	box.add_child(_note("The bench toolbox. Three drawers, hand-labelled, in the order the tools are actually used."))
	var grid := GridContainer.new()
	grid.columns = 3
	box.add_child(grid)
	var inventory: Array = [
		["spanners", "10, 12, 14 mm"], ["screwdrivers", "flat and cross"],
		["pliers", "two, one bent"], ["hacksaw", "new blade"],
		["file", "half-round"], ["chisel", "cold"],
		["tape measure", "5 m"], ["spirit level", "9 inch"],
		["welding rods", "half a pack"], ["solder", "60/40, 0.8 mm"],
	]
	for pair: Array in inventory:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(220, 60)
		grid.add_child(card)
		var v := VBoxContainer.new()
		card.add_child(v)
		var t := Label.new()
		t.text = String(pair[0])
		t.add_theme_font_size_override("font_size", 17)
		t.add_theme_color_override("font_color", GarageTheme.col("ink"))
		v.add_child(t)
		var s := Label.new()
		s.text = String(pair[1])
		s.add_theme_font_size_override("font_size", 13)
		s.add_theme_color_override("font_color", GarageTheme.col("muted"))
		v.add_child(s)


func _fill_inspect() -> void:
	if player == null or player.target == null:
		return
	var payload: Dictionary = player.target.describe()
	_inspect_title.text = String(payload.get("title", "Unknown"))
	_inspect_area.text = "area  %s   ·   kind  %s" % [String(payload.get("area", "-")), String(payload.get("kind", "-"))]
	_inspect_body_lbl.text = String(payload.get("body", ""))
	_inspect_lore.text = String(payload.get("lore", ""))
	for c: Node in _inspect_spec.get_children():
		c.queue_free()
	var rows: Array = payload.get("spec", [])
	for r: Variant in rows:
		var pair: Array = r
		var k := Label.new()
		k.text = String(pair[0])
		k.add_theme_font_override("font", _font("mono"))
		k.add_theme_font_size_override("font_size", 15)
		k.add_theme_color_override("font_color", GarageTheme.col("amber"))
		_inspect_spec.add_child(k)
		var v := Label.new()
		v.text = String(pair[1])
		v.add_theme_font_size_override("font_size", 16)
		v.add_theme_color_override("font_color", GarageTheme.col("ink"))
		_inspect_spec.add_child(v)
	_inspect_progress.visible = bool(payload.get("show_progress", false))


# ===========================================================================
# event handlers
# ===========================================================================

func _on_objective(objective_id: String, text: String) -> void:
	if text == "":
		return
	objective_label.text = text
	objective_hint.text = GameConfig.objective_hint(objective_id)
	objective_hint.visible = false
	_flash(objective_panel)


func _on_hover(target: Node3D) -> void:
	if target is Station:
		var s: Station = target as Station
		_last_prompt = s.current_prompt()
		prompt_label.text = _last_prompt
		prompt_host.text = s.display_name.to_upper()
		prompt_label.visible = true
		prompt_host.visible = true
		prompt_box.visible = true
		crosshair.modulate = GarageTheme.col("cyan")
		AudioBank.play("ui_hover", -12.0)


func _on_unhover(_target: Node3D) -> void:
	prompt_label.text = ""
	prompt_host.text = ""
	prompt_box.visible = false
	crosshair.modulate = Color.WHITE


func _on_carry_hint(hint: String) -> void:
	## The mouse-carry line. An empty string hides it and restores the crosshair;
	## a non-empty one tints the crosshair cyan, the same colour that means
	## "clickable" everywhere else in the interface.
	if carry_hint_label == null:
		return
	carry_hint_label.text = hint
	if hint != "":
		crosshair.modulate = GarageTheme.col("cyan")


func _on_notice(message: String, tone: String) -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := HBoxContainer.new()
	panel.add_child(v)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(4, 30)
	match tone:
		"success": bar.color = GarageTheme.col("green")
		"warning": bar.color = GarageTheme.col("amber")
		"error": bar.color = GarageTheme.col("red")
		_: bar.color = GarageTheme.col("cyan")
	v.add_child(bar)
	var l := Label.new()
	l.text = message
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", GarageTheme.col("ink"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	v.add_child(l)
	notice_stack.add_child(panel)
	_notices.append({"node": panel, "life": 4.2})
	if _notices.size() > 5:
		var oldest: Dictionary = _notices.pop_front()
		if is_instance_valid(oldest.node):
			(oldest.node as Control).queue_free()
	AudioBank.play("ui_pick", -10.0)


func _on_stage(_stage: int, stage_name: String) -> void:
	_refresh_status()
	if _assembly_status != null and assembly_panel.visible:
		_assembly_status.text = "stage: %s   ·   modules: %d/3" % [
			stage_name, GameState.collected_components.size()]


func _on_component(_id: String) -> void:
	_refresh_modules()
	_refresh_status()


func _flash(control: Control) -> void:
	var tw := create_tween()
	control.modulate = Color(1.6, 1.6, 1.6, 1.0)
	tw.tween_property(control, "modulate", Color(1, 1, 1, 1), 0.6)


func _refresh_status() -> void:
	if status_box == null:
		return
	var states: Dictionary = {
		"power": GameState.power_on,
		"computer": GameState.computer_on,
		"shutter": GameState.shutter_open,
		"core": runtime != null and runtime.core_active,
		"assembly": GameState.assembly_stage == GameState.AssemblyStage.ACTIVE,
	}
	for key: String in states:
		var dot: ColorRect = status_box.find_child(key + "_Dot", true, false) as ColorRect
		if dot != null:
			dot.color = GarageTheme.col("green") if bool(states[key]) else GarageTheme.col("line")
	if progress_bar != null:
		progress_bar.value = GameState.completion_ratio() * 100.0


func _refresh_modules() -> void:
	if modules_box == null:
		return
	for c: Node in modules_box.get_children():
		c.queue_free()
	var cap := Label.new()
	cap.text = "MODULES  %d / %d" % [GameState.collected_components.size(), GameConfig.total_components()]
	cap.add_theme_font_override("font", _font("mono"))
	cap.add_theme_font_size_override("font_size", 13)
	cap.add_theme_color_override("font_color", GarageTheme.col("muted"))
	modules_box.add_child(cap)
	for c: Variant in GameConfig.components:
		var cd: Dictionary = c
		var id: String = String(cd.get("id", ""))
		var row := HBoxContainer.new()
		modules_box.add_child(row)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(9, 9)
		dot.color = GameConfig.component_slot_color(id) if GameState.has_component(id) else GarageTheme.col("line")
		row.add_child(dot)
		var l := Label.new()
		l.text = String(cd.get("short", id))
		l.add_theme_font_override("font", _font("mono"))
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", GarageTheme.col("ink") if GameState.has_component(id) else GarageTheme.col("muted"))
		row.add_child(l)


func _update_readouts() -> void:
	if computer_panel == null:
		return
	var snap: Dictionary = ScreenContent._snapshot()
	var values: Dictionary = {
		"stage": snap.stage_name, "progress": "%d%%" % int(snap.progress * 100.0),
		"power": "ON" if snap.power else "OFF", "core": "ONLINE" if snap.core else "STANDBY",
		"holo": "ACTIVE" if snap.hologram else "STANDBY",
		"frame": "%.1f%%" % (snap.frame_integrity * 100.0),
		"core_buffer": "%.1f%%" % (snap.core_buffer * 100.0),
		"thermal": "%.1f%%" % (snap.thermal * 100.0),
		"optics": "%.1f%%" % (snap.optics * 100.0),
		"shell": "%.1f%%" % (snap.shell_bonding * 100.0),
		"backlash": "%.2f mm" % (snap.backlash * 1.6),
	}
	for key: String in values:
		var lbl: Label = computer_panel.find_child("Value_" + key, true, false) as Label
		if lbl != null:
			lbl.text = String(values[key])


func _update_inventory_states() -> void:
	if computer_panel == null:
		return
	for c: Variant in GameConfig.components:
		var cd: Dictionary = c
		var id: String = String(cd.get("id", ""))
		var lbl: Label = computer_panel.find_child("InvState_" + id, true, false) as Label
		if lbl != null:
			var got: bool = GameState.has_component(id)
			lbl.text = "RECOVERED" if got else "MISSING"
			lbl.add_theme_color_override("font_color", GarageTheme.col("green") if got else GarageTheme.col("red"))


func _process(delta: float) -> void:
	_update_guides()
	# FPS counter, sampled once a second so the number is readable
	_fps_frames += 1
	_fps_accum += delta
	if _fps_accum >= 1.0:
		_fps = float(_fps_frames) / _fps_accum
		_fps_accum = 0.0
		_fps_frames = 0
		if fps_label != null and (_show_fps or bool(GameState.settings.get("show_fps", false))):
			fps_label.text = "%5.1f fps   %4.2f ms" % [_fps, 1000.0 / maxf(_fps, 1.0)]
	# notices age out
	for i: int in range(_notices.size() - 1, -1, -1):
		var n: Dictionary = _notices[i]
		n.life = float(n.life) - delta
		var node: Control = n.node as Control
		if is_instance_valid(node):
			if float(n.life) < 0.6:
				node.modulate.a = clampf(float(n.life) / 0.6, 0.0, 1.0)
			if float(n.life) <= 0.0:
				node.queue_free()
				_notices.remove_at(i)
	# live panel refreshes, throttled
	_panel_accum += delta
	if _panel_accum > 0.25:
		_panel_accum = 0.0
		if computer_panel.visible:
			_update_readouts()
			_update_inventory_states()
		if assembly_panel.visible:
			_rebuild_assembly_slots()
		if diagnostics_panel.visible:
			_rebuild_diag_rows()
		_refresh_status()
		_refresh_modules()
	# objective hint after 35 s, mirroring the director
	if director != null and objective_hint != null:
		objective_hint.visible = director.hints_shown.get(director.current_id, false)


var _panel_accum: float = 0.0


func toggle_fps() -> void:
	_show_fps = not _show_fps
	GameState.settings["show_fps"] = _show_fps
