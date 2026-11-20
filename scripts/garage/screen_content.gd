class_name ScreenContent
extends RefCounted
## Builds the specification for every display in the garage.
##
## The brief is explicit that the workstation must not be a screenshot of a real
## operating system, and that the interfaces must be built from Godot UI
## components. This class is the in-world half of that: each function returns a
## SignCanvas spec — the same declarative layer list the HUD uses — which the
## SignageBaker renders into a live SubViewport and the screen shader samples.
##
## Because the specs are regenerated from GameState every refresh, the monitors
## are genuinely reading the simulation: the assembly progress bar, the component
## inventory, the power status and the log tail all change when the player acts,
## with no separate data path to keep in sync.
##
## Palette: charcoal ground, industrial grey rules, amber for the inventor's own
## annotations, cyan for the machine, deep blue behind. Deliberately not a
## terminal-green pastiche.

const CHARCOAL: String = "#0e1216"
const PANEL: String = "#161d24"
const LINE: String = "#25313a"
const CYAN: String = "#4fd8ff"
const CYAN_DIM: String = "#1d5f75"
const AMBER: String = "#ffb347"
const GOLD: String = "#d4af37"
const GREEN: String = "#5fd08a"
const RED: String = "#e2453c"
const INK: String = "#e8ecef"
const MUTED: String = "#8a97a2"

## The spec canvas is authored at 960 x 600; live screens render into a SubViewport
## scaled by LIVE_SCALE and the canvas is scaled to match, so the layouts keep their
## authored coordinates while the pixels actually redrawn five times a second drop
## to 44% of what 960 x 600 cost.
const W: int = 960
const H: int = 600


static func _base(title: String, subtitle: String) -> Dictionary:
	return {
		"size": Vector2i(W, H),
		"transparent": false,
		"bg": CHARCOAL,
		"border": {"color": LINE, "width": 3.0},
		"layers": [
			{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(W, 54), "color": PANEL},
			{"type": "line", "from": Vector2(0, 54), "to": Vector2(W, 54), "color": CYAN_DIM, "width": 2.0},
			{"type": "text", "name": "HDR", "pos": Vector2(18, 12), "size": 30, "color": CYAN, "text": title, "font": "mono"},
			{"type": "text", "name": "SUB", "pos": Vector2(360, 16), "size": 22, "color": MUTED, "text": subtitle, "font": "mono"},
			{"type": "corner", "pos": Vector2(10, 64), "length": 22.0, "width": 3.0, "color": CYAN},
			{"type": "corner", "pos": Vector2(W - 10, H - 10), "length": -22.0, "width": 3.0, "color": CYAN, "flip": Vector2(-1, -1)},
		],
	}


static func _append(d: Dictionary, layers: Array) -> Dictionary:
	var out: Array = d.get("layers", [])
	out.append_array(layers)
	d["layers"] = out
	return d


# ===========================================================================
# workstation status board
# ===========================================================================

static func workstation_status() -> Dictionary:
	var d: Dictionary = _base("DESHI IRON GARAGE  ·  ENGINEERING CONSOLE", "MK-I PROTOTYPE STATUS")
	var gs: Dictionary = _snapshot()
	var layers: Array = []
	# left column: prototype status
	layers.append({"type": "text", "pos": Vector2(28, 84), "size": 20, "color": AMBER, "text": "PROTOTYPE STATUS", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(28, 108), "to": Vector2(430, 108), "color": LINE, "width": 1.5})
	layers.append({"type": "text", "name": "STAGE", "pos": Vector2(28, 118), "size": 30, "color": CYAN if gs.stage > 0 else MUTED, "text": gs.stage_name, "font": "mono"})
	layers.append({"type": "text", "pos": Vector2(28, 152), "size": 18, "color": MUTED, "text": "assembly progress", "font": "mono"})
	layers.append({"type": "progress", "pos": Vector2(28, 176), "sz": Vector2(400, 16), "value": gs.progress, "color": CYAN, "track": "#122029", "border": CYAN_DIM})
	layers.append({"type": "text", "name": "PROGPCT", "pos": Vector2(360, 152), "size": 18, "color": INK, "text": "%d%%" % int(gs.progress * 100.0), "font": "mono"})
	# component inventory
	layers.append({"type": "text", "pos": Vector2(28, 214), "size": 20, "color": AMBER, "text": "COMPONENT INVENTORY", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(28, 238), "to": Vector2(430, 238), "color": LINE, "width": 1.5})
	var comps: Array = gs.components
	for i: int in range(comps.size()):
		var c: Dictionary = comps[i]
		var y: float = 248.0 + float(i) * 46.0
		var got: bool = bool(c.got)
		layers.append({"type": "rect", "pos": Vector2(28, y), "sz": Vector2(402, 38), "color": Color(0.06, 0.12, 0.15, 0.85)})
		layers.append({"type": "rect", "pos": Vector2(28, y), "sz": Vector2(5, 38), "color": c.accent})
		layers.append({"type": "text", "pos": Vector2(44, y + 4), "size": 22, "color": INK, "text": String(c.label), "font": "mono"})
		layers.append({"type": "text", "pos": Vector2(44, y + 22), "size": 16, "color": MUTED, "text": String(c.origin), "font": "mono"})
		layers.append({"type": "text", "pos": Vector2(340, y + 10), "size": 20, "color": GREEN if got else RED, "text": "RECOVERED" if got else "MISSING", "font": "mono"})
	# power and system state
	layers.append({"type": "text", "pos": Vector2(28, 400), "size": 20, "color": AMBER, "text": "WORKSHOP STATE", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(28, 424), "to": Vector2(430, 424), "color": LINE, "width": 1.5})
	layers.append(_state_row(28, 434, "MAIN SUPPLY", gs.power, "230 V / 50 Hz"))
	layers.append(_state_row(28, 462, "WORKSTATION", gs.computer, "boot complete"))
	layers.append(_state_row(28, 490, "SHUTTER", gs.shutter, "courtyard open"))
	layers.append(_state_row(28, 518, "HOLOGRAPHY", gs.hologram, "design table"))
	# right column: schematic preview + diagnostics
	layers.append({"type": "rect", "pos": Vector2(460, 84), "sz": Vector2(472, 250), "color": "#0a141b"})
	layers.append({"type": "grid", "pos": Vector2(460, 84), "sz": Vector2(472, 250), "step": 24.0, "color": "#12242e"})
	layers.append({"type": "text", "pos": Vector2(470, 90), "size": 18, "color": AMBER, "text": "BLUEPRINT PREVIEW", "font": "mono"})
	layers.append_array(_schematic_layers(460, 110))
	layers.append({"type": "text", "pos": Vector2(460, 348), "size": 20, "color": AMBER, "text": "DIAGNOSTICS", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(460, 372), "to": Vector2(932, 372), "color": LINE, "width": 1.5})
	layers.append({"type": "text", "name": "D1", "pos": Vector2(460, 382), "size": 18, "color": MUTED, "text": "frame integrity", "font": "mono"})
	layers.append({"type": "progress", "pos": Vector2(660, 384), "sz": Vector2(270, 12), "value": gs.frame_integrity, "color": GREEN, "track": "#122029"})
	layers.append({"type": "text", "name": "D2", "pos": Vector2(460, 410), "size": 18, "color": MUTED, "text": "core buffer", "font": "mono"})
	layers.append({"type": "progress", "pos": Vector2(660, 412), "sz": Vector2(270, 12), "value": gs.core_buffer, "color": CYAN, "track": "#122029"})
	layers.append({"type": "text", "name": "D3", "pos": Vector2(460, 438), "size": 18, "color": MUTED, "text": "thermal envelope", "font": "mono"})
	layers.append({"type": "progress", "pos": Vector2(660, 440), "sz": Vector2(270, 12), "value": gs.thermal, "color": AMBER, "track": "#122029"})
	layers.append({"type": "text", "name": "D4", "pos": Vector2(460, 466), "size": 18, "color": MUTED, "text": "optics", "font": "mono"})
	layers.append({"type": "progress", "pos": Vector2(660, 468), "sz": Vector2(270, 12), "value": gs.optics, "color": GOLD, "track": "#122029"})
	layers.append({"type": "text", "pos": Vector2(460, 498), "size": 20, "color": AMBER, "text": "SYSTEM LOG", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(460, 522), "to": Vector2(932, 522), "color": LINE, "width": 1.5})
	var log: Array = gs.log
	for i: int in range(mini(4, log.size())):
		var idx: int = maxi(0, log.size() - 4) + i
		layers.append({"type": "text", "name": "LOG%d" % i, "pos": Vector2(460, 528 + float(i) * 17), "size": 15, "color": "#6a8a95", "text": "> %s" % String(log[idx]), "font": "mono"})
	return _append(d, layers)


static func _state_row(x: float, y: float, label: String, on: bool, note: String) -> Dictionary:
	return {"type": "rich", "name": "ROW_" + label, "pos": Vector2(x, y), "width": 400, "height": 26, "size": 18, "font": "mono",
		"bbcode": "[color=#8a97a2]%s[/color]  [color=%s]%s[/color]  [color=#4a5a64]%s[/color]" % [
			label.rpad(16, "."), GREEN if on else RED, "ON" if on else "OFF", note]}


static func _schematic_layers(x: float, y: float) -> Array:
	## The blueprint thumbnail: the same silhouette the notebook draws, so the
	## computer, the sketch and the built suit are visibly the same object.
	var out: Array = []
	var cx: float = x + 236.0
	out.append({"type": "circle", "center": Vector2(cx, y + 34), "radius": 20, "color": CYAN_DIM, "filled": false, "width": 2.0})
	out.append({"type": "poly", "points": [Vector2(cx - 24, y + 56), Vector2(cx + 24, y + 56), Vector2(cx + 32, y + 118), Vector2(cx - 32, y + 118)], "color": CYAN, "filled": false, "width": 2.5})
	out.append({"type": "line", "from": Vector2(cx - 32, y + 62), "to": Vector2(cx - 62, y + 132), "color": CYAN_DIM, "width": 2.0})
	out.append({"type": "line", "from": Vector2(cx + 32, y + 62), "to": Vector2(cx + 62, y + 132), "color": CYAN_DIM, "width": 2.0})
	out.append({"type": "line", "from": Vector2(cx - 22, y + 118), "to": Vector2(cx - 26, y + 196), "color": CYAN, "width": 2.5})
	out.append({"type": "line", "from": Vector2(cx + 22, y + 118), "to": Vector2(cx + 26, y + 196), "color": CYAN, "width": 2.5})
	out.append({"type": "circle", "center": Vector2(cx, y + 86), "radius": 12, "color": AMBER, "filled": false, "width": 2.5})
	out.append({"type": "circle", "center": Vector2(cx, y + 86), "radius": 5, "color": AMBER, "filled": true})
	out.append({"type": "line", "from": Vector2(cx + 70, y + 20), "to": Vector2(cx + 70, y + 196), "color": "#3a4a54", "width": 1.0})
	out.append({"type": "text", "pos": Vector2(cx + 76, y + 96), "size": 15, "color": "#5a6a74", "text": "1860", "font": "mono"})
	out.append({"type": "text", "pos": Vector2(x + 448, y + 210), "size": 15, "color": "#4a5a64", "text": "MK-I  ·  FRONT ELEV", "font": "mono"})
	return out


# ===========================================================================
# CRT terminal
# ===========================================================================

static func crt_terminal() -> Dictionary:
	var d: Dictionary = _base("SHANTI SPARES  ·  DIAGNOSTIC TERMINAL", "VT-220 EMULATION")
	d["bg"] = "#0a0f0d"
	var gs: Dictionary = _snapshot()
	var layers: Array = [
		{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(W, H), "color": Color(0.02, 0.05, 0.03, 0.6)},
		{"type": "text", "pos": Vector2(24, 74), "size": 20, "color": "#3fd87a", "text": "C:/GARAGE>", "font": "mono"},
		{"type": "text", "pos": Vector2(24, 100), "size": 18, "color": "#8ad8a8", "text": "IPS bank ........................ %s" % ("OK" if gs.power else "DEAD"), "font": "mono"},
		{"type": "text", "pos": Vector2(24, 124), "size": 18, "color": "#8ad8a8", "text": "buffer coil ..................... %s" % ("MOUNTED" if gs.core else "LOOSE"), "font": "mono"},
		{"type": "text", "pos": Vector2(24, 148), "size": 18, "color": "#8ad8a8", "text": "frame welds ..................... %d checked" % gs.welds, "font": "mono"},
		{"type": "text", "pos": Vector2(24, 172), "size": 18, "color": "#8ad8a8", "text": "shell plates .................... %d formed" % gs.plates, "font": "mono"},
		{"type": "text", "pos": Vector2(24, 196), "size": 18, "color": "#8ad8a8", "text": "optics alignment ................ %s" % ("IN SPEC" if gs.optics > 0.9 else "RECHECK"), "font": "mono"},
		{"type": "text", "pos": Vector2(24, 220), "size": 18, "color": "#8ad8a8", "text": "standing test authorization ..... %s" % ("GRANTED" if gs.diagnostics else "PENDING"), "font": "mono"},
		{"type": "line", "from": Vector2(24, 252), "to": Vector2(936, 252), "color": "#1d5f3a", "width": 1.5},
		{"type": "text", "pos": Vector2(24, 264), "size": 18, "color": "#3fd87a", "text": "NOTE:", "font": "mono"},
		{"type": "text", "pos": Vector2(90, 264), "size": 18, "color": "#8ad8a8", "text": "this is a display model. no live high voltage, no flight,", "font": "mono"},
		{"type": "text", "pos": Vector2(90, 288), "size": 18, "color": "#8ad8a8", "text": "no load bearing. the point of MK-I is that it exists.", "font": "mono"},
		{"type": "text", "pos": Vector2(24, 330), "size": 20, "color": "#3fd87a", "text": "স্বপ্নের গ্যারেজ — নির্মাণ চলছে", "font": "bangla"},
		{"type": "text", "pos": Vector2(24, 372), "size": 18, "color": "#8ad8a8", "text": "uptime %s   ·   %d entries logged" % [gs.uptime, gs.log.size()], "font": "mono"},
		{"type": "text", "pos": Vector2(24, 410), "size": 18, "color": "#8ad8a8", "text": "press TAB for the engineering console", "font": "mono"},
		{"type": "text", "pos": Vector2(24, 540), "size": 22, "color": "#3fd87a", "text": "_", "font": "mono"},
	]
	return _append(d, layers)


# ===========================================================================
# wall diagnostics
# ===========================================================================

static func diagnostic_log(index: int) -> Dictionary:
	var titles: Array[String] = ["STRUCTURAL TRACE", "POWER TRACE", "ASSEMBLY TRACE"]
	var d: Dictionary = _base(titles[index % 3], "WALL ARRAY %d / 3" % (index + 1))
	var gs: Dictionary = _snapshot()
	var layers: Array = []
	match index % 3:
		0:
			layers.append({"type": "text", "pos": Vector2(28, 84), "size": 20, "color": AMBER, "text": "FRAME LOAD PATH", "font": "mono"})
			layers.append({"type": "poly", "points": [Vector2(120, 140), Vector2(420, 140), Vector2(470, 260), Vector2(70, 260)], "color": CYAN, "filled": false, "width": 3.0})
			layers.append({"type": "line", "from": Vector2(120, 140), "to": Vector2(70, 260), "color": CYAN_DIM, "width": 2.0})
			layers.append({"type": "line", "from": Vector2(420, 140), "to": Vector2(470, 260), "color": CYAN_DIM, "width": 2.0})
			for i: int in range(6):
				layers.append({"type": "circle", "center": Vector2(120.0 + float(i) * 60.0, 140.0), "radius": 6.0, "color": GREEN if gs.stage > 0 else RED, "filled": true})
			layers.append({"type": "text", "pos": Vector2(28, 300), "size": 18, "color": MUTED, "text": "spine tube  612 mm  ·  0.8 mm tolerance", "font": "mono"})
			layers.append({"type": "text", "pos": Vector2(28, 326), "size": 18, "color": MUTED, "text": "donor  recycled chrome-moly, lot 27", "font": "mono"})
			layers.append({"type": "bars", "pos": Vector2(28, 380), "values": [0.9, 0.7, 0.95, 0.4, 0.8, 0.65, 0.88, 0.55, 0.72, 0.9], "bar_width": 22.0, "gap": 12.0, "max_height": 120.0, "color": CYAN})
			layers.append({"type": "text", "pos": Vector2(28, 512), "size": 20, "color": AMBER, "text": "load spectrum, standing test", "font": "mono"})
		1:
			layers.append({"type": "text", "pos": Vector2(28, 84), "size": 20, "color": AMBER, "text": "CORE BUFFER", "font": "mono"})
			layers.append({"type": "circle", "center": Vector2(240, 240), "radius": 110.0, "color": CYAN_DIM, "filled": false, "width": 4.0})
			layers.append({"type": "arc", "center": Vector2(240, 240), "radius": 110.0, "start": -1.5708, "end": -1.5708 + TAU * gs.core_buffer, "color": CYAN, "width": 10.0, "segments": 48})
			layers.append({"type": "text", "pos": Vector2(190, 226), "size": 40, "color": INK, "text": "%d%%" % int(gs.core_buffer * 100.0), "font": "mono"})
			layers.append({"type": "text", "pos": Vector2(400, 120), "size": 18, "color": MUTED, "text": "nominal  48 V (simulated)", "font": "mono"})
			layers.append({"type": "text", "pos": Vector2(400, 148), "size": 18, "color": MUTED, "text": "buffer   2 x 12 V tubular", "font": "mono"})
			layers.append({"type": "text", "pos": Vector2(400, 176), "size": 18, "color": MUTED, "text": "coupling flyback ferrite", "font": "mono"})
			layers.append({"type": "text", "pos": Vector2(400, 204), "size": 18, "color": RED, "text": "display model only", "font": "mono"})
			layers.append({"type": "bars", "pos": Vector2(400, 250), "values": [0.4, 0.6, 0.8, 0.5, 0.9, 0.3, 0.7, 0.85, 0.45, 0.65], "bar_width": 18.0, "gap": 10.0, "max_height": 90.0, "color": AMBER})
			layers.append({"type": "text", "pos": Vector2(28, 400), "size": 20, "color": AMBER, "text": "CELL BALANCE", "font": "mono"})
			layers.append({"type": "line", "from": Vector2(28, 424), "to": Vector2(932, 424), "color": LINE, "width": 1.5})
			for i: int in range(6):
				layers.append({"type": "text", "pos": Vector2(28.0 + float(i) * 150.0, 436), "size": 16, "color": MUTED, "text": "C%d" % (i + 1), "font": "mono"})
				layers.append({"type": "progress", "pos": Vector2(28.0 + float(i) * 150.0, 458), "sz": Vector2(120, 10), "value": 0.55 + float(i) * 0.07, "color": GREEN, "track": "#122029"})
		_:
			layers.append({"type": "text", "pos": Vector2(28, 84), "size": 20, "color": AMBER, "text": "ASSEMBLY STAGES", "font": "mono"})
			var stages: Array[String] = ["DORMANT", "FRAME", "CORE", "SHELL", "ASSEMBLING", "ACTIVE"]
			for i: int in range(stages.size()):
				var done: bool = gs.stage >= i
				layers.append({"type": "rect", "pos": Vector2(28, 116.0 + float(i) * 62.0), "sz": Vector2(430, 48), "color": PANEL})
				layers.append({"type": "rect", "pos": Vector2(28, 116.0 + float(i) * 62.0), "sz": Vector2(5, 48), "color": GREEN if done else LINE})
				layers.append({"type": "text", "pos": Vector2(46, 124.0 + float(i) * 62.0), "size": 22, "color": INK if done else MUTED, "text": stages[i], "font": "mono"})
				layers.append({"type": "text", "pos": Vector2(360, 124.0 + float(i) * 62.0), "size": 22, "color": GREEN if done else RED, "text": "DONE" if done else "WAIT", "font": "mono"})
			layers.append({"type": "text", "pos": Vector2(490, 84), "size": 20, "color": AMBER, "text": "ATTACHMENT ORDER", "font": "mono"})
			var order: Array[String] = ExosuitFactory.attach_order()
			for i: int in range(mini(order.size(), 14)):
				layers.append({"type": "text", "pos": Vector2(490.0 + float(i % 2) * 230.0, 116.0 + float(i / 2) * 32.0), "size": 17, "color": "#6a8a95", "text": "%02d %s" % [i + 1, order[i]], "font": "mono"})
	return _append(d, layers)


static func prototype_trace() -> Dictionary:
	var d: Dictionary = _base("EXOSUIT MK-I  ·  LIVE TRACE", "TESTING CORNER")
	var gs: Dictionary = _snapshot()
	var layers: Array = [
		{"type": "text", "pos": Vector2(28, 84), "size": 22, "color": AMBER, "text": "PROTOTYPE", "font": "bangla"},
		{"type": "text", "pos": Vector2(28, 116), "size": 20, "color": MUTED, "text": "standing test only — no flight, no load", "font": "mono"},
		{"type": "line", "from": Vector2(28, 148), "to": Vector2(932, 148), "color": LINE, "width": 1.5},
	]
	var rows: Array = [
		["frame integrity", gs.frame_integrity, GREEN],
		["core buffer", gs.core_buffer, CYAN],
		["thermal envelope", gs.thermal, AMBER],
		["optics left", gs.optics, GOLD],
		["optics right", gs.optics * 0.96, GOLD],
		["joint backlash", 1.0 - gs.backlash, CYAN_DIM],
		["shell bonding", gs.shell_bonding, GREEN],
	]
	for i: int in range(rows.size()):
		var r: Array = rows[i]
		var y: float = 160.0 + float(i) * 44.0
		layers.append({"type": "text", "pos": Vector2(28, y), "size": 18, "color": MUTED, "text": String(r[0]), "font": "mono"})
		layers.append({"type": "progress", "pos": Vector2(280, y + 2), "sz": Vector2(500, 18), "value": float(r[1]), "color": String(r[2]), "track": "#122029", "border": LINE})
		layers.append({"type": "text", "pos": Vector2(800, y), "size": 18, "color": INK, "text": "%.1f%%" % (float(r[1]) * 100.0), "font": "mono"})
	layers.append({"type": "line", "from": Vector2(28, 480), "to": Vector2(932, 480), "color": LINE, "width": 1.5})
	layers.append({"type": "text", "pos": Vector2(28, 492), "size": 20, "color": AMBER, "text": "VERDICT", "font": "mono"})
	var verdict: String = "CERTIFIED" if gs.stage >= 5 and gs.diagnostics else "INCOMPLETE"
	layers.append({"type": "text", "name": "VERDICT_VAL", "pos": Vector2(160, 492), "size": 26, "color": GREEN if verdict == "CERTIFIED" else RED, "text": verdict, "font": "mono"})
	layers.append({"type": "bars", "pos": Vector2(28, 528), "values": [0.8, 0.6, 0.9, 0.5, 0.7, 0.85, 0.4, 0.75, 0.65, 0.9, 0.55, 0.8], "bar_width": 16.0, "gap": 10.0, "max_height": 56.0, "color": CYAN})
	return _append(d, layers)


# ===========================================================================
# snapshot: the single read path all screens share
# ===========================================================================

static func _snapshot() -> Dictionary:
	var comps: Array = []
	for c: Variant in GameConfig.components:
		var cd: Dictionary = c
		var id: String = String(cd.get("id", ""))
		comps.append({
			"id": id,
			"label": String(cd.get("label", id)),
			"origin": String(cd.get("source_area", "")),
			"got": GameState.has_component(id),
			"accent": GameConfig.component_slot_color(id).to_html(),
		})
	var uptime: float = GameState.elapsed_seconds
	var mm: int = int(uptime) / 60
	var ss: int = int(uptime) % 60
	var stage: int = int(GameState.assembly_stage)
	var log_tail: Array = []
	var runtime: Node = _find_runtime()
	if runtime != null:
		var lines: PackedStringArray = runtime.log_lines
		for i: int in range(maxi(0, lines.size() - 40), lines.size()):
			log_tail.append(lines[i])
	return {
		"stage": stage,
		"stage_name": GameState.ASSEMBLY_STAGE_NAMES[stage],
		"progress": GameState.completion_ratio(),
		"components": comps,
		"power": GameState.power_on,
		"computer": GameState.computer_on,
		"shutter": GameState.shutter_open,
		"hologram": GameState.hologram_used,
		"core": stage >= 2,
		"diagnostics": GameState.diagnostics_run,
		"uptime": "%02d:%02d" % [mm, ss],
		"log": log_tail,
		# the diagnostic figures are derived from the actual build state rather
		## than randomised, so a loaded save reproduces the same numbers
		"frame_integrity": 0.72 + 0.26 * (1.0 if stage >= 1 else 0.0),
		"core_buffer": 0.18 + 0.78 * (1.0 if stage >= 2 else 0.0),
		"thermal": 0.35 + 0.5 * (1.0 if stage >= 4 else 0.0),
		"optics": 0.4 + 0.58 * (1.0 if stage >= 5 else 0.0),
		"shell_bonding": 0.55 + 0.43 * (1.0 if stage >= 3 else 0.0),
		"backlash": 0.35 - 0.25 * (1.0 if stage >= 5 else 0.0),
		"welds": 14 + stage * 6,
		"plates": 9 + stage * 4,
	}


static func _find_runtime() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return _search_runtime(tree.root)


static func _search_runtime(node: Node) -> Node:
	if node.has_method("bind") and "log_lines" in node:
		return node
	for c: Node in node.get_children():
		var found: Node = _search_runtime(c)
		if found != null:
			return found
	return null


static func regenerate(id: String, previous: Dictionary) -> Dictionary:
	## Rebuilds a live screen's spec from the current simulation state. Kept as one
	## entry point so the world's refresh loop does not need to know which
	## function produced which screen.
	match id:
		"status":
			return workstation_status()
		"crt":
			return crt_terminal()
		"diag0":
			return diagnostic_log(0)
		"diag1":
			return diagnostic_log(1)
		"diag2":
			return diagnostic_log(2)
		"test":
			return prototype_trace()
	return previous


static func spec_for(id: String) -> Dictionary:
	return regenerate(id, {})
