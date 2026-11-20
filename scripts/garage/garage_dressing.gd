class_name GarageDressing
extends Node3D
## Fills the shell with the two worlds.
##
## Placement is split into three tiers, and the split is the answer to the brief's
## instruction to avoid "random objects on every surface":
##
##   1. AUTHORED  — the objects that carry meaning (benches, the stand, the
##                  workstation, the three module crates, the notebook, the
##                  switchboard). Fixed positions, fixed rotations, each one
##                  chosen for the sightline it creates. Never randomised.
##   2. PROCEDURAL — the small clutter, distributed by the layout groups in
##                  data/workshop_objects.json using a seeded RNG with a minimum
##                  spacing rule. Same seed, same garage, every run, which is what
##                  makes the benchmark screenshots comparable.
##   3. RACKS — wall-mounted tools on explicit ordered lists, because a tool board
##              is organised by habit, not by chance.
##
## Every authored object also registers its Station, its light, its fan or its
## screen with the runtime, so dressing is the single place where the garage's
## interactivity is wired.

const TAU_D: float = 6.283185307179586

var props: PropFactory
var ML: MaterialLibrarySingleton
var baker: SignageBaker
var runtime: GarageRuntime
var structure: GarageStructure
var rng: RandomNumberGenerator
var placed: Dictionary = {}
var placed_count: int = 0
var collision_bodies: int = 0
var _occupied: Array[AABB] = []


func setup(factory: PropFactory, material_library: MaterialLibrarySingleton, signage: SignageBaker, rt: GarageRuntime, shell: GarageStructure) -> void:
	props = factory
	ML = material_library
	baker = signage
	runtime = rt
	structure = shell
	rng = NoiseTools.rng(0xD5121)


func dress() -> void:
	_area_entrance()
	_area_mechanical()
	_area_electronics()
	_area_assembly()
	_area_testing()
	_area_store()
	_procedural_layouts()
	_wall_racks()
	_cables()
	_signage()
	_ambience_props()


# ===========================================================================
# Tier 1: authored placement helpers
# ===========================================================================

func _place(kind: String, pos: Vector3, rot: Vector3 = Vector3.ZERO, opts: Dictionary = {}) -> Node3D:
	var node: Node3D = props.build(kind, opts)
	node.position = pos
	node.rotation = rot
	add_child(node)
	placed_count += 1
	placed[kind] = int(placed.get(kind, 0)) + 1
	return node


## Converts a position in a bench-local frame to world space. `u` runs along the
## bench's width and `v` across its depth, both in metres from the centre, so a
## placement reads as "840 mm along, 300 mm back" rather than as world arithmetic
## that has to be re-derived every time the bench moves.
func _desk(origin: Vector3, size: Vector2, u: float, v: float, height: float = 0.945) -> Vector3:
	return Vector3(origin.x - u, height, origin.z - v)


func _station(node: Node3D, kind: Station.Kind, pos: Vector3 = Vector3.ZERO, opts: Dictionary = {}) -> Station:
	## Wraps an already-placed prop in a Station volume. The station is a separate
	## node so the prop's own transform stays authored-clean and the interaction
	## offset can be tuned independently of the mesh.
	var s := Station.new()
	s.kind = kind
	s.runtime = runtime
	s.area = StringName(String(opts.get("area", "")))
	s.display_name = String(opts.get("title", ""))
	s.description = String(opts.get("desc", ""))
	s.lore = String(opts.get("lore", ""))
	s.spec_rows = opts.get("spec", [])
	s.inspectable = bool(opts.get("inspectable", true))
	s.prompt = String(opts.get("prompt", ""))
	s.id = String(opts.get("id", ""))
	s.fan_key = String(opts.get("fan_key", ""))
	s.circuit = int(opts.get("circuit", 0))
	s.module_id = String(opts.get("module_id", ""))
	s.primary_action = String(opts.get("action", "use"))
	s.sfx = String(opts.get("sfx", "tool_place"))
	s.repeatable = bool(opts.get("repeatable", true))
	s.max_distance = float(opts.get("distance", 3.4))
	if node != null:
		node.add_child(s)
		var b: AABB = ShapeKit.node_bounds(node)
		if b.has_volume():
			var shape: CollisionShape3D = ShapeKit.col_box(b.size + Vector3.ONE * 0.1)
			shape.position = b.get_center() - node.global_position
			s.add_child(shape)
			_occupied.append(b)
		else:
			s.add_child(ShapeKit.col_box(Vector3.ONE * 0.4))
	else:
		s.position = pos
		s.add_child(ShapeKit.col_box(Vector3.ONE * 0.5))
	runtime.register_station(s)
	return s


func _register_light(node: Node3D, circuit: int, zone: StringName, energy: float, range: float = 6.0, attenuation: float = 1.6, shadow: bool = false, color: Color = Color.WHITE) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = Vector3.ZERO
	light.light_energy = energy
	light.omni_range = range
	light.omni_attenuation = attenuation
	light.light_color = color
	light.shadow_enabled = shadow
	if shadow:
		light.shadow_bias = 0.03
		light.shadow_normal_bias = 0.06
		light.shadow_blur = 1.2
	node.add_child(light)
	runtime.register_light(light, circuit, zone, energy)
	return light


func _spot(node: Node3D, pos: Vector3, target: Vector3, circuit: int, zone: StringName, energy: float, angle: float = 24.0, shadow: bool = true, color: Color = Color("ffe6bd")) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = pos
	light.look_at_from_position(pos, target, Vector3.UP)
	light.spot_angle = angle
	light.spot_attenuation = 1.4
	light.spot_range = 9.0
	light.light_energy = energy
	light.light_color = color
	light.shadow_enabled = shadow
	if shadow:
		light.shadow_bias = 0.04
		light.shadow_normal_bias = 0.08
		light.shadow_blur = 1.6
	node.add_child(light)
	runtime.register_light(light, circuit, zone, energy)
	return light


# ===========================================================================
# AREA 1 — entrance
# ===========================================================================

func _area_entrance() -> void:
	var half_l: float = structure.half_l
	# the shutter station is the first interaction in the experience
	var shutter: Node3D = structure.get_node_or_null("Shutter")
	if shutter != null:
		runtime.setup_shutter(shutter)
		_station(shutter, Station.Kind.SHUTTER, Vector3.ZERO, {
			"area": "entrance", "title": "Rolling shutter",
			"desc": "The corrugated curtain that keeps the monsoon out. Half-down when you arrive, because the inventor slept in the workshop again.",
			"lore": "The slats are individual geometry: as the curtain lifts, each one curls around the barrel instead of sliding through the lintel.",
			"spec": [["mechanism", "manual chain drive"], ["curtain", "26 slats"], ["travel", "2.9 m"], ["padlock", "still on the rail"]],
			"prompt": "Press E to roll the shutter", "sfx": "latch", "distance": 5.0,
		})
	# the signboard over the shutter
	var sign: Node3D = _place("signboard", Vector3(0.0, 3.55, half_l + 0.16), Vector3.ZERO, {"width": 3.2, "height": 0.72})
	_station(sign, Station.Kind.SIGN, Vector3.ZERO, {
		"area": "entrance", "title": "Garage signboard",
		"desc": "Hand-painted on a sheet of tin: the shop name in Bangla, the tagline underneath, and a phone number that is really a mobile number.",
		"spec": [["script", "Bengali, Noto Sans Bengali"], ["medium", "house paint on tin"], ["repainted", "three times"]],
		"sfx": "", "distance": 8.0,
	})
	# the courtyard and its clutter
	_place("bicycle", Vector3(-structure.half_w + 1.6, 0.0, half_l + 2.6), Vector3(0.0, 0.5, 0.0))
	_place("wheel_rickshaw", Vector3(structure.half_w - 1.4, 0.0, half_l + 1.8), Vector3(0.0, 0.3, 0.0))
	_place("crate_stack", Vector3(structure.half_w - 2.4, 0.0, half_l + 3.0), Vector3(0.0, -0.4, 0.0), {"count": 4})
	_place("scrap_bin", Vector3(-structure.half_w + 3.4, 0.0, half_l + 3.6), Vector3(0.0, 0.9, 0.0))
	_place("tubewell_bucket", Vector3(structure.half_w - 0.9, 0.0, half_l + 0.9))
	_place("sandals", Vector3(-0.9, 0.0, half_l - 0.35), Vector3(0.0, 0.4, 0.0))
	_place("sandals", Vector3(1.1, 0.0, half_l - 0.5), Vector3(0.0, -0.7, 0.0))
	_place("tea_stall_box", Vector3(-structure.half_w + 4.6, 0.0, half_l + 4.2), Vector3(0.0, 0.2, 0.0))
	# the interior entrance strip: boxes, a stool, the incoming cable
	_place("storage_box", Vector3(-structure.half_w + 1.2, 0.0, half_l - 1.0), Vector3(0.0, 0.3, 0.0))
	_place("wooden_stool", Vector3(structure.half_w - 1.6, 0.0, half_l - 1.4))
	_place("sack", Vector3(-structure.half_w + 2.0, 0.0, half_l - 0.6), Vector3(0.0, 0.6, 0.0))
	_place("bicycle_chain", Vector3(structure.half_w - 2.2, 0.9, half_l - 0.9), Vector3(0.0, 0.0, 1.4))
	_place("wall_socket", Vector3(structure.half_w - 0.2, 1.35, half_l - 1.2), Vector3(0.0, -PI * 0.5, 0.0))
	_place("switchboard", Vector3(-structure.half_w + 0.35, 1.75, half_l - 1.6), Vector3(0.0, PI * 0.5, 0.0))
	# the switchboard is the power puzzle's object
	var board: Node3D = structure.get_node_or_null("Switchboard")
	if board == null:
		for child: Node in get_children():
			if String(child.name).contains("switchboard"):
				board = child as Node3D
				break
	if board != null:
		_station(board, Station.Kind.SWITCHBOARD, Vector3.ZERO, {
			"area": "entrance", "title": "Main switchboard",
			"desc": "The distribution board that feeds the whole garage. The main switch is down: the workshop has been running off one borrowed circuit, and it finally gave up.",
			"lore": "Restoring power here brings up the tube lights, the bench lamps, the workstation, the fans and the reactor zone in sequence — real light nodes, not a material swap.",
			"spec": [["supply", "230 V / 50 Hz"], ["incoming", "weather-proof gland"], ["MCBs", "5 ways"], ["main", "63 A switch disconnector"]],
			"prompt": "Press E to work the main switch", "sfx": "switch_throw", "distance": 3.0,
		})
	# the MCB row is separately interactive, for the circuit toggles
	for mcb_host: Node in get_children():
		if String(mcb_host.name) == "McbRow":
			_station(mcb_host, Station.Kind.MCB, Vector3.ZERO, {
				"area": "entrance", "title": "MCB bank", "circuit": 2,
				"desc": "The miniature circuit breakers. Each way feeds a different half of the workshop.",
				"spec": [["ways", "5"], ["rating", "6 A / C-curve"]],
				"prompt": "Press E to isolate this circuit", "sfx": "switch_throw",
			})
			break


# ===========================================================================
# AREA 2 — desi mechanical workshop
# ===========================================================================

func _area_mechanical() -> void:
	var x: float = -structure.half_w
	# the main bench against the west wall, the heart of World A
	var bench: Node3D = _place("workbench", Vector3(x + 1.6, 0.0, 2.9), Vector3(0.0, PI * 0.5, 0.0), {"w": 3.0, "d": 0.9})
	_station(bench, Station.Kind.TOOLBOX, Vector3(0.0, 1.0, 0.0), {
		"area": "mechanical", "title": "Mechanical bench",
		"desc": "Three boards of teak, scarred through to the grain where the bench edge meets a forearm. Everything on it has been moved at least once today.",
		"spec": [["top", "3.0 m teak"], ["age", "19 years"], ["surface oil", "used gear oil"]],
		"sfx": "tool_place",
	})
	_place("bench_pegboard", Vector3(x + 0.28, 1.55, 2.9), Vector3(0.0, PI * 0.5, 0.0), {"w": 2.9, "h": 1.2})
	_place("tool_chest", Vector3(x + 1.35, 0.96, 3.6), Vector3(0.0, PI * 0.5, 0.0), {"width": 0.46})
	_place("bench_vice", Vector3(x + 1.9, 0.98, 2.1))
	_place("grindstone", Vector3(x + 0.9, 0.0, 5.4))
	_place("welding_mask", Vector3(x + 2.2, 1.02, 4.3), Vector3(0.0, 0.6, 0.0))
	_place("welding_rod", Vector3(x + 1.7, 1.0, 4.6), Vector3(0.2, 1.1, 0.0))
	_place("weld_spatter", Vector3(x + 1.1, 0.97, 5.0))
	_place("oil_can", Vector3(x + 1.05, 0.98, 3.2))
	_place("funnel", Vector3(x + 2.4, 0.99, 3.4))
	_place("hammer", Vector3(x + 1.5, 1.02, 2.6), Vector3(PI * 0.5, 0.0, 0.3))
	_place("spanner", Vector3(x + 1.2, 1.0, 2.3), Vector3(PI * 0.5, 0.0, 0.9))
	_place("screwdriver", Vector3(x + 1.8, 1.0, 2.9), Vector3(PI * 0.5, 0.0, -0.4))
	_place("pliers", Vector3(x + 2.0, 1.0, 2.2), Vector3(PI * 0.5, 0.0, 1.2))
	_place("tape_measure", Vector3(x + 0.9, 1.0, 2.8))
	_place("bolt_cluster", Vector3(x + 2.1, 1.0, 3.0))
	_place("washer_pile", Vector3(x + 1.6, 1.0, 3.1))
	_place("notebook", Vector3(x + 1.1, 1.0, 3.5), Vector3(0.0, 0.35, 0.0), {"width": 0.26})
	_place("pen", Vector3(x + 1.35, 1.02, 3.35), Vector3(PI * 0.5, 0.0, 0.2))
	_place("tea_glass", Vector3(x + 2.3, 1.0, 2.7))
	_place("flask", Vector3(x + 2.5, 0.98, 3.8))
	_place("newspaper_fold", Vector3(x + 0.7, 0.96, 4.4))
	_place("workbench_lamp", Vector3(x + 2.6, 0.98, 2.0))
	_place("cot_bed", Vector3(x + 1.1, 0.0, 6.6), Vector3(0.0, 0.1, 0.0))
	_place("plastic_chair", Vector3(x + 3.0, 0.0, 5.8), Vector3(0.0, -0.5, 0.0))
	_place("wooden_stool", Vector3(x + 2.6, 0.0, 4.0))
	_place("shelf_unit", Vector3(x + 0.55, 0.0, 0.6), Vector3(0.0, PI * 0.5, 0.0), {"w": 2.4, "levels": 5})
	_place("scrap_bin", Vector3(x + 1.6, 0.0, -1.4))
	_place("steel_drum", Vector3(x + 0.9, 0.0, -2.6))
	_place("rickshaw_frame", Vector3(x + 2.6, 0.0, -3.4), Vector3(0.0, 0.4, 0.0), {"scale": 0.9})
	_place("wheel_rickshaw", Vector3(x + 1.2, 0.36, -4.4), Vector3(0.0, 0.2, 0.0))
	_place("bicycle", Vector3(x + 2.4, 0.0, 7.4), Vector3(0.0, 1.2, 0.0))
	# the engine parts that the exosuit is built from
	var engine: Node3D = _place("engine_block", Vector3(x + 1.4, 0.98, 1.6), Vector3(0.0, 0.4, 0.0))
	_station(engine, Station.Kind.PART, Vector3.ZERO, {
		"area": "mechanical", "title": "Split single-cylinder engine",
		"desc": "Pulled off a 100 cc bike two monsoons ago. The fins are still straight, which means it was not seized when it came off.",
		"spec": [["type", "air-cooled OHV single"], ["bore", "50 mm"], ["condition", "carboned, serviceable"], ["donor for", "frame module"]],
		"sfx": "metal_thunk",
	})
	_place("cylinder_head", Vector3(x + 2.0, 1.0, 1.2), Vector3(0.0, 0.9, 0.0))
	_place("piston", Vector3(x + 1.1, 1.0, 0.9), Vector3(0.3, 0.0, 0.0))
	_place("camshaft", Vector3(x + 1.7, 1.0, 0.6), Vector3(0.0, 0.4, PI * 0.5))
	_place("crankshaft", Vector3(x + 2.2, 1.0, 0.8), Vector3(0.0, 1.1, PI * 0.5))
	_place("carburettor", Vector3(x + 0.9, 1.0, 0.5))
	_place("silencer", Vector3(x + 1.3, 0.0, -0.6), Vector3(0.0, 0.3, 0.0))
	_place("spark_plug", Vector3(x + 2.3, 1.0, 1.5))
	_place("chain_sprocket", Vector3(x + 0.8, 1.0, 1.9), Vector3(PI * 0.5, 0.0, 0.0))
	_place("bicycle_chain", Vector3(x + 1.5, 1.0, 2.0), Vector3(0.0, 0.6, 0.0), {"links": 18})
	_place("gear_set", Vector3(x + 2.1, 1.0, 1.9))
	_place("bearing", Vector3(x + 1.0, 1.0, 1.4))
	_place("brake_drum", Vector3(x + 2.5, 1.0, 4.9), Vector3(PI * 0.5, 0.0, 0.0))
	_place("headlamp_bowl", Vector3(x + 0.7, 1.0, 4.7), Vector3(0.0, 0.4, 0.0))
	_place("tail_lamp", Vector3(x + 1.9, 1.0, 5.1))
	_place("suspension_fork", Vector3(x + 0.5, 0.0, 3.9), Vector3(0.0, 0.0, 0.35))
	_place("suspension_fork", Vector3(x + 0.9, 0.0, 4.2), Vector3(0.0, 0.3, -0.3))
	_place("tyre", Vector3(x + 2.8, 0.3, 6.4), Vector3(0.0, 0.5, PI * 0.5))
	_place("wheel_motorcycle", Vector3(x + 3.2, 0.3, -1.0), Vector3(0.0, 0.2, PI * 0.5))
	_place("motorcycle_frame", Vector3(x + 3.4, 0.0, 1.0), Vector3(0.0, -0.3, 0.0))
	_place("electric_motor", Vector3(x + 1.2, 0.1, 5.9), Vector3(0.0, 0.7, 0.0))
	_place("transformer_block", Vector3(x + 2.6, 0.98, 5.6))
	_place("scrap_plate", Vector3(x + 3.0, 0.02, 2.4))
	_place("bent_rod", Vector3(x + 2.7, 0.05, 3.0))
	_place("offcut_tin", Vector3(x + 3.1, 0.03, 4.6))
	_place("rusty_can", Vector3(x + 0.6, 0.98, 6.0))
	_place("old_lock", Vector3(x + 2.4, 1.0, 6.2))
	_place("spring_coil", Vector3(x + 1.4, 1.0, 6.4))
	_place("cable_reel", Vector3(x + 0.5, 0.0, 7.0))
	_place("angle_bracket", Vector3(x + 1.9, 1.0, 6.7))
	_place("broken_fan_guard", Vector3(x + 2.9, 0.9, 6.9))
	_place("brush_cup", Vector3(x + 0.8, 0.98, 2.0))
	_place("mirror_small", Vector3(x + 0.3, 1.9, 6.2), Vector3(0.0, PI * 0.5, 0.0))
	_place("radio", Vector3(x + 2.2, 0.98, 6.9))
	_place("pedestal_fan", Vector3(x + 3.6, 0.0, 7.2), Vector3(0.0, -0.6, 0.0))
	_place("ceiling_fan", Vector3(x + 2.4, structure.height - 0.2, 3.0), Vector3.ZERO, {"radius": 0.62, "drop": 0.5})
	_place("fluorescent_battlement", Vector3(x + 2.2, structure.height - 0.35, 1.0), Vector3(0.0, PI * 0.5, 0.0), {"length": 1.4})
	_place("bulb_hanging", Vector3(x + 3.0, structure.height - 0.4, 5.6), Vector3.ZERO, {"drop": 0.9})
	_place("wall_calendar", Vector3(x + 0.26, 2.3, 4.6), Vector3(0.0, PI * 0.5, 0.0))
	_place("poster", Vector3(x + 0.26, 2.4, 6.6), Vector3(0.0, PI * 0.5, 0.0), {"variant": 1})
	_place("wall_clock", Vector3(x + 0.26, 2.6, 0.2), Vector3(0.0, PI * 0.5, 0.0))
	# the interactive ones
	for n: Node in get_children():
		match String(n.name):
			"Toolbox":
				pass
			"PedestalFan":
				_station(n, Station.Kind.FAN_PEDESTAL, Vector3.ZERO, {
					"area": "mechanical", "fan_key": "pedestal", "title": "Pedestal fan",
					"desc": "The wire-guarded standing fan. One blade is cracked, so it ticks twice per revolution when it is up to speed.",
					"spec": [["blades", "3, one cracked"], ["motor", "40 W shaded pole"], ["height", "1.15 m"]],
					"prompt": "Press E to start the fan", "sfx": "switch_throw",
				})
			"CeilingFan":
				_station(n, Station.Kind.FAN_CEILING, Vector3(0.0, -0.4, 0.0), {
					"area": "mechanical", "fan_key": "ceiling", "title": "Ceiling fan",
					"desc": "The three-blade fan that is in every room in the country. The pull chain is the only switch it has ever known.",
					"spec": [["blades", "3"], ["sweep", "1.24 m"], ["pull chain", "yes"]],
					"prompt": "Press E to pull the chain", "sfx": "switch_throw",
				})
			"WorkbenchLamp":
				_station(n, Station.Kind.LAMP_BENCH, Vector3.ZERO, {
					"area": "mechanical", "title": "Workbench lamp", "circuit": 2,
					"desc": "The spring-arm bench lamp. The shade is a cut petrol can, painted inside.",
					"spec": [["arm", "spring balanced"], ["shade", "hand-formed tin"], ["lamp", "40 W bulb"]],
					"prompt": "Press E to switch the lamp", "sfx": "switch_throw",
				})
			"FluorescentBattlement":
				_station(n, Station.Kind.TUBE_LIGHT, Vector3.ZERO, {
					"area": "mechanical", "title": "Tube light", "circuit": 1,
					"desc": "The 4 ft batten. The choke is original, the starter is a spare, and the diffuser has gone the colour of strong tea.",
					"spec": [["tube", "4 ft / 18 W"], ["ballast", "iron choke"], ["starter", "replaced twice"]],
					"prompt": "Press E to switch the tube", "sfx": "switch_throw",
				})
			"HangingBulb":
				_station(n, Station.Kind.BULB, Vector3.ZERO, {
					"area": "mechanical", "title": "Hanging bulb", "circuit": 3,
					"desc": "A bare bulb on a flex, tied to the beam with a length of wire. The whole country is lit by these.",
					"spec": [["lamp", "60 W incandescent"], ["flex", "salvaged"], ["height", "adjustable"]],
					"prompt": "Press E to switch the bulb", "sfx": "switch_throw",
				})
			"Notebook":
				_station(n, Station.Kind.NOTEBOOK, Vector3.ZERO, {
					"area": "mechanical", "title": "Engineering notebook",
					"desc": "The inventor's khata. Corkboard covers, string binding, and the first sketch of the exosuit on page four with a tea ring over the margin.",
					"lore": "Reading it unlocks the design intent and marks the objective complete.",
					"spec": [["pages", "84, numbered"], ["binding", "strung corkboard"], ["sketches", "17"]],
					"prompt": "Press E to read the notebook", "sfx": "paper",
				})
			"WallCalendar":
				_station(n, Station.Kind.CALENDAR, Vector3.ZERO, {
					"area": "mechanical", "title": "Wall calendar",
					"desc": "A free promotional calendar from a spare-parts dealer, showing both the Gregorian and Bengali months. It is four months out of date.",
					"spec": [["script", "Bengali"], ["columns", "English / Bangla dates"]],
				})
			"WallClock":
				_station(n, Station.Kind.CLOCK, Vector3.ZERO, {
					"area": "mechanical", "title": "Wall clock",
					"desc": "Battery clock, one hand bent. Keeps time anyway.",
					"spec": [["movement", "quartz"], ["battery", "AA, uncertain"]],
				})


# ===========================================================================
# AREA 3 — electronics repair laboratory
# ===========================================================================

func _area_electronics() -> void:
	var x: float = structure.half_w
	# ------------------------------------------------------------------
	# The electronics bench. Everything here is placed in DESK-LOCAL
	# coordinates and converted through _desk().
	#
	# The first version used hand-computed world offsets and got them wrong: the
	# desk spans x [3.7, 6.3] by z [3.6, 4.4], but the monitors were placed at
	# z = 3.5 and 3.6, so one hovered entirely off the front edge and the other
	# hung half over it. The oscilloscope, printer, speaker and desk lamp were at
	# z = 2.2 .. 5.1, i.e. scattered around the room at bench height. A local
	# frame with named rows removes the arithmetic that caused it: BACK is where
	# the monitors stand, FRONT is where hands work, and every prop sits between.
	# ------------------------------------------------------------------
	var desk_origin := Vector3(x - 1.5, 0.0, 4.0)
	var desk_size := Vector2(3.0, 1.0)
	var desk: Node3D = _place("desk_electronics", desk_origin, Vector3(0.0, PI, 0.0),
		{"w": desk_size.x, "d": desk_size.y, "h": 0.92})
	var desk_top: float = 0.92 + 0.025

	# --- monitors, standing along the back edge, facing into the room ---
	_place("crt_monitor", _desk(desk_origin, desk_size, -0.75, 0.30), Vector3(0.0, PI + 0.18, 0.0), {"width": 0.44})
	_place("lcd_monitor", _desk(desk_origin, desk_size, 0.35, 0.30), Vector3(0.0, PI - 0.22, 0.0), {"width": 0.46})
	# a third panel on a salvaged arm, because a repair bench never has enough
	_place("monitor_wall_panel", _desk(desk_origin, desk_size, 1.20, 0.24), Vector3(0.0, PI - 0.5, 0.0), {"width": 0.42})
	# the tower stands on the floor beside the desk, not on it
	var tower: Node3D = _place("desktop_tower", desk_origin + Vector3(-1.85, 0.0, 0.35), Vector3(0.0, PI + 0.15, 0.0))

	# --- the working row: where the hands actually go ---
	_place("keyboard", _desk(desk_origin, desk_size, -0.35, -0.30), Vector3(0.0, PI, 0.0))
	_place("mouse", _desk(desk_origin, desk_size, 0.20, -0.32))
	_place("multimeter", _desk(desk_origin, desk_size, 0.72, -0.24))
	_place("solder_station", _desk(desk_origin, desk_size, 1.18, -0.20), Vector3(0.0, PI + 0.3, 0.0))
	_place("laptop_shell", _desk(desk_origin, desk_size, -1.25, -0.15), Vector3(0.0, PI - 0.35, 0.0))

	# --- component work: the centre of the bench, where the boards are ---
	_place("pcb_stack", _desk(desk_origin, desk_size, -0.62, 0.02), Vector3.ZERO, {"count": 11})
	_place("pcb_board", _desk(desk_origin, desk_size, -0.18, 0.06), Vector3(0.0, 0.7, 0.0))
	_place("heatsink", _desk(desk_origin, desk_size, -0.40, 0.20))
	_place("ram_stick", _desk(desk_origin, desk_size, 0.06, 0.14), Vector3(0.0, 1.2, 0.0))
	_place("cpu_fan", _desk(desk_origin, desk_size, -0.30, 0.24), Vector3(PI * 0.5, 0.0, 0.0))
	_place("capacitor", _desk(desk_origin, desk_size, -0.50, 0.26), Vector3(0.0, 0.0, 0.4))
	_place("resistor_pack", _desk(desk_origin, desk_size, 0.30, 0.10))
	_place("dip_switch", _desk(desk_origin, desk_size, 0.02, 0.26))
	_place("led_cluster", _desk(desk_origin, desk_size, -0.72, 0.22))
	_place("fuse_glass", _desk(desk_origin, desk_size, 0.34, 0.26))
	_place("jack_socket", _desk(desk_origin, desk_size, 0.58, 0.14))
	_place("transformer_core", _desk(desk_origin, desk_size, 0.86, 0.08))
	_place("solder_spool", _desk(desk_origin, desk_size, 1.30, 0.10))
	_place("wire_cutters", _desk(desk_origin, desk_size, 1.05, 0.14), Vector3(PI * 0.5, 0.0, 0.4))
	_place("ribbon_cable", _desk(desk_origin, desk_size, -1.05, 0.20), Vector3(0.0, 0.9, 0.0))
	_place("power_adapter", _desk(desk_origin, desk_size, -1.42, 0.16))

	# --- instruments on a side bench, because they will not fit on the desk ---
	var side: Vector3 = desk_origin + Vector3(-0.4, 0.0, -0.95)
	_place("workbench", side, Vector3(0.0, 0.0, 0.0), {"w": 1.8, "d": 0.7, "h": 0.90})
	_place("oscilloscope", side + Vector3(-0.5, 0.945, 0.0), Vector3(0.0, 0.2, 0.0))
	_place("variac", side + Vector3(0.25, 0.94, 0.02))
	_place("voltage_regulator", side + Vector3(0.62, 0.945, 0.05))
	_place("table_fan", side + Vector3(0.85, 0.94, -0.18))
	_place("desk_lamp", side + Vector3(-0.72, 0.94, -0.14))

	# --- floor stock under and beside the bench ---
	_place("component_drawer", desk_origin + Vector3(-1.95, 0.0, -0.55), Vector3(0.0, PI * 0.5, 0.0), {"drawers": 7})
	_place("power_strip", desk_origin + Vector3(-1.6, 0.02, 0.9), Vector3(0.0, 0.4, 0.0), {"sockets": 5})
	_place("ups_battery", desk_origin + Vector3(-2.05, 0.0, 1.15))
	_place("ips_battery", desk_origin + Vector3(-0.35, 0.0, 1.25))
	_place("battery_rack", desk_origin + Vector3(1.05, 0.0, 1.35), Vector3(0.0, -0.3, 0.0))
	_place("stabilizer", desk_origin + Vector3(2.05, 0.0, 0.95), Vector3(0.0, PI, 0.0))
	_place("printer", desk_origin + Vector3(1.85, 0.0, -0.45), Vector3(0.0, -PI * 0.5, 0.0))
	_place("router_box", desk_origin + Vector3(1.45, 0.945, -0.62))
	_place("speaker", desk_origin + Vector3(-1.55, 0.945, -0.55))
	_place("blower_fan", desk_origin + Vector3(2.3, 0.0, 0.3), Vector3(0.0, PI * 0.5, 0.0))
	_place("office_chair", desk_origin + Vector3(0.35, 0.0, -1.5), Vector3(0.0, PI * 0.15, 0.0))
	_place("crt_guts", desk_origin + Vector3(2.45, 0.0, 1.6), Vector3(0.0, 0.8, 0.0))
	_place("ups_battery", desk_origin + Vector3(-2.5, 0.0, -0.9))
	_place("tea_glass", desk_origin + Vector3(-1.36, desk_top, 0.16))
	_place("crt_guts", Vector3(x - 3.0, 0.9, 4.2), Vector3(0.0, 0.8, 0.0))
	_place("shelf_unit", Vector3(x - 0.45, 0.0, 2.0), Vector3(0.0, -PI * 0.5, 0.0), {"w": 2.2, "levels": 6})
	_place("wall_socket", Vector3(x - 0.2, 1.3, 3.0), Vector3(0.0, -PI * 0.5, 0.0))
	_place("switch_wall", Vector3(x - 0.2, 1.3, 4.4), Vector3(0.0, -PI * 0.5, 0.0))
	_place("tea_glass", Vector3(x - 1.35, 0.95, 4.7))
	_place("clip_board", Vector3(x - 0.25, 1.6, 4.9), Vector3(0.0, -PI * 0.5, 0.0))
	_place("newspaper_fold", Vector3(x - 2.85, 0.94, 4.9))
	_place("poster", Vector3(x - 0.22, 2.3, 2.6), Vector3(0.0, -PI * 0.5, 0.0), {"variant": 2})
	_place("pedestal_fan", Vector3(x - 3.4, 0.0, 6.6), Vector3(0.0, 2.2, 0.0))
	_place("ceiling_fan", Vector3(x - 2.0, structure.height - 0.2, 4.4), Vector3.ZERO, {"radius": 0.55, "drop": 0.42, "wood": true})
	_place("fluorescent_battlement", Vector3(x - 2.0, structure.height - 0.35, 3.6), Vector3(0.0, PI * 0.5, 0.0), {"length": 1.2})
	# the workstation station, the centre of the electronics half
	if tower != null:
		_station(tower, Station.Kind.COMPUTER, Vector3(0.0, 0.2, 0.1), {
			"area": "electronics", "title": "Workstation tower",
			"desc": "A second-hand desktop with the side panel missing. It is the only machine in the garage that can run the design software, and it has been repaired four times.",
			"lore": "Starting it opens the engineering computer: prototype status, part inventory, assembly progress, diagnostics and system logs.",
			"spec": [["cpu", "salvaged quad-core"], ["ram", "8 GB, two sticks"], ["storage", "500 GB HDD"], ["display out", "VGA + HDMI"]],
			"prompt": "Press E to start the workstation", "sfx": "relay", "distance": 3.0,
		})
	for n: Node in get_children():
		match String(n.name):
			"CrtMonitor":
				var s: Station = _station(n, Station.Kind.CRT, Vector3.ZERO, {
					"area": "electronics", "title": "Salvaged CRT",
					"desc": "The 17-inch tube the inventor kept when everything else went to the scrap dealer. Its yoke is the donor for the core's coupling coil.",
					"spec": [["tube", "17 inch shadow mask"], ["refresh", "60/75 Hz"], ["donor for", "energy module"]],
					"prompt": "Press E to power the tube", "sfx": "relay",
				})
				runtime.register_screen(n.get_node_or_null("Screen") as Node3D, "crt", "crt")
			"LcdMonitor":
				_station(n, Station.Kind.LCD, Vector3.ZERO, {
					"area": "electronics", "title": "Second-hand LCD",
					"desc": "The panel that shows the prototype status board. Bright, flat, and older than the student using it.",
					"spec": [["panel", "15.6 inch TN"], ["input", "VGA"], ["content", "prototype status board"]],
					"prompt": "Press E to wake the panel", "sfx": "relay",
				})
				runtime.register_screen(n.get_node_or_null("Screen") as Node3D, "workstation", "status")
			"TableFan":
				_station(n, Station.Kind.FAN_TABLE, Vector3.ZERO, {
					"area": "electronics", "fan_key": "table", "title": "Desk fan",
					"desc": "Points at the oscilloscope, because the scope runs hot and there is no air conditioning.",
					"spec": [["blades", "3"], ["purpose", "scope cooling"]],
					"prompt": "Press E to start the fan", "sfx": "switch_throw",
				})
			"DeskLamp":
				_station(n, Station.Kind.LAMP_DESK, Vector3.ZERO, {
					"area": "electronics", "title": "Desk lamp", "circuit": 3,
					"desc": "Cool-white task light for the soldering position. The shade is bent from a biscuit tin lid.",
					"spec": [["colour", "cool white"], ["shade", "tin lid"]],
					"prompt": "Press E to switch the lamp", "sfx": "switch_throw",
				})
			"Oscilloscope":
				_station(n, Station.Kind.OSCILLOSCOPE, Vector3.ZERO, {
					"area": "electronics", "title": "Bench oscilloscope",
					"desc": "Analogue dual-trace, salvaged, recalibrated against a 555 timer because there is no proper reference here.",
					"spec": [["bandwidth", "20 MHz"], ["channels", "2"], ["calibration", "homemade"]],
				})
			"Variac":
				_station(n, Station.Kind.VARIAC, Vector3.ZERO, {
					"area": "electronics", "title": "Variac",
					"desc": "The variable autotransformer every repair bench in the country owns. Used to test adaptors at half supply.",
					"spec": [["range", "0-260 V"], ["current", "5 A"]],
				})
			"Stabilizer":
				_station(n, Station.Kind.STABILIZER, Vector3.ZERO, {
					"area": "electronics", "title": "Voltage stabilizer",
					"desc": "Servo stabilizer. The supply in this lane swings between 170 and 260 V, and nothing survives that without one.",
					"spec": [["type", "servo voltage regulator"], ["rating", "1 kVA"], ["output", "220 V +-3%"]],
				})
			"BatteryRack":
				_station(n, Station.Kind.BATTERY, Vector3.ZERO, {
					"area": "electronics", "title": "IPS battery rack",
					"desc": "Two tubular cells strapped in series with a distribution board and a ferrite coupling coil lifted off a dead flyback. This is the physical donor for the exosuit's energy module.",
					"lore": "Nothing here is a live high-voltage source. The glowing core in the suit is a display model, and the fiction is deliberate.",
					"spec": [["cells", "2 x 12 V tubular"], ["buffer", "series string"], ["coupling", "flyback ferrite coil"]],
					"sfx": "metal_thunk",
				})
			"IpsBattery":
				_station(n, Station.Kind.BATTERY, Vector3.ZERO, {
					"area": "electronics", "title": "IPS cell",
					"desc": "The tall tubular lead-acid cell that keeps a Bangladeshi household through load shedding. Six filler caps, corroded terminals.",
					"spec": [["type", "tubular flooded"], ["capacity", "150 Ah nominal"], ["terminals", "corroded"]],
					"sfx": "metal_thunk",
				})
			"UpsBattery":
				_station(n, Station.Kind.BATTERY, Vector3.ZERO, {
					"area": "electronics", "title": "UPS unit",
					"desc": "A sealed lead-acid UPS that no longer holds a charge. Its case is the housing for the fictional energy module.",
					"spec": [["type", "sealed SLA"], ["state", "dead, kept for the case"]],
					"sfx": "metal_thunk",
				})
			"Radio":
				_station(n, Station.Kind.RADIO, Vector3.ZERO, {
					"area": "mechanical", "title": "Transistor radio",
					"desc": "Runs on a single cell and plays the news at half volume. The scale is hand-marked in Bengali.",
					"spec": [["bands", "MW / SW"], ["speaker", "8 ohm"]],
				})
			"CeilingFan":
				if String(n.name) == "CeilingFan" and not runtime.fans.any(func(f: Dictionary) -> bool: return String(f.key) == "ceiling_elec"):
					_station(n, Station.Kind.FAN_CEILING, Vector3(0.0, -0.4, 0.0), {
						"area": "electronics", "fan_key": "ceiling_elec", "title": "Ceiling fan",
						"desc": "The electronics-side fan. Wooden blades on this one, inherited from an older room.",
						"spec": [["blades", "3, teak"], ["sweep", "1.1 m"]],
						"prompt": "Press E to pull the chain", "sfx": "switch_throw",
					})


# ===========================================================================
# AREA 4 — futuristic assembly laboratory
# ===========================================================================

func _area_assembly() -> void:
	var centre := Vector3(0.0, 0.0, -2.2)
	var platform: Node3D = _place("assembly_platform", centre, Vector3.ZERO, {"radius": 2.7})
	var stand: Node3D = _place("suit_stand", centre + Vector3(0.0, 0.22, 0.0), Vector3(0.0, PI, 0.0))
	# the suit itself
	var exosuit := ExosuitFactory.new(props)
	var built: Dictionary = exosuit.build({})
	var suit_root: Node3D = built["root"] as Node3D
	suit_root.position = centre + Vector3(0.0, 0.3, 0.0)
	suit_root.rotation.y = PI
	add_child(suit_root)
	# The suit is the centrepiece and it was being dwarfed: a 1.86 m figure on a
	# 5.4 m stage reads as a figurine in the first screenshot. Raising it onto the
	# stand's torso cradle and scaling it up puts the chest core at roughly eye
	# level from the entrance sightline, which is what the brief asks for.
	suit_root.scale = Vector3.ONE * 1.22
	suit_root.position = centre + Vector3(0.0, 0.34, 0.0)
	runtime.install_suit(suit_root, built["parts"] as Dictionary, stand, platform, null, [])
	# the reactor cradle at the platform centre
	var cradle: Node3D = platform.get_node_or_null("ReactorCradle") as Node3D
	if cradle == null:
		cradle = _place("energy_cradle", centre + Vector3(0.0, 0.3, 0.0), Vector3.ZERO, {"radius": 0.6})
	runtime.cradle = cradle
	runtime.install_core(cradle)
	# the four arms
	var arm_nodes: Array[Node3D] = []
	for i: int in range(4):
		var a: float = TAU_D * float(i) / 4.0 + 0.4
		var arm: Node3D = _place("robot_arm", centre + Vector3(cos(a) * 2.4, 0.28, sin(a) * 2.4), Vector3(0.0, -a + PI * 0.5, 0.0), {"reach": 1.2})
		arm_nodes.append(arm)
	runtime.arms = arm_nodes
	# the overhead gantry
	var rail: Node3D = _place("overhead_rail", centre + Vector3(0.0, structure.height - 0.75, 0.0), Vector3(0.0, PI * 0.5, 0.0), {"span": 5.4})
	# the holographic design table
	var table: Node3D = _place("holo_table", centre + Vector3(-3.6, 0.0, 1.9), Vector3(0.0, 0.7, 0.0), {"radius": 1.0})
	var holo_volume: Node3D = table.get_node_or_null("HoloVolume") as Node3D
	runtime.install_hologram(holo_volume)
	# the wall of salvaged monitors behind the stand
	for i: int in range(3):
		var panel: Node3D = _place("monitor_wall_panel", centre + Vector3(-1.5 + float(i) * 1.5, 2.6, -structure.half_l + 0.45), Vector3.ZERO, {"width": 0.56})
		var scr: Node3D = panel.get_node_or_null("Screen") as Node3D
		if scr != null:
			runtime.register_screen(scr, "diagnostic", "diag%d" % i)
	# the big reactor housing on the north wall
	var housing: Node3D = _place("reactor_housing", centre + Vector3(0.0, 2.5, -structure.half_l + 0.35), Vector3.ZERO, {"radius": 0.85})
	# indicator strips along the platform rim
	for i: int in range(4):
		var a: float = TAU_D * float(i) / 4.0
		_place("indicator_strip", centre + Vector3(cos(a) * 2.9, 0.42, sin(a) * 2.9), Vector3(0.0, -a, 0.0), {"length": 1.6, "count": 12})
	# the conduit runs feeding the platform
	_place("conduit_run", centre + Vector3(3.4, 0.35, -1.0), Vector3(0.0, 0.9, 0.0), {"length": 3.2})
	_place("conduit_run", centre + Vector3(-3.4, 0.35, -1.4), Vector3(0.0, -0.9, 0.0), {"length": 3.0})
	_place("cable_tray_future", centre + Vector3(0.0, structure.height - 1.3, -3.0), Vector3.ZERO, {"length": 5.0})
	# part kits and crates around the platform
	_place("part_kit", centre + Vector3(2.2, 0.34, 1.6), Vector3(0.0, 0.6, 0.0), {"count": 10})
	_place("part_kit", centre + Vector3(-2.3, 0.34, -1.2), Vector3(0.0, -0.4, 0.0), {"count": 8})
	_place("component_crate", centre + Vector3(3.6, 0.0, 2.6), Vector3(0.0, -0.5, 0.0), {"module": "frame", "width": 0.56})
	_place("component_crate", centre + Vector3(-4.4, 0.0, -0.6), Vector3(0.0, 0.9, 0.0), {"module": "energy", "width": 0.52})
	_place("component_crate", centre + Vector3(1.9, 0.0, 3.9), Vector3(0.0, 2.1, 0.0), {"module": "shell", "width": 0.54})
	# futuristic lighting
	_spot(platform, Vector3(0.0, 3.4, 0.0), Vector3(0.0, 1.2, 0.0), 4, &"assembly", 6.5, 34.0, true, Color("ffe0b8"))
	_register_light(platform, 4, &"core", 3.2, 7.0, 1.5, false, Color("7cf3ff"))
	var table_light := OmniLight3D.new()
	table.add_child(table_light)
	table_light.light_color = Color("57e6ff")
	table_light.light_energy = 0.0
	table_light.omni_range = 4.0
	table_light.omni_attenuation = 1.4
	runtime.register_light(table_light, 4, &"holo", 2.4)
	# stations
	_station(platform, Station.Kind.ASSEMBLY, Vector3(0.0, 0.6, 0.0), {
		"area": "assembly", "title": "Assembly station",
		"desc": "The circular stage the prototype is built on. Deck plates, four manipulator arms, the reactor pit and the umbilical.",
		"lore": "Opening the interface installs the salvaged modules in order and runs the assembly sequence.",
		"spec": [["deck", "8 lift plates"], ["arms", "4, two-axis"], ["reactor", "coupling coil cradle"]],
		"prompt": "Press E to open the assembly interface", "sfx": "servo", "distance": 4.5,
	})
	_station(suit_root, Station.Kind.SUIT_DISPLAY, Vector3(0.0, 1.3, 0.0), {
		"area": "assembly", "title": "Exosuit MK-I",
		"desc": "The finished prototype: asymmetric shoulders, exposed hydraulics, hand-formed red plates over a recycled frame, and a core set in a brake-drum bezel.",
		"spec": [["height", "1.86 m"], ["mass", "27.5 kg"], ["frame", "recycled chrome-moly"], ["status", "standing test only"]],
		"prompt": "Press E to wake the prototype", "sfx": "servo", "distance": 4.0,
	})
	_station(cradle, Station.Kind.CORE, Vector3.ZERO, {
		"area": "assembly", "title": "Energy core",
		"desc": "The fictional reactor display: plasma churn, containment rings, arc filaments and a fresnel shell, all in one emissive shader.",
		"lore": "Exposed parameters: glow strength, pulse speed, core colour, rotation speed. The graphics bench lets you drive all four live.",
		"spec": [["shader", "energy_core.gdshader"], ["terms", "plasma, rings, spokes, arcs, fresnel"], ["emission", "feeds bloom"]],
		"prompt": "Press E to pulse the core", "sfx": "core_charge", "distance": 4.0,
	})
	_station(table, Station.Kind.HOLO_TABLE, Vector3(0.0, 0.9, 0.0), {
		"area": "assembly", "title": "Holographic design table",
		"desc": "The inventor's answer to a design review room: a projected cyan schematic of the suit, drawn from the same part list the assembly uses.",
		"spec": [["shader", "hologram.gdshader"], ["terms", "fresnel, scanlines, grid, flicker, band"], ["labels", "Bengali + English"]],
		"prompt": "Press E to raise the schematic", "sfx": "core_charge", "distance": 3.6,
	})
	for n: Node in get_children():
		if String(n.name) == "ComponentCrate":
			var mod: String = String(n.get_meta("module_kind", "frame"))
			var k: Station.Kind = Station.Kind.MODULE_FRAME
			var comp_id: String = "frame_module"
			match mod:
				"energy":
					k = Station.Kind.MODULE_ENERGY
					comp_id = "energy_module"
				"shell":
					k = Station.Kind.MODULE_SHELL
					comp_id = "armour_shell"
			_station(n, k, Vector3(0.0, 0.4, 0.0), {
				"area": "assembly", "title": GameConfig.component_label(comp_id),
				"desc": GameConfig.component_story(comp_id),
				"spec": GameConfig.component_spec(comp_id),
				"module_id": comp_id,
				"prompt": "Press E to recover the module", "sfx": "metal_thunk",
				"repeatable": false,
			})
			(n as Station).module_id = comp_id
			break


# ===========================================================================
# AREA 5 — prototype testing corner
# ===========================================================================

func _area_testing() -> void:
	var centre := Vector3(2.4, 0.0, -structure.half_l + 2.2)
	var deck: Node3D = _place("testing_platform", centre, Vector3.ZERO, {"size": 2.4})
	_place("safety_boundary", centre, Vector3.ZERO, {"radius": 2.1})
	var panel: Node3D = _place("instrument_panel", centre + Vector3(-1.5, 0.0, 0.2), Vector3(0.0, 0.9, 0.0), {"width": 0.95})
	var screen: Node3D = _place("diagnostic_screen", centre + Vector3(1.6, 0.0, -0.6), Vector3(0.0, -0.7, 0.0), {"width": 0.46})
	var scr: Node3D = screen.get_node_or_null("Screen") as Node3D
	if scr != null:
		runtime.register_screen(scr, "diagnostic", "test")
	_place("wooden_stool", centre + Vector3(-1.2, 0.0, 1.2))
	_place("tea_glass", centre + Vector3(-1.3, 0.72, 1.0))
	_place("oil_can", centre + Vector3(-1.6, 0.0, 1.6))
	_place("crate_stack", centre + Vector3(2.2, 0.0, 0.8), Vector3(0.0, 0.4, 0.0), {"count": 3})
	_place("bulb_hanging", centre + Vector3(0.0, structure.height - 0.4, 0.0), Vector3.ZERO, {"drop": 1.1})
	_place("indicator_strip", centre + Vector3(0.0, 1.05, -1.6), Vector3.ZERO, {"length": 2.4, "count": 16})
	_place("conduit_run", centre + Vector3(1.8, 0.3, -1.0), Vector3(0.0, 0.4, 0.0), {"length": 2.2})
	_spot(deck, Vector3(0.0, 3.2, 0.0), Vector3(0.0, 1.0, 0.0), 4, &"testing", 4.2, 30.0, true, Color("fff0d8"))
	_station(panel, Station.Kind.DIAGNOSTICS, Vector3(0.0, 0.9, 0.0), {
		"area": "testing", "title": "Diagnostic console",
		"desc": "Analog gauges, a toggle bank, an emergency stop and a small panel. The instruments are World A; the readings are World B.",
		"spec": [["gauges", "3, panel meter"], ["stops", "1 mushroom head"], ["logging", "200 lines"]],
		"prompt": "Press E to run diagnostics", "sfx": "relay", "distance": 3.4,
	})
	_station(screen, Station.Kind.SUIT_DISPLAY, Vector3(0.0, 1.2, 0.0), {
		"area": "testing", "title": "Prototype display screen",
		"desc": "Portrait panel showing the suit's live diagnostic trace once the prototype is complete.",
		"spec": [["orientation", "portrait"], ["content", "diagnostic trace"]],
		"prompt": "Press E to wake the prototype", "sfx": "servo",
	})


# ===========================================================================
# store room
# ===========================================================================

func _area_store() -> void:
	var x: float = structure.half_w - 1.9
	var z: float = -structure.half_l + 2.2
	_place("shelf_unit", Vector3(x, 0.0, z - 1.2), Vector3(0.0, PI * 0.5, 0.0), {"w": 2.6, "levels": 6, "wood": true})
	_place("shelf_unit", Vector3(x, 0.0, z + 1.2), Vector3(0.0, -PI * 0.5, 0.0), {"w": 2.6, "levels": 5})
	_place("crate_stack", Vector3(x - 0.6, 0.0, z), Vector3(0.0, 0.3, 0.0), {"count": 4})
	_place("sack", Vector3(x + 0.6, 0.0, z - 0.4), Vector3(0.0, 1.1, 0.0))
	_place("sack", Vector3(x + 0.4, 0.55, z + 0.5), Vector3(0.0, 0.4, 0.0))
	_place("storage_box", Vector3(x - 0.2, 0.0, z + 1.8), Vector3(0.0, 0.9, 0.0))
	_place("biscuit_tin", Vector3(x, 1.62, z - 1.2))
	_place("muri_tin", Vector3(x, 1.05, z + 1.2))
	_place("gas_cylinder", Vector3(x + 1.0, 0.0, z + 1.9))
	_place("pallet", Vector3(x, 0.0, z + 2.6))
	_place("hay_bale", Vector3(x, 0.16, z + 2.6))
	_place("water_bucket", Vector3(x - 1.0, 0.0, z + 2.0))
	_place("bulb_hanging", Vector3(x, structure.height - 0.3, z), Vector3.ZERO, {"drop": 0.8})


# ===========================================================================
# Tier 2: procedural layout distribution
# ===========================================================================

func _procedural_layouts() -> void:
	## Distributes the small clutter from the pools in data/workshop_objects.json.
	## Seeded per layout, with rejection sampling against a minimum spacing so
	## objects never intersect, and an occupancy test against the authored
	## furniture AABBs so procedural props never spawn inside a bench.
	var groups: Array = GameConfig.layout_groups()
	for g: Variant in groups:
		var spec: Dictionary = g
		var pool: Array = GameConfig.prop_pool(String(spec.get("pool", "")))
		if pool.is_empty():
			continue
		var r: RandomNumberGenerator = NoiseTools.rng(int(spec.get("seed", 1337)))
		var region: Dictionary = spec.get("region", {})
		var centre: Vector3 = _vec3(region.get("center", Vector3.ZERO))
		var size: Vector3 = _vec3(region.get("size", Vector3.ONE))
		var count: int = int(spec.get("count", 8))
		var min_sep: float = float(spec.get("min_spacing", 0.24))
		var surface: String = String(spec.get("surface", "bench"))
		var placed_here: Array[Vector3] = []
		var attempts: int = 0
		var made: int = 0
		while made < count and attempts < count * 14:
			attempts += 1
			var p := Vector3(
				centre.x + r.randf_range(-size.x * 0.5, size.x * 0.5),
				centre.y,
				centre.z + r.randf_range(-size.z * 0.5, size.z * 0.5),
			)
			var rejected: bool = false
			for q: Vector3 in placed_here:
				if Vector2(q.x - p.x, q.z - p.z).length() < min_sep:
					rejected = true
					break
			if rejected or _inside_authored(p):
				continue
			placed_here.append(p)
			made += 1
			var kind: String = String(pool[r.randi_range(0, pool.size() - 1)])
			var node: Node3D = props.build(kind, {"scale": r.randf_range(
				float((spec.get("scale_range", [0.9, 1.1]))[0]),
				float((spec.get("scale_range", [0.9, 1.1]))[1]),
			)})
			node.position = p
			node.rotation.y = r.randf_range(0.0, TAU_D)
			if surface == "floor":
				node.position.y = 0.01 + r.randf_range(0.0, 0.02)
			add_child(node)
			placed_count += 1
			placed["~procedural:" + kind] = int(placed.get("~procedural:" + kind, 0)) + 1
			# a few of the clutter items become readable, so inspection rewards
			# exploring rather than only pointing at the important objects
			if r.randf() > 0.86:
				_station(node, Station.Kind.PART, Vector3.ZERO, {
					"area": String(spec.get("id", "")), "title": _title_from_kind(kind),
					"desc": _desc_from_kind(kind), "sfx": "tool_place",
				})
		var stats: Dictionary = {
			"layout": String(spec.get("id", "")), "requested": count, "placed": made,
			"attempts": attempts, "efficiency": float(made) / float(maxi(attempts, 1)),
		}
		_layout_stats.append(stats)


var _layout_stats: Array = []


func layout_stats() -> Array:
	return _layout_stats


func _vec3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _inside_authored(p: Vector3) -> bool:
	for box: AABB in _occupied:
		if box.has_point(p + Vector3(0.0, 0.1, 0.0)):
			return true
	return false


func _title_from_kind(kind: String) -> String:
	return kind.replace("_", " ").capitalize()


func _desc_from_kind(kind: String) -> String:
	match kind:
		"spanner", "screwdriver", "pliers", "hammer", "chisel", "file_metal", "tyre_lever":
			return "A hand tool from the bench, used daily and kept sharp. It has no serial number and no brand; it predates both."
		"pcb_board", "capacitor", "resistor_pack", "heatsink", "ram_stick", "dip_switch":
			return "Salvaged board stock, sorted into the component tins by hand. Half of it is already dead and the other half is uncertain."
		"tea_glass", "flask", "muri_tin", "biscuit_tin", "newspaper_fold", "cup_brush":
			return "A daily-life object in a working space. The tea is how long jobs get through."
		"scrap_plate", "bent_rod", "offcut_tin", "rusty_can", "angle_bracket", "spring_coil":
			return "Offcut stock kept because a workshop never throws away the piece that might become a bracket."
		"bearing", "gear_set", "chain_link", "piston", "bolt_cluster", "washer_pile":
			return "Driven stock. Sorted by size, tested by feel, and re-used until it rattles."
		_:
			return "Workshop stock, in the place it has always been in."


# ===========================================================================
# Tier 3: wall racks
# ===========================================================================

func _wall_racks() -> void:
	var rack_specs: Array = [
		{"origin": Vector3(-structure.half_w + 0.3, 1.75, 2.2), "facing": PI * 0.5,
			"tools": ["hammer", "hacksaw", "pipe_wrench", "pliers", "spanner", "screwdriver", "chisel", "tape_measure", "spirit_level", "file_metal"],
			"spacing": 0.29},
		{"origin": Vector3(-structure.half_w + 0.3, 1.3, 5.4), "facing": PI * 0.5,
			"tools": ["spanner", "screwdriver", "pliers", "adjustable_wrench", "hammer", "tyre_lever", "chisel"],
			"spacing": 0.31},
		{"origin": Vector3(structure.half_w - 0.3, 1.7, 2.0), "facing": -PI * 0.5,
			"tools": ["soldering_iron", "wire_cutters", "screwdriver", "pliers", "tape_measure"],
			"spacing": 0.3},
	]
	for rs: Dictionary in rack_specs:
		var origin: Vector3 = rs["origin"]
		var facing: float = rs["facing"]
		var tools: Array = rs["tools"]
		var spacing: float = rs["spacing"]
		var rail: MeshInstance3D = ShapeKit.cyl(0.018, float(tools.size()) * spacing + 0.2, ML.steel_dark(), 10, Vector3i(0, 0, 1), "ToolRail")
		rail.position = origin
		rail.rotation.y = facing
		add_child(rail)
		_occupied.append(AABB(origin - Vector3(0.3, 0.3, 0.3), Vector3(0.6, 0.6, float(tools.size()) * spacing + 0.4)))
		for i: int in range(tools.size()):
			var kind: String = String(tools[i])
			var node: Node3D = props.build(kind, {})
			var z: float = origin.z - (float(tools.size()) * spacing) * 0.5 + float(i) * spacing + spacing * 0.5
			node.position = Vector3(origin.x, origin.y - 0.06, z)
			node.rotation = Vector3(0.0, facing, PI * 0.5)
			# hanging tools tilt outward slightly, the way they actually rest
			node.rotation.x = 0.12 * (1.0 if i % 2 == 0 else -1.0)
			add_child(node)
			placed_count += 1
			placed["~rack:" + kind] = int(placed.get("~rack:" + kind, 0)) + 1
			if i % 3 == 0:
				_station(node, Station.Kind.TOOL, Vector3.ZERO, {
					"area": "mechanical", "title": _title_from_kind(kind),
					"desc": _desc_from_kind(kind), "sfx": "tool_place", "distance": 2.6,
				})


# ===========================================================================
# cables
# ===========================================================================

func _cables() -> void:
	## The procedural cable generator's in-world use: the switchboard pigtail, the
	## workstation loom, the IPS leads, the reactor feed and the hanging runs along
	## the beams. Bundled where several wires share a route, which is the draw-call
	## saving measured in Experiment 4.
	var gen := CableGenerator.new()
	var sleeve: StandardMaterial3D = ML.cable_material(Color("#1b1d20"))
	var red: StandardMaterial3D = ML.cable_material(Color("#7a1f1a"))
	var blue: StandardMaterial3D = ML.cable_material(Color("#1a2f6a"))
	var yellow: StandardMaterial3D = ML.cable_material(Color("#6a5a1a"))
	var holo: StandardMaterial3D = ML.cable_material(Color("#123a45"))
	var half_l: float = structure.half_l
	var x: float = structure.half_w

	# 1. switchboard -> mechanical bench, a bundled loom of four
	var loom_wires: Array = [
		{"start": Vector3(-x + 0.4, 1.6, half_l - 1.6), "end": Vector3(-x + 1.2, 0.98, 3.0), "sag": 0.28},
		{"start": Vector3(-x + 0.4, 1.55, half_l - 1.6), "end": Vector3(-x + 1.6, 0.98, 2.4), "sag": 0.3},
		{"start": Vector3(-x + 0.4, 1.5, half_l - 1.6), "end": Vector3(-x + 2.2, 0.98, 4.4), "sag": 0.34},
		{"start": Vector3(-x + 0.4, 1.45, half_l - 1.6), "end": Vector3(-x + 0.9, 0.0, 5.8), "sag": 0.5},
	]
	var bundle: MeshInstance3D = gen.make_node({
		"wires": loom_wires, "radius": 0.011, "radial_segments": 7, "length_segments": 26,
		"spread": 0.03, "material": sleeve, "u_scale": 2.0,
	}, "SwitchboardLoom")
	add_child(bundle)
	_bundle_stats = gen.last_stats.duplicate()

	# 2. workstation loom: tower -> CRT -> LCD -> socket, bundled
	var ws_wires: Array = [
		{"start": Vector3(x - 2.4, 0.35, 3.1), "end": Vector3(x - 1.9, 0.94, 3.6), "sag": 0.12},
		{"start": Vector3(x - 2.4, 0.35, 3.1), "end": Vector3(x - 1.0, 0.94, 3.5), "sag": 0.16},
		{"start": Vector3(x - 2.4, 0.35, 3.1), "end": Vector3(x - 1.5, 0.94, 4.3), "sag": 0.1},
		{"start": Vector3(x - 2.4, 0.35, 3.1), "end": Vector3(x - 0.2, 1.3, 3.0), "sag": 0.3},
	]
	add_child(gen.make_node({
		"wires": ws_wires, "radius": 0.008, "radial_segments": 6, "length_segments": 22,
		"spread": 0.022, "material": sleeve, "u_scale": 1.6,
	}, "WorkstationLoom"))

	# 3. IPS leads: battery rack -> switchboard, the heaviest cables in the room
	add_child(gen.make_node({
		"wires": [
			{"start": Vector3(x - 3.2, 0.35, 5.9), "end": Vector3(x - 2.2, 0.02, 5.4), "sag": 0.12},
			{"start": Vector3(x - 3.2, 0.35, 5.9), "end": Vector3(x - 1.2, 0.02, 5.2), "sag": 0.14},
			{"start": Vector3(x - 3.2, 0.4, 5.9), "end": Vector3(x - 0.2, 1.3, 3.0), "sag": 0.5},
		],
		"radius": 0.016, "radial_segments": 8, "length_segments": 28, "spread": 0.04,
		"material": red, "u_scale": 2.4,
	}, "IpsLeads"))

	# 4. the reactor feed: a single thick conduit-cable, the labelled one
	var feed: MeshInstance3D = gen.make_node({
		"start": Vector3(x - 0.4, 1.4, 2.4), "end": Vector3(0.0, 0.42, -2.2),
		"sag": 1.1, "slack": 0.4, "sideways": 0.6, "radius": 0.03,
		"radial_segments": 12, "length_segments": 44, "material": holo, "u_scale": 4.0,
		"taper": 0.96,
	}, "ReactorFeed")
	add_child(feed)
	_feed_stats = gen.last_stats.duplicate()

	# 5. hanging runs along the ceiling beams, sagged and spaced
	for i: int in range(5):
		var z: float = -structure.half_l + 1.6 + float(i) * 2.6
		var hang: MeshInstance3D = gen.make_hang(
			Vector3(-structure.half_w + 0.4, structure.height - 0.28, z),
			Vector3(structure.half_w - 0.4, structure.height - 0.32, z + 0.3),
			1.06, 0.009, [sleeve, blue, yellow, sleeve, holo][i], 30)
		hang.name = "CeilingRun%d" % i
		add_child(hang)

	# 6. the loose jumper cables a workshop always has, draped over the shelf
	add_child(gen.make_hang(
		Vector3(-structure.half_w + 0.6, 1.9, 0.6),
		Vector3(-structure.half_w + 1.4, 0.98, 1.2), 1.35, 0.007, blue, 24))
	add_child(gen.make_hang(
		Vector3(structure.half_w - 0.5, 1.85, 2.0),
		Vector3(structure.half_w - 1.6, 0.94, 2.3), 1.4, 0.006, yellow, 24))


var _bundle_stats: Dictionary = {}
var _feed_stats: Dictionary = {}


func cable_stats() -> Dictionary:
	return {"bundle": _bundle_stats, "reactor_feed": _feed_stats}


# ===========================================================================
# signage and ambience
# ===========================================================================

func _signage() -> void:
	## All in-world text, baked through the SignageBaker so Bengali is shaped by
	## the engine's text stack. The brief's sample strings contained orthographic
	## errors; the strings here are standard Bengali (see docs/PROJECT_OVERVIEW.md).
	var labels: Dictionary = GameConfig.bangla_labels()
	var half_l: float = structure.half_l
	# the signboard face
	var sign: Node3D = _find_first("Signboard")
	if sign != null:
		var face: MeshInstance3D = sign.get_node_or_null("Face") as MeshInstance3D
		if face != null:
			var spec: Dictionary = _sign_spec(String(labels.garage_name), String(labels.brand), String(labels.tagline))
			baker.apply_baked(face, spec, "signboard", 0.35, 0.42)
	# the workshop name plate inside
	var plate_spec: Dictionary = _plate_spec(String(labels.lab))
	var plate: MeshInstance3D = ShapeKit.plane(Vector2(1.1, 0.34), null, "LabPlate")
	plate.position = Vector3(-structure.half_w + 0.24, 2.9, 1.0)
	plate.rotation = Vector3(0.0, PI * 0.5, 0.0)
	add_child(plate)
	baker.apply_baked(plate, plate_spec, "lab_plate", 0.2, 0.3)
	# the danger notice by the switchboard
	var danger_spec: Dictionary = _danger_spec(String(labels.danger_electric), String(labels.switchboard))
	var danger: MeshInstance3D = ShapeKit.plane(Vector2(0.34, 0.24), null, "DangerNotice")
	danger.position = Vector3(-structure.half_w + 0.22, 2.35, half_l - 1.6)
	danger.rotation = Vector3(0.0, PI * 0.5, 0.0)
	add_child(danger)
	baker.apply_baked(danger, danger_spec, "danger", 0.15, 0.5)
	# the calendar face, with Bengali month names
	var cal: Node3D = _find_first("WallCalendar")
	if cal != null:
		var sheet: MeshInstance3D = cal.get_node_or_null("Sheet") as MeshInstance3D
		if sheet != null:
			baker.apply_baked(sheet, _calendar_spec(labels), "calendar", 0.0, 0.7)
	# the notebook's open page: the first sketch of the suit
	var nb: Node3D = _find_first("Notebook")
	if nb != null:
		var page: MeshInstance3D = nb.get_node_or_null("OpenPage") as MeshInstance3D
		if page != null:
			baker.apply_baked(page, _notebook_spec(String(labels.first_sketch)), "notebook", 0.0, 0.85)
	# the poster faces
	var posters: Array = _find_all("Poster")
	for i: int in range(posters.size()):
		var p: Node3D = posters[i] as Node3D
		var poster_sheet: MeshInstance3D = p.get_node_or_null("Sheet") as MeshInstance3D
		if poster_sheet == null:
			continue
		baker.apply_baked(poster_sheet, _poster_spec(i, String(labels.dream), String(labels.prototype)), "poster%d" % i, 0.0, 0.65)
	# the component crate tags
	for crate: Node in _find_all("ComponentCrate"):
		var tag: MeshInstance3D = (crate as Node3D).get_node_or_null("Tag") as MeshInstance3D
		if tag == null:
			continue
		var mod: String = String(crate.get_meta("module_kind", "frame"))
		var comp_id: String = "frame_module"
		match mod:
			"energy":
				comp_id = "energy_module"
			"shell":
				comp_id = "armour_shell"
		var rows: Array = GameConfig.component_spec(comp_id)
		var detail: String = String(rows[0][1]) if not rows.is_empty() else "salvage"
		baker.apply_baked(tag, _crate_tag_spec(GameConfig.component_short(comp_id), detail), "tag_" + mod, 0.25, 0.5)


func _find_first(name: String) -> Node3D:
	for n: Node in get_children():
		if String(n.name) == name:
			return n as Node3D
	return null


func _find_all(name: String) -> Array:
	var out: Array = []
	for n: Node in get_children():
		if String(n.name) == name:
			out.append(n)
	return out


func _sign_spec(garage: String, brand: String, tagline: String) -> Dictionary:
	return {
		"size": Vector2i(1024, 256), "transparent": false, "bg": "#0e1a26",
		"border": {"color": "#d4af37", "width": 6.0},
		"layers": [
			{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(1024, 62), "color": "#16283a"},
			{"type": "rect", "pos": Vector2(0, 194), "sz": Vector2(1024, 62), "color": "#16283a"},
			{"type": "text", "name": "GARAGE", "pos": Vector2(28, 62), "size": 96, "color": "#f2e6c8", "text": garage, "font": "bangla", "shadow": true},
			{"type": "text", "name": "BRAND", "pos": Vector2(28, 12), "size": 34, "color": "#d4af37", "text": brand, "font": "bangla"},
			{"type": "text", "name": "TAG", "pos": Vector2(28, 202), "size": 40, "color": "#4fd8ff", "text": tagline, "font": "bangla"},
			{"type": "text", "name": "EN", "pos": Vector2(700, 206), "size": 30, "color": "#8fa0ab", "text": "OPEN 24 HOURS", "font": "mono"},
			{"type": "circle", "center": Vector2(960, 128), "radius": 34, "color": "#e2453c", "filled": true},
			{"type": "text", "name": "NUM", "pos": Vector2(700, 74), "size": 40, "color": "#c8d0d8", "text": "017XX-XXXXXX", "font": "mono"},
		],
	}


func _plate_spec(lab: String) -> Dictionary:
	return {
		"size": Vector2i(512, 160), "transparent": false, "bg": "#12202b",
		"border": {"color": "#4fd8ff", "width": 3.0},
		"layers": [
			{"type": "text", "name": "LAB", "pos": Vector2(18, 44), "size": 54, "color": "#9ff0ff", "text": lab, "font": "bangla"},
			{"type": "line", "from": Vector2(18, 108), "to": Vector2(494, 108), "color": "#2a5a6a", "width": 2.0},
			{"type": "text", "name": "SUB", "pos": Vector2(18, 118), "size": 26, "color": "#7a8a95", "text": "EXPERIMENTAL LABORATORY  ·  MK-I", "font": "mono"},
		],
	}


func _danger_spec(danger: String, board: String) -> Dictionary:
	return {
		"size": Vector2i(384, 256), "transparent": false, "bg": "#f2d024",
		"border": {"color": "#1b1d20", "width": 5.0},
		"layers": [
			{"type": "poly", "points": [Vector2(192, 22), Vector2(348, 210), Vector2(36, 210)], "color": Color(0.1, 0.1, 0.12, 1.0), "filled": false, "width": 12.0},
			{"type": "text", "name": "BOLT", "pos": Vector2(168, 176), "size": 96, "color": "#f2d024", "text": "⚡", "font": "latin"},
			{"type": "text", "name": "BN", "pos": Vector2(16, 214), "size": 34, "color": "#1b1d20", "text": danger, "font": "bangla"},
			{"type": "text", "name": "EN", "pos": Vector2(16, 228), "size": 20, "color": "#3a3520", "text": ("MAIN SWITCHBOARD / " + board), "font": "mono"},
		],
	}


func _calendar_spec(labels: Dictionary) -> Dictionary:
	var months: Array = labels.get("months", [])
	var month_names: Array = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
		"JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
	var bn: String = String(months[10]) if months.size() > 10 else "নভেম্বর"
	var en: String = String(month_names[10])
	var layers: Array = [
		{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(512, 92), "color": "#b03a2c"},
		{"type": "text", "name": "MONTH_BN", "pos": Vector2(20, 22), "size": 52, "color": "#f4ecd8", "text": bn, "font": "bangla"},
		{"type": "text", "name": "MONTH_EN", "pos": Vector2(20, 62), "size": 24, "color": "#e8c8a0", "text": en + "  2026", "font": "mono"},
		{"type": "grid", "pos": Vector2(16, 100), "sz": Vector2(480, 300), "step": 68.0, "color": "#c8bfa8"},
	]
	# the day cells, with both date columns every Bangladeshi calendar carries
	var digits: Array = labels.get("digits", [])
	for r: int in range(5):
		for c: int in range(7):
			var day: int = r * 7 + c + 1
			if day > 30:
				continue
			var x: float = 24.0 + float(c) * 68.0
			var y: float = 104.0 + float(r) * 60.0
			layers.append({"type": "text", "name": "D%d_%d" % [r, c], "pos": Vector2(x, y), "size": 26, "color": "#2a2a28", "text": str(day), "font": "latin"})
			var bn_digit: String = String(digits[day % 10]) if digits.size() == 10 else str(day % 10)
			layers.append({"type": "text", "name": "B%d_%d" % [r, c], "pos": Vector2(x + 34, y + 2), "size": 20, "color": "#8a2a1a", "text": bn_digit, "font": "bangla"})
	layers.append({"type": "text", "name": "FOOT", "pos": Vector2(20, 412), "size": 22, "color": "#5a5548", "text": "SHANTI SPARES  ·  BAIDYAPATH ROAD", "font": "mono"})
	return {"size": Vector2i(512, 448), "transparent": false, "bg": "#f4ecd8", "layers": layers}


func _notebook_spec(first_sketch: String) -> Dictionary:
	## The page the player finds on the bench: the first exosuit sketch, drawn as
	## construction lines rather than a finished illustration, with Bengali
	## annotations and the dimensions that matter to the build.
	var layers: Array = [
		{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(512, 384), "color": "#efe7cf"},
		{"type": "grid", "pos": Vector2(10, 60), "sz": Vector2(492, 300), "step": 24.0, "color": Color(0.35, 0.45, 0.6, 0.22)},
		{"type": "text", "name": "TITLE", "pos": Vector2(16, 12), "size": 34, "color": "#2a3a5a", "text": first_sketch, "font": "bangla"},
		{"type": "text", "name": "SUB", "pos": Vector2(300, 20), "size": 18, "color": "#6a5a4a", "text": "MK-I  ·  sheet 4 of 84", "font": "mono"},
		# the figure: torso, head, arms, legs, all construction lines
		{"type": "circle", "center": Vector2(256, 118), "radius": 26, "color": "#2a3a5a", "filled": false, "width": 2.5},
		{"type": "poly", "points": [Vector2(230, 146), Vector2(282, 146), Vector2(292, 214), Vector2(220, 214)], "color": "#2a3a5a", "filled": false, "width": 3.0},
		{"type": "line", "from": Vector2(220, 152), "to": Vector2(186, 226), "color": "#2a3a5a", "width": 2.5},
		{"type": "line", "from": Vector2(292, 152), "to": Vector2(326, 226), "color": "#2a3a5a", "width": 2.5},
		{"type": "line", "from": Vector2(232, 214), "to": Vector2(226, 300), "color": "#2a3a5a", "width": 2.5},
		{"type": "line", "from": Vector2(280, 214), "to": Vector2(286, 300), "color": "#2a3a5a", "width": 2.5},
		{"type": "circle", "center": Vector2(256, 180), "radius": 15, "color": "#8a2a1a", "filled": false, "width": 3.0},
		{"type": "circle", "center": Vector2(256, 180), "radius": 7, "color": "#8a2a1a", "filled": true},
		# the dimension lines
		{"type": "line", "from": Vector2(340, 92), "to": Vector2(340, 300), "color": "#8a2a1a", "width": 1.5},
		{"type": "line", "from": Vector2(334, 92), "to": Vector2(346, 92), "color": "#8a2a1a", "width": 1.5},
		{"type": "line", "from": Vector2(334, 300), "to": Vector2(346, 300), "color": "#8a2a1a", "width": 1.5},
		{"type": "text", "name": "H", "pos": Vector2(348, 186), "size": 18, "color": "#8a2a1a", "text": "1860 mm", "font": "mono"},
		{"type": "line", "from": Vector2(186, 320), "to": Vector2(326, 320), "color": "#8a2a1a", "width": 1.5},
		{"type": "text", "name": "W", "pos": Vector2(214, 326), "size": 18, "color": "#8a2a1a", "text": "740 mm", "font": "mono"},
		# the annotations
		{"type": "text", "name": "A1", "pos": Vector2(20, 250), "size": 20, "color": "#2a3a5a", "text": "ফ্রেম: পুরনো বাইক", "font": "bangla"},
		{"type": "text", "name": "A2", "pos": Vector2(20, 280), "size": 20, "color": "#2a3a5a", "text": "শক্তি: আইপিএস খন্ড", "font": "bangla"},
		{"type": "text", "name": "A3", "pos": Vector2(20, 310), "size": 20, "color": "#2a3a5a", "text": "খোলস: ছাদার কলজ", "font": "bangla"},
		{"type": "text", "name": "NOTE", "pos": Vector2(20, 344), "size": 16, "color": "#6a5a4a", "text": "standing test only — no flight, no load", "font": "mono"},
	]
	return {"size": Vector2i(512, 384), "transparent": false, "bg": "#efe7cf", "layers": layers}


func _poster_spec(index: int, dream: String, prototype: String) -> Dictionary:
	var palettes: Array = [
		["#1a2a3a", "#e0c04a", "#c85a3a"],
		["#2a1a2a", "#8ab0c8", "#d4af37"],
		["#123a2a", "#e8e0c8", "#b03a2c"],
	]
	var pal: Array = palettes[index % palettes.size()]
	return {
		"size": Vector2i(512, 704), "transparent": false, "bg": String(pal[0]),
		"border": {"color": String(pal[2]), "width": 4.0},
		"layers": [
			{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(512, 150), "color": String(pal[2])},
			{"type": "text", "name": "T", "pos": Vector2(24, 40), "size": 62, "color": "#f4ecd8", "text": dream, "font": "bangla"},
			{"type": "text", "name": "S", "pos": Vector2(24, 104), "size": 26, "color": "#e8d8b0", "text": prototype, "font": "bangla"},
			{"type": "circle", "center": Vector2(256, 400), "radius": 120, "color": String(pal[1]), "filled": false, "width": 6.0},
			{"type": "circle", "center": Vector2(256, 400), "radius": 70, "color": String(pal[1]), "filled": false, "width": 3.0},
			{"type": "poly", "points": [Vector2(196, 400), Vector2(316, 400), Vector2(256, 300)], "color": String(pal[1]), "filled": true},
			{"type": "line", "from": Vector2(24, 600), "to": Vector2(488, 600), "color": String(pal[1]), "width": 2.0},
			{"type": "text", "name": "F", "pos": Vector2(24, 620), "size": 22, "color": "#c8c0a8", "text": "DREAM GARAGE  ·  EST. 2019", "font": "mono"},
		],
	}


func _crate_tag_spec(short: String, detail: String) -> Dictionary:
	return {
		"size": Vector2i(256, 128), "transparent": false, "bg": "#e8e0cc",
		"border": {"color": "#8a2a1a", "width": 4.0},
		"layers": [
			{"type": "text", "name": "M", "pos": Vector2(14, 12), "size": 44, "color": "#1b2a3a", "text": short, "font": "display"},
			{"type": "line", "from": Vector2(14, 66), "to": Vector2(242, 66), "color": "#8a2a1a", "width": 2.0},
			{"type": "text", "name": "D", "pos": Vector2(14, 78), "size": 20, "color": "#4a4538", "text": detail, "font": "mono"},
		],
	}


# ===========================================================================
# ambience props
# ===========================================================================

func _ambience_props() -> void:
	## Objects that exist to be looked at rather than used: the tea corner, the
	## hanging gamcha, the sack pile, the newspaper underfoot.
	var half_l: float = structure.half_l
	_place("tea_glass", Vector3(-2.2, 0.72, 7.3))
	_place("tea_glass", Vector3(-1.9, 0.72, 7.5))
	_place("flask", Vector3(-2.5, 0.72, 7.1))
	_place("muri_tin", Vector3(-1.6, 0.72, 7.0))
	_place("biscuit_tin", Vector3(-2.8, 0.72, 6.8))
	_place("newspaper_fold", Vector3(-1.4, 0.02, 6.2))
	_place("newspaper_fold", Vector3(2.0, 0.02, 5.0))
	_place("towel_hanging", Vector3(-3.0, structure.height - 0.55, 2.4), Vector3(0.0, 0.2, 0.0), {"length": 0.8})
	_place("towel_hanging", Vector3(2.6, structure.height - 0.6, 4.8), Vector3(0.0, -0.3, 0.0), {"length": 0.7})
	_place("sack", Vector3(-4.2, 0.0, -6.4), Vector3(0.0, 0.7, 0.0))
	_place("sack", Vector3(-4.0, 0.42, -6.0), Vector3(0.0, -0.3, 0.0), {"scale": 0.85})
	_place("water_bucket", Vector3(4.4, 0.0, 7.2))
	_place("cup_brush", Vector3(4.1, 0.02, 7.0))
	_place("soap_dish", Vector3(-5.4, 0.02, 7.4))
	_place("comb", Vector3(-5.1, 0.02, 7.2))
	_place("plastic_bag_roll", Vector3(-6.0, 1.9, 4.0))
	_place("shelf_label", Vector3(-6.1, 1.4, 0.6), Vector3(0.0, PI * 0.5, 0.0))
	_place("shelf_label", Vector3(6.1, 1.4, 2.0), Vector3(0.0, -PI * 0.5, 0.0))
	_place("hook_nail", Vector3(-6.1, 2.1, 6.8), Vector3(0.0, PI * 0.5, 0.0))
	_place("photo_frame", Vector3(-6.0, 1.9, 7.6), Vector3(0.0, PI * 0.5, 0.0))
	_place("clip_board", Vector3(6.0, 1.9, 5.6), Vector3(0.0, -PI * 0.5, 0.0))
	_place("gas_cylinder", Vector3(-5.6, 0.0, -6.8))
	_place("pallet", Vector3(5.2, 0.0, -6.2))
	_place("crate_stack", Vector3(5.2, 0.18, -6.2), Vector3(0.0, 0.6, 0.0), {"count": 3})
	_place("cable_reel", Vector3(-5.8, 0.0, -4.0))
	_place("steel_drum", Vector3(5.6, 0.0, -3.0))
	_place("scrap_bin", Vector3(-5.2, 0.0, -2.0))
	_place("bicycle", Vector3(5.0, 0.0, 7.6), Vector3(0.0, 2.4, 0.0))
	_place("wheel_motorcycle", Vector3(-3.4, 0.3, -7.0), Vector3(0.0, 0.4, PI * 0.5))
	_place("tyre", Vector3(3.2, 0.28, -7.2), Vector3(0.0, -0.3, PI * 0.5))
	_place("hand_drill", Vector3(-4.6, 0.98, 2.2))
	_place("impact_driver", Vector3(4.2, 0.94, 2.6))
	_place("cutting_torch", Vector3(-4.9, 0.0, 4.4))
	_place("tool_chest", Vector3(-4.8, 0.0, 0.2), Vector3(0.0, 0.4, 0.0), {"width": 0.5})
	_place("radio", Vector3(4.6, 0.96, 6.6))
	_place("wall_clock", Vector3(6.05, 2.5, 6.4), Vector3(0.0, -PI * 0.5, 0.0))
	_place("poster", Vector3(-6.05, 2.4, -3.0), Vector3(0.0, PI * 0.5, 0.0), {"variant": 3})
	_place("poster", Vector3(6.05, 2.3, -4.6), Vector3(0.0, -PI * 0.5, 0.0), {"variant": 4})
	_place("wall_calendar", Vector3(6.05, 2.35, 0.6), Vector3(0.0, -PI * 0.5, 0.0))
	_place("ceiling_fan", Vector3(0.0, structure.height - 0.2, 5.2), Vector3.ZERO, {"radius": 0.6, "drop": 0.46})
	_place("fluorescent_battlement", Vector3(0.0, structure.height - 0.35, 6.4), Vector3(0.0, PI * 0.5, 0.0), {"length": 1.6})
	_place("bulb_hanging", Vector3(3.6, structure.height - 0.35, -5.6), Vector3.ZERO, {"drop": 1.0})
	_place("pedestal_fan", Vector3(-2.0, 0.0, -6.6), Vector3(0.0, 1.0, 0.0))
