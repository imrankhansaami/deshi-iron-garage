extends Node
## Visual verification harness. Runs the real garage with the Forward+ renderer,
## drives the full progression, and writes PNGs at fixed viewpoints so the result
## can be judged rather than asserted.
##
## This exists because "it compiles" and "it looks like a Bangladeshi garage" are
## different claims, and the brief asks for the second one. Everything captured
## here is what docs/EXPERIMENTS.md reports; nothing is invented.
##
## Usage:
##   godot --path . --write-movie out.avi -s res://tests/capture.gd   (movie mode)
##   godot --path . -s res://tests/capture.gd                          (windowed)

const OUT_DIR: String = "res://captures"
const SHOTS: Array = [
	{"name": "01_exterior", "pos": Vector3(0.0, 1.75, 13.2), "look": Vector3(0.0, 2.4, 8.2), "wait": 1.5},
	{"name": "02_entrance", "pos": Vector3(0.0, 1.7, 7.4), "look": Vector3(-1.4, 1.6, 2.0), "wait": 1.2},
	{"name": "03_mechanical", "pos": Vector3(-2.6, 1.7, 3.4), "look": Vector3(-6.2, 1.3, 2.8), "wait": 1.2},
	{"name": "04_engine_parts", "pos": Vector3(-3.8, 1.5, 1.0), "look": Vector3(-5.6, 1.1, 1.6), "wait": 1.0},
	{"name": "05_electronics", "pos": Vector3(2.4, 1.7, 4.6), "look": Vector3(5.6, 1.2, 3.6), "wait": 1.2},
	{"name": "06_assembly_wide", "pos": Vector3(0.0, 2.0, 3.2), "look": Vector3(0.0, 1.4, -2.2), "wait": 1.6},
	{"name": "07_suit_close", "pos": Vector3(-1.6, 1.6, -0.6), "look": Vector3(0.0, 1.4, -2.2), "wait": 1.4},
	{"name": "08_holo_table", "pos": Vector3(-2.2, 1.6, -2.4), "look": Vector3(-3.6, 1.0, -4.1), "wait": 1.4},
	{"name": "09_testing", "pos": Vector3(0.4, 1.7, -5.0), "look": Vector3(2.4, 1.2, -6.4), "wait": 1.2},
	{"name": "10_final_garage", "pos": Vector3(0.0, 2.4, 2.0), "look": Vector3(0.0, 1.3, -2.2), "wait": 2.0},
]

var _frames: int = 0
var _stage: int = 0
var _world: Node = null
var _shot_index: int = -1
var _settle_until: int = 0
var _report: PackedStringArray = PackedStringArray()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("user://captures")
	print("CAPTURE: driver attached, waiting for the build")
	_log("driver _ready, process enabled=%s in_tree=%s" % [process, is_inside_tree()])
	_log("world build_complete=%s" % str(get_parent().get("build_complete")))


## Redirected stdout is block-buffered and a killed run loses it, so every driver
## event is also appended to a flushed file. This is what made the 29-second build
## visible after four runs that looked like hard hangs.
##
## FileAccess.READ_WRITE does not create a missing file, so the log is kept in a
## static buffer and rewritten whole on each append: cheap at this volume, and it
## cannot silently drop every line the way an open-on-missing file does.
static var _lines: PackedStringArray = PackedStringArray()


static func _log(line: String) -> void:
	_lines.append("%06.1f  %s" % [float(Time.get_ticks_msec()) / 1000.0, line])
	var f := FileAccess.open("user://captures/capture.log", FileAccess.WRITE)
	if f == null:
		return
	for l: String in _lines:
		f.store_line(l)
	f.flush()
	f.close()


func _process(_delta: float) -> void:
	_frames += 1
	if _frames % 60 == 0:
		# one line a second: enough to tell a slow run from a stuck one
		_log("frame %d  fps %.1f  stage %d  shot %d" % [
			_frames, Performance.get_monitor(Performance.TIME_FPS), _stage, _shot_index])
	if _world == null:
		var first: Node = get_tree().root.get_child(0)
		if first != null and first.has_method("build_report"):
			_world = first
			_log("world bound")
		return
	if not bool(_world.get("build_complete")):
		return
	match _stage:
		0:
			_report_header()
			_drive_progression()
			_settle_until = _frames + 90
			_stage = 1
			_log("progression driven, settling")
		1:
			if _frames >= _settle_until:
				_stage = 2
				_shot_index = 0
				_place_camera(SHOTS[0])
				_settle_until = _frames + 45
				_log("shooting begins")
		2:
			if _frames < _settle_until:
				return
			_shoot_current()
			_shot_index += 1
			if _shot_index >= SHOTS.size():
				_log("all shots taken")
				_finish()
				get_tree().quit()
				return
			_place_camera(SHOTS[_shot_index])
			_settle_until = _frames + 45


func _report_header() -> void:
	var rep: Dictionary = _world.call("build_report")
	_line("=== BUILD REPORT ===")
	for k: String in rep:
		if k == "steps_ms":
			for s: String in rep[k]:
				_line("  step %-12s %8.1f ms" % [s, float(rep[k][s])])
		elif k == "prop_kinds" or k == "stations" or k == "lights" or k == "screens" or k == "props":
			_line("  %-16s %d" % [k, int(rep[k])])
		else:
			_line("  %-16s %s" % [k, str(rep[k])])
	_line("=== RENDERER ===")
	_line("  renderer  " + String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus")))
	_line("  video mem " + str(int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))))
	_line("  draw calls " + str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))))
	_line("  objects   " + str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))))


func _line(text: String) -> void:
	print(text)
	_report.append(text)


func _drive_progression() -> void:
	var rt: Node = _world.get_node("Runtime")
	var player: Node = _world.get_node("Player")
	_line("=== DRIVING THE FULL PROGRESSION ===")
	# 1. shutter up
	rt.call("animate_shutter", true, 0.01)
	rt.set("shutter_open_amount", 1.0)
	rt.call("_apply_shutter", 1.0)
	GameState.shutter_open = true
	_line("  shutter open")
	# 2. power restored
	rt.call("set_power", true, true)
	_line("  power on, circuits " + str(rt.get("circuits_on")))
	# 3. workstation booted
	rt.call("boot_computer")
	_line("  workstation booting")
	# 4. modules recovered
	for c: String in GameConfig.component_order():
		GameState.collect_component(c)
	_line("  modules collected: " + str(GameState.collected_components.keys()))
	# 5. hologram raised
	rt.call("set_hologram_visible", true, 0.01)
	_line("  hologram raised")
	# 6. assembly run to completion (instant, so the capture does not wait on it)
	for m: String in ["frame_module", "energy_module", "armour_shell"]:
		rt.call("_install_moduleImmediate", m)
	_line("  modules installed on the stand")
	rt.call("set_core_active", true, true)
	rt.call("_light_suit", true)
	GameState.set_assembly_stage(GameState.AssemblyStage.ACTIVE)
	GameState.diagnostics_run = true
	_line("  prototype active, core lit")
	# 7. fans
	for fan: Dictionary in rt.get("fans"):
		fan["target"] = float(fan.rpm)
	_line("  fans spun up: " + str(rt.get("fans").size()))
	_line("  stations registered: " + str(rt.call("station_count")))
	_line("  lights registered: " + str(rt.get("lights").size()))
	_line("  screens registered: " + str(rt.get("screens").size()))
	_line("  props built: " + str(rt.get("props").props_built))


func _shoot_current() -> void:
	if _shot_index < 0 or _shot_index >= SHOTS.size():
		return
	var shot: Dictionary = SHOTS[_shot_index]
	var cam: Camera3D = _world.get_node("Player/Camera3D") as Camera3D
	if cam == null:
		_line("  %s  FAILED (no camera)" % String(shot.name))
		return
	var img: Image = cam.get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_line("  %s  FAILED (no image)" % String(shot.name))
		return
	var path: String = "user://captures/%s.png" % String(shot.name)
	var err: Error = img.save_png(path)
	var total: float = 0.0
	var dark: int = 0
	var blown: int = 0
	var samples: int = 0
	for y: int in range(0, img.get_height(), 4):
		for x: int in range(0, img.get_width(), 4):
			var c: Color = img.get_pixel(x, y)
			var l: float = c.get_luminance()
			total += l
			samples += 1
			if l < 0.02:
				dark += 1
			elif l > 0.96:
				blown += 1
	var mean: float = total / float(maxi(samples, 1))
	_line("  %s  %s  %dx%d  mean_luma=%.3f  black=%.1f%%  clipped=%.1f%%" % [
		String(shot.name), error_string(err), img.get_width(), img.get_height(), mean,
		100.0 * float(dark) / float(maxi(samples, 1)), 100.0 * float(blown) / float(maxi(samples, 1))])
	# a mean below 0.02 means the frame is effectively black: the lighting rig
	## failed, and no amount of code review would show that otherwise
	if mean < 0.02:
		_line("    WARNING: frame is nearly black")


func _place_camera(shot: Dictionary) -> void:
	var cam: Camera3D = _world.get_node("Player/Camera3D") as Camera3D
	var player: Node = _world.get_node("Player")
	player.set("global_position", shot.pos)
	cam.global_position = shot.pos as Vector3
	cam.look_at_from_position(shot.pos as Vector3, shot.look as Vector3, Vector3.UP)


func _finish() -> void:
	_line("=== DONE ===")
	var f := FileAccess.open("user://captures/report.txt", FileAccess.WRITE)
	if f != null:
		for l: String in _report:
			f.store_line(l)
		f.close()
	print("CAPTURE: report written to user://captures/report.txt")
