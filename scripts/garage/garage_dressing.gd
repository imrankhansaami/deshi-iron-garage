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
	_ambience_props()
	_scientists_corner()
	# last, so it sees crates placed by any area
	_register_component_crates()
	# signage after everything: it looks up props by name
	_signage()
	# grime last of all, so the decals project onto the finished floor and walls
	_grime_decals()


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
		# fans are registered here rather than at their call sites, because a fan
		# station is useless without a rotor in the runtime's spin list: the switch
		# flipped, the log line printed, and the blades stood still.
		var kind_value: int = int(kind)
		if kind_value == int(Station.Kind.FAN_CEILING) or kind_value == int(Station.Kind.FAN_PEDESTAL) or kind_value == int(Station.Kind.FAN_TABLE):
			runtime.register_fan(node, String(opts.get("fan_key", "")), float(opts.get("rpm", 42.0)))
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
	## Compact entrance. Everything here is measured from the structure's own
	## half-extents so it tracks the preset dimensions instead of assuming them, and
	## the courtyard props sit in the 4.6 m of yard rather than out past the boundary
	## wall where the earlier 6 m yard put them.
	var half_l: float = structure.half_l
	var half_w: float = structure.half_w
	# the shutter station is the first interaction in the experience
	var shutter: Node3D = structure.get_node_or_null("Shutter")
	if shutter != null:
		runtime.setup_shutter(shutter)
		_station(shutter, Station.Kind.SHUTTER, Vector3.ZERO, {
			"area": "entrance", "title": "Rolling shutter",
			"desc": "The corrugated curtain that keeps the monsoon out. It is chained up these days: the workshop runs open, because the inventor works late and customers come when they come.",
			"lore": "The slats are individual geometry, and the curtain is coupled to the daylight — with it up, the shafts and the volumetric fog stand at full strength all day.",
			"spec": [["mechanism", "manual chain drive"], ["curtain", "20 slats"], ["travel", "2.25 m"], ["state", "chained open"]],
			"prompt": "Press E to check the shutter", "sfx": "latch", "distance": 4.0,
		})
	# the signboard over the shutter. Raised from 2.78 to 2.95: at 2.78 its bottom
	# third sat behind the shutter head beam, which is 3 cm prouder than the board.
	var sign: Node3D = _place("signboard", Vector3(0.0, 2.95, half_l + 0.14), Vector3.ZERO, {"width": 2.5, "height": 0.6})
	_station(sign, Station.Kind.SIGN, Vector3.ZERO, {
		"area": "entrance", "title": "Garage signboard",
		"desc": "Hand-painted on a sheet of tin: the shop name in Bangla, the tagline underneath, and a phone number that is really a mobile number.",
		"spec": [["script", "Bengali, Noto Sans Bengali"], ["medium", "house paint on tin"], ["repainted", "three times"]],
		"sfx": "", "distance": 7.0,
	})
	# the banner over the left pier of the facade, facing the street. A second,
	# larger print than the signboard, in the English name the owner uses for it.
	## The print face is a blank in the prop; _signage() bakes the generated banner
	## onto it through the same SignCanvas the interior signs use.
	var outside_banner: Node3D = _place("wall_banner", Vector3(-2.85, 1.78, half_l + 0.17), Vector3.ZERO, {"width": 1.7, "spec": true})
	outside_banner.name = "OutsideBanner"
	_station(outside_banner, Station.Kind.SIGN, Vector3.ZERO, {
		"area": "exterior", "title": "Street banner",
		"desc": "Printed at the sign shop two lanes over: IMRAN'S GARAGE, in gold on navy, because that is what the stickers on the toolboxes say.",
		"spec": [["print", "flex banner, 1.7 m"], ["script", "English + Bengali"], ["hung", "over the left pier"]],
		"sfx": "", "distance": 5.5,
	})
	# the courtyard: three props, because 8.5 m of frontage holds three
	var bicycle: Node3D = _place("bicycle", Vector3(-half_w + 1.3, 0.0, half_l + 1.9), Vector3(0.0, 0.5, 0.0), {"scale": 0.95})
	_station(bicycle, Station.Kind.PART, Vector3.ZERO, {
		"area": "exterior", "title": "Workshop bicycle",
		"desc": "The spare bicycle. It does not belong to anyone in particular and it is used by everyone.",
		"spec": [["wheels", "26 inch, wire spoked"], ["purpose", "spares and short errands"]],
		"sfx": "metal_tink", "distance": 2.8,
	})
	_place("wheel_rickshaw", Vector3(half_w - 1.1, 0.34, half_l + 1.6), Vector3(0.0, 0.3, 0.0), {"radius": 0.34})
	_place("crate_stack", Vector3(half_w - 2.0, 0.0, half_l + 2.6), Vector3(0.0, -0.4, 0.0), {"count": 3})
	_place("scrap_bin", Vector3(-half_w + 2.6, 0.0, half_l + 2.9), Vector3(0.0, 0.9, 0.0), {"w": 0.7, "h": 0.45})
	_place("sandals", Vector3(-0.7, 0.0, half_l - 0.3), Vector3(0.0, 0.4, 0.0))
	_place("water_bucket", Vector3(half_w - 0.6, 0.0, half_l - 0.5))
	# the interior entrance strip
	var stool: Node3D = _place("wooden_stool", Vector3(half_w - 1.5, 0.0, half_l - 1.7))
	_station(stool, Station.Kind.EVERYDAY, Vector3.ZERO, {
		"area": "entrance", "title": "Wooden stool",
		"desc": "Where the visitor sits while the job is finished. Three legs are original.",
		"spec": [["seat", "teak, 380 mm"], ["legs", "4, one replaced"]],
		"sfx": "tool_place",
	})
	_place("storage_box", Vector3(-half_w + 1.0, 0.0, half_l - 1.4), Vector3(0.0, 0.3, 0.0))
	_place("sack", Vector3(-half_w + 1.9, 0.0, half_l - 0.7), Vector3(0.0, 0.6, 0.0), {"scale": 0.85})
	_place("bicycle_chain", Vector3(half_w - 0.12, 1.35, 3.75), Vector3(0.0, -PI * 0.5, 1.4), {"links": 14})
	# the entrance light is the batten _ambience_props() hangs at (0, 3.5): the bare
	# bulb that used to hang here sat 15 cm from it
	_place("wall_socket", Vector3(half_w - 0.14, 1.25, half_l - 1.2), Vector3(0.0, -PI * 0.5, 0.0))
	# the switchboard on the west wall, four metres from the shutter
	var board: Node3D = _place("switchboard", Vector3(-half_w + 0.2, 1.58, 3.6), Vector3(0.0, PI * 0.5, 0.0), {"width": 0.42, "height": 0.55, "mcbs": 4})
	_station(board, Station.Kind.SWITCHBOARD, Vector3.ZERO, {
		"area": "entrance", "title": "Main switchboard",
		"desc": "The distribution board that feeds the whole garage. The main switch is down: the workshop has been running off one borrowed circuit, and it finally gave up.",
		"lore": "Restoring power here brings up the tube lights, the bench lamps, the workstation, the fans and the reactor zone in sequence — real light nodes, not a material swap.",
		"spec": [["supply", "230 V / 50 Hz"], ["incoming", "weather-proof gland"], ["MCBs", "4 ways"], ["main", "63 A switch disconnector"]],
		"prompt": "Press E to work the main switch", "sfx": "switch_throw", "distance": 2.8,
	})
	# the incoming supply and the battery bank it is charged from, beside the board
	_place("ips_battery", Vector3(-half_w + 0.75, 0.0, 4.55), Vector3(0.0, 0.3, 0.0))
	_place("cable_reel", Vector3(-half_w + 1.55, 0.0, half_l - 0.35), Vector3(0.0, 0.0, 0.0))


# ===========================================================================
# AREA 2 — desi mechanical workshop
# ===========================================================================

func _area_mechanical() -> void:
	## West wall, 10.5 m of it. The previous layout used the same wall but stretched
	## its objects from z = -7 to z = +7; in a 10.5 m room the usable bay is z +5.1 to
	## -5.1, so this is a genuine redistribution rather than a translation. The rule
	## applied: bench and its tools in the middle third where the light is, floor
	## salvage in the corners, nothing within 0.6 m of the walk lane.
	var half_w: float = structure.half_w
	var wall: float = -half_w + 0.13
	# --- the bench, the heart of World A ---------------------------------
	var bench: Node3D = _place("workbench", Vector3(wall + 0.36, 0.0, 1.7), Vector3(0.0, PI * 0.5, 0.0), {"w": 2.0, "d": 0.7})
	_station(bench, Station.Kind.TOOLBOX, Vector3(0.0, 0.95, 0.0), {
		"area": "mechanical", "title": "Mechanical bench",
		"desc": "Three boards of teak, scarred through to the grain where the bench edge meets a forearm. Everything on it has been moved at least once today.",
		"spec": [["top", "2.0 m teak"], ["age", "19 years"], ["surface oil", "used gear oil"]],
		"sfx": "tool_place",
	})
	_place("bench_pegboard", Vector3(wall + 0.02, 1.72, 1.7), Vector3(0.0, PI * 0.5, 0.0), {"w": 1.9, "h": 0.95})
	# The tool chest moved to the floor: it was on the bench in the old 3 m layout
	# and would now hang past the bench end at y = 0.96.
	_place("tool_chest", Vector3(wall + 0.30, 0.0, 2.98), Vector3(0.0, PI * 0.5, 0.0), {"width": 0.4})
	_place("vice", Vector3(wall + 0.7, 0.96, 0.85))
	_place("workbench_lamp", Vector3(wall + 0.42, 0.96, 0.85))
	_place("brush_cup", Vector3(wall + 0.34, 0.96, 1.45))
	_place("oil_can", Vector3(wall + 0.62, 0.96, 1.28))
	_place("notebook", Vector3(wall + 0.5, 0.98, 1.95), Vector3(0.0, 0.35, 0.0), {"width": 0.24})
	_place("pen", Vector3(wall + 0.34, 1.0, 1.82), Vector3(PI * 0.5, 0.0, 0.2))
	_place("tea_glass", Vector3(wall + 0.66, 0.97, 2.35))
	_place("flask", Vector3(wall + 0.5, 0.95, 2.62))
	# --- the engine, on the bench where it is being worked on ------------
	var engine: Node3D = _place("engine_block", Vector3(wall + 0.36, 0.95, 1.15), Vector3(0.0, 0.4, 0.0))
	_station(engine, Station.Kind.PART, Vector3.ZERO, {
		"area": "mechanical", "title": "Split single-cylinder engine",
		"desc": "Pulled off a 100 cc bike two monsoons ago. The fins are still straight, which means it was not seized when it came off.",
		"spec": [["type", "air-cooled OHV single"], ["bore", "50 mm"], ["condition", "carboned, serviceable"], ["donor for", "frame module"]],
		"sfx": "metal_thunk",
	})
	_place("cylinder_head", Vector3(wall + 0.62, 0.97, 1.62), Vector3(0.0, 0.9, 0.0))
	_place("piston", Vector3(wall + 0.3, 0.97, 1.55), Vector3(0.3, 0.0, 0.0))
	_place("carburettor", Vector3(wall + 0.66, 0.96, 0.95))
	# --- the shelf, north of the bench -----------------------------------
	_place("shelf_unit", Vector3(wall + 0.26, 0.0, -1.15), Vector3(0.0, PI * 0.5, 0.0), {"w": 1.6, "levels": 4})
	_place("bench_pegboard", Vector3(wall + 0.02, 1.62, -3.0), Vector3(0.0, PI * 0.5, 0.0), {"w": 1.3, "h": 0.8})
	# --- floor salvage: the corners, not the walkable middle --------------
	var scrap: Node3D = _place("scrap_bin", Vector3(-half_w + 0.72, 0.0, -2.55), Vector3(0.0, 0.3, 0.0), {"w": 0.75, "h": 0.5})
	_station(scrap, Station.Kind.SCRAP, Vector3.ZERO, {
		"area": "mechanical", "title": "Scrap bin",
		"desc": "Offcuts, brackets and bent rod. It is not rubbish: every piece in it was kept because it might become something.",
		"spec": [["contents", "steel offcuts"], ["kept since", "first week"]],
		"sfx": "metal_clank",
	})
	_place("motorcycle_frame", Vector3(wall + 0.5, 0.0, -1.95), Vector3(0.0, 0.45, 0.0), {"scale": 0.85})
	_place("wheel_rickshaw", Vector3(wall + 0.42, 0.34, -0.55), Vector3(0.0, 0.2, 0.0), {"radius": 0.33})
	_place("steel_drum", Vector3(-half_w + 0.6, 0.0, -4.3))
	_place("tyre", Vector3(-half_w + 1.05, 0.26, 3.9), Vector3(0.0, 0.5, PI * 0.5), {"radius": 0.26})
	_place("suspension_fork", Vector3(-half_w + 0.42, 0.0, 3.3), Vector3(0.0, 0.0, 0.32))
	# the silencer was on the old 3 m bench; here it leans against the wall
	_place("silencer", Vector3(-half_w + 0.6, 0.0, 3.4), Vector3(0.0, 0.3, 0.0))
	_place("brake_drum", Vector3(wall + 0.28, 1.583, -1.3))
	_place("grindstone", Vector3(-half_w + 0.85, 0.0, 4.45), Vector3(0.0, 0.5, 0.0), {"scale": 0.85})
	_place("plastic_chair", Vector3(-half_w + 1.5, 0.0, 3.55), Vector3(0.0, -0.5, 0.0))
	_place("biscuit_tin", Vector3(wall + 0.5, 1.583, -1.15))
	# --- wall fixtures ----------------------------------------------------
	_place("wall_calendar", Vector3(wall + 0.01, 2.05, 0.75), Vector3(0.0, PI * 0.5, 0.0), {"width": 0.3})
	# the poster moved off the switchboard wall: at z = 3.65 it collided with the
	# danger notice above the board
	_place("poster", Vector3(wall + 0.01, 2.28, 3.0), Vector3(0.0, PI * 0.5, 0.0), {"variant": 1, "width": 0.36})
	_place("hook_nail", Vector3(wall + 0.01, 2.0, 4.4), Vector3(0.0, PI * 0.5, 0.0))
	_place("towel_hanging", Vector3(wall + 0.02, 1.98, 4.4), Vector3(0.0, 0.2, 0.0), {"length": 0.6})
	# the frame crate, standing where the frame came off the bench
	_place("component_crate", Vector3(-2.6, 0.0, 4.35), Vector3(0.0, 0.5, 0.0), {"module": "frame", "width": 0.52})
	# --- one fan, one tube light -----------------------------------------
	var fan: Node3D = _place("ceiling_fan", Vector3(-1.6, structure.height - 0.12, 2.4), Vector3.ZERO, {"radius": 0.52, "drop": 0.38})
	_station(fan, Station.Kind.FAN_CEILING, Vector3(0.0, -0.35, 0.0), {
		"area": "mechanical", "fan_key": "ceiling", "title": "Ceiling fan",
		"desc": "The three-blade fan that is in every room in the country. The pull chain is the only switch it has ever known.",
		"spec": [["blades", "3"], ["sweep", "1.04 m"], ["pull chain", "yes"]],
		"prompt": "Press E to pull the chain", "sfx": "switch_throw",
	})
	var tube: Node3D = _place("fluorescent_battlement", Vector3(-1.9, structure.height - 0.3, 1.2), Vector3(0.0, PI * 0.5, 0.0), {"length": 1.2})
	_station(tube, Station.Kind.TUBE_LIGHT, Vector3.ZERO, {
		"area": "mechanical", "title": "Tube light", "circuit": 1,
		"desc": "The 4 ft batten. The choke is original, the starter is a spare, and the diffuser has gone the colour of strong tea.",
		"spec": [["tube", "4 ft / 18 W"], ["ballast", "iron choke"], ["starter", "replaced twice"]],
		"prompt": "Press E to switch the tube", "sfx": "switch_throw",
	})
	# --- stations for the props that carry text --------------------------
	for n: Node in get_children():
		match String(n.name):
			"Toolbox":
				pass
			"WallCalendar":
				_station(n, Station.Kind.CALENDAR, Vector3.ZERO, {
					"area": "mechanical", "title": "Wall calendar",
					"desc": "A free promotional calendar from a spare-parts dealer, showing both the Gregorian and Bengali months. It is four months out of date.",
					"spec": [["script", "Bengali"], ["columns", "English / Bangla dates"]],
				})
			"Notebook":
				_station(n, Station.Kind.NOTEBOOK, Vector3.ZERO, {
					"area": "mechanical", "title": "Engineering notebook",
					"desc": "The inventor's khata. Corkboard covers, string binding, and the first sketch of the exosuit on page four with a tea ring over the margin.",
					"lore": "Reading it unlocks the design intent and marks the objective complete.",
					"spec": [["pages", "84, numbered"], ["binding", "strung corkboard"], ["sketches", "17"]],
					"prompt": "Press E to read the notebook", "sfx": "paper",
				})
			"WorkbenchLamp":
				_station(n, Station.Kind.LAMP_BENCH, Vector3.ZERO, {
					"area": "mechanical", "title": "Workbench lamp", "circuit": 2,
					"desc": "The spring-arm bench lamp. The shade is a cut petrol can, painted inside.",
					"spec": [["arm", "spring balanced"], ["shade", "hand-formed tin"], ["lamp", "40 W bulb"]],
					"prompt": "Press E to switch the lamp", "sfx": "switch_throw",
				})
			_:
				pass


func _area_electronics() -> void:
	## East wall. The previous version had a 3.0 x 1.0 m desk with a second workbench
	## behind it and thirty-odd props spread across both. This is one bench, because a
	## repair shop with one bench is the honest picture of a one-person operation, and
	## because at 8.5 m wide the room cannot hold two facing workstations without the
	## player losing the walk lane.
	var half_w: float = structure.half_w
	var wall: float = half_w - 0.12
	# --- the desk, monitors standing along it ----------------------------
	# 1.9 m of bench, 0.62 deep, hard against the wall so the player's shoulder has
	# clearance on the far side. The desk faces west into the room.
	var desk: Node3D = _place("desk_electronics", Vector3(wall - 0.32, 0.0, 1.5), Vector3(0.0, -PI * 0.5, 0.0),
		{"w": 1.9, "d": 0.62, "h": 0.9})
	var dtop: float = 0.925
	_station(desk, Station.Kind.TOOLBOX, Vector3(0.0, dtop, 0.0), {
		"area": "electronics", "title": "Electronics bench",
		"desc": "A lighter table than the mechanical bench, with an anti-static mat taped down at one corner. This is where the boards are worked on.",
		"spec": [["top", "plywood on steel legs"], ["mat", "ESD, taped"], ["solder", "60/40, 0.8 mm"]],
		"sfx": "tool_place",
	})
	# monitors, standing at the back of the desk facing the room
	var crt: Node3D = _place("crt_monitor", Vector3(wall - 0.12, dtop, 0.95), Vector3(0.0, -PI * 0.5 + 0.16, 0.0), {"width": 0.38})
	_station(crt, Station.Kind.CRT, Vector3.ZERO, {
		"area": "electronics", "title": "Salvaged CRT",
		"desc": "The 15-inch tube the inventor kept when everything else went to the scrap dealer. Its yoke is the donor for the core's coupling coil.",
		"spec": [["tube", "15 inch shadow mask"], ["refresh", "60/75 Hz"], ["donor for", "energy module"]],
		"prompt": "Press E to power the tube", "sfx": "relay",
	})
	runtime.register_screen(crt.get_node_or_null("Screen") as Node3D, "crt", "crt")
	var lcd: Node3D = _place("lcd_monitor", Vector3(wall - 0.12, dtop, 1.85), Vector3(0.0, -PI * 0.5 - 0.2, 0.0), {"width": 0.4})
	_station(lcd, Station.Kind.LCD, Vector3.ZERO, {
		"area": "electronics", "title": "Second-hand LCD",
		"desc": "The panel that shows the prototype status board. Bright, flat, and older than the student using it.",
		"spec": [["panel", "15.6 inch TN"], ["input", "VGA"], ["content", "prototype status board"]],
		"prompt": "Press E to wake the panel", "sfx": "relay",
	})
	runtime.register_screen(lcd.get_node_or_null("Screen") as Node3D, "workstation", "status")
	# the working row: keyboard, mouse, multimeter, solder station
	_place("keyboard", Vector3(wall - 0.42, dtop - 0.012, 1.75), Vector3(0.0, -PI * 0.5, 0.0), {"width": 0.38})
	_place("mouse", Vector3(wall - 0.4, dtop - 0.012, 1.38))
	var solder: Node3D = _place("solder_station", Vector3(wall - 0.24, dtop, 2.28), Vector3(0.0, -PI * 0.5 + 0.25, 0.0))
	_station(solder, Station.Kind.TOOL, Vector3.ZERO, {
		"area": "electronics", "title": "Solder station",
		"desc": "Temperature-controlled, with a sponge that has not been wet since yesterday. The iron lives in the coil rest.",
		"spec": [["range", "200-450 C"], ["tip", "conical, 0.8 mm"], ["alloy", "60/40"]],
		"sfx": "tool_place", "distance": 2.6,
	})
	_place("multimeter", Vector3(wall - 0.3, dtop, 1.05))
	_place("laptop_shell", Vector3(wall - 0.38, dtop - 0.005, 0.52), Vector3(0.0, -PI * 0.5 - 0.3, 0.0), {"width": 0.3})
	# component work along the front of the desk
	_place("pcb_stack", Vector3(wall - 0.5, dtop - 0.01, 1.5), Vector3.ZERO, {"count": 7})
	_place("pcb_board", Vector3(wall - 0.36, dtop, 0.72), Vector3(0.0, 0.7, 0.0))
	_place("heatsink", Vector3(wall - 0.46, dtop, 0.6))
	_place("ram_stick", Vector3(wall - 0.3, dtop, 0.85), Vector3(0.0, 1.2, 0.0))
	_place("cpu_fan", Vector3(wall - 0.42, dtop + 0.005, 0.72), Vector3(-PI * 0.5, 0.0, 0.0), {"size": 0.07})
	_place("transformer_core", Vector3(wall - 0.26, dtop, 2.0))
	_place("solder_spool", Vector3(wall - 0.5, dtop, 2.2))
	_place("wire_cutters", Vector3(wall - 0.36, dtop, 2.02), Vector3(-PI * 0.5, 0.0, 0.4))
	_place("tea_glass", Vector3(wall - 0.5, dtop, 1.12))
	_place("desk_lamp", Vector3(wall - 0.22, dtop, 1.6))
	# --- the tower and the instruments -------------------------------------
	# The earlier version had a shelf unit standing behind this desk whose uprights
	# passed through the desktop, and a printer, router, oscilloscope and speaker
	# all placed at y = 0.9 with nothing under them — four props floating in mid-air
	# and only visible as such from the side. This version puts every instrument on
	# a surface that exists: a small instrument bench north of the desk, and the
	# parts cabinet for the router.
	var tower: Node3D = _place("desktop_tower", Vector3(wall - 0.4, 0.0, 2.85), Vector3(0.0, -PI * 0.5 + 0.15, 0.0), {"height": 0.4})
	_station(tower, Station.Kind.COMPUTER, Vector3(0.0, 0.25, 0.05), {
		"area": "electronics", "title": "Workstation tower",
		"desc": "A second-hand desktop with the side panel missing. It is the only machine in the garage that can run the design software, and it has been repaired four times.",
		"lore": "Starting it opens the engineering computer: prototype status, part inventory, assembly progress, diagnostics and system logs.",
		"spec": [["cpu", "salvaged quad-core"], ["ram", "8 GB, two sticks"], ["storage", "500 GB HDD"], ["display out", "VGA + HDMI"]],
		"prompt": "Press E to start the workstation", "sfx": "relay", "distance": 2.6,
	})
	_place("speaker", Vector3(half_w - 0.8, 0.0, 2.5), Vector3(0.0, -1.1, 0.0))
	# the parts cabinet, and the router on top of it because the phone line comes
	# in at that corner
	_place("component_drawer", Vector3(half_w - 0.6, 0.0, -0.55), Vector3(0.0, -PI * 0.5, 0.0), {"drawers": 6, "width": 0.3})
	_place("router_box", Vector3(half_w - 0.6, 0.515, -0.55), Vector3(0.0, -PI * 0.5, 0.0))
	# the instrument bench: shorter and lower than the desk, for the scope and the
	# printer. The desk is 1.9 m and carries the workstation; this is 1.4 m.
	_place("desk_electronics", Vector3(wall - 0.3, 0.0, -1.6), Vector3(0.0, -PI * 0.5, 0.0),
		{"w": 1.4, "d": 0.5, "h": 0.78})
	var itop: float = 0.805
	_place("oscilloscope", Vector3(wall - 0.28, itop, -1.15), Vector3(0.0, -PI * 0.5 + 0.25, 0.0))
	_place("printer", Vector3(wall - 0.3, itop, -1.95), Vector3(0.0, -PI * 0.5, 0.0))
	_place("tea_glass", Vector3(wall - 0.5, itop, -1.62))
	_place("stabilizer", Vector3(half_w - 0.5, 0.0, 3.6), Vector3(0.0, -PI * 0.5, 0.0))
	_place("chair_office", Vector3(half_w - 1.6, 0.0, 1.5), Vector3(0.0, -PI * 0.5 - 0.2, 0.0), {"scale": 0.95})
	# --- the power hardware, which is the donor for the energy module -----
	var rack: Node3D = _place("battery_rack", Vector3(half_w - 1.0, 0.0, 4.0), Vector3(0.0, -0.25, 0.0), {"scale": 0.92})
	_station(rack, Station.Kind.BATTERY, Vector3.ZERO, {
		"area": "electronics", "title": "IPS battery rack",
		"desc": "Two tubular cells strapped in series with a distribution board and a ferrite coupling coil lifted off a dead flyback. This is the physical donor for the exosuit's energy module.",
		"lore": "Nothing here is a live high-voltage source. The glowing core in the suit is a display model, and the fiction is deliberate.",
		"spec": [["cells", "2 x 12 V tubular"], ["buffer", "series string"], ["coupling", "flyback ferrite coil"]],
		"sfx": "metal_thunk",
	})
	_place("ups_battery", Vector3(half_w - 0.45, 0.0, 4.85))
	_place("power_strip", Vector3(half_w - 1.3, 0.02, 3.2), Vector3(0.0, -PI * 0.4, 0.0), {"sockets": 4})
	# one fan, pointing at the scope, because the scope runs hot. Aimed at the
	# instrument bench 6 m north of it rather than at the old bench at z = 4.2.
	var fan: Node3D = _place("pedestal_fan", Vector3(half_w - 1.5, 0.0, 4.9), Vector3(0.0, -0.15, 0.0), {"height": 1.0})
	_station(fan, Station.Kind.FAN_PEDESTAL, Vector3.ZERO, {
		"area": "electronics", "fan_key": "pedestal", "title": "Pedestal fan",
		"desc": "The wire-guarded standing fan, aimed at the oscilloscope because the scope runs hot and there is no air conditioning.",
		"spec": [["blades", "3, one cracked"], ["motor", "40 W shaded pole"], ["purpose", "scope cooling"]],
		"prompt": "Press E to start the fan", "sfx": "switch_throw",
	})
	# --- wall fixtures ----------------------------------------------------
	_place("switch_wall", Vector3(wall, 1.2, 3.3), Vector3(0.0, -PI * 0.5, 0.0))
	_place("clip_board", Vector3(wall, 1.55, 2.35), Vector3(0.0, -PI * 0.5, 0.0))
	# (the second poster used to hang at z = -0.5; the inventions board took that
	# spot, because a wall in a lab is better spent on the things the lab is for)
	# the LED strip goes on the wall above the instrument bench: at x = 1.9 m from
	# the wall it was hanging in mid-air with no bracket
	_place("led_cluster", Vector3(half_w - 0.06, 1.78, -2.5), Vector3(0.0, -PI * 0.5, 0.2), {"count": 5})
	# the energy crate, beside the rack it came out of
	_place("component_crate", Vector3(half_w - 2.1, 0.0, 2.55), Vector3(0.0, -1.1, 0.0), {"module": "energy", "width": 0.48})


func _area_assembly() -> void:
	## North-centre. The platform drops from 2.7 m to 1.45 m radius and the arms come
	## in from 2.4 m to 1.3 m: at 8.5 m wide, a 5.4 m stage left no floor at all and the
	## player could not walk around the thing they had just built. Four arms at 1.3 m
	## still close a complete ring around a 1.86 m figure.
	var centre := Vector3(0.0, 0.0, -1.5)
	var platform: Node3D = _place("assembly_platform", centre, Vector3.ZERO, {"radius": 1.45})
	var stand: Node3D = _place("suit_stand", centre + Vector3(0.0, 0.2, 0.0), Vector3(0.0, PI, 0.0))
	# the suit itself
	var exosuit := ExosuitFactory.new(props)
	var built: Dictionary = exosuit.build({})
	var suit_root: Node3D = built["root"] as Node3D
	suit_root.rotation.y = PI
	suit_root.scale = Vector3.ONE * 1.12
	suit_root.position = centre + Vector3(0.0, 0.32, 0.0)
	add_child(suit_root)
	runtime.install_suit(suit_root, built["parts"] as Dictionary, stand, platform, null, [])
	# the reactor cradle at the platform centre
	var cradle: Node3D = platform.get_node_or_null("ReactorCradle") as Node3D
	if cradle == null:
		cradle = _place("energy_cradle", centre + Vector3(0.0, 0.28, 0.0), Vector3.ZERO, {"radius": 0.42})
	runtime.cradle = cradle
	runtime.install_core(cradle)
	# the four arms, still four, at a radius that fits the smaller stage
	var arm_nodes: Array[Node3D] = []
	for i: int in range(4):
		var a: float = TAU_D * float(i) / 4.0 + 0.4
		var arm: Node3D = _place("robot_arm", centre + Vector3(cos(a) * 1.28, 0.24, sin(a) * 1.28), Vector3(0.0, -a + PI * 0.5, 0.0), {"reach": 0.9})
		arm_nodes.append(arm)
	runtime.arms = arm_nodes
	# the overhead gantry, spanning the platform only
	_place("overhead_rail", centre + Vector3(0.0, structure.height - 0.58, 0.0), Vector3(0.0, PI * 0.5, 0.0), {"span": 3.0})
	# the holographic design table, on the west side of the bay
	var table: Node3D = _place("holo_table", Vector3(-2.55, 0.0, -0.1), Vector3(0.0, 0.55, 0.0), {"radius": 0.72})
	var holo_volume: Node3D = table.get_node_or_null("HoloVolume") as Node3D
	runtime.install_hologram(holo_volume)
	# the wall array behind the stand: two panels, not three
	for i: int in range(2):
		var panel: Node3D = _place("monitor_wall_panel", Vector3(-0.8 + float(i) * 1.05, 2.0, -structure.half_l + 0.32), Vector3.ZERO, {"width": 0.46})
		var scr: Node3D = panel.get_node_or_null("Screen") as Node3D
		if scr != null:
			runtime.register_screen(scr, "diagnostic", "diag%d" % i)
	# the reactor housing on the north wall, scaled to the headroom
	_place("reactor_housing", Vector3(1.5, 1.9, -structure.half_l + 0.26), Vector3.ZERO, {"radius": 0.5})
	# The one supplied photograph in the project: the workshop owner's own banner,
	# hung on the brick between the store corner and the display panels at his
	# request. Everything else on these walls is generated; this is not, and
	# ASSET_LICENSES.md says so.
	var banner: Node3D = _place("wall_banner", Vector3(-2.35, 1.42, -structure.half_l + 0.175), Vector3.ZERO, {"width": 2.0})
	_station(banner, Station.Kind.SIGN, Vector3.ZERO, {
		"area": "assembly", "title": "Founder's banner",
		"desc": "A print-shop banner for Imran International Airlines, showing the founder and owner, Imran Khan. It has nothing to do with exosuits, which is exactly why it reads as real: workshops hang what they are given.",
		"spec": [["print", "photograph supplied by the project's author"], ["mount", "batten frame, 2.0 m"], ["subject", "Imran Khan — founder & owner"]],
		"sfx": "paper", "distance": 3.2,
	})
	# two indicator strips resting on the platform's outer ring (ring tube top at
	# y = 0.23) rather than floating above it
	for i: int in range(2):
		var a: float = TAU_D * float(i) / 2.0 + 0.4
		_place("indicator_strip", centre + Vector3(cos(a) * 1.5, 0.26, sin(a) * 1.5), Vector3(0.0, -a, 0.0), {"length": 1.1, "count": 8})
	# one conduit run feeding the platform
	_place("conduit_run", centre + Vector3(1.85, 0.3, -0.2), Vector3(0.0, 1.0, 0.0), {"length": 2.0})
	_place("cable_tray_future", centre + Vector3(0.0, structure.height - 1.0, -2.5), Vector3.ZERO, {"length": 3.2})
	# the parts tray on the floor beside the stage, where a fitter would leave it
	_place("part_kit", centre + Vector3(-1.9, 0.0, -0.9), Vector3(0.0, -0.4, 0.0), {"count": 6})
	# futuristic lighting: one key spot, the core, the hologram pool. The platform
	# spot does not cast: the environment's StandKey already throws the readable
	# shadow, and doubling it cost a shadow pass for no visual gain — the shadow
	# budget is seven, matched to the documented rig.
	_spot(platform, Vector3(0.0, 2.65, 0.7), Vector3(0.0, 1.15, 0.0), 4, &"assembly", 5.6, 36.0, false, Color("ffe0b8"))
	var core_light := OmniLight3D.new()
	platform.add_child(core_light)
	core_light.light_color = Color("7cf3ff")
	core_light.light_energy = 0.0
	core_light.omni_range = 5.5
	core_light.omni_attenuation = 1.45
	core_light.shadow_enabled = false
	runtime.register_light(core_light, 4, &"core", 3.0)
	var table_light := OmniLight3D.new()
	table.add_child(table_light)
	table_light.light_color = Color("57e6ff")
	table_light.light_energy = 0.0
	table_light.omni_range = 3.2
	table_light.omni_attenuation = 1.5
	table_light.shadow_enabled = false
	runtime.register_light(table_light, 4, &"holo", 2.0)
	# stations
	_station(platform, Station.Kind.ASSEMBLY, Vector3(0.0, 0.5, 0.0), {
		"area": "assembly", "title": "Assembly station",
		"desc": "The circular stage the prototype is built on. Deck plates, four manipulator arms, the reactor pit and the umbilical.",
		"lore": "Opening the interface installs the salvaged modules in order and runs the assembly sequence.",
		"spec": [["deck", "8 lift plates"], ["arms", "4, two-axis"], ["reactor", "coupling coil cradle"]],
		"prompt": "Press E to open the assembly interface", "sfx": "servo", "distance": 3.2,
	})
	_station(suit_root, Station.Kind.SUIT_DISPLAY, Vector3(0.0, 1.25, 0.0), {
		"area": "assembly", "title": "Exosuit MK-I",
		"desc": "The finished prototype: asymmetric shoulders, exposed hydraulics, hand-formed red plates over a recycled frame, and a core set in a brake-drum bezel.",
		"spec": [["height", "1.86 m"], ["mass", "27.5 kg"], ["frame", "recycled chrome-moly"], ["status", "standing test only"]],
		"prompt": "Press E to wake the prototype", "sfx": "servo", "distance": 3.0,
	})
	_station(cradle, Station.Kind.CORE, Vector3.ZERO, {
		"area": "assembly", "title": "Energy core",
		"desc": "The fictional reactor display: plasma churn, containment rings, arc filaments and a fresnel shell, all in one emissive shader.",
		"lore": "Exposed parameters: glow strength, pulse speed, core colour, rotation speed. The graphics bench lets you drive all four live.",
		"spec": [["shader", "energy_core.gdshader"], ["terms", "plasma, rings, spokes, arcs, fresnel"], ["emission", "feeds bloom"]],
		"prompt": "Press E to pulse the core", "sfx": "core_charge", "distance": 3.2,
	})
	_station(table, Station.Kind.HOLO_TABLE, Vector3(0.0, 0.7, 0.0), {
		"area": "assembly", "title": "Holographic design table",
		"desc": "The inventor's answer to a design review room: a projected cyan schematic of the suit, drawn from the same part list the assembly uses.",
		"spec": [["shader", "hologram.gdshader"], ["terms", "fresnel, scanlines, grid, flicker, band"], ["labels", "Bengali + English"]],
		"prompt": "Press E to raise the schematic", "sfx": "core_charge", "distance": 3.0,
	})
	# the shell crate, beside the stage it will be installed on
	_place("component_crate", Vector3(2.35, 0.0, -1.05), Vector3(0.0, 2.1, 0.0), {"module": "shell", "width": 0.5})


# ===========================================================================
# the three salvage crates
# ===========================================================================

func _register_component_crates() -> void:
	## Called once from dress() after every area has been placed. Two bugs are
	## fixed here rather than inherited: the earlier loop broke after the first
	## crate (so two of three salvage objectives were unreachable), and it matched
	## children by name — but Godot renames duplicate node names as they are added,
	## so only the first crate is ever called "ComponentCrate". The module meta the
	## crate prop writes is unique, so that is the test now.
	var registered: int = 0
	for n: Node in get_children():
		if not n.has_meta("module_kind"):
			continue
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
		var s: Station = _station(n, k, Vector3(0.0, 0.35, 0.0), {
			"area": "salvage", "title": GameConfig.component_label(comp_id),
			"desc": GameConfig.component_story(comp_id),
			"spec": GameConfig.component_spec(comp_id),
			"module_id": comp_id,
			"prompt": "Press E to recover the module", "sfx": "metal_thunk",
			"repeatable": false,
		})
		s.module_id = comp_id
		registered += 1
	if registered != GameConfig.total_components():
		push_warning("GarageDressing: %d salvage crates registered, expected %d" % [
			registered, GameConfig.total_components()])


# ===========================================================================
# AREA 5 — prototype testing corner
# ===========================================================================

func _area_testing() -> void:
	## North-east corner, a 1.5 m deck inside a 1.3 m rail. The previous corner had a
	## 2.4 m deck and a 2.1 m boundary in a room 13 m wide; here the whole corner is
	## about 3 x 3.4 m, so the deck is one person's standing platform and the rail is
	## just wide enough to walk outside of.
	var centre := Vector3(2.15, 0.0, -3.6)
	var deck: Node3D = _place("testing_platform", centre, Vector3.ZERO, {"size": 1.5})
	_place("safety_boundary", centre, Vector3.ZERO, {"radius": 1.3})
	var panel: Node3D = _place("instrument_panel", centre + Vector3(-1.0, 0.0, 0.45), Vector3(0.0, 0.75, 0.0), {"width": 0.72})
	# The diagnostic screen's origin is the middle of its frame, with the post and
	# base hanging 0.7 m below it — it was placed at y = 0, which buried the post,
	# the base and the bottom third of the panel under the floor. w = 0.36 gives
	# h = 0.61, so the frame centre belongs at 0.61/2 + 0.4 = 0.71.
	var screen: Node3D = _place("diagnostic_screen", centre + Vector3(0.6, 0.71, -1.0), Vector3(0.0, -0.5, 0.0), {"width": 0.36})
	var scr: Node3D = screen.get_node_or_null("Screen") as Node3D
	if scr != null:
		runtime.register_screen(scr, "diagnostic", "test")
	_place("wooden_stool", centre + Vector3(-0.8, 0.0, 1.0))
	_place("tea_glass", centre + Vector3(-0.86, 0.484, 0.86))
	_place("crate_stack", centre + Vector3(1.1, 0.0, 0.7), Vector3(0.0, 0.4, 0.0), {"count": 2})
	_place("bulb_hanging", centre + Vector3(0.0, structure.height - 0.2, 0.0), Vector3.ZERO, {"drop": 0.62})
	# the status strip runs along the floor at the deck edge, where it can be seen
	# and where it has something to sit on
	_place("indicator_strip", centre + Vector3(0.0, 0.02, -0.95), Vector3.ZERO, {"length": 1.4, "count": 10})
	# no shadow from this spot either: the corner's cast shadow comes from the core
	# light, and a second caster here cost a shadow pass for a shadow nobody reads
	_spot(deck, Vector3(0.0, 2.55, 0.0), Vector3(0.0, 0.9, 0.22), 4, &"testing", 3.4, 32.0, false, Color("fff0d8"))
	_station(panel, Station.Kind.DIAGNOSTICS, Vector3(0.0, 0.8, 0.0), {
		"area": "testing", "title": "Diagnostic console",
		"desc": "Analog gauges, a toggle bank, an emergency stop and a small panel. The instruments are World A; the readings are World B.",
		"spec": [["gauges", "3, panel meter"], ["stops", "1 mushroom head"], ["logging", "200 lines"]],
		"prompt": "Press E to run diagnostics", "sfx": "relay", "distance": 2.8,
	})
	_station(screen, Station.Kind.SUIT_DISPLAY, Vector3.ZERO, {
		"area": "testing", "title": "Prototype display screen",
		"desc": "Portrait panel showing the suit's live diagnostic trace once the prototype is complete.",
		"spec": [["orientation", "portrait"], ["content", "diagnostic trace"]],
		"prompt": "Press E to wake the prototype", "sfx": "servo",
	})


# ===========================================================================
# the north-west corner, which used to be a separate store room
# ===========================================================================

func _area_store() -> void:
	## Not a room any more. In an 8.5 x 10.5 m single-volume workshop there is no
	## separate store, so the stock occupies the north-west corner: one shelf, a crate
	## stack, the sacks, and the gas cylinder that has nowhere else to live. The
	## previous version had two 2.6 m shelf units, a pallet with a hay bale and a
	## bucket — about four square metres of floor that this room does not have.
	var half_w: float = structure.half_w
	var sx: float = -half_w + 0.3
	_place("shelf_unit", Vector3(sx, 0.0, -4.25), Vector3(0.0, PI * 0.5, 0.0), {"w": 1.5, "levels": 5, "d": 0.36})
	_place("crate_stack", Vector3(-half_w + 0.8, 0.0, -2.9), Vector3(0.0, 0.3, 0.0), {"count": 3})
	_place("sack", Vector3(-2.7, 0.0, -4.4), Vector3(0.0, 1.1, 0.0), {"scale": 0.88})
	_place("sack", Vector3(-2.62, 0.44, -4.3), Vector3(0.0, 0.4, 0.0), {"scale": 0.76})
	_place("gas_cylinder", Vector3(-half_w + 0.62, 0.0, -5.0))
	# tin and label sit on shelf planks: the unit's levels are at 0.18/0.695/1.21/
	# 1.725/2.24, so these y values are measured, not guessed
	_place("muri_tin", Vector3(sx + 0.02, 0.71, -4.15))
	_place("storage_box", Vector3(-half_w + 0.58, 0.0, -3.8), Vector3(0.0, 0.9, 0.0), {"w": 0.26, "h": 0.17, "d": 0.19})
	_place("bulb_hanging", Vector3(-half_w + 1.3, structure.height - 0.15, -4.2), Vector3.ZERO, {"drop": 0.5})
	_place("shelf_label", Vector3(sx + 0.19, 1.225, -4.2), Vector3(0.0, PI * 0.5, 0.0), {"width": 0.11})


# ===========================================================================
# the scientists' corner, east wall of the lab
# ===========================================================================

func _scientists_corner() -> void:
	## Six plaques for scientists this country claims, a header over them, and one
	## board of things this country built — the east wall above the instrument
	## bench, where the lab's bench work happens and where a student would actually
	## look up from a dead oscilloscope. Names, dates and notes come from
	## data/scientists.json and data/inventions.json; the engraving is a SignCanvas
	## bake in _signage(), like every other sign in the room.
	var x: float = structure.half_w - 0.15
	var spin := Vector3(0.0, -PI * 0.5, 0.0)
	var rows: Array[float] = [1.90, 1.46]
	var z0: float = -1.06
	var step: float = 0.34
	var scientists: Array = GameConfig.scientists
	for i: int in range(scientists.size()):
		var s: Dictionary = scientists[i]
		var col: int = i % 3
		var row: int = i / 3
		var y: float = rows[min(row, rows.size() - 1)]
		var z: float = z0 - float(col) * step
		var plaque: Node3D = _place("wall_plaque", Vector3(x, y, z), spin, {})
		plaque.name = "SciPlaque%d" % i
		_station(plaque, Station.Kind.SIGN, Vector3.ZERO, {
			"area": "electronics", "title": String(s.get("name", "")),
			"desc": String(s.get("note", "")),
			"spec": [["জীবনকাল", String(s.get("dates", ""))], ["স্মরণে", "গবেষণার দেয়াল"]],
			"sfx": "paper", "distance": 2.6,
		})
	var header: Node3D = _place("wall_plaque", Vector3(x, 2.44, -1.40), spin, {"width": 0.62, "height": 0.16})
	header.name = "SciHeader"
	# the inventions board beside them, taller than the plaques
	var board: Node3D = _place("wall_plaque", Vector3(x, 1.60, -0.42), spin, {"width": 0.58, "height": 0.80})
	board.name = "InventionsBoard"
	_station(board, Station.Kind.SIGN, Vector3.ZERO, {
		"area": "electronics", "title": "এই মাটির আবিষ্কার",
		"desc": "A hand-lettered board of things this country built or proved: oral rehydration therapy first proven in a Dhaka laboratory, the jute genome, the first satellite, the Padma bridge, the solar home programme.",
		"spec": [["script", "Bengali, Noto Sans Bengali"], ["board", "plywood and teak batten"], ["items", "%d" % GameConfig.inventions.size()]],
		"sfx": "paper", "distance": 2.6,
	})


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
	## True when a point would spawn inside authored furniture. A point within half
	## a metre of a box's top face is allowed instead: that is what "on the bench"
	## means, and every station's box is taller than the surface it describes — the
	## mechanical bench by 0.45 m because of its tool rail, and all of them by
	## 0.5 m below floor level because their collision shapes are centred on the
	## prop origin. Without this tolerance the bench-top group rejected all 84 of
	## its attempts and placed nothing, which is what the build log showed.
	for box: AABB in _occupied:
		var probe: Vector3 = p + Vector3(0.0, 0.1, 0.0)
		if not box.has_point(probe):
			continue
		if probe.y >= box.position.y + box.size.y - 0.55:
			continue
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
	## Two rails, not three. The third ran along the west wall at z = 5.4, which is
	## outside this room's north wall, and the first carried ten tools across 3.1 m
	## of wall — longer than the bench it served. One rail per bench, sized to it.
	var rack_specs: Array = [
		{"origin": Vector3(-structure.half_w + 0.3, 1.72, 1.7), "facing": PI * 0.5,
			"tools": ["hammer", "hacksaw", "pipe_wrench", "pliers", "spanner", "tape_measure"],
			"spacing": 0.30},
		{"origin": Vector3(structure.half_w - 0.3, 1.66, 3.8), "facing": -PI * 0.5,
			"tools": ["soldering_iron", "wire_cutters", "pliers", "screwdriver"],
			"spacing": 0.32},
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

	# 1. switchboard -> mechanical bench, a bundled loom of four. The switchboard
	# is on the west wall at z = 3.6 and the bench at z = 1.7, so these runs are
	# short and steep rather than the six-metre diagonal the old plan had.
	var loom_wires: Array = [
		{"start": Vector3(-x + 0.4, 1.62, half_l - 1.65), "end": Vector3(-x + 1.3, 0.98, 2.4), "sag": 0.26},
		{"start": Vector3(-x + 0.4, 1.56, half_l - 1.65), "end": Vector3(-x + 1.1, 0.98, 1.9), "sag": 0.28},
		{"start": Vector3(-x + 0.4, 1.5, half_l - 1.65), "end": Vector3(-x + 0.8, 0.98, 1.4), "sag": 0.3},
		{"start": Vector3(-x + 0.4, 1.44, half_l - 1.65), "end": Vector3(-x + 0.9, 0.02, 4.1), "sag": 0.42},
	]
	var bundle: MeshInstance3D = gen.make_node({
		"wires": loom_wires, "radius": 0.011, "radial_segments": 7, "length_segments": 26,
		"spread": 0.03, "material": sleeve, "u_scale": 2.0,
	}, "SwitchboardLoom")
	add_child(bundle)
	_bundle_stats = gen.last_stats.duplicate()

	# 2. workstation loom: tower -> monitors -> wall socket, bundled
	var ws_wires: Array = [
		{"start": Vector3(x - 0.62, 0.36, 2.85), "end": Vector3(x - 0.24, 0.9, 1.9), "sag": 0.1},
		{"start": Vector3(x - 0.62, 0.36, 2.85), "end": Vector3(x - 0.2, 0.92, 1.0), "sag": 0.14},
		{"start": Vector3(x - 0.62, 0.36, 2.85), "end": Vector3(x - 0.14, 1.2, 4.0), "sag": 0.3},
	]
	add_child(gen.make_node({
		"wires": ws_wires, "radius": 0.008, "radial_segments": 6, "length_segments": 22,
		"spread": 0.022, "material": sleeve, "u_scale": 1.6,
	}, "WorkstationLoom"))

	# 3. IPS leads: the battery rack down to the stabilizer and the floor strip,
	# which are on the same wall it is. They used to run the width of the room to
	# the switchboard, which is now on the opposite wall.
	add_child(gen.make_node({
		"wires": [
			{"start": Vector3(x - 1.0, 0.4, 4.0), "end": Vector3(x - 0.35, 0.04, 3.62), "sag": 0.1},
			{"start": Vector3(x - 1.0, 0.4, 4.0), "end": Vector3(x - 0.5, 0.04, 3.42), "sag": 0.12},
			{"start": Vector3(x - 1.0, 0.44, 4.0), "end": Vector3(x - 1.55, 0.02, 3.25), "sag": 0.16},
		],
		"radius": 0.016, "radial_segments": 8, "length_segments": 28, "spread": 0.04,
		"material": red, "u_scale": 2.4,
	}, "IpsLeads"))

	# 4. the reactor feed: a thick conduit-cable from the reactor housing on the
	# north wall down to the platform cradle — its actual source, a 3.5 m run inside
	# the assembly bay. The earlier version started on the east wall and crossed the
	# whole room at chest height, which cut the electronics bench in half.
	var feed: MeshInstance3D = gen.make_node({
		"start": Vector3(1.45, 1.75, -4.75), "end": Vector3(0.05, 0.5, -1.55),
		"sag": 0.35, "slack": 0.25, "sideways": 0.3, "radius": 0.03,
		"radial_segments": 12, "length_segments": 44, "material": holo, "u_scale": 4.0,
		"taper": 0.96,
	}, "ReactorFeed")
	add_child(feed)
	_feed_stats = gen.last_stats.duplicate()

	# 5. hanging runs along the ceiling, sagged and spaced. Three runs at 3 m
	# rather than five at 2.6 m: the room is 10.5 m long, not 16.5 m.
	for i: int in range(3):
		var z: float = -3.0 + float(i) * 3.0
		var hang: MeshInstance3D = gen.make_hang(
			Vector3(-structure.half_w + 0.4, structure.height - 0.28, z),
			Vector3(structure.half_w - 0.4, structure.height - 0.32, z + 0.3),
			1.06, 0.009, [sleeve, blue, yellow][i], 30)
		hang.name = "CeilingRun%d" % i
		add_child(hang)

	# 6. the loose jumper cables a workshop always has, draped over the shelf edge
	add_child(gen.make_hang(
		Vector3(-structure.half_w + 0.5, 1.55, -0.5),
		Vector3(-structure.half_w + 1.1, 0.9, 0.1), 1.35, 0.007, blue, 24))
	add_child(gen.make_hang(
		Vector3(structure.half_w - 0.5, 1.6, 2.6),
		Vector3(structure.half_w - 1.4, 0.93, 2.9), 1.4, 0.006, yellow, 24))


var _bundle_stats: Dictionary = {}
var _feed_stats: Dictionary = {}


func cable_stats() -> Dictionary:
	return {"bundle": _bundle_stats, "reactor_feed": _feed_stats}


func dressing_breakdown() -> Dictionary:
	## Counters for the documentation: how the placements divide between the
	## authored areas, the wall racks and the seeded procedural layouts, and how
	## efficient the rejection sampler actually was. Read from `placed` rather than
	## hand-counted, so the number in the thesis is the number the build made.
	var procedural: int = 0
	var racks: int = 0
	for key: String in placed:
		if key.begins_with("~procedural:"):
			procedural += int(placed[key])
		elif key.begins_with("~rack:"):
			racks += int(placed[key])
	var eff_sum: float = 0.0
	for s: Dictionary in _layout_stats:
		eff_sum += float(s.get("efficiency", 0.0))
	return {
		"total": placed_count,
		"authored": placed_count - procedural - racks,
		"procedural": procedural,
		"racks": racks,
		"layout_groups": _layout_stats.size(),
		"sampler_efficiency": eff_sum / maxf(float(_layout_stats.size()), 1.0),
	}


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
	# the street banner over the facade: generated text on the banner prop, so the
	# name over the door is editable data like everything else on these walls
	var outside: Node3D = _find_first("OutsideBanner")
	if outside != null:
		var print_face: MeshInstance3D = outside.get_node_or_null("Print") as MeshInstance3D
		if print_face != null:
			baker.apply_baked(print_face, _street_banner_spec(String(labels.garage_name)), "street_banner", 0.12, 0.55)
	# the scientists' corner: one bake per plaque, from data/scientists.json
	var scientists: Array = GameConfig.scientists
	for i: int in range(scientists.size()):
		var plaque: Node3D = _find_first("SciPlaque%d" % i)
		if plaque == null:
			continue
		var face: MeshInstance3D = plaque.get_node_or_null("Print") as MeshInstance3D
		if face != null:
			baker.apply_baked(face, _scientist_spec(scientists[i]), "scientist_%d" % i, 0.10, 0.6)
	var header: Node3D = _find_first("SciHeader")
	if header != null:
		var header_face: MeshInstance3D = header.get_node_or_null("Print") as MeshInstance3D
		if header_face != null:
			baker.apply_baked(header_face, _corner_header_spec(), "sci_header", 0.14, 0.55)
	var board: Node3D = _find_first("InventionsBoard")
	if board != null:
		var board_face: MeshInstance3D = board.get_node_or_null("Print") as MeshInstance3D
		if board_face != null:
			baker.apply_baked(board_face, _inventions_spec(GameConfig.inventions), "inventions", 0.12, 0.6)


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


func _street_banner_spec(garage_name: String) -> Dictionary:
	## The banner over the facade's left pier: IMRAN'S GARAGE in gold on navy, a
	## looking-glass rhyme with the airline banner the owner already has, and the
	## shop's Bangla name underneath so the two prints agree with each other.
	## English in the display face, Bangla through the engine's shaper, both baked
	## through the same SignCanvas the interior signs use. The subtitle stays
	## Latin because the mono face carries no Bengali glyphs.
	return {
		"size": Vector2i(640, 358), "transparent": false, "bg": "#14213a",
		"border": {"color": "#d4af37", "width": 7.0},
		"layers": [
			{"type": "rect", "pos": Vector2(26, 26), "sz": Vector2(588, 3), "color": "#c9a83f"},
			{"type": "rect", "pos": Vector2(26, 329), "sz": Vector2(588, 3), "color": "#c9a83f"},
			# size 64, not 84: at 84 the line wrapped inside its own width box and
			# the second half landed on top of the Bangla name below it
			{"type": "text", "name": "NAME", "pos": Vector2(20, 62), "size": 64, "width": 600, "align": "center", "color": "#e8c56a", "text": "IMRAN'S GARAGE", "font": "display", "shadow": true},
			{"type": "text", "name": "BN", "pos": Vector2(20, 172), "size": 38, "width": 600, "align": "center", "color": "#e8ecef", "text": garage_name, "font": "bangla"},
			{"type": "text", "name": "SUB", "pos": Vector2(20, 252), "size": 22, "width": 600, "align": "center", "color": "#9fb0c8", "text": "PROTOTYPE WORKSHOP  ·  EST. 2019", "font": "mono"},
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


func _scientist_spec(s: Dictionary) -> Dictionary:
	## One honour plaque: a gold medallion with the scientist's Bangla monogram,
	## the name, the years, and one line of what they did — in Bangla, through the
	## engine's shaper. Sizes are chosen so a name of 30 Bengali glyphs and a note
	## of four wrapped lines both fit inside 384 x 486.
	return {
		"size": Vector2i(384, 486), "transparent": false, "bg": "#101a2c",
		"border": {"color": "#d4af37", "width": 4.0},
		"layers": [
			{"type": "line", "from": Vector2(28, 206), "to": Vector2(356, 206), "color": "#d4af37", "width": 2.0},
			{"type": "circle", "center": Vector2(192, 112), "radius": 62, "color": "#d4af37", "filled": false, "width": 3.0},
			{"type": "circle", "center": Vector2(192, 112), "radius": 54, "color": "#1c2a44", "filled": true},
			{"type": "text", "name": "MONO", "pos": Vector2(32, 60), "size": 62, "width": 320, "align": "center", "color": "#e8c56a", "text": String(s.get("initial", "")), "font": "bangla"},
			{"type": "text", "name": "NAME", "pos": Vector2(16, 216), "size": 30, "width": 352, "align": "center", "color": "#f2e9d4", "text": String(s.get("name", "")), "font": "bangla"},
			{"type": "text", "name": "DATES", "pos": Vector2(16, 262), "size": 20, "width": 352, "align": "center", "color": "#d4af37", "text": String(s.get("dates", "")), "font": "bangla"},
			{"type": "text", "name": "NOTE", "pos": Vector2(22, 302), "size": 21, "width": 340, "align": "center", "color": "#b9c6d6", "text": String(s.get("note", "")), "font": "bangla"},
		],
	}


func _corner_header_spec() -> Dictionary:
	## The header over the plaques.
	return {
		"size": Vector2i(640, 160), "transparent": false, "bg": "#101a2c",
		"border": {"color": "#d4af37", "width": 4.0},
		"layers": [
			{"type": "text", "name": "BN", "pos": Vector2(16, 22), "size": 54, "width": 608, "align": "center", "color": "#e8c56a", "text": "বিজ্ঞানীদের কর্নার", "font": "bangla"},
			{"type": "text", "name": "EN", "pos": Vector2(16, 100), "size": 22, "width": 608, "align": "center", "color": "#8fa0ab", "text": "SCIENTISTS OF BENGAL", "font": "mono"},
		],
	}


func _inventions_spec(items: Array) -> Dictionary:
	## The board beside the plaques: things this country built or proved, one line
	## each with a year, under a title that says whose work it is.
	var layers: Array = [
		{"type": "text", "name": "TITLE", "pos": Vector2(16, 16), "size": 40, "width": 432, "align": "center", "color": "#e8c56a", "text": "এই মাটির আবিষ্কার", "font": "bangla"},
		{"type": "line", "from": Vector2(26, 84), "to": Vector2(438, 84), "color": "#d4af37", "width": 2.0},
	]
	for i: int in range(mini(items.size(), 6)):
		var it: Dictionary = items[i]
		var y: float = 104.0 + float(i) * 104.0
		layers.append({"type": "text", "name": "T%d" % i, "pos": Vector2(20, y), "size": 27, "width": 424, "align": "center", "color": "#f2e9d4", "text": String(it.get("title", "")), "font": "bangla"})
		layers.append({"type": "text", "name": "Y%d" % i, "pos": Vector2(20, y + 36), "size": 19, "width": 424, "align": "center", "color": "#d4af37", "text": String(it.get("year", "")), "font": "bangla"})
		layers.append({"type": "text", "name": "N%d" % i, "pos": Vector2(24, y + 62), "size": 17, "width": 416, "align": "center", "color": "#b9c6d6", "text": String(it.get("note", "")), "font": "bangla"})
	layers.append({"type": "text", "name": "TAG", "pos": Vector2(20, 636), "size": 24, "width": 424, "align": "center", "color": "#4fd8ff", "text": "নিজের মাথা, নিজের হাতে", "font": "bangla"})
	return {
		"size": Vector2i(464, 672), "transparent": false, "bg": "#101a2c",
		"border": {"color": "#d4af37", "width": 5.0},
		"layers": layers,
	}


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
	## Objects that exist to be looked at rather than used. Cut from forty-odd to
	## fifteen: the old list ran to z = 7.6, a metre past this room's north wall,
	## and it duplicated objects the areas now place themselves — two wall
	## calendars, two ceiling fans, three loose tyres, a second bicycle.
	var x: float = structure.half_w
	# the ceiling fixtures the World A circuit is aimed at. The mechanical bench's
	# batten is placed by _area_mechanical(); these are the other three zones.
	var tubes: Array = [
		Vector3(1.9, structure.height - 0.3, 1.6),
		Vector3(0.0, structure.height - 0.32, 3.5),
		Vector3(-1.9, structure.height - 0.3, 3.9),
	]
	for i: int in range(tubes.size()):
		_place("fluorescent_battlement", tubes[i], Vector3(0.0, PI * 0.5, 0.0), {"length": 1.2})
	# the wet-weather line: two towels on the rope that crosses the room
	_place("towel_hanging", Vector3(-1.2, 2.92, 2.16), Vector3(0.0, 0.2, 0.0), {"length": 0.62})
	_place("towel_hanging", Vector3(0.6, 2.9, 2.28), Vector3(0.0, -0.3, 0.0), {"length": 0.5})
	# newspaper pages that blew off the bench
	_place("newspaper_fold", Vector3(-0.9, 0.02, 3.35), Vector3(0.0, 0.6, 0.0))
	_place("newspaper_fold", Vector3(1.4, 0.02, 0.4), Vector3(0.0, 2.1, 0.0))
	# the wall clock over the shutter, and the photograph of the first bench
	_place("wall_clock", Vector3(x - 0.02, 2.5, 4.55), Vector3(0.0, -PI * 0.5, 0.0))
	_place("hook_nail", Vector3(-x + 0.02, 1.78, 0.3), Vector3(0.0, PI * 0.5, 0.0))
	_place("photo_frame", Vector3(-x + 0.03, 1.68, 0.3), Vector3(0.0, PI * 0.5, 0.0))
	# the polythene bag roll on the top store plank (y = 1.725 + 0.014), and the
	# radio, drill and driver on the mechanical shelf's second plank, both on
	# measured plank heights rather than somewhere near them
	_place("plastic_bag_roll", Vector3(-3.92, 1.739, -3.62), Vector3(0.0, 0.2, 0.0))
	_place("radio", Vector3(-3.86, 0.881, -0.72), Vector3(0.0, 0.35, 0.0))
	_place("hand_drill", Vector3(-3.88, 0.881, -1.08), Vector3(0.0, 0.3, 0.0))
	_place("impact_driver", Vector3(-3.86, 0.881, -1.42), Vector3(0.0, -0.4, 0.0))
	# the brush by the bucket at the drain, where the floor gets washed down
	_place("cup_brush", Vector3(3.45, 0.02, 4.62))


# ===========================================================================
# grime decals
# ===========================================================================

func _grime_decals() -> void:
	## Soft grime where the geometry says it belongs: under machinery, beneath the
	## wall fixtures, at the drain. A `Decal` projects onto whatever is behind it, so
	## a stain follows the floor's wear and the wall's brick instead of floating as a
	## painted disc. One generated texture serves every decal; the cost is the decal
	## passes and nothing else, which the perf harness measures.
	var oil: ImageTexture = _grime_texture(9127, Color(0.045, 0.04, 0.035, 0.85))
	var rust: ImageTexture = _grime_texture(4471, Color(0.30, 0.15, 0.07, 0.5))
	# floor: under the benches and machines, where a real floor is always darkest
	_decal_floor(Vector3(-3.7, 0.3, 1.7), 2.0, oil)
	_decal_floor(Vector3(-3.35, 0.3, 4.4), 1.2, oil)
	_decal_floor(Vector3(3.1, 0.3, 1.3), 1.7, oil)
	_decal_floor(Vector3(3.25, 0.3, 3.9), 1.2, oil)
	_decal_floor(Vector3(0.0, 0.3, 4.35), 1.5, rust)
	_decal_floor(Vector3(2.2, 0.3, 0.2), 1.1, oil)
	_decal_floor(Vector3(-3.6, 0.3, -4.2), 1.4, oil)
	# walls: rust runs under the window and the tool wall, down the plaster
	_decal_wall(Vector3(-4.05, 1.15, 2.3), 1.3, rust, Vector3(0.0, 0.0, PI * 0.5))
	_decal_wall(Vector3(-4.05, 1.05, 1.7), 1.1, rust, Vector3(0.0, 0.0, PI * 0.5))
	# and under the window's sill on the electronics side
	_decal_wall(Vector3(4.05, 1.1, 2.3), 1.2, rust, Vector3(0.0, 0.0, -PI * 0.5))


func _decal_floor(pos: Vector3, diameter: float, tex: Texture2D) -> void:
	var d := Decal.new()
	d.name = "GrimeFloor"
	d.texture_albedo = tex
	d.size = Vector3(diameter, 0.6, diameter)
	d.position = pos
	add_child(d)


func _decal_wall(pos: Vector3, diameter: float, tex: Texture2D, rot: Vector3) -> void:
	var d := Decal.new()
	d.name = "GrimeWall"
	d.texture_albedo = tex
	d.size = Vector3(diameter, 1.0, diameter)
	d.position = pos
	d.rotation = rot
	add_child(d)


func _grime_texture(seed_value: int, tint: Color) -> ImageTexture:
	## A soft irregular blot: overlapping radial blobs with a broken interior,
	## drawn by hand rather than with FastNoiseLite because the noise images come
	## back empty under the headless renderer and a decal must look the same in
	## both. Deterministic for a given seed.
	var size: int = 192
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng: RandomNumberGenerator = NoiseTools.rng(seed_value)
	var blobs: Array[Vector3] = []
	for i: int in range(10):
		blobs.append(Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8), rng.randf_range(0.12, 0.3)))
	for y: int in range(size):
		var py: float = float(y) / float(size)
		for x: int in range(size):
			var px: float = float(x) / float(size)
			var cover: float = 0.0
			for b: Vector3 in blobs:
				var dx: float = px - b.x
				var dy: float = py - b.y
				cover = maxf(cover, clampf(1.0 - sqrt(dx * dx + dy * dy) / b.z, 0.0, 1.0))
			var streak: float = lerpf(0.6, 1.0, 0.5 + 0.5 * sin(px * 41.0) * sin(py * 37.0))
			img.set_pixel(x, y, Color(tint.r, tint.g, tint.b, pow(cover, 1.7) * streak * tint.a))
	return ImageTexture.create_from_image(img)
