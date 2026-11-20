class_name GarageRuntime
extends Node
## The garage's state machine. Every cross-cutting behaviour lives here: power,
## the shutter, the fans, the lamps, the workstation boot, the energy core, the
## assembly sequence and the diagnostics pass.
##
## Why one node instead of thirteen scripts: those systems are not independent.
## Turning on the power changes eleven lights, two fans, four monitors, the core
## pulse, the hologram availability and the room's ambience, and the assembly
## sequence depends on all of them being in a known state. Distributing that
## knowledge across per-object scripts is how you get a garage where the fan
## spins but the monitor stays black. Stations stay thin (input surface + prompt);
## this node owns the truth.
##
## Everything animates through Tweens on real nodes — light energy, fan rotation,
## shutter slats, core emission — never by swapping a room material, which is the
## explicit requirement in Section 12.

const AssemblyStage := GameStateSingleton.AssemblyStage

signal circuit_changed(circuit: int, on: bool)
signal light_zone_changed(zone: StringName, energy: float)

var props: PropFactory
var baker: SignageBaker
var structure: GarageStructure
var ML: MaterialLibrarySingleton

## --- registries ----------------------------------------------------------
var lights: Array[Dictionary] = []          # {node, circuit, base_energy, zone}
var fans: Array[Dictionary] = []            # {rotor, station, rpm, target, node}
var screens: Array[Dictionary] = []         # {node, material, kind, live_id}
var stations: Dictionary = {}               # id -> station node
var _by_kind: Dictionary = {}             # kind -> first station of that kind
var modules: Dictionary = {}                # component id -> Node3D in world
var suit_parts: Dictionary = {}             # part id -> Node3D
var suit_root: Node3D
var core_material: ShaderMaterial
var hologram_materials: Array[ShaderMaterial] = []
var platform_deck: Node3D
var arms: Array = []   # Array[Node3D]: untyped so a plain Array from the dressing pass assigns cleanly
var cradle: Node3D
var shutter_node: Node3D
var curtain: Node3D
var slat_nodes: Array[MeshInstance3D] = []
var holo_volume: Node3D
var dust: GPUParticles3D
var rain: GPUParticles3D
var sun: DirectionalLight3D

## --- state ---------------------------------------------------------------
var shutter_open_amount: float = 0.0        # 0 closed .. 1 fully rolled
var power_on: bool = false
var circuits_on: Dictionary = {}            # circuit id -> bool
var computer_stage: int = 0                 # 0 off, 1 POST, 2 login, 3 ready
var core_active: bool = false
var assembly_running: bool = false
var diagnostics_running: bool = false
var fan_spin: Dictionary = {}               # fan key -> current rpm
var _tweens: Array[Tween] = []
var _pending_logs: PackedStringArray = PackedStringArray()
var log_lines: PackedStringArray = PackedStringArray()
var boot_started: int = 0


func _ready() -> void:
	set_process(true)


func bind(factory: PropFactory, signage: SignageBaker, shell: GarageStructure, material_library: MaterialLibrarySingleton) -> void:
	props = factory
	baker = signage
	structure = shell
	ML = material_library


# ===========================================================================
# Registration (called by the dressing pass)
# ===========================================================================

func register_light(light: Light3D, circuit: int, zone: StringName, base_energy: float = 0.0) -> void:
	var e: float = base_energy if base_energy > 0.0 else light.light_energy
	# The shadow budget is designed per light — seven casters, chosen for where a
	# shadow is actually readable — so the flag the creation site set is recorded
	# here. The quality code used to replace this with "every light on circuit 0 or
	# 1 casts", which turned twelve casters on, switched the core and stand-key
	# shadows off, and made the graphics bench's lighting experiment measure a rig
	# that no one was running.
	lights.append({
		"node": light, "circuit": circuit, "base_energy": e, "zone": zone,
		"wants_shadow": light.shadow_enabled,
	})
	light.light_energy = 0.0 if circuit > 0 else e


func register_fan(node: Node3D, key: String, rpm: float = 42.0) -> void:
	var rotor_path: String = String(node.get_meta("rotor_path", "Rotor"))
	var rotor: Node3D = node.get_node_or_null(rotor_path) as Node3D
	if rotor == null:
		return
	fans.append({"node": node, "rotor": rotor, "key": key, "rpm": rpm, "spin": 0.0})


func register_screen(node: Node3D, kind: String, live_id: String = "") -> void:
	screens.append({"node": node, "kind": kind, "live_id": live_id, "on": false})


func register_station(station: Node) -> void:
	## Stations are accepted and looked up as untyped Nodes on purpose. Station is
	## statically typed against GarageRuntime — it calls set_power(), boot_computer(),
	## install_module() and the rest — so a reverse static type here would make the
	## two scripts mutually dependent, which Godot refuses to compile. Duck typing
	## on this side breaks the cycle while keeping the contract documented: anything
	## registered here must expose id, kind, display_name and tick().
	##
	## Keyed by id rather than kind: several objects legitimately share a kind (two
	## IPS batteries, a dozen readable props), so a kind-keyed map would silently
	## drop all but the last one.
	var sid: String = String(station.get("id"))
	if sid == "":
		sid = "station_%d" % stations.size()
		station.set("id", sid)
	stations[sid] = station
	var kind_value: Variant = station.get("kind")
	if kind_value != null:
		_by_kind[int(kind_value)] = station


func station(kind: int) -> Node:
	return _by_kind.get(kind, null) as Node


func station_by_id(id: String) -> Node:
	return stations.get(id, null) as Node


func station_count() -> int:
	return stations.size()


func sys_log(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 200:
		log_lines.remove_at(0)


## GarageRuntime extends Node, not Node3D, so there is no transform to fall back
## on when an audio or light position is needed and the referenced node is absent.
func _origin() -> Vector3:
	return Vector3.ZERO


# ===========================================================================
# Shutter# ===========================================================================

func setup_shutter(node: Node3D) -> void:
	shutter_node = node
	curtain = node.get_node_or_null("Curtain") as Node3D
	if curtain == null:
		return
	slat_nodes.clear()
	for child: Node in curtain.get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Slat"):
			slat_nodes.append(child as MeshInstance3D)
	slat_nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.position.y < b.position.y)
	shutter_open_amount = 0.0
	_apply_shutter(0.0)


## Scrubs the curtain to an open fraction. Slats that reach the barrel are
## rotated and displaced along the barrel's arc, so the curtain curls rather than
## sliding through the lintel — the mechanical-animation requirement in Section 6.
func _apply_shutter(amount: float) -> void:
	if curtain == null or slat_nodes.is_empty():
		return
	var count: int = slat_nodes.size()
	var slat_h: float = float(shutter_node.get_meta("slat_height", 0.115))
	var travel: float = float(count) * slat_h * amount
	var barrel_radius: float = 0.16
	for i: int in range(count):
		var slat: MeshInstance3D = slat_nodes[i]
		var base_y: float = slat_h * (float(i) + 0.5)
		var lifted: float = base_y + travel
		var top_of_stack: float = float(count) * slat_h
		# how far past the lintel this slat has travelled, in slat-heights
		var past: float = (lifted - top_of_stack) / slat_h
		if past <= 0.0:
			slat.position = Vector3(0.0, lifted, 0.0)
			slat.rotation = Vector3.ZERO
		else:
			# wrap around the barrel: a quarter turn per slat, clamped
			var turn: float = clampf(past * 1.55, 0.0, PI * 1.4)
			var arc_y: float = top_of_stack + sin(turn) * barrel_radius
			var arc_z: float = (1.0 - cos(turn)) * barrel_radius
			slat.position = Vector3(0.0, arc_y, -arc_z)
			slat.rotation = Vector3(-turn, 0.0, 0.0)
	shutter_node.set_meta("open_amount", amount)


func animate_shutter(open: bool, duration: float = 3.4) -> void:
	if curtain == null:
		return
	var from: float = shutter_open_amount
	var to: float = 1.0 if open else 0.0
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(_shutter_scrub, from, to, duration)
	_tweens.append(t)
	if open:
		AudioBank.start_bed("shutter", 0.05)
		var stop := create_tween()
		stop.tween_interval(duration + 0.15)
		stop.tween_callback(func() -> void: AudioBank.stop_bed("shutter", 0.6))
		_tweens.append(stop)


func _shutter_scrub(v: float) -> void:
	shutter_open_amount = v
	_apply_shutter(v)
	# the rattle grows as more curtain comes off the barrel
	if AudioBank.bed_active("shutter"):
		AudioBank.play_at("metal_clank", _shutter_world_pos(), -18.0, 0.7 + v * 0.5)


func _shutter_world_pos() -> Vector3:
	if shutter_node == null:
		return Vector3.ZERO
	return shutter_node.global_position + Vector3(0.0, 2.6, 0.0)


# ===========================================================================
# Power
# ===========================================================================

func set_power(on: bool, instant: bool = false) -> void:
	if on == power_on:
		return
	power_on = on
	GameState.power_on = on
	var dur: float = 0.001 if instant else 1.6
	# 1. the circuits come up in sequence, not all at once: the tube lights
	#    strike first, then the bench lamps, then the futuristic zone.
	var order: Array[int] = [1, 2, 3, 4]
	for circuit: int in order:
		var delay: float = 0.08 * float(circuit - 1)
		for entry: Dictionary in lights:
			if int(entry.circuit) != circuit:
				continue
			var light: Light3D = entry["node"] as Light3D
			if not is_instance_valid(light):
				continue
			var target: float = float(entry.base_energy) if on else 0.0
			var tw := create_tween()
			tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if delay > 0.0:
				tw.tween_interval(delay)
			tw.tween_property(light, "light_energy", target, dur)
			_tweens.append(tw)
		circuits_on[circuit] = on
		circuit_changed.emit(circuit, on)
	# 2. the tube lights flicker on: two false strikes before they hold, which is
	#    how a failing starter actually behaves and costs nothing to implement.
	if on:
		_strike_tube_lights()
	# 3. fans spin up, screens wake, the core starts pulsing
	for fan: Dictionary in fans:
		_set_fan_target(String(fan.key), float(fan.rpm) if on else 0.0, on)
	_wake_screens(on)
	set_core_active(on, on)
	AudioBank.apply_power_state(on)
	EventBus.power_state_changed.emit(on)
	sys_log("POWER %s" % ("RESTORED" if on else "LOST"))


func _strike_tube_lights() -> void:
	for entry: Dictionary in lights:
		var light: Light3D = entry["node"] as Light3D
		if not is_instance_valid(light) or int(entry.circuit) != 1:
			continue
		var tw := create_tween()
		tw.tween_property(light, "light_energy", float(entry.base_energy) * 0.55, 0.05)
		tw.tween_property(light, "light_energy", 0.0, 0.04)
		tw.tween_property(light, "light_energy", float(entry.base_energy) * 0.8, 0.03)
		tw.tween_property(light, "light_energy", 0.0, 0.06)
		tw.tween_property(light, "light_energy", float(entry.base_energy), 0.22)
		_tweens.append(tw)


func toggle_circuit(circuit: int) -> void:
	var on: bool = not bool(circuits_on.get(circuit, false))
	circuits_on[circuit] = on
	for entry: Dictionary in lights:
		if int(entry.circuit) != circuit:
			continue
		var light: Light3D = entry["node"] as Light3D
		if is_instance_valid(light):
			var tw := create_tween()
			tw.tween_property(light, "light_energy", float(entry.base_energy) if on else 0.0, 0.35)
			_tweens.append(tw)
	EventBus.notification_requested.emit(
		"circuit %d %s" % [circuit, "energised" if on else "isolated"], "info")
	sys_log("CIRCUIT %d -> %s" % [circuit, "ON" if on else "OFF"])


# ===========================================================================
# Fans
# ===========================================================================

func _set_fan_target(key: String, rpm: float, on: bool) -> void:
	fan_spin[key] = 0.0 if not on else 0.0
	for fan: Dictionary in fans:
		if String(fan.key) != key:
			continue
		fan["target"] = rpm
		if on:
			AudioBank.start_bed("fan" if rpm < 50.0 else "fan_fast", 1.4)


func set_fan_on(key: String, on: bool) -> void:
	for fan: Dictionary in fans:
		if String(fan.key) != key:
			continue
		fan["target"] = float(fan.rpm) if on else 0.0
		if not on:
			AudioBank.stop_bed("fan", 0.9)
			AudioBank.stop_bed("fan_fast", 0.9)
		else:
			AudioBank.start_bed("fan", 1.2)
	sys_log("FAN %s -> %s" % [key, "ON" if on else "OFF"])


func _process(delta: float) -> void:
	# fan spin-up / spin-down with a first-order lag, so the blades accelerate
	# like a real motor instead of snapping to speed
	for fan: Dictionary in fans:
		var rotor: Node3D = fan["rotor"] as Node3D
		if rotor == null or not is_instance_valid(rotor):
			continue
		var target: float = float(fan.get("target", 0.0))
		var current: float = float(fan.get("spin", 0.0))
		var rate: float = 2.6 if target > current else 1.3
		current += (target - current) * minf(1.0, delta * rate)
		fan["spin"] = current
		rotor.rotation.z += current * delta
	# the wall clock, driven from the system clock so it is always right. Any
	## station may expose tick(); Station.tick() no-ops unless it is a clock, so
	## this costs one dictionary pass and no enum coupling back to Station.
	for id: String in stations:
		var s: Node = stations[id]
		if s != null and is_instance_valid(s) and s.has_method(&"tick"):
			s.call(&"tick", delta)


# ===========================================================================
# Screens
# ===========================================================================

func _wake_screens(on: bool) -> void:
	for entry: Dictionary in screens:
		var node: Node3D = entry["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var kind: String = String(entry.kind)
		if kind == "workstation" or kind == "crt":
			entry["on"] = on and computer_stage >= 1
			continue
		entry["on"] = on
		if on:
			_apply_screen_texture(entry, kind)
		else:
			node.material_override = ML.screen_off_material()


func _apply_screen_texture(entry: Dictionary, kind: String) -> void:
	var node: Node3D = entry["node"] as Node3D
	var live_id: String = String(entry.get("live_id", ""))
	var tex: Texture2D = baker.live_texture(live_id) if live_id != "" else null
	if tex == null:
		tex = baker.bake_placeholder(Vector2i(512, 320), Color(0.02, 0.05, 0.06))
	var mat: ShaderMaterial = ML.shader_material("res://shaders/screen.gdshader", {
		"screen_texture": tex,
		"glow": 1.35,
		"power": 1.0,
		"static_amount": 0.0,
		"scanline_strength": 0.22 if kind != "crt" else 0.34,
		"chroma_amount": 0.002 if kind != "crt" else 0.006,
		"bezel_curve": 0.2 if kind == "crt" else 0.02,
	})
	node.material_override = mat
	entry["material"] = mat


func boot_computer() -> void:
	if not power_on:
		EventBus.notification_requested.emit("workstation dead — restore power first", "warning")
		AudioBank.play("ui_error")
		return
	if computer_stage > 0:
		return
	computer_stage = 1
	AudioBank.play_at("boot", _screen_world_pos(), -3.0)
	sys_log("BOOT SEQUENCE INITIATED")
	# POST -> login -> ready, with the CRT static clearing as it goes
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_callback(func() -> void: _computer_stage_visual(1))
	tw.tween_interval(1.5)
	tw.tween_callback(func() -> void: _computer_stage_visual(2))
	tw.tween_interval(1.9)
	tw.tween_callback(func() -> void: _computer_stage_visual(3))
	tw.tween_callback(func() -> void:
		computer_stage = 3
		GameState.computer_on = true
		EventBus.computer_state_changed.emit(true)
		sys_log("WORKSTATION READY")
		EventBus.notification_requested.emit("workstation online — press TAB", "success")
	)


func _computer_stage_visual(stage: int) -> void:
	for entry: Dictionary in screens:
		if String(entry.kind) != "workstation" and String(entry.kind) != "crt":
			continue
		var mat: ShaderMaterial = entry.get("material", null) as ShaderMaterial
		if mat == null:
			_apply_screen_texture(entry, String(entry.kind))
			mat = entry.get("material", null) as ShaderMaterial
		if mat == null:
			continue
		match stage:
			1:
				mat.set_shader_parameter("static_amount", 0.85)
				mat.set_shader_parameter("power", 0.35)
			2:
				mat.set_shader_parameter("static_amount", 0.18)
				mat.set_shader_parameter("power", 0.8)
			_:
				mat.set_shader_parameter("static_amount", 0.0)
				mat.set_shader_parameter("power", 1.0)
		if stage >= 2:
			_apply_screen_texture(entry, String(entry.kind))
			var m2: ShaderMaterial = entry.get("material", null) as ShaderMaterial
			if m2 != null:
				m2.set_shader_parameter("static_amount", 0.0 if stage >= 3 else 0.18)
				m2.set_shader_parameter("power", 1.0)
		AudioBank.play_at("relay", _screen_world_pos(), -8.0)


func _screen_world_pos() -> Vector3:
	for entry: Dictionary in screens:
		var n: Node3D = entry["node"] as Node3D
		if is_instance_valid(n) and String(entry.kind) == "workstation":
			return n.global_position
	return Vector3.ZERO

# ===========================================================================
# Energy core
# ===========================================================================

func install_core(node: Node3D) -> void:
	if node == null:
		return
	core_material = ML.energy_core_material({
		"core_color": Color("7cf3ff"),
		"rim_color": Color("b8f6ff"),
		"pulse_speed": 1.35,
		"glow_strength": 0.0,
		"ring_count": 3.0,
		"ring_speed": 0.0,
		"plasma_amount": 0.55,
		"arc_intensity": 0.35,
		"mode": 1.0,
	})
	var body: Node3D = node.get_node_or_null(String(node.get_meta("core_body", "CoreBody"))) as Node3D
	if body != null:
		body.material_override = core_material
	var face: Node3D = node.get_node_or_null(String(node.get_meta("core_face", "CoreFace"))) as Node3D
	if face != null:
		var fm: ShaderMaterial = ML.energy_core_material({
			"core_color": Color("9ff8ff"), "glow_strength": 0.0, "mode": 0.0,
			"pulse_speed": 1.35, "ring_count": 4.0, "ring_speed": 0.0,
		})
		face.material_override = fm
		node.set_meta("core_face_material", fm)
	# the rings start still
	var ring_names: PackedStringArray = node.get_meta("ring_paths", PackedStringArray())
	for rn: String in ring_names:
		var r: Node3D = node.get_node_or_null(rn) as Node3D
		if r != null:
			r.set_meta("spin", 0.0)


func set_core_active(on: bool, instant: bool = false) -> void:
	if core_material == null:
		return
	core_active = on
	var dur: float = 0.001 if instant else 2.2
	var tw := create_tween()
	_tweens.append(tw)
	tw.tween_method(_core_glow, core_material.get_shader_parameter("glow_strength") as float, 3.6 if on else 0.0, dur)
	var face_mat: ShaderMaterial = null
	if cradle != null:
		face_mat = cradle.get_meta("core_face_material") as ShaderMaterial
	if face_mat != null:
		var tw2 := create_tween()
		tw2.tween_method(_core_face_glow, face_mat.get_shader_parameter("glow_strength") as float, 3.0 if on else 0.0, dur)
		_tweens.append(tw2)
	# the rings spin up, and the reactor's own light comes with it
	for entry: Dictionary in lights:
		if entry.zone != &"core":
			continue
		var light: Light3D = entry["node"] as Light3D
		if is_instance_valid(light):
			var tw3 := create_tween()
			tw3.tween_property(light, "light_energy", float(entry.base_energy) if on else 0.0, dur * 1.2)
			_tweens.append(tw3)
	if on:
		AudioBank.play_at("core_charge", _core_world_pos(), -2.0)
		AudioBank.start_bed("core_idle", 2.4)
		sys_log("CORE IGNITION SEQUENCE COMPLETE")
	else:
		AudioBank.stop_bed("core_idle", 1.2)
		sys_log("CORE STANDBY")
	EventBus.notification_requested.emit(
		"energy core %s" % ("online" if on else "standby"), "info" if on else "warning")


func _core_glow(v: float) -> void:
	if core_material != null:
		core_material.set_shader_parameter("glow_strength", v)
		core_material.set_shader_parameter("ring_speed", v * 0.16)
		core_material.set_shader_parameter("arc_intensity", clampf(v * 0.2, 0.0, 1.0))
	if cradle != null:
		var rings: PackedStringArray = cradle.get_meta("ring_paths", PackedStringArray())
		for rn: String in rings:
			var r: Node3D = cradle.get_node_or_null(rn) as Node3D
			if r != null:
				r.set_meta("spin", v * 0.35)


func _core_face_glow(v: float) -> void:
	if cradle == null:
		return
	var fm: ShaderMaterial = cradle.get_meta("core_face_material") as ShaderMaterial
	if fm != null:
		fm.set_shader_parameter("glow_strength", v)


func _core_world_pos() -> Vector3:
	return cradle.global_position if cradle != null else _origin()


func set_core_parameters(glow: float, pulse: float, color: Color, spin: float) -> void:
	if core_material == null:
		return
	core_material.set_shader_parameter("glow_strength", glow)
	core_material.set_shader_parameter("pulse_speed", pulse)
	core_material.set_shader_parameter("core_color", color)
	core_material.set_shader_parameter("spin", spin)


# ===========================================================================
# Holographic table
# ===========================================================================

func install_hologram(volume: Node3D) -> void:
	holo_volume = volume
	if volume == null:
		return
	_build_hologram_content(volume)


func _build_hologram_content(volume: Node3D) -> void:
	## The schematic on the design table is the suit, drawn as hologram geometry:
	## a wireframe torso, the ring set, the grid floor and the label plates. It is
	## the same part list the assembly uses, so the drawing and the build agree.
	var holo: ShaderMaterial = ML.hologram_material({"opacity": 0.0, "glow_strength": 2.1})
	holo_volume = volume
	var shell: MeshInstance3D = ShapeKit.sphere(0.42, holo, 20, "HoloShell")
	shell.scale = Vector3(0.62, 1.0, 0.42)
	volume.add_child(shell)
	hologram_materials.append(holo)
	for i: int in range(3):
		var ring: MeshInstance3D = ShapeKit.torus(0.3 + float(i) * 0.12, 0.008, ML.hologram_material({
			"opacity": 0.0, "glow_strength": 1.8, "scan_density": 40.0,
		}), 26, 6, "HoloRing%d" % i)
		ring.rotation = Vector3(PI * 0.5 + float(i) * 0.22, float(i) * 0.4, 0.0)
		ring.position = Vector3(0.0, 0.35 + float(i) * 0.28, 0.0)
		volume.add_child(ring)
		hologram_materials.append(ring.material_override as ShaderMaterial)
	# the projected floor grid. It was drawn at 1.6 m radius against a 0.72 m table,
	# so the grid hung 0.9 m past the table rim on every side as a glowing plane at
	# ankle height — the "bathtub of light" visible in the assembly captures. It is
	# sized to the table now.
	var grid: MeshInstance3D = ShapeKit.disc(0.62, 0.01, ML.holo_floor_material(), "HoloGrid", 40)
	grid.position = Vector3(0.0, -0.02, 0.0)
	volume.add_child(grid)
	# a miniature suit silhouette built from the same part offsets
	var mini := Node3D.new()
	mini.name = "HoloSuit"
	mini.scale = Vector3.ONE * 0.42
	mini.position = Vector3(0.0, 0.06, 0.0)
	volume.add_child(mini)
	var part_holo: ShaderMaterial = ML.hologram_material({
		"opacity": 0.0, "glow_strength": 2.4, "wireframe_only": 1.0, "grid_amount": 0.7,
	})
	hologram_materials.append(part_holo)
	for id: String in ExosuitFactory.PART_IDS:
		var off: Vector3 = ExosuitFactory.home_offset(id)
		var piece: MeshInstance3D
		match id:
			"helmet":
				piece = ShapeKit.sphere(0.13, part_holo, 12, "Holo_" + id)
			"chest", "back":
				piece = ShapeKit.box(Vector3(0.34, 0.4, 0.16), part_holo, "Holo_" + id)
			"core":
				piece = ShapeKit.torus(0.09, 0.02, part_holo, 16, 5, "Holo_" + id)
			"arm_left", "arm_right":
				piece = ShapeKit.cyl(0.05, 0.32, part_holo, 8, Vector3i(0, 1, 0), "Holo_" + id)
			"forearm_left", "forearm_right":
				piece = ShapeKit.cyl(0.045, 0.3, part_holo, 8, Vector3i(0, 1, 0), "Holo_" + id)
			"hand_left", "hand_right":
				piece = ShapeKit.box(Vector3(0.07, 0.12, 0.05), part_holo, "Holo_" + id)
			"leg_left", "leg_right":
				piece = ShapeKit.cyl(0.06, 0.7, part_holo, 8, Vector3i(0, 1, 0), "Holo_" + id)
			_:
				piece = ShapeKit.cyl(0.05, 0.34, part_holo, 8, Vector3i(0, 1, 0), "Holo_" + id)
		piece.position = off - Vector3(0.0, 0.9, 0.0)
		mini.add_child(piece)
	mini.set_meta("spin", 0.22)
	# label plates, baked from SignCanvas specs
	_holo_label(volume, "EXOSUIT MK-I", "প্রোটোটাইপ", Vector3(0.55, 1.15, 0.0), 0.6)
	_holo_label(volume, "CORE BUFFER", "শক্তি খন্ড", Vector3(-0.6, 0.85, 0.1), 0.55)
	_holo_label(volume, "SALVAGED FRAME", "ফ্রেম", Vector3(0.5, 0.42, -0.15), 0.5)


func _holo_label(volume: Node3D, english: String, bangla: String, pos: Vector3, width: float) -> void:
	var spec: Dictionary = {
		"size": Vector2i(512, 128),
		"transparent": true,
		"bg": null,
		"layers": [
			{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(512, 128), "color": Color(0.1, 0.6, 0.85, 0.10)},
			{"type": "line", "from": Vector2(0, 8), "to": Vector2(512, 8), "color": Color(0.35, 0.9, 1.0, 0.85), "width": 3.0},
			{"type": "corner", "pos": Vector2(6, 6), "length": 26.0, "width": 3.0, "color": Color(0.35, 0.9, 1.0, 0.9)},
			{"type": "corner", "pos": Vector2(506, 122), "length": -26.0, "width": 3.0, "color": Color(0.35, 0.9, 1.0, 0.9), "flip": Vector2(-1, -1)},
			{"type": "text", "name": "EN", "pos": Vector2(22, 22), "size": 40, "color": Color(0.85, 0.98, 1.0, 1.0), "text": english, "font": "latin"},
			{"type": "text", "name": "BN", "pos": Vector2(22, 74), "size": 34, "color": Color(0.55, 0.92, 1.0, 0.9), "text": bangla, "font": "bangla"},
		],
	}
	var plate: MeshInstance3D = ShapeKit.plane(Vector2(width, width * 0.25), null, "Label_" + english)
	plate.position = pos
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	volume.add_child(plate)
	var mat: StandardMaterial3D = baker.apply_baked(plate, spec, "holo_" + english, 1.6, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true


func set_hologram_visible(on: bool, duration: float = 1.1) -> void:
	for mat: ShaderMaterial in hologram_materials:
		if mat == null:
			continue
		var from: float = float(mat.get_shader_parameter("opacity"))
		var to: float = 0.62 if on else 0.0
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			mat.set_shader_parameter("opacity", v), from, to, duration)
		_tweens.append(tw)
	if on:
		AudioBank.play_at("core_charge", holo_volume.global_position, -10.0, 1.6)
		GameState.hologram_used = true
		sys_log("HOLOGRAPHIC TABLE ACTIVE")
	else:
		sys_log("HOLOGRAPHIC TABLE STANDBY")


# ===========================================================================
# Exosuit and assembly
# ===========================================================================

## Node3D has no modulate property — the suit parts are Node3D roots, so the
## assembly's fade passes go through the geometry instance's own transparency.
## Before this, every `n.modulate = ...` in the runtime raised a script error and
## the parts simply popped in at full opacity.
func _set_part_alpha(node: Node3D, alpha: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var t: float = clampf(1.0 - alpha, 0.0, 1.0)
	for child: Node in node.find_children("*", "GeometryInstance3D", true, false):
		(child as GeometryInstance3D).transparency = t


func install_suit(root: Node3D, parts: Dictionary, stand: Node3D, platform: Node3D, reactor_cradle: Node3D, robot_arms: Array) -> void:
	suit_root = root
	suit_parts = parts
	platform_deck = platform
	cradle = reactor_cradle
	arms = robot_arms
	install_core(reactor_cradle)
	# every part starts detached and invisible; the assembly brings them home
	for id: String in parts:
		var n: Node3D = parts[id] as Node3D
		n.set_meta("home_position", n.position)
		n.visible = false
		_set_part_alpha(n, 0.0)
	var stage: int = int(GameState.assembly_stage)
	if stage >= int(AssemblyStage.FRAME):
		_install_moduleImmediate("frame_module")
	if stage >= int(AssemblyStage.CORE):
		_install_moduleImmediate("energy_module")
	if stage >= int(AssemblyStage.SHELL):
		_install_moduleImmediate("armour_shell")
	if stage >= int(AssemblyStage.ACTIVE):
		set_core_active(true, true)
		_light_suit(true)


func _install_moduleImmediate(module_id: String) -> void:
	for part_id: String in ExosuitFactory.module_parts(module_id):
		var n: Node3D = suit_parts.get(part_id, null) as Node3D
		if n == null:
			continue
		n.visible = true
		_set_part_alpha(n, 1.0)
		n.position = n.get_meta("home_position") as Vector3
		n.rotation = Vector3.ZERO
		n.scale = Vector3.ONE


func install_module(module_id: String) -> void:
	## Places a salvaged module's parts onto the stand with a short mechanical
	## settle, and advances the stage. Called by the assembly UI once the player
	## has selected the component.
	if not GameState.has_component(module_id):
		return
	var parts_to_add: Array[String] = ExosuitFactory.module_parts(module_id)
	var delay: float = 0.0
	for part_id: String in parts_to_add:
		var n: Node3D = suit_parts.get(part_id, null) as Node3D
		if n == null:
			continue
		var home: Vector3 = n.get_meta("home_position") as Vector3
		n.visible = true
		# start the part out on the module crate side, then fly it in
		var start: Vector3 = home + Vector3(0.9, 0.55, 0.75)
		n.position = start
		n.rotation = Vector3(0.4, 0.7, 0.3)
		_set_part_alpha(n, 0.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.chain().tween_interval(delay)
		tw.tween_property(n, "position", home, 0.62).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(n, "rotation", Vector3.ZERO, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_method(_set_part_alpha.bind(n), 0.0, 1.0, 0.3)
		_tweens.append(tw)
		delay += 0.13
		AudioBank.play_at("metal_thunk", n.global_position, -8.0, 0.9 + delay * 0.1)
	var stage: int
	match module_id:
		"frame_module":
			stage = int(AssemblyStage.FRAME)
		"energy_module":
			stage = int(AssemblyStage.CORE)
		_:
			stage = int(AssemblyStage.SHELL)
	GameState.set_assembly_stage(stage as AssemblyStage)
	sys_log("MODULE %s INSTALLED" % module_id.to_upper())
	# the arm nearest the part swings to meet it
	if not arms.is_empty():
		var arm: Node3D = arms[int(hash(module_id) % arms.size())]
		_arm_gesture(arm, 0.5)


func _arm_gesture(arm: Node3D, amount: float) -> void:
	if arm == null:
		return
	var shoulder: Node3D = arm.get_node_or_null("Shoulder") as Node3D
	var elbow: Node3D = arm.get_node_or_null("Shoulder/Elbow") as Node3D
	if shoulder == null:
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(shoulder, "rotation:y", amount * 0.9, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if elbow != null:
		tw.tween_property(elbow, "rotation:x", -amount * 0.7, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tweens.append(tw)
	AudioBank.play_at("servo", arm.global_position, -6.0)


func run_assembly() -> void:
	## The full sequence from Section 19: platform wakes, arms move in, the frame
	## appears, armour attaches in order, the core ignites, the eyes light, the
	## screens report. Driven by a single Tween chain so timing is auditable in
	## one place and can be scrubbed by the benchmark harness.
	if assembly_running:
		return
	if not GameState.all_components_collected():
		AudioBank.play("ui_error")
		var missing: int = GameConfig.total_components() - GameState.collected_components.size()
		EventBus.notification_requested.emit("assembly blocked — %d module(s) missing" % missing, "warning")
		return
	assembly_running = true
	GameState.set_assembly_stage(AssemblyStage.ASSEMBLING)
	sys_log("ASSEMBLY SEQUENCE START")
	EventBus.notification_requested.emit("assembly sequence running", "info")
	AudioBank.play_at("core_charge", _core_world_pos(), -6.0, 0.7)
	var total: float = 0.0
	# 1. the deck plates rise and the ring lights come up
	if platform_deck != null:
		for child: Node in platform_deck.get_children():
			if child is MeshInstance3D:
				var plate: MeshInstance3D = child as MeshInstance3D
				var tw0 := create_tween()
				tw0.tween_property(plate, "position:y", plate.position.y + 0.06, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tweens.append(tw0)
				total += 0.05
	# 2. arms sweep in
	for arm: Node3D in arms:
		_arm_gesture(arm, 1.0)
	# 3. modules install in the brief's order
	var order: Array[String] = ["frame_module", "energy_module", "armour_shell"]
	for module_id: String in order:
		await _wait_seconds(0.85)
		install_module(module_id)
	# 4. the attachment order pass, part by part, with the arm tracking each one
	await _wait_seconds(1.2)
	var attach_list: Array[String] = ExosuitFactory.attach_order()
	for i: int in range(attach_list.size()):
		var part_id: String = attach_list[i]
		var n: Node3D = suit_parts.get(part_id, null) as Node3D
		if n == null or n.visible:
			continue
		var home: Vector3 = n.get_meta("home_position") as Vector3
		n.visible = true
		n.position = home + Vector3(0.0, 0.35, 0.0)
		_set_part_alpha(n, 0.0)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(n, "position", home, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(_set_part_alpha.bind(n), 0.0, 1.0, 0.22)
		_tweens.append(tw)
		AudioBank.play_at("metal_clank", n.global_position, -10.0, 1.1 + float(i) * 0.02)
		if not arms.is_empty():
			_arm_gesture(arms[i % arms.size()], 0.35 + float(i) * 0.05)
		await _wait_seconds(0.22)
	# 5. core ignition and the eye lights
	await _wait_seconds(0.6)
	set_core_active(true)
	_light_suit(true)
	await _wait_seconds(1.8)
	GameState.set_assembly_stage(AssemblyStage.ACTIVE)
	assembly_running = false
	EventBus.prototype_activated.emit()
	AudioBank.play_at("assembly_done", _core_world_pos(), -2.0)
	sys_log("PROTOTYPE MK-I ACTIVE")
	EventBus.notification_requested.emit("prototype exosuit active", "success")
	GameState.playthroughs_completed += 1


func _light_suit(on: bool) -> void:
	var glow: Color = Color("9ff0ff")
	for id: String in ["helmet"]:
		var n: Node3D = suit_parts.get(id, null) as Node3D
		if n == null:
			continue
		for eye_name: String in ["EyeLeft", "EyeRight"]:
			var eye: MeshInstance3D = n.get_node_or_null(eye_name) as MeshInstance3D
			if eye != null and eye.material_override is StandardMaterial3D:
				var m: StandardMaterial3D = eye.material_override as StandardMaterial3D
				var tw := create_tween()
				tw.tween_method(func(v: float) -> void:
					m.emission_energy_multiplier = v, m.emission_energy_multiplier, 5.0 if on else 0.0, 0.9)
				_tweens.append(tw)
	# the forearm vents and the joint LEDs
	for part: String in suit_parts:
		var p: Node3D = suit_parts[part] as Node3D
		if p == null:
			continue
		for child: Node in _all_descendants(p):
			if child is MeshInstance3D:
				var cn: String = String(child.name)
				if cn.begins_with("Vent") or cn.begins_with("JointLed") or cn == "StatusLed" or cn.begins_with("StepLed") or cn.begins_with("SensorLens"):
					var mm: MeshInstance3D = child as MeshInstance3D
					if mm.material_override is StandardMaterial3D:
						var m2: StandardMaterial3D = mm.material_override as StandardMaterial3D
						var tw2 := create_tween()
						tw2.tween_method(func(v: float) -> void:
							m2.emission_energy_multiplier = v, m2.emission_energy_multiplier, 3.2 if on else 0.0, 1.1)
						_tweens.append(tw2)
	if on:
		sys_log("SUIT OPTICS ONLINE")


static func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for c: Node in node.get_children():
		out.append(c)
		out.append_array(_all_descendants(c))
	return out


func _wait_seconds(seconds: float) -> void:
	var t := get_tree().create_timer(seconds)
	await t.timeout


# ===========================================================================
# Diagnostics
# ===========================================================================

func run_diagnostics() -> void:
	if diagnostics_running:
		return
	if GameState.assembly_stage != AssemblyStage.ACTIVE:
		AudioBank.play("ui_error")
		EventBus.notification_requested.emit("no prototype to diagnose", "warning")
		return
	diagnostics_running = true
	GameState.diagnostics_run = true
	sys_log("DIAGNOSTIC PASS STARTED")
	var stages: Array[String] = [
		"frame integrity ......... 98.4%",
		"core buffer ............. 48.2 V nominal",
		"thermal envelope ........ 31 C steady",
		"optics .................. left 100% / right 96%",
		"joint backlash .......... 0.8 mm",
		"shell bonding ........... pass",
		"exosuit MK-I ............ CERTIFIED FOR STANDING TEST",
	]
	for line: String in stages:
		await _wait_seconds(0.42)
		sys_log(line)
		AudioBank.play_at("ui_confirm", _screen_world_pos(), -14.0)
		EventBus.notification_requested.emit(line, "info")
	diagnostics_running = false
	AudioBank.play_at("assembly_done", _core_world_pos(), -8.0, 1.3)


# ===========================================================================
# Atmosphere hooks
# ===========================================================================

func set_dust(on: bool) -> void:
	if dust != null:
		dust.emitting = on


func set_rain(on: bool) -> void:
	if rain != null:
		rain.emitting = on
	AudioBank.set_bed_playing("rain", on)
	if sun != null:
		var tw := create_tween()
		tw.tween_property(sun, "light_energy", 2.4 if not on else 1.5, 2.0)
		_tweens.append(tw)


func apply_settings() -> void:
	var s: Dictionary = GameState.settings
	AudioBank.refresh_settings()
	set_rain(bool(s.get("rain", true)))
	for entry: Dictionary in lights:
		var light: Light3D = entry["node"] as Light3D
		if is_instance_valid(light):
			light.shadow_enabled = bool(s.get("shadows", true)) and bool(entry.get("wants_shadow", false))
			light.set_meta("base_energy", float(entry.base_energy))


func _exit_tree() -> void:
	for tw: Tween in _tweens:
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()
