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
	_wall_maps()
	_keepsakes()
	_photo_boards()
	_fake_details()
	_wayfinding()
	_armor()
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
			# The collider is built in the node's LOCAL space: a world-space box
			# parented under a rotated prop comes out turned 90 degrees, which is
			# why every rotated station's interaction volume was wrong-oriented.
			var local: AABB = node.global_transform.affine_inverse() * b
			var shape: CollisionShape3D = ShapeKit.col_box(local.size + Vector3.ONE * 0.1)
			shape.position = local.get_center()
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
		# a physical bulb has size; without it the shadow pools on the concrete
		# read as hard black ellipses instead of soft light falloff
		light.light_size = 0.7
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
		light.light_size = 0.6
	node.add_child(light)
	runtime.register_light(light, circuit, zone, energy)
	return light


func _always_on_bulb(pos: Vector3, drop: float = 0.55, energy: float = 1.6, reach: float = 7.0) -> Node3D:
	## A bare bulb on the incoming line: on circuit 0, so set_power never touches
	## it and the room is never dark, even before the switchboard. Its warm light is
	## parented to the bulb itself, so carrying the bulb carries its light; the
	## glass gets an emissive material of its own because the shared prop ships
	## unlit. Every always-on light in the room is built here.
	var bulb: Node3D = _place("bulb_hanging", pos, Vector3.ZERO, {"drop": drop})
	var glass: MeshInstance3D = bulb.get_node_or_null("Bulb") as MeshInstance3D
	if glass != null:
		glass.material_override = ML.bulb_material(Color("ffd9a0"), 6.0)
	var lamp: OmniLight3D = _register_light(bulb, 0, &"always_on", energy, reach, 1.5, false, Color("ffd9a0"))
	lamp.name = "AlwaysOnLamp"
	lamp.position = Vector3(0.0, -drop - 0.05, 0.0)
	lamp.light_indirect_energy = 0.35
	return bulb


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
			"desc": "The corrugated curtain that keeps the monsoon out. It rolls up by itself now: the presence sensor over the lintel, lifted off a dead security lamp, trips as soon as anything crosses the courtyard.",
			"lore": "The slats are individual geometry, and the curtain is coupled to the daylight — as it lifts, the shafts and the volumetric fog strengthen with it.",
			"spec": [["mechanism", "manual chain drive"], ["sensor", "salvaged PIR on the lintel"], ["curtain", "20 slats"], ["travel", "2.25 m"]],
			"prompt": "Press E to check the shutter", "sfx": "latch", "distance": 4.0,
		})
	# the signboard over the shutter. Raised from 2.78 to 2.95: at 2.78 its bottom
	# third sat behind the shutter head beam, which is 3 cm prouder than the board.
	var sign: Node3D = _place("signboard", Vector3(0.0, 2.95, half_l + 0.14), Vector3.ZERO, {"width": 2.5, "height": 0.6})
	# the sign's RGB rig: the LED frame lives in the prop (its shader self-animates);
	# the two washes and their hue cycle are added here, on circuit 0 so the sign is
	# never dark
	var rgb_script: GDScript = load("res://scripts/garage/sign_rgb.gd")
	sign.set_script(rgb_script)
	sign.call("setup_rgb", runtime)
	_station(sign, Station.Kind.SIGN, Vector3.ZERO, {
		"area": "entrance", "title": "Garage signboard",
		"desc": "Hand-painted on a sheet of tin: the shop name in Bangla, the tagline underneath, and a phone number that is really a mobile number. The frame is a chasing RGB LED strip from the electronics market, and two washes keep the board readable after dark.",
		"spec": [["script", "Bengali, Noto Sans Bengali"], ["medium", "house paint on tin"], ["repainted", "three times"], ["lighting", "RGB LED frame, cycling washes"]],
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
	# the courtyard: three props, because 8.5 m of frontage holds three. They stand
	# on the packed earth at y = -0.14, not on the interior slab height: placing
	# them at 0 left every courtyard prop hovering 14 cm, which the carry system's
	# probe exposed when it dropped a crate onto the real ground.
	var YARD_Y: float = -0.14
	var bicycle: Node3D = _place("bicycle", Vector3(-half_w + 1.3, YARD_Y, half_l + 1.9), Vector3(0.0, 0.5, 0.0), {"scale": 0.95})
	_station(bicycle, Station.Kind.PART, Vector3.ZERO, {
		"area": "exterior", "title": "Workshop bicycle",
		"desc": "The spare bicycle. It does not belong to anyone in particular and it is used by everyone.",
		"spec": [["wheels", "26 inch, wire spoked"], ["purpose", "spares and short errands"]],
		"sfx": "metal_tink", "distance": 2.8,
	})
	_place("wheel_rickshaw", Vector3(half_w - 1.1, YARD_Y + 0.34, half_l + 1.6), Vector3(0.0, 0.3, 0.0), {"radius": 0.34})
	_place("crate_stack", Vector3(half_w - 2.0, YARD_Y, half_l + 2.6), Vector3(0.0, -0.4, 0.0), {"count": 3})
	_place("scrap_bin", Vector3(-half_w - 0.25, YARD_Y, half_l + 3.75), Vector3(0.0, 0.9, 0.0), {"w": 0.7, "h": 0.45})
	# the national corner by the gate: the flag on its pole and the big display
	# coin leaning on its plinth, nonsense planted by the courtyard wall facing the
	# camera — see _signage() for the cloth and the two coin faces
	var flag: Node3D = _place("flag_pole", Vector3(3.6, YARD_Y, half_l + 2.35), Vector3.ZERO, {})
	_station(flag, Station.Kind.SIGN, Vector3(0.0, 0.2, 0.0), {
		"area": "exterior", "title": "National flag",
		"desc": "Bottle green with the red disc of the rising sun, on a pole beside the gate. The disc sits at nine-twentieths of the length from the hoist, its radius one-fifth of the length, exactly as the specification says.",
		"spec": [["ratio", "10 : 6"], ["disc", "9/20 from hoist, r = L/5"], ["cloth", "0.9 m, weighted at the fly"]],
		"sfx": "paper", "distance": 4.0,
	})
	var coin: Node3D = _place("big_coin", Vector3(2.6, YARD_Y, half_l + 3.1), Vector3(0.0, -0.16, 0.0), {"radius": 0.42})
	_station(coin, Station.Kind.SIGN, Vector3(0.0, 0.3, 0.0), {
		"area": "exterior", "title": "Display coin",
		"desc": "A big brass ৫ টাকা leaning on its plinth — a sign-shop ornament for the gate, not money. The face carries the shapla and the country's name; the back carries the denomination in Bangla and English.",
		"spec": [["diameter", "0.84 m"], ["face", "shapla and ৫ টাকা"], ["note", "display piece, not legal tender"]],
		"sfx": "metal_thunk", "distance": 3.4,
	})
	_place("sandals", Vector3(-0.7, 0.0, half_l - 0.3), Vector3(0.0, 0.4, 0.0))
	_place("water_bucket", Vector3(half_w - 0.5, 0.0, half_l - 0.3))
	# the interior entrance strip
	var stool: Node3D = _place("wooden_stool", Vector3(half_w - 1.9, 0.0, half_l - 2.1))
	_station(stool, Station.Kind.EVERYDAY, Vector3.ZERO, {
		"area": "entrance", "title": "Wooden stool",
		"desc": "Where the visitor sits while the job is finished. Three legs are original.",
		"spec": [["seat", "teak, 380 mm"], ["legs", "4, one replaced"]],
		"sfx": "tool_place",
	})
	# the storage box lives under the bench now: on the south floor it shared its
	# spot with the tyre and the grindstone
	_place("storage_box", Vector3(-half_w + 0.51, 0.0, half_l - 2.95), Vector3(0.0, 0.15, 0.0))
	_place("sack", Vector3(-half_w + 2.55, 0.0, half_l - 0.65), Vector3(0.0, 0.6, 0.0), {"scale": 0.85})
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
	_place("vice", Vector3(wall + 0.74, 0.96, 1.10))
	_place("workbench_lamp", Vector3(wall + 0.42, 0.96, 0.85))
	_place("brush_cup", Vector3(wall + 0.18, 1.01, 1.38))
	_place("oil_can", Vector3(wall + 0.62, 1.01, 1.28))
	_place("notebook", Vector3(wall + 0.5, 0.98, 1.95), Vector3(0.0, 0.35, 0.0), {"width": 0.24})
	_place("pen", Vector3(wall + 0.34, 1.0, 1.82), Vector3(PI * 0.5, 0.0, 0.2))
	_place("tea_glass", Vector3(wall + 0.66, 0.97, 2.35))
	# the flask lives on the tool chest now: on the bench it sat inside the spare
	# helmet's face whenever the helmet was back from a job
	_place("flask", Vector3(wall + 0.30, 0.32, 2.98))
	# --- the engine, on the bench where it is being worked on ------------
	var engine: Node3D = _place("engine_block", Vector3(wall + 0.36, 1.00, 1.15), Vector3(0.0, 0.4, 0.0))
	_station(engine, Station.Kind.PART, Vector3.ZERO, {
		"area": "mechanical", "title": "Split single-cylinder engine",
		"desc": "Pulled off a 100 cc bike two monsoons ago. The fins are still straight, which means it was not seized when it came off.",
		"spec": [["type", "air-cooled OHV single"], ["bore", "50 mm"], ["condition", "carboned, serviceable"], ["donor for", "frame module"]],
		"sfx": "metal_thunk",
	})
	_place("cylinder_head", Vector3(wall + 0.62, 1.02, 1.62), Vector3(0.0, 0.9, 0.0))
	_place("piston", Vector3(wall + 0.18, 1.02, 1.52), Vector3(0.3, 0.0, 0.0))
	_place("carburettor", Vector3(wall + 0.66, 1.01, 0.95))
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
	_place("motorcycle_frame", Vector3(wall + 0.57, 0.0, -2.65), Vector3(0.0, 0.45, 0.0), {"scale": 0.85})
	_place("wheel_rickshaw", Vector3(wall + 0.42, 0.34, -0.55), Vector3(0.0, 0.2, 0.0), {"radius": 0.33})
	# the store drum, off the shelf's footprint: at the old spot two-thirds of it
	# passed through the shelf planks and into the spare gauntlet beside them
	_place("steel_drum", Vector3(-half_w + 1.1, 0.0, -3.55))
	# the spare tyre stands against the wall in the south corner, clear of the
	# grindstone, the battery and the frame crate: lying flat on the open floor it
	# had none of them
	_place("tyre", Vector3(-half_w + 0.35, 0.33, 4.94), Vector3(0.0, 0.15, PI * 0.5), {"radius": 0.26})
	# the fork leans on the wall at a height where it leans, not where it sinks:
	# at y = 0 its stanchion stood 30 cm into the concrete
	_place("suspension_fork", Vector3(-half_w + 0.42, 0.30, 3.75), Vector3(0.0, 0.0, 0.32))
	# the silencer was on the old 3 m bench; here it leans against the wall
	_place("silencer", Vector3(-half_w + 0.6, 0.0, 3.4), Vector3(0.0, 0.3, 0.0))
	_place("brake_drum", Vector3(wall + 0.28, 1.583, -1.3))
	_place("grindstone", Vector3(-half_w + 0.85, 0.0, 3.90), Vector3(0.0, 0.5, 0.0), {"scale": 0.85})
	_place("plastic_chair", Vector3(-half_w + 1.5, 0.0, 3.55), Vector3(0.0, -0.5, 0.0))
	_place("biscuit_tin", Vector3(wall + 0.5, 1.583, -1.15))
	# --- wall fixtures ----------------------------------------------------
	_place("wall_calendar", Vector3(wall + 0.01, 2.05, 0.75), Vector3(0.0, PI * 0.5, 0.0), {"width": 0.3})
	# the poster moved off the switchboard wall: at z = 3.65 it collided with the
	# danger notice above the board
	_place("poster", Vector3(wall + 0.01, 2.28, 3.0), Vector3(0.0, PI * 0.5, 0.0), {"variant": 1, "width": 0.36})
	_place("hook_nail", Vector3(wall + 0.01, 2.0, 4.4), Vector3(0.0, PI * 0.5, 0.0))
	_place("towel_hanging", Vector3(wall + 0.02, 1.98, 4.0), Vector3(0.0, 0.2, 0.0), {"length": 0.6})
	# the frame crate, standing where the frame came off the bench
	# the frame crate by the bench's north end, squared against the wall line
	# rather than dropped mid-floor
	_place("component_crate", Vector3(-2.55, 0.0, 4.52), Vector3(0.0, 0.08, 0.0), {"module": "frame", "width": 0.52})
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
	# the CRT is seated with its foot resting on the desktop and its body clear of
	# the desk's back tray: at desk height its shell passed through that tray, and
	# raised further its foot floated
	var crt: Node3D = _place("crt_monitor", Vector3(wall - 0.25, dtop + 0.055, 0.95), Vector3(0.0, -PI * 0.5 + 0.16, 0.0), {"width": 0.38})
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
	_place("keyboard", Vector3(wall - 0.42, dtop + 0.005, 1.75), Vector3(0.0, -PI * 0.5, 0.0), {"width": 0.38})
	_place("mouse", Vector3(wall - 0.70, dtop - 0.012, 1.05))
	var solder: Node3D = _place("solder_station", Vector3(wall - 0.24, dtop, 2.28), Vector3(0.0, -PI * 0.5 + 0.25, 0.0))
	_station(solder, Station.Kind.TOOL, Vector3.ZERO, {
		"area": "electronics", "title": "Solder station",
		"desc": "Temperature-controlled, with a sponge that has not been wet since yesterday. The iron lives in the coil rest.",
		"spec": [["range", "200-450 C"], ["tip", "conical, 0.8 mm"], ["alloy", "60/40"]],
		"sfx": "tool_place", "distance": 2.6,
	})
	_place("multimeter", Vector3(wall - 0.3, dtop, 1.05))
	# the laptop pulled back onto the desk, lying along it: at z = 0.52 it hung
	# 20 cm off the desk's south end, and facing the room it reached into the CRT
	_place("laptop_shell", Vector3(wall - 0.41, dtop - 0.005, 0.62), Vector3(0.0, -0.08, 0.0), {"width": 0.3})
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
	_place("ups_battery", Vector3(half_w - 0.25, 0.0, 4.50))
	_place("power_strip", Vector3(half_w - 1.3, 0.02, 3.2), Vector3(0.0, -PI * 0.4, 0.0), {"sockets": 4})
	# one fan, pointing at the scope, because the scope runs hot. Aimed at the
	# instrument bench 6 m north of it rather than at the old bench at z = 4.2.
	var fan: Node3D = _place("pedestal_fan", Vector3(half_w - 2.35, 0.0, 4.9), Vector3(0.0, -0.15, 0.0), {"height": 1.0})
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
	# the energy crate stands beside the rack it came out of, squared to it
	_place("component_crate", Vector3(2.35, 0.0, 3.92), Vector3(0.0, -0.25, 0.0), {"module": "energy", "width": 0.48})


func _area_assembly() -> void:
	## North-centre. The platform drops from 2.7 m to 1.45 m radius and the arms come
	## in from 2.4 m to 1.3 m: at 8.5 m wide, a 5.4 m stage left no floor at all and the
	## player could not walk around the thing they had just built. Four arms at 1.3 m
	## still close a complete ring around a 1.86 m figure.
	var centre := Vector3(0.0, 0.0, -1.5)
	var platform: Node3D = _place("assembly_platform", centre, Vector3.ZERO, {"radius": 1.45})
	var stand: Node3D = _place("suit_stand", centre + Vector3(0.0, 0.2, 0.0), Vector3(0.0, PI, 0.0), {"base_radius": 0.07})
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
	# one conduit run feeding the platform: it stops just outside the outer ring
	# now. The old line ran diagonal into the stage area and its far end stood
	# inside the ring, between the arms.
	_place("conduit_run", centre + Vector3(2.49, 0.3, 0.05), Vector3(0.0, -0.94, 0.0), {"length": 2.3})
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
	# two of the fence spans are left out as gates: span 3 (135-180 degrees) where
	# the diagnostic console stands, span 6 (270-315) where the display screen does
	_place("safety_boundary", centre, Vector3.ZERO, {"radius": 1.3, "skip_spans": [3, 6]})
	# the console stands west of the fence now, in the gap's mouth: every spot
	# closer in crossed either the barrier's tape or the platform's outer ring
	var panel: Node3D = _place("instrument_panel", centre + Vector3(-1.95, 0.0, 0.0), Vector3(0.0, 0.75, 0.0), {"width": 0.72})
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
	# the testing corner's always-on bulb: the area's own circuit spot above the
	# deck is the shadowed key; this is the one that burns without power
	_always_on_bulb(centre + Vector3(0.0, structure.height - 0.2, 0.0), 0.62)
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
	_always_on_bulb(Vector3(-half_w + 1.3, structure.height - 0.15, -4.2), 0.5, 1.5, 6.0)
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
	# is on the west wall at z = 3.6 and the bench at z = 1.7. The wires now drop
	# down the wall and plug in at the bench's back edge; the old ends were aimed
	# at the bench top's middle, so the whole descent crossed the bench-top clutter
	# (flask, tea glass, notebook, piston, brush cup) at hand height.
	var loom_wires: Array = [
		{"start": Vector3(-x + 0.4, 1.62, half_l - 1.65), "end": Vector3(-x + 0.24, 0.99, 1.05), "sag": 0.06},
		{"start": Vector3(-x + 0.4, 1.56, half_l - 1.65), "end": Vector3(-x + 0.22, 0.99, 1.35), "sag": 0.07},
		{"start": Vector3(-x + 0.4, 1.5, half_l - 1.65), "end": Vector3(-x + 0.22, 0.99, 1.65), "sag": 0.08},
		{"start": Vector3(-x + 0.4, 1.44, half_l - 1.65), "end": Vector3(-x + 0.21, 0.03, half_l - 0.9), "sag": 0.18},
	]
	var bundle: MeshInstance3D = gen.make_node({
		"wires": loom_wires, "radius": 0.011, "radial_segments": 7, "length_segments": 26,
		"spread": 0.03, "material": sleeve, "u_scale": 2.0,
	}, "SwitchboardLoom")
	add_child(bundle)
	_bundle_stats = gen.last_stats.duplicate()

	# 2. workstation loom: the wall socket drops to the tower top, a short lead
	# pools at the tower's base, and the two monitors are linked across their
	# backs. The previous three wires ran from the tower straight to the monitor
	# backs and the socket, so each crossed the desk body diagonally: through the
	# drawer, the top and the wall duct.
	var ws_wires: Array = [
		{"start": Vector3(x - 0.16, 1.24, 4.06), "end": Vector3(x - 0.45, 0.48, 2.90), "sag": 0.12},
		{"start": Vector3(x - 0.23, 0.42, 2.72), "end": Vector3(x - 0.20, 0.05, 2.58), "sag": 0.06},
		{"start": Vector3(x - 0.16, 1.08, 1.16), "end": Vector3(x - 0.16, 1.32, 1.78), "sag": 0.04},
	]
	add_child(gen.make_node({
		"wires": ws_wires, "radius": 0.008, "radial_segments": 6, "length_segments": 22,
		"spread": 0.022, "material": sleeve, "u_scale": 1.6,
	}, "WorkstationLoom"))

	# 3. IPS leads: the battery rack down to the stabilizer and the floor strip,
	# which are on the same wall it is. They now leave the cells' face and land on
	# the stabilizer's top and the strip; the old ends crossed the rack's skid and
	# the stabilizer's body on the way down.
	add_child(gen.make_node({
		"wires": [
			{"start": Vector3(x - 0.95, 0.44, 4.02), "end": Vector3(x - 0.53, 0.33, 3.56), "sag": 0.06},
			{"start": Vector3(x - 0.95, 0.42, 4.02), "end": Vector3(x - 0.47, 0.33, 3.66), "sag": 0.05},
			{"start": Vector3(x - 0.95, 0.44, 4.02), "end": Vector3(x - 1.20, 0.06, 3.30), "sag": 0.12},
		],
		"radius": 0.016, "radial_segments": 8, "length_segments": 28, "spread": 0.04,
		"material": red, "u_scale": 2.4,
	}, "IpsLeads"))

	# 4. the reactor feed: a thick conduit-cable from the reactor housing on the
	# north wall down to the platform. It leaves the housing high and lands by the
	# pit's edge; the old path sagged to y ~0.5 across the testing corner, which
	# put it through the diagnostic console's face and the boundary rail.
	var feed: MeshInstance3D = gen.make_node({
		"start": Vector3(1.47, 2.05, -4.68), "end": Vector3(0.58, 0.31, -1.05),
		"sag": 0.12, "slack": 0.18, "sideways": -0.12, "radius": 0.03,
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

	# 6. the loose jumper cables a workshop always has. The first hangs off the
	# bench's front edge; it used to be slung from the store shelf toward the holo
	# table, which dragged it through the table's glass top.
	add_child(gen.make_hang(
		Vector3(-structure.half_w + 0.83, 1.02, 2.10),
		Vector3(-structure.half_w + 0.95, 0.22, 1.94), 0.08, 0.007, blue, 24))
	add_child(gen.make_hang(
		Vector3(structure.half_w - 0.5, 1.6, 2.6),
		Vector3(structure.half_w - 1.4, 0.93, 2.9), 1.0, 0.006, yellow, 24))


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
			baker.apply_baked(face, spec, "signboard", 1.0, 0.42)
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
	# the flag's cloth: the shader samples the baked pattern, so one bake feeds
	# every flag pole in the scene — the courtyard mast and the desk flag — via
	# their shader uniforms rather than a standard material
	var poles: Array = _find_all("FlagPole")
	poles.append_array(_find_all("DeskFlagPole"))
	if not poles.is_empty():
		baker.bake_async(_flag_spec(), "flag_cloth", func(tex: ImageTexture) -> void:
			for p: Node in poles:
				var cloth: MeshInstance3D = (p as Node3D).get_node_or_null("Flag") as MeshInstance3D
				if cloth != null and cloth.material_override is ShaderMaterial:
					(cloth.material_override as ShaderMaterial).set_shader_parameter("flag_tex", tex))
	# the display coin's two faces: struck-metal look, so the baked design is given
	# a metallic response on top rather than left as a flat print
	var coin: Node3D = _find_first("BigCoin")
	if coin != null:
		var coin_root: Node3D = coin.get_node_or_null("Coin") as Node3D
		if coin_root != null:
			var front: MeshInstance3D = coin_root.get_node_or_null("Front") as MeshInstance3D
			if front != null:
				var mf: StandardMaterial3D = baker.apply_baked(front, _coin_face_spec(true), "coin_front", 0.0, 0.34)
				mf.metallic = 0.6
				mf.metallic_specular = 0.55
			var back_face: MeshInstance3D = coin_root.get_node_or_null("Back") as MeshInstance3D
			if back_face != null:
				var mb: StandardMaterial3D = baker.apply_baked(back_face, _coin_face_spec(false), "coin_back", 0.0, 0.34)
				mb.metallic = 0.6
				mb.metallic_specular = 0.55
	# the two wall maps: flat paper prints, so no depth on the bake
	var bd_map: Node3D = _find_first("BangladeshMap")
	if bd_map != null:
		var bd_face: MeshInstance3D = bd_map.get_node_or_null("Print") as MeshInstance3D
		if bd_face != null:
			baker.apply_baked(bd_face, _bangladesh_map_spec(), "map_bangladesh", 0.0, 0.62)
	var sy_map: Node3D = _find_first("SylhetMap")
	if sy_map != null:
		var sy_face: MeshInstance3D = sy_map.get_node_or_null("Print") as MeshInstance3D
		if sy_face != null:
			baker.apply_baked(sy_face, _sylhet_map_spec(), "map_sylhet", 0.0, 0.62)


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
			{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(1024, 62), "color": "#1c3450"},
			{"type": "rect", "pos": Vector2(0, 194), "sz": Vector2(1024, 62), "color": "#1c3450"},
			{"type": "text", "name": "GARAGE", "pos": Vector2(28, 62), "size": 96, "color": "#f6ecd2", "text": garage, "font": "bangla", "shadow": true},
			{"type": "text", "name": "BRAND", "pos": Vector2(28, 12), "size": 34, "color": "#e2bf4a", "text": brand, "font": "bangla"},
			{"type": "text", "name": "TAG", "pos": Vector2(28, 202), "size": 40, "color": "#5fe0ff", "text": tagline, "font": "bangla"},
			{"type": "text", "name": "EN", "pos": Vector2(700, 208), "size": 30, "color": "#a8b8c4", "text": "OPEN 24 HOURS", "font": "mono"},
			{"type": "circle", "center": Vector2(960, 128), "radius": 34, "color": "#e2453c", "filled": true},
			{"type": "text", "name": "NUM", "pos": Vector2(694, 68), "size": 46, "color": "#e8eef4", "text": "017XX-XXXXXX", "font": "mono"},
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


func _flag_spec() -> Dictionary:
	## The national flag at its official construction: a bottle-green field, a red
	## disc whose centre sits nine-twentieths of the flag's length from the hoist
	## with a radius of one-fifth of the length. In a 2:3 weave the "length" is the
	## 480 px side, so the disc is centred at (216, 160) with r = 96 — not the middle
	## of the cloth, which is the detail everyone gets wrong.
	return {
		"size": Vector2i(480, 320), "transparent": false, "bg": "#006a4e",
		"layers": [
			{"type": "circle", "center": Vector2(216, 160), "radius": 96, "color": "#f42a41", "filled": true},
		],
	}


func _coin_face_spec(front: bool) -> Dictionary:
	## A display coin's face, drawn in brass tones with an embossed trick: every
	## element is painted twice, a light copy offset by two pixels under a dark one,
	## which is enough to read as relief once the material is given a metallic
	## response. The front carries the shapla and the country's name; the back the
	## denomination. It is a shop ornament and the inspect text says so.
	var brass_dark: String = "#6d5426"
	var brass_mid: String = "#9a7b3a"
	var brass_light: String = "#cba85f"
	var layers: Array = [
		{"type": "rect", "pos": Vector2(0, 0), "sz": Vector2(512, 512), "color": brass_mid},
		{"type": "circle", "center": Vector2(256, 256), "radius": 244, "color": brass_light, "filled": false, "width": 8.0},
		{"type": "circle", "center": Vector2(256, 256), "radius": 226, "color": brass_dark, "filled": false, "width": 3.0},
	]
	if front:
		# embossed country name
		layers.append({"type": "text", "name": "NM2", "pos": Vector2(34, 44), "size": 46, "width": 448, "align": "center", "color": brass_light, "text": "বাংলাদেশ", "font": "bangla"})
		layers.append({"type": "text", "name": "NM", "pos": Vector2(32, 42), "size": 46, "width": 448, "align": "center", "color": brass_dark, "text": "বাংলাদেশ", "font": "bangla"})
		# the shapla: a centre petal and two side petals, drawn as eight-point
		# lenses so they read as leaves rather than diamonds, over two water arcs
		layers.append({"type": "poly", "points": [Vector2(256, 148), Vector2(246, 188), Vector2(238, 212), Vector2(246, 238), Vector2(256, 270), Vector2(266, 238), Vector2(274, 212), Vector2(266, 188)], "color": brass_light})
		layers.append({"type": "poly", "points": [Vector2(256, 150), Vector2(247, 189), Vector2(240, 212), Vector2(247, 236), Vector2(256, 266), Vector2(265, 236), Vector2(272, 212), Vector2(265, 189)], "color": brass_dark})
		layers.append({"type": "poly", "points": [Vector2(206, 184), Vector2(196, 206), Vector2(184, 224), Vector2(196, 240), Vector2(210, 260), Vector2(224, 238), Vector2(232, 220), Vector2(224, 198)], "color": brass_light})
		layers.append({"type": "poly", "points": [Vector2(208, 186), Vector2(198, 207), Vector2(187, 224), Vector2(198, 239), Vector2(210, 257), Vector2(222, 238), Vector2(229, 220), Vector2(222, 200)], "color": brass_dark})
		layers.append({"type": "poly", "points": [Vector2(306, 184), Vector2(316, 206), Vector2(328, 224), Vector2(316, 240), Vector2(302, 260), Vector2(288, 238), Vector2(280, 220), Vector2(288, 198)], "color": brass_light})
		layers.append({"type": "poly", "points": [Vector2(304, 186), Vector2(314, 207), Vector2(325, 224), Vector2(314, 239), Vector2(302, 257), Vector2(290, 238), Vector2(283, 220), Vector2(290, 200)], "color": brass_dark})
		layers.append({"type": "arc", "center": Vector2(256, 288), "radius": 76, "start": 0.22, "end": 2.92, "color": brass_dark, "width": 3.0})
		layers.append({"type": "arc", "center": Vector2(256, 300), "radius": 94, "start": 0.32, "end": 2.82, "color": brass_dark, "width": 2.0})
		# the denomination, embossed
		layers.append({"type": "text", "name": "VN2", "pos": Vector2(48, 356), "size": 58, "width": 420, "align": "center", "color": brass_light, "text": "৫ টাকা", "font": "bangla"})
		layers.append({"type": "text", "name": "VN", "pos": Vector2(46, 354), "size": 58, "width": 420, "align": "center", "color": brass_dark, "text": "৫ টাকা", "font": "bangla"})
		layers.append({"type": "text", "name": "YR", "pos": Vector2(32, 444), "size": 24, "width": 448, "align": "center", "color": brass_dark, "text": "২০১৯", "font": "bangla"})
	else:
		layers.append({"type": "text", "name": "B2", "pos": Vector2(36, 96), "size": 220, "width": 440, "align": "center", "color": brass_light, "text": "৫", "font": "bangla"})
		layers.append({"type": "text", "name": "B1", "pos": Vector2(32, 92), "size": 220, "width": 440, "align": "center", "color": brass_dark, "text": "৫", "font": "bangla"})
		layers.append({"type": "text", "name": "W2", "pos": Vector2(34, 348), "size": 46, "width": 444, "align": "center", "color": brass_light, "text": "পাঁচ টাকা", "font": "bangla"})
		layers.append({"type": "text", "name": "W1", "pos": Vector2(32, 346), "size": 46, "width": 444, "align": "center", "color": brass_dark, "text": "পাঁচ টাকা", "font": "bangla"})
		layers.append({"type": "text", "name": "E", "pos": Vector2(32, 418), "size": 30, "width": 448, "align": "center", "color": brass_dark, "text": "FIVE TAKA", "font": "mono"})
		layers.append({"type": "text", "name": "D", "pos": Vector2(32, 456), "size": 20, "width": 448, "align": "center", "color": brass_dark, "text": "প্রদর্শনী মুদ্রা", "font": "bangla"})
	return {"size": Vector2i(512, 512), "transparent": false, "bg": brass_mid, "layers": layers}


func _wall_maps() -> void:
	## The two framed wall maps, hung where they are actually useful to a visitor:
	## the country on the entrance's south wall, right of the gate (the wall you
	## face walking in), and its Sylhet division on the west wall beside the door.
	## Both are wall_plaques with larger formats and both prints are hand-drawn
	## signage bakes (see _bangladesh_map_spec / _sylhet_map_spec) — line sketches,
	## not survey data, and their inspection text says so.
	var half_l: float = structure.half_l
	var bd: Node3D = _place("wall_plaque", Vector3(2.7, 1.30, half_l - 0.16), Vector3(0.0, PI, 0.0), {"width": 0.62, "height": 0.78})
	bd.name = "BangladeshMap"
	_station(bd, Station.Kind.SIGN, Vector3(0.0, 0.39, 0.04), {
		"area": "entrance", "title": "Wall map — Bangladesh",
		"desc": "A hand-drawn map of the country, hung right of the gate where a customer waiting out a repair can find their district. It is a sketch, not a survey: the delta in the south, the Sylhet wedge in the north-east, the Chittagong hills running down to Teknaf, the four great rivers and the main towns marked.",
		"spec": [["format", "sketch map, 0.6 × 0.8 m"], ["rivers", "পদ্মা · যমুনা · মেঘনা · সুরমা"], ["honesty", "a line drawing, not survey data"]],
		"sfx": "paper", "distance": 3.0,
	})
	var sy: Node3D = _place("wall_plaque", Vector3(-structure.half_w + 0.20, 1.28, 4.55), Vector3(0.0, PI * 0.5, 0.0), {"width": 0.66, "height": 0.58})
	sy.name = "SylhetMap"
	_station(sy, Station.Kind.SIGN, Vector3(0.0, 0.29, 0.04), {
		"area": "entrance", "title": "Wall map — Sylhet division",
		"desc": "The division this garage calls home — সুনামগঞ্জ, সিলেট, মৌলভীবাজার and হবিগঞ্জ — drawn with its two rivers, the সুরমা and the কুশিয়ারা, running through it. Same hand and same sketch honesty as the country map across the room.",
		"spec": [["districts", "4: সুনামগঞ্জ · সিলেট · মৌলভীবাজার · হবিগঞ্জ"], ["rivers", "সুরমা · কুশিয়ারা"], ["honesty", "a line drawing, not survey data"]],
		"sfx": "paper", "distance": 3.0,
	})


func _keepsakes() -> void:
	## The author's own pictures, hung where a working garage keeps them: a photo
	## row above the mechanical bench (the railway, the Sylhet clock tower, the
	## batch that came before), the team photo leaning by the notebook, the dream
	## poster on the wall the suit faces, and a desk flag on the electronics bench.
	## Photographs load through MaterialLibrary.photo_print() — the same
	## load_from_file path as the street banner, so no import side files — and
	## docs/ASSET_LICENSES.md records them as author-supplied.
	var half_w: float = structure.half_w
	var spin := Vector3(0.0, PI * 0.5, 0.0)
	var px: float = -half_w + 0.20
	var photo_row: Array = [
		{"photo": "res://assets/textures/user/photo_train.jpg", "z": 1.30, "title": "Photo — Bangladesh Railway",
		 "desc": "A Bangladesh Railway diesel locomotive, blue over cream with the red buffer beam, hung above the bench by someone who rode the Sylhet line to school.",
		 "spec": [["subject", "BR class 2900 locomotive"], ["place", "a level crossing, Sylhet division"], ["frame", "teak, 0.34 m"]]},
		{"photo": "res://assets/textures/user/photo_clock.jpg", "z": 1.70, "title": "Photo — Ali Amjad's clock",
		 "desc": "The red clock tower by the Surma in Sylhet — corrugated iron on a tank of a base, the town's own landmark. It hangs beside its district on the map.",
		 "spec": [["subject", "Ali Amjad's Clock"], ["place", "Sylhet city"], ["frame", "teak, 0.34 m"]]},
		{"photo": "res://assets/textures/user/photo_students.jpg", "z": 2.10, "title": "Photo — the batch before",
		 "desc": "Three students around a half-stripped television, one meter between them, a wall of notes at the left. Everybody learns to fix things on something.",
		 "spec": [["subject", "a lab batch, earlier years"], ["tools", "analog multimeter, soldering iron, CRT"], ["frame", "teak, 0.34 m"]]},
	]
	for p: Dictionary in photo_row:
		var frame: Node3D = _place("wall_plaque", Vector3(px, 2.42, p["z"]), spin, {"width": 0.34, "height": 0.227, "photo": p["photo"]})
		_station(frame, Station.Kind.SIGN, Vector3(0.0, 0.11, 0.05), {
			"area": "mechanical", "title": p["title"], "desc": p["desc"], "spec": p["spec"],
			"sfx": "paper", "distance": 2.4,
		})
	# the team photo, leaning by the notebook on the mechanical bench
	var team: Node3D = _place("wall_plaque", Vector3(-3.70, 0.985, 2.28), Vector3(-0.12, 0.5, 0.0), {"width": 0.22, "height": 0.293, "photo": "res://assets/textures/user/photo_team.jpg"})
	_station(team, Station.Kind.SIGN, Vector3(0.0, 0.15, 0.03), {
		"area": "mechanical", "title": "Photo — the team",
		"desc": "Three of them at a convocation, lanyards and all. The photo leans against the tool rail where the owner can see it while he works.",
		"spec": [["subject", "the workshop's people"], ["frame", "teak, 0.22 m, leaning"], ["note", "it is never quite straight"]],
		"sfx": "paper", "distance": 2.2,
	})
	# the dream poster on the north wall, in the clear brick between the shop's
	# airline banner (x -3.35..-1.35) and the fan ring — two earlier spots sat
	# behind those two and never showed
	var dream: Node3D = _place("wall_plaque", Vector3(-0.75, 2.00, -structure.half_l + 0.20), Vector3.ZERO, {"width": 0.62, "height": 0.62, "photo": "res://assets/textures/user/poster_dream.jpg"})
	_station(dream, Station.Kind.SIGN, Vector3(0.0, 0.31, 0.05), {
		"area": "assembly", "title": "Poster — the dream",
		"desc": "A printed concept: the exosuit as it will be — drawn over a blueprint, glowing. It hangs beside the shop's airline banner, on the wall the stand faces, so the suit and its dream look at each other.",
		"spec": [["medium", "print, 0.62 m"], ["subject", "the exosuit, imagined"], ["pinned", "four drawing pins"]],
		"sfx": "paper", "distance": 2.8,
	})
	# the desk flag on the electronics bench, art shared with the gate's flag.
	# Named explicitly: a second node called "FlagPole" would be auto-renamed by
	# Godot on the name collision and the signage pass would miss its cloth.
	# the desk flag stands in the gap between the CRT and the keyboard; at its old
	# spot its base sat inside the CRT's body and the pole crossed the screen
	var desk_flag: Node3D = _place("flag_pole", Vector3(3.82, 0.925, 1.32), Vector3(0.0, -0.6, 0.0), {"height": 0.46, "flag_width": 0.24})
	desk_flag.name = "DeskFlagPole"
	_station(desk_flag, Station.Kind.SIGN, Vector3(0.0, 0.28, 0.0), {
		"area": "electronics", "title": "Desk flag",
		"desc": "The same flag as the one on the courtyard pole, scaled down to desk size — a gift-shop flag with a weighted fly, standing between the keyboard and the scope.",
		"spec": [["format", "desk flag, 0.24 m"], ["ratio", "10 : 6"], ["note", "same cloth art as the gate flag"]],
		"sfx": "paper", "distance": 1.6,
	})
	# the notice wall: the curated Commons photographs, pinned on the south wall's
	# west pier — the wall you face walking in, opposite the country map
	var notice_photos: Array = []
	for n: int in range(1, 16):
		if n == 9 or n == 10:
			continue
		notice_photos.append("res://assets/textures/wall/wall_%02d.jpg" % n)
	var notice: Node3D = _place("photo_wall", Vector3(-2.7, 1.30, structure.half_l - 0.16), Vector3(0.0, PI, 0.0), {"photos": notice_photos, "cols": 4})
	_station(notice, Station.Kind.SIGN, Vector3(0.0, 0.43, 0.05), {
		"area": "entrance", "title": "Photo wall — the shop's places",
		"desc": "Thirteen photographs pinned crooked to a plywood sheet: the rickshaw seen from the door, Sadarghat market, a tea stall in Khulna, the tea gardens, the railway, Sylhet, the boats, the paddy. The owner's picks of the country, with their credits kept in the project's asset list.",
		"spec": [["photographs", "13, pinned"], ["licences", "CC BY-SA 4.0 (see docs/ASSET_LICENSES.md)"], ["board", "plywood, 1.1 × 0.9 m"]],
		"sfx": "paper", "distance": 3.2,
	})


func _fake_details() -> void:
	## The painted-on layer that makes a room read as used: tool outlines on the
	## pegboard, chalk notes on the floor, tea rings and an old spill on the bench
	## top, paper labels on the component drawers, and a few stickers. All of it is
	## flush overlays and small quads — no props, no stations, no lights — the
	## cheap end of faking a lived-in workshop.
	# 1. painted tool outlines, on the pegboard between the board and the hanging tools
	var outlines: MeshInstance3D = ShapeKit.plane(Vector2(1.8, 0.85), null, "ToolOutlines")
	outlines.position = Vector3(-structure.half_w + 0.19, 1.72, 1.7)
	outlines.rotation = Vector3(0.0, PI * 0.5, 0.0)
	add_child(outlines)
	baker.apply_baked(outlines, _tool_outline_spec(), "tool_outlines", 0.0, 0.85)
	# 2. chalk marks on the floor by the walk lane
	var chalk: MeshInstance3D = ShapeKit.plane(Vector2(1.6, 0.8), null, "FloorChalk")
	chalk.position = Vector3(-1.75, 0.012, 0.85)
	chalk.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(chalk)
	baker.apply_baked(chalk, _chalk_spec(), "floor_chalk", 0.0, 0.9)
	# 3. bench wear: tea rings, an old spill, scratches — under everything on the top
	var wear: MeshInstance3D = ShapeKit.plane(Vector2(1.3, 1.3), null, "BenchWear")
	wear.position = Vector3(-3.89, 0.972, 1.7)
	wear.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(wear)
	baker.apply_baked(wear, _bench_wear_spec(), "bench_wear", 0.0, 0.9)
	# 4. paper labels on the component-drawer front (the cabinet is 0.51 m tall)
	var labels: MeshInstance3D = ShapeKit.plane(Vector2(0.26, 0.32), null, "DrawerLabels")
	labels.position = Vector3(3.485, 0.27, -0.55)
	labels.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	add_child(labels)
	baker.apply_baked(labels, _drawer_label_spec(), "drawer_labels", 0.0, 0.85)
	# 5. stickers: small flat quads on cabinets, legs, jambs and crates
	var stickers: Array = [
		[Vector3(-3.265, 0.235, 4.50), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.09, 0.06), ML.paint_yellow(), "CkSticker"],
		[Vector3(-3.955, 1.47, 3.50), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.07, 0.05), ML.led(Color("e2453c"), 0.0), "RedSticker"],
		[Vector3(-3.525, 0.60, 1.45), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.08, 0.055), ML.paint_blue(0.6), "BlueSticker"],
		[Vector3(3.50, 0.47, -0.62), Vector3(0.0, -PI * 0.5, 0.0), Vector2(0.10, 0.07), ML.rust(), "RustSticker"],
		[Vector3(-3.53, 0.42, 0.80), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.07, 0.05), ML.paint_blue(0.6), "LegSticker"],
		[Vector3(-3.53, 0.42, 2.60), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.08, 0.05), ML.paint_yellow(), "LegSticker2"],
		[Vector3(-3.62, 0.95, -1.30), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.06, 0.06), ML.led(Color("35c06a"), 0.0), "ShelfSticker"],
		[Vector3(-1.42, 1.18, 5.06), Vector3(0.0, PI, 0.0), Vector2(0.08, 0.06), ML.paint_yellow(), "JambSticker"],
		[Vector3(1.42, 1.18, 5.06), Vector3(0.0, PI, 0.0), Vector2(0.07, 0.05), ML.led(Color("4a6fa5"), 0.0), "JambSticker2"],
		[Vector3(2.92, 0.50, -3.55), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.09, 0.06), ML.rust(), "DeckSticker"],
		[Vector3(-2.55, 0.42, 4.86), Vector3(0.0, 0.0, 0.0), Vector2(0.07, 0.05), ML.paint_blue(0.6), "CrateSticker"],
	]
	for s: Array in stickers:
		var chip: MeshInstance3D = ShapeKit.plane(s[2], s[3], s[4])
		chip.position = s[0]
		chip.rotation = s[1]
		add_child(chip)
	# 6. greasy handprints: on both gate jambs and the bench apron, where hands go
	var smudges: Array = [
		[Vector3(-1.42, 1.02, 5.06), Vector3(0.0, PI, 0.0), Vector2(0.24, 0.3)],
		[Vector3(1.42, 1.02, 5.06), Vector3(0.0, PI, 0.0), Vector2(0.24, 0.3)],
		[Vector3(-3.53, 0.68, 2.05), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.3, 0.26)],
	]
	for sm: Array in smudges:
		var mark: MeshInstance3D = ShapeKit.plane(sm[2], null, "GreaseMark")
		mark.position = sm[0]
		mark.rotation = sm[1]
		add_child(mark)
		baker.apply_baked(mark, _smudge_spec(), "grease_mark", 0.0, 0.95)
	# 7. the paint-test board, on the east wall where the light is good
	var swatch: MeshInstance3D = ShapeKit.plane(Vector2(0.5, 0.36), null, "PaintSwatches")
	swatch.position = Vector3(structure.half_w - 0.19, 1.62, 2.55)
	swatch.rotation = Vector3(0.0, -PI * 0.5, 0.0)
	add_child(swatch)
	baker.apply_baked(swatch, _swatch_spec(), "paint_swatches", 0.0, 0.85)
	# 8. a second chalk patch outside the gate: delivery notes for the yard
	var yard_chalk: MeshInstance3D = ShapeKit.plane(Vector2(1.2, 0.6), null, "YardChalk")
	yard_chalk.position = Vector3(-1.3, -0.128, 6.4)
	yard_chalk.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(yard_chalk)
	baker.apply_baked(yard_chalk, _chalk_spec(1), "yard_chalk", 0.0, 0.9)
	# 9. desk wear: rings and a solder scorch on the electronics bench
	var desk_wear: MeshInstance3D = ShapeKit.plane(Vector2(1.0, 1.0), null, "DeskWear")
	desk_wear.position = Vector3(3.8, 0.927, 1.5)
	desk_wear.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(desk_wear)
	baker.apply_baked(desk_wear, _bench_wear_spec(), "desk_wear", 0.0, 0.9)
	# 10. wall scuff bands: the dark brush marks at bench height where people
	# lean over the benches, breaking the plaster's clean edge
	var scuffs: Array = [
		[Vector3(-4.105, 1.10, 1.70), Vector3(0.0, PI * 0.5, 0.0), Vector2(1.8, 0.26)],
		[Vector3(4.105, 1.16, 1.50), Vector3(0.0, -PI * 0.5, 0.0), Vector2(1.6, 0.24)],
	]
	for sc: Array in scuffs:
		var band: MeshInstance3D = ShapeKit.plane(sc[2], null, "ScuffBand")
		band.position = sc[0]
		band.rotation = sc[1]
		add_child(band)
		baker.apply_baked(band, _scuff_spec(), "scuff_band", 0.0, 0.98)
	# 11. rain drips: dark runs below the switchboard and the north wall panels
	var drips: Array = [
		[Vector3(-4.105, 0.95, 3.60), Vector3(0.0, PI * 0.5, 0.0), Vector2(0.34, 0.5)],
		[Vector3(-0.30, 1.55, -5.105), Vector3(0.0, 0.0, 0.0), Vector2(0.40, 0.45)],
	]
	for dr: Array in drips:
		var run: MeshInstance3D = ShapeKit.plane(dr[2], null, "DripStreak")
		run.position = dr[0]
		run.rotation = dr[1]
		add_child(run)
		baker.apply_baked(run, _drip_spec(), "drip_streak", 0.0, 0.95)
	# 12. old leaks: dried mineral rings high on the plaster, out of the way
	var rings: Array = [
		[Vector3(-4.105, 2.52, 0.40), Vector3(0.0, PI * 0.5, 0.0)],
		[Vector3(2.60, 2.50, -5.105), Vector3(0.0, 0.0, 0.0)],
	]
	for rg: Array in rings:
		var stain: MeshInstance3D = ShapeKit.plane(Vector2(0.5, 0.44), null, "WaterStain")
		stain.position = rg[0]
		stain.rotation = rg[1]
		add_child(stain)
		baker.apply_baked(stain, _stain_spec(), "water_stain", 0.0, 0.92)
	# 13. dusty boot prints coming in off the yard, fading as the dust runs out
	var prints: MeshInstance3D = ShapeKit.plane(Vector2(1.2, 0.8), null, "BootPrints")
	prints.position = Vector3(-0.35, 0.013, 4.45)
	prints.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	add_child(prints)
	baker.apply_baked(prints, _prints_spec(), "boot_prints", 0.0, 0.9)
	# 14. cobwebs: the top corners of an old workshop are never clean. Variant
	# flips the web for corners that sit to the right of the viewer.
	var webs: Array = [
		[Vector3(-3.98, 3.12, -4.92), Vector3(0.0, PI * 0.25, 0.0), 0],
		[Vector3(3.98, 3.12, -4.92), Vector3(0.0, -PI * 0.25, 0.0), 1],
		[Vector3(3.98, 3.12, 4.92), Vector3(0.0, -PI * 0.75, 0.0), 1],
	]
	for wb: Array in webs:
		var web: MeshInstance3D = ShapeKit.plane(Vector2(0.55, 0.55), null, "Cobweb")
		web.position = wb[0]
		web.rotation = wb[1]
		web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(web)
		baker.apply_baked(web, _web_spec(int(wb[2])), "cobweb%d" % int(wb[2]), 0.0, 1.0)
	# 15. paint flaking off the dado: pale patches where the green has let go
	var peels: Array = [
		[Vector3(-4.105, 1.02, -2.35), Vector3(0.0, PI * 0.5, 0.0)],
		[Vector3(4.105, 1.02, -2.60), Vector3(0.0, -PI * 0.5, 0.0)],
	]
	for pl: Array in peels:
		var peel: MeshInstance3D = ShapeKit.plane(Vector2(0.34, 0.17), null, "PaintPeel")
		peel.position = pl[0]
		peel.rotation = pl[1]
		add_child(peel)
		baker.apply_baked(peel, _peel_spec(), "paint_peel", 0.0, 0.9)


func _tool_outline_spec() -> Dictionary:
	## Dark paint silhouettes where the tools hang, the way every workshop paints
	## the shadow of each tool on its board.
	var dark: String = "#4a3b2a"
	var light: String = "#6a5136"
	return {
		"size": Vector2i(512, 256), "transparent": true,
		"layers": [
			{"type": "rect", "pos": Vector2(60, 90), "sz": Vector2(14, 120), "color": dark},
			{"type": "rect", "pos": Vector2(38, 64), "sz": Vector2(58, 30), "color": dark},
			{"type": "circle", "center": Vector2(138, 92), "radius": 19, "color": dark, "filled": true},
			{"type": "circle", "center": Vector2(138, 92), "radius": 9, "color": "#c9b28a", "filled": true},
			{"type": "rect", "pos": Vector2(131, 92), "sz": Vector2(14, 110), "color": dark},
			{"type": "circle", "center": Vector2(214, 96), "radius": 18, "color": dark, "filled": true},
			{"type": "rect", "pos": Vector2(206, 96), "sz": Vector2(16, 96), "color": dark},
			{"type": "circle", "center": Vector2(214, 200), "radius": 15, "color": dark, "filled": true},
			{"type": "poly", "points": [Vector2(268, 148), Vector2(392, 108), Vector2(352, 190)], "color": dark},
			{"type": "rect", "pos": Vector2(252, 138), "sz": Vector2(34, 38), "color": light},
			{"type": "rect", "pos": Vector2(420, 82), "sz": Vector2(13, 108), "color": light},
			{"type": "poly", "points": [Vector2(418, 190), Vector2(435, 190), Vector2(426, 216)], "color": dark},
			{"type": "rect", "pos": Vector2(415, 60), "sz": Vector2(23, 26), "color": dark},
			{"type": "line", "from": Vector2(330, 52), "to": Vector2(312, 128), "color": dark, "width": 9.0},
			{"type": "line", "from": Vector2(358, 52), "to": Vector2(342, 128), "color": dark, "width": 9.0},
			{"type": "circle", "center": Vector2(318, 136), "radius": 7, "color": dark, "filled": true},
			{"type": "circle", "center": Vector2(348, 136), "radius": 7, "color": dark, "filled": true},
		],
	}


func _scuff_spec() -> Dictionary:
	## The dark brush band at bench height where shoulders and stock scuff the
	## plaster. Broken into uneven strokes and two ghost lines so it reads as wear
	## rather than a painted stripe.
	var ink: String = "#3b3f36"
	var soft: String = "#4a4e44"
	return {
		"size": Vector2i(512, 96), "transparent": true,
		"layers": [
			{"type": "rect", "pos": Vector2(6, 30), "sz": Vector2(120, 34), "color": ink},
			{"type": "rect", "pos": Vector2(112, 24), "sz": Vector2(96, 46), "color": soft},
			{"type": "rect", "pos": Vector2(196, 32), "sz": Vector2(150, 30), "color": ink},
			{"type": "rect", "pos": Vector2(334, 26), "sz": Vector2(80, 42), "color": soft},
			{"type": "rect", "pos": Vector2(402, 34), "sz": Vector2(104, 28), "color": ink},
			{"type": "line", "from": Vector2(20, 20), "to": Vector2(500, 18), "color": soft, "width": 5.0},
			{"type": "line", "from": Vector2(14, 78), "to": Vector2(494, 80), "color": soft, "width": 6.0},
		],
	}


func _drip_spec() -> Dictionary:
	## Rain down the plaster: a few dark runs from the top edge, heaviest where
	## the fixing above lets the water through.
	var ink: String = "#57544a"
	var ink2: String = "#63605a"
	return {
		"size": Vector2i(160, 224), "transparent": true,
		"layers": [
			{"type": "line", "from": Vector2(38, 0), "to": Vector2(40, 176), "color": ink, "width": 7.0},
			{"type": "line", "from": Vector2(70, 0), "to": Vector2(66, 210), "color": ink2, "width": 5.0},
			{"type": "line", "from": Vector2(102, 0), "to": Vector2(106, 132), "color": ink, "width": 6.0},
			{"type": "line", "from": Vector2(126, 0), "to": Vector2(124, 88), "color": ink2, "width": 4.0},
			{"type": "circle", "center": Vector2(106, 150), "radius": 7, "color": ink, "filled": true},
		],
	}


func _stain_spec() -> Dictionary:
	## An old leak: two or three dried rings of pale mineral stain.
	var ink: String = "#6f6a58"
	var ink2: String = "#7d7866"
	return {
		"size": Vector2i(256, 224), "transparent": true,
		"layers": [
			{"type": "arc", "center": Vector2(120, 108), "radius": 92, "start": 0.0, "end": 6.28, "color": ink, "width": 4.0},
			{"type": "arc", "center": Vector2(126, 100), "radius": 70, "start": 0.0, "end": 6.28, "color": ink2, "width": 3.0},
			{"type": "arc", "center": Vector2(118, 112), "radius": 48, "start": 0.0, "end": 6.28, "color": ink, "width": 3.0},
			{"type": "circle", "center": Vector2(114, 106), "radius": 30, "color": ink2, "filled": true},
		],
	}


func _prints_spec() -> Dictionary:
	## Dusty boot prints crossing the threshold: four steps, alternating feet,
	## fading as the dust runs out.
	var ink: String = "#4c4a42"
	var ink2: String = "#5b594f"
	var ink3: String = "#6a685c"
	return {
		"size": Vector2i(256, 192), "transparent": true,
		"layers": [
			{"type": "rect", "pos": Vector2(36, 140), "sz": Vector2(30, 44), "color": ink},
			{"type": "circle", "center": Vector2(51, 130), "radius": 12, "color": ink, "filled": true},
			{"type": "rect", "pos": Vector2(96, 118), "sz": Vector2(30, 44), "color": ink2},
			{"type": "circle", "center": Vector2(111, 108), "radius": 12, "color": ink2, "filled": true},
			{"type": "rect", "pos": Vector2(150, 96), "sz": Vector2(30, 44), "color": ink3},
			{"type": "circle", "center": Vector2(165, 86), "radius": 12, "color": ink3, "filled": true},
			{"type": "rect", "pos": Vector2(204, 74), "sz": Vector2(30, 44), "color": ink3},
			{"type": "circle", "center": Vector2(219, 64), "radius": 12, "color": ink3, "filled": true},
		],
	}


func _web_spec(variant: int = 0) -> Dictionary:
	## A corner cobweb: threads from a corner point plus echoed arcs. Grey and
	## thin; it only reads at the edge of vision, which is the point. Variant 1
	## mirrors it for corners that sit to the right of the viewer.
	var ink: String = "#b9b4a6"
	var size: float = 192.0
	var cx: float = 18.0 if variant == 0 else size - 18.0
	var a0: float = 0.0 if variant == 0 else 1.5708
	var a1: float = 1.5708 if variant == 0 else 3.1416
	var layers: Array = []
	var spokes: Array = [Vector2(180, 22), Vector2(170, 66), Vector2(140, 118), Vector2(96, 164), Vector2(30, 184)]
	for sp: Vector2 in spokes:
		var p: Vector2 = sp if variant == 0 else Vector2(size - sp.x, sp.y)
		layers.append({"type": "line", "from": Vector2(cx, 18), "to": p, "color": ink, "width": 1.6})
	for rr: float in [66.0, 120.0, 162.0]:
		layers.append({"type": "arc", "center": Vector2(cx, 18), "radius": rr, "start": a0, "end": a1, "color": ink, "width": 1.4})
	return {"size": Vector2i(192, 192), "transparent": true, "layers": layers}


func _peel_spec() -> Dictionary:
	## Flaked dado paint: an irregular pale patch with a dark edge, where the
	## green has let go of the plaster.
	var pale: String = "#8d8878"
	var rim: String = "#4f5a4c"
	return {
		"size": Vector2i(256, 128), "transparent": true,
		"layers": [
			{"type": "poly", "points": [Vector2(40, 42), Vector2(88, 26), Vector2(150, 34), Vector2(196, 52), Vector2(212, 84), Vector2(160, 102), Vector2(96, 104), Vector2(52, 82)], "color": rim, "filled": true},
			{"type": "poly", "points": [Vector2(50, 46), Vector2(92, 34), Vector2(146, 42), Vector2(188, 56), Vector2(200, 80), Vector2(156, 94), Vector2(100, 96), Vector2(60, 78)], "color": pale, "filled": true},
		],
	}


func _chalk_spec(variant: int = 0) -> Dictionary:
	## The floor notes a builder leaves himself: a dimension, an arrow, a circled
	## question, a cross where the drain runs. Variant 1 is the yard's set —
	## delivery notes by the gate. Thin dark strokes on nothing.
	var ink: String = "#33363d"
	if variant == 1:
		return {
			"size": Vector2i(384, 192), "transparent": true,
			"layers": [
				{"type": "text", "name": "G", "pos": Vector2(24, 16), "size": 34, "color": ink, "text": "গেট · ২.৬ m", "font": "bangla"},
				{"type": "line", "from": Vector2(24, 74), "to": Vector2(150, 74), "color": ink, "width": 4.0},
				{"type": "poly", "points": [Vector2(150, 62), Vector2(176, 74), Vector2(150, 86)], "color": ink, "filled": true},
				{"type": "line", "from": Vector2(220, 40), "to": Vector2(340, 40), "color": ink, "width": 3.0},
				{"type": "line", "from": Vector2(220, 56), "to": Vector2(340, 56), "color": ink, "width": 3.0},
				{"type": "line", "from": Vector2(220, 72), "to": Vector2(340, 72), "color": ink, "width": 3.0},
				{"type": "text", "name": "OK", "pos": Vector2(228, 96), "size": 28, "color": ink, "text": "ঠিক আছে", "font": "bangla"},
				{"type": "arc", "center": Vector2(96, 140), "radius": 34, "start": 0.4, "end": 5.9, "color": ink, "width": 3.0},
			],
		}
	return {
		"size": Vector2i(512, 256), "transparent": true,
		"layers": [
			{"type": "text", "name": "DIM", "pos": Vector2(30, 24), "size": 40, "color": ink, "text": "২.৪ × ০.৯", "font": "bangla"},
			{"type": "line", "from": Vector2(30, 96), "to": Vector2(232, 96), "color": ink, "width": 4.0},
			{"type": "poly", "points": [Vector2(232, 82), Vector2(262, 96), Vector2(232, 110)], "color": ink, "filled": true},
			{"type": "text", "name": "Q", "pos": Vector2(300, 28), "size": 30, "color": ink, "text": "SUIT MK-I ?", "font": "mono"},
			{"type": "arc", "center": Vector2(404, 164), "radius": 58, "start": 0.2, "end": 6.1, "color": ink, "width": 4.0},
			{"type": "line", "from": Vector2(58, 168), "to": Vector2(84, 192), "color": ink, "width": 4.0},
			{"type": "line", "from": Vector2(84, 168), "to": Vector2(58, 192), "color": ink, "width": 4.0},
			{"type": "line", "from": Vector2(470, 52), "to": Vector2(470, 224), "color": ink, "width": 3.0},
			{"type": "line", "from": Vector2(458, 52), "to": Vector2(482, 52), "color": ink, "width": 3.0},
			{"type": "line", "from": Vector2(458, 224), "to": Vector2(482, 224), "color": ink, "width": 3.0},
		],
	}


func _smudge_spec() -> Dictionary:
	## Greasy handprints: overlaid finger streaks and palm dots where hands land
	## on jambs and rails. Transparent, nearly black, slightly glossy via the
	## material's roughness.
	var ink: String = "#1e1a15"
	return {
		"size": Vector2i(256, 256), "transparent": true,
		"layers": [
			{"type": "line", "from": Vector2(70, 40), "to": Vector2(96, 150), "color": ink, "width": 13.0},
			{"type": "line", "from": Vector2(100, 34), "to": Vector2(120, 148), "color": ink, "width": 12.0},
			{"type": "line", "from": Vector2(130, 40), "to": Vector2(142, 146), "color": ink, "width": 11.0},
			{"type": "line", "from": Vector2(158, 52), "to": Vector2(164, 140), "color": ink, "width": 10.0},
			{"type": "circle", "center": Vector2(126, 190), "radius": 34, "color": ink, "filled": true},
			{"type": "circle", "center": Vector2(88, 208), "radius": 12, "color": ink, "filled": true},
			{"type": "circle", "center": Vector2(170, 206), "radius": 11, "color": ink, "filled": true},
		],
	}


func _swatch_spec() -> Dictionary:
	## The paint-test board: smears of every colour the shop mixes, in the order
	## they were tried, on a scrap of plywood.
	return {
		"size": Vector2i(256, 192), "transparent": false, "bg": "#c9b28a",
		"border": {"color": "#8a7f66", "width": 4.0},
		"layers": [
			{"type": "circle", "center": Vector2(42, 44), "radius": 17, "color": "#d4af37", "filled": true},
			{"type": "circle", "center": Vector2(100, 40), "radius": 17, "color": "#a51f1b", "filled": true},
			{"type": "circle", "center": Vector2(158, 44), "radius": 17, "color": "#4a6fa5", "filled": true},
			{"type": "circle", "center": Vector2(216, 42), "radius": 17, "color": "#4f7a3a", "filled": true},
			{"type": "circle", "center": Vector2(38, 104), "radius": 15, "color": "#4fd8ff", "filled": true},
			{"type": "circle", "center": Vector2(92, 108), "radius": 15, "color": "#8a5a2b", "filled": true},
			{"type": "circle", "center": Vector2(148, 104), "radius": 15, "color": "#e8e0cc", "filled": true},
			{"type": "circle", "center": Vector2(204, 106), "radius": 15, "color": "#2b2b33", "filled": true},
			{"type": "text", "name": "T", "pos": Vector2(40, 146), "size": 22, "color": "#4a4234", "text": "রঙের নমুনা", "font": "bangla"},
		],
	}


func _bench_wear_spec() -> Dictionary:
	## Decades of tea: rings, an old oil spill pressed into the grain, scratches.
	## Square canvas so its orientation on the bench top cannot matter.
	var ring: String = "#3c2f22"
	var oil: String = "#2c2118"
	return {
		"size": Vector2i(512, 512), "transparent": true,
		"layers": [
			{"type": "circle", "center": Vector2(150, 150), "radius": 46, "color": ring, "filled": false, "width": 4.0},
			{"type": "circle", "center": Vector2(150, 150), "radius": 34, "color": ring, "filled": false, "width": 2.0},
			{"type": "arc", "center": Vector2(336, 122), "radius": 38, "start": 0.6, "end": 4.4, "color": ring, "width": 3.0},
			{"type": "circle", "center": Vector2(120, 368), "radius": 42, "color": oil, "filled": true},
			{"type": "circle", "center": Vector2(172, 392), "radius": 30, "color": oil, "filled": true},
			{"type": "circle", "center": Vector2(84, 402), "radius": 22, "color": oil, "filled": true},
			{"type": "arc", "center": Vector2(128, 382), "radius": 62, "start": 3.4, "end": 5.9, "color": "#4a3a2c", "width": 3.0},
			{"type": "line", "from": Vector2(310, 330), "to": Vector2(452, 356), "color": "#4a3a2c", "width": 2.0},
			{"type": "line", "from": Vector2(322, 352), "to": Vector2(430, 372), "color": "#4a3a2c", "width": 2.0},
			{"type": "line", "from": Vector2(300, 396), "to": Vector2(398, 414), "color": "#4a3a2c", "width": 2.0},
		],
	}


func _drawer_label_spec() -> Dictionary:
	## Six paper labels taped to the component drawers: IC, R, C, LED, SCR, and the
	## one drawer nobody has decided about.
	var names: Array[String] = ["IC", "R", "C", "LED", "SCR", "?"]
	var layers: Array = []
	for i: int in range(names.size()):
		var y: float = 8.0 + float(i) * 50.0
		layers.append({"type": "rect", "pos": Vector2(10, y), "sz": Vector2(236, 42), "color": "#e9e2d0"})
		layers.append({"type": "rect", "pos": Vector2(10, y), "sz": Vector2(236, 42), "color": "#8a8066", "filled": false})
		layers.append({"type": "text", "name": "L%d" % i, "pos": Vector2(20, y + 6), "size": 30, "color": "#2b2b33", "text": names[i], "font": "mono"})
	return {"size": Vector2i(256, 320), "transparent": true, "layers": layers}


func _armor() -> void:
	## The shop's other project: a whole armoured figure on a service base by the
	## north wall, and its spare plates laid out where they are worked on — a
	## helmet on the bench, the chest plate on the shelf under it, a gauntlet on
	## the electronics desk, the other boot on the floor. Red and gold over dark
	## alloy; an homage in the reference palette and deliberately unbranded, and
	## every piece is individually pickable with the mouse.
	var figure: Node3D = _place("armor_figure", Vector3(-1.6, 0.0, -4.55), Vector3(0.0, 0.35, 0.0), {})
	_station(figure, Station.Kind.SIGN, Vector3(0.0, 1.0, 0.12), {
		"area": "assembly", "title": "The shop's armour",
		"desc": "A whole armoured figure on a service base, core lens and eye slits lit — red plates over gold over dark alloy. The shop's own homage build, made here, not a film prop; the core is a cold-cathode tube out of a dead scanner.",
		"spec": [["height", "1.77 m"], ["palette", "red over gold over alloy"], ["state", "standing test only"]],
		"sfx": "metal_thunk", "distance": 3.4,
	})
	# raised 6 cm: the jaw used to sink into the bench top's slab
	var helmet: Node3D = _place("armor_helmet", Vector3(-3.72, 1.02, 2.55), Vector3(0.0, 0.6, 0.0), {})
	_station(helmet, Station.Kind.SIGN, Vector3(0.0, 0.14, 0.0), {
		"area": "mechanical", "title": "Spare helmet",
		"desc": "The figure's spare head, parked on the bench between jobs. The eye slits are lit even off the stand — a passive tube, no switch.",
		"spec": [["shell", "red plate over alloy"], ["faceplate", "brushed gold"], ["state", "spare"]],
		"sfx": "metal_thunk", "distance": 2.2,
	})
	var chest: Node3D = _place("armor_chest_plate", Vector3(-3.85, 0.29, 1.6), Vector3(0.0, -0.3, 0.0), {})
	_station(chest, Station.Kind.SIGN, Vector3(0.0, 0.18, 0.0), {
		"area": "mechanical", "title": "Spare chest plate",
		"desc": "A spare chest plate on the bench's lower shelf, core lens fitted and cold. The band across the top is the same gold as the figure's.",
		"spec": [["lens", "cold-cathode, unlit"], ["plates", "rolled steel, shop-painted"], ["state", "spare"]],
		"sfx": "metal_thunk", "distance": 2.2,
	})
	var gauntlet: Node3D = _place("armor_gauntlet", Vector3(-3.86, 0.70, -4.55), Vector3(0.0, 0.35, 0.0), {})
	_station(gauntlet, Station.Kind.SIGN, Vector3(0.0, 0.18, 0.0), {
		"area": "store", "title": "Spare gauntlet",
		"desc": "A forearm gauntlet up on the store shelf, gold knuckle up, the wrist slit glowing faintly. Somebody has been measuring it against the wrist jig.",
		"spec": [["shell", "red over alloy"], ["knuckle", "gold"], ["state", "spare"]],
		"sfx": "metal_tink", "distance": 2.0,
	})
	var boot: Node3D = _place("armor_boot", Vector3(-0.9, 0.0, -4.25), Vector3(0.0, 1.2, 0.0), {})
	_station(boot, Station.Kind.SIGN, Vector3(0.0, 0.1, 0.0), {
		"area": "assembly", "title": "Spare boot",
		"desc": "The other boot, left where it was kicked off after the last fitting. Gold toe, red shell, a dark sole that has seen the yard.",
		"spec": [["toe", "gold"], ["sole", "dark compound"], ["state", "spare"]],
		"sfx": "metal_tink", "distance": 2.0,
	})


func _bangladesh_map_spec() -> Dictionary:
	## A sketch map of Bangladesh for the entrance wall: the outline traced from
	## the country's familiar shape — the north border stepping down from the
	## Rangpur high corner to the Sylhet wedge, the Tripura notch, the Chittagong
	## hills running down to Teknaf, the delta and the estuary — with the four great
	## rivers, the main towns and the sea lines under the coast. Drawn through the
	## same SignCanvas bake as every other sign. It is deliberately a hand-drawing:
	## the station text is honest that it is a line sketch, not survey data.
	var ink: String = "#2f2b26"
	var land: String = "#b3c48e"
	var land_edge: String = "#5c6b45"
	var paper: String = "#efe8d3"
	var river: String = "#4f86ad"
	var sea: String = "#8fb4c9"
	var coast: Array = [
		Vector2(98, 101), Vector2(130, 104), Vector2(165, 115), Vector2(183, 123),
		Vector2(196, 155), Vector2(204, 190), Vector2(216, 208), Vector2(226, 214),
		Vector2(240, 206), Vector2(252, 205), Vector2(270, 208), Vector2(284, 208),
		Vector2(298, 210), Vector2(318, 212), Vector2(335, 218), Vector2(352, 224),
		Vector2(360, 240), Vector2(362, 258), Vector2(356, 274), Vector2(348, 288),
		Vector2(334, 302), Vector2(318, 320), Vector2(302, 338), Vector2(294, 352),
		Vector2(290, 366), Vector2(296, 380), Vector2(312, 396), Vector2(330, 404),
		Vector2(352, 414), Vector2(366, 428), Vector2(368, 446), Vector2(362, 466),
		Vector2(354, 486), Vector2(350, 506), Vector2(350, 524), Vector2(350, 540),
		Vector2(346, 522), Vector2(340, 504), Vector2(334, 486), Vector2(328, 468),
		Vector2(322, 450), Vector2(318, 436), Vector2(312, 428), Vector2(304, 432),
		Vector2(296, 440), Vector2(288, 448), Vector2(280, 454), Vector2(272, 448),
		Vector2(266, 436), Vector2(262, 422), Vector2(258, 408), Vector2(254, 394),
		Vector2(250, 384), Vector2(245, 384), Vector2(240, 392), Vector2(234, 400),
		Vector2(228, 410), Vector2(222, 418), Vector2(214, 428), Vector2(206, 438),
		Vector2(196, 448), Vector2(188, 456), Vector2(178, 462), Vector2(160, 466),
		Vector2(146, 468), Vector2(134, 462), Vector2(130, 448), Vector2(130, 430),
		Vector2(132, 410), Vector2(134, 392), Vector2(130, 372), Vector2(128, 352),
		Vector2(126, 332), Vector2(122, 316), Vector2(112, 298), Vector2(104, 284),
		Vector2(94, 268), Vector2(86, 252), Vector2(81, 240), Vector2(85, 226),
		Vector2(90, 208), Vector2(93, 190), Vector2(94, 172), Vector2(96, 158),
		Vector2(94, 142), Vector2(94, 126), Vector2(98, 110),
	]
	var layers: Array = [
		{"type": "grid", "pos": Vector2(60, 96), "sz": Vector2(360, 464), "step": 50.0, "color": "#e0d6ba"},
		{"type": "poly", "points": coast, "color": land, "filled": true},
		{"type": "poly", "points": coast, "color": land_edge, "filled": false, "width": 2.2},
		# the sea, hinted with coast-parallel lines under the delta
		{"type": "line", "from": Vector2(150, 500), "to": Vector2(220, 512), "color": sea, "width": 2.0},
		{"type": "line", "from": Vector2(180, 528), "to": Vector2(250, 540), "color": sea, "width": 2.0},
		{"type": "line", "from": Vector2(240, 506), "to": Vector2(268, 546), "color": sea, "width": 2.0},
		{"type": "text", "name": "SEA", "pos": Vector2(52, 552), "size": 17, "color": sea, "text": "বঙ্গোপসাগর", "font": "bangla"},
	]
	var rivers: Array = [
		# যমুনা, from the Kurigram entry south to the Padma confluence
		[Vector2(183, 130), Vector2(190, 165), Vector2(196, 205), Vector2(200, 245), Vector2(196, 280), Vector2(185, 305), Vector2(177, 316)],
		# পদ্মা, entering at Chapainawabganj, running south-east
		[Vector2(84, 254), Vector2(105, 268), Vector2(130, 286), Vector2(155, 304), Vector2(177, 316)],
		# the combined Padma from the confluence to the Chandpur meeting with the Meghna
		[Vector2(177, 316), Vector2(205, 338), Vector2(228, 352), Vector2(244, 361)],
		# মেঘনা, from the Sylhet hills down into the estuary inlet
		[Vector2(338, 236), Vector2(322, 254), Vector2(303, 272), Vector2(285, 290), Vector2(268, 300), Vector2(257, 322), Vector2(249, 344), Vector2(245, 360), Vector2(247, 372), Vector2(250, 382)],
		# সুরমা, the short upper reach by Sylhet town
		[Vector2(352, 230), Vector2(343, 242), Vector2(332, 250), Vector2(320, 257)],
		# কর্ণফুলী, the short Chattogram river
		[Vector2(334, 406), Vector2(326, 420), Vector2(320, 432)],
	]
	for chain: Array in rivers:
		for i: int in range(chain.size() - 1):
			layers.append({"type": "line", "from": chain[i], "to": chain[i + 1], "color": river, "width": 2.4})
	# towns: dot and name, and the capital gets the bigger dot
	var towns: Array = [
		[Vector2(228, 317), "ঢাকা", 17, 4.5],
		[Vector2(318, 427), "চট্টগ্রাম", 15, 3.2],
		[Vector2(322, 233), "সিলেট", 15, 3.2],
		[Vector2(174, 391), "খুলনা", 15, 3.2],
		[Vector2(113, 273), "রাজশাহী", 14, 3.0],
		[Vector2(226, 400), "বরিশাল", 14, 3.0],
		[Vector2(155, 168), "রংপুর", 14, 3.0],
		[Vector2(228, 244), "ময়মনসিংহ", 13, 2.8],
	]
	for t: Array in towns:
		layers.append({"type": "circle", "center": t[0], "radius": t[3], "color": ink, "filled": true})
		var lp: Vector2 = (t[0] as Vector2) + Vector2(7.0, -9.0)
		if String(t[1]) == "বরিশাল":
			lp = (t[0] as Vector2) + Vector2(-64.0, -9.0)
		layers.append({"type": "text", "name": "town_%s" % String(t[1]), "pos": lp, "size": t[2], "color": ink, "text": t[1], "font": "bangla"})
	# title, subtitle, compass, scale
	layers.append({"type": "text", "name": "T", "pos": Vector2(40, 22), "size": 44, "width": 400, "align": "center", "color": ink, "text": "বাংলাদেশ", "font": "bangla"})
	layers.append({"type": "text", "name": "S", "pos": Vector2(40, 70), "size": 14, "width": 400, "align": "center", "color": "#7a7263", "text": "SKETCH MAP  ·  হাতে আঁকা", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(444, 96), "to": Vector2(444, 66), "color": ink, "width": 2.0})
	layers.append({"type": "poly", "points": [Vector2(444, 56), Vector2(439, 70), Vector2(449, 70)], "color": ink, "filled": true})
	layers.append({"type": "text", "name": "N", "pos": Vector2(436, 98), "size": 14, "color": ink, "text": "N", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(310, 580), "to": Vector2(420, 580), "color": ink, "width": 3.0})
	layers.append({"type": "line", "from": Vector2(365, 574), "to": Vector2(365, 586), "color": ink, "width": 2.0})
	layers.append({"type": "text", "name": "SC", "pos": Vector2(302, 560), "size": 12, "color": "#7a7263", "text": "≈ 100 km", "font": "mono"})
	return {"size": Vector2i(480, 600), "transparent": false, "bg": paper, "border": {"color": "#8a7f66", "width": 3.0}, "layers": layers}


func _sylhet_map_spec() -> Dictionary:
	## A sketch map of the Sylhet division for the wall beside the door: the four
	## districts, their lines, the city and the Surma and the Kushiyara. Same
	## honesty as the country map — a hand drawing, said so in its station text.
	var ink: String = "#2f2b26"
	var land: String = "#bccd9a"
	var edge: String = "#5c6b45"
	var paper: String = "#efe8d3"
	var river: String = "#4f86ad"
	var district: String = "#8a8067"
	var border: Array = [
		Vector2(96, 104), Vector2(150, 84), Vector2(216, 88), Vector2(270, 74),
		Vector2(330, 66), Vector2(380, 88), Vector2(414, 124), Vector2(420, 160),
		Vector2(396, 196), Vector2(402, 232), Vector2(376, 262), Vector2(342, 282),
		Vector2(308, 292), Vector2(282, 318), Vector2(252, 352), Vector2(214, 374),
		Vector2(170, 380), Vector2(128, 362), Vector2(92, 326), Vector2(70, 282),
		Vector2(62, 230), Vector2(70, 176), Vector2(78, 130),
	]
	var layers: Array = [
		{"type": "grid", "pos": Vector2(48, 96), "sz": Vector2(384, 292), "step": 48.0, "color": "#e0d6ba"},
		{"type": "poly", "points": border, "color": land, "filled": true},
		{"type": "poly", "points": border, "color": edge, "filled": false, "width": 2.2},
	]
	var inner: Array = [
		[Vector2(206, 86), Vector2(198, 150), Vector2(192, 220), Vector2(188, 292), Vector2(176, 366)],
		[Vector2(318, 176), Vector2(306, 216), Vector2(296, 258), Vector2(284, 316)],
		[Vector2(284, 316), Vector2(240, 344), Vector2(206, 362)],
	]
	for chain: Array in inner:
		for i: int in range(chain.size() - 1):
			layers.append({"type": "line", "from": chain[i], "to": chain[i + 1], "color": district, "width": 1.4})
	var rivers: Array = [
		[Vector2(404, 148), Vector2(372, 168), Vector2(340, 182), Vector2(308, 196), Vector2(276, 210), Vector2(240, 220), Vector2(212, 226)],
		[Vector2(408, 224), Vector2(380, 238), Vector2(350, 250), Vector2(318, 258), Vector2(286, 262), Vector2(252, 262), Vector2(220, 250)],
	]
	for chain: Array in rivers:
		for i: int in range(chain.size() - 1):
			layers.append({"type": "line", "from": chain[i], "to": chain[i + 1], "color": river, "width": 2.6})
	var labels: Array = [
		[Vector2(120, 190), "সুনামগঞ্জ", 18],
		[Vector2(300, 148), "সিলেট", 20],
		[Vector2(322, 306), "মৌলভীবাজার", 16],
		[Vector2(150, 312), "হবিগঞ্জ", 18],
	]
	for l: Array in labels:
		layers.append({"type": "text", "name": "dist_%s" % String(l[1]), "pos": (l[0] as Vector2) - Vector2(60.0, 12.0), "size": l[2], "width": 120, "align": "center", "color": ink, "text": l[1], "font": "bangla"})
	layers.append({"type": "circle", "center": Vector2(296, 196), "radius": 4.5, "color": ink, "filled": true})
	layers.append({"type": "text", "name": "CITY", "pos": Vector2(240, 222), "size": 12, "color": "#6f6757", "text": "সিলেট শহর", "font": "bangla"})
	layers.append({"type": "text", "name": "T", "pos": Vector2(40, 18), "size": 40, "width": 400, "align": "center", "color": ink, "text": "সিলেট", "font": "bangla"})
	layers.append({"type": "text", "name": "S", "pos": Vector2(40, 62), "size": 14, "width": 400, "align": "center", "color": "#7a7263", "text": "SYLHET DIVISION  ·  চার জেলা", "font": "mono"})
	layers.append({"type": "line", "from": Vector2(444, 92), "to": Vector2(444, 64), "color": ink, "width": 2.0})
	layers.append({"type": "poly", "points": [Vector2(444, 54), Vector2(439, 68), Vector2(449, 68)], "color": ink, "filled": true})
	layers.append({"type": "text", "name": "N", "pos": Vector2(436, 94), "size": 13, "color": ink, "text": "N", "font": "mono"})
	return {"size": Vector2i(480, 420), "transparent": false, "bg": paper, "border": {"color": "#8a7f66", "width": 3.0}, "layers": layers}


func _photo_boards() -> void:
	# the notice wall's siblings: two more boards of community-licensed country
	# photographs, from the Openverse set — the assembly bay's west wall and the
	# north wall by the testing corner
	var wall_photos_b: Array = []
	var wall_photos_c: Array = []
	for n: int in range(21, 33):
		var p: String = "res://assets/textures/wall/wall_%02d.jpg" % n
		if not FileAccess.file_exists(ProjectSettings.globalize_path(p)):
			continue
		if wall_photos_b.size() < 6:
			wall_photos_b.append(p)
		else:
			wall_photos_c.append(p)
	var board_b: Node3D = _place("photo_wall", Vector3(-structure.half_w + 0.19, 1.0, -3.0), Vector3(0.0, PI * 0.5, 0.0), {"photos": wall_photos_b, "cols": 3})
	_station(board_b, Station.Kind.SIGN, Vector3(0.0, 0.4, 0.05), {
		"area": "assembly", "title": "Photo board — the streets",
		"desc": "Six more pictures of the country, pinned where the assembly bay can see them: streetside scenes, a Dhaka rickshaw, a tea counter, Keane Bridge with Ali Amjad's clock behind it, traffic, and a Sundarbans boat. Community-licensed; the credits are in the project's asset list.",
		"spec": [["photographs", "6, pinned"], ["licences", "CC0 / CC BY / CC BY-SA (see docs/ASSET_LICENSES.md)"], ["board", "plywood, 0.84 m"]],
		"sfx": "paper", "distance": 3.0,
	})
	var board_c: Node3D = _place("photo_wall", Vector3(2.25, 1.3, -structure.half_l + 0.19), Vector3.ZERO, {"photos": wall_photos_c, "cols": 2})
	_station(board_c, Station.Kind.SIGN, Vector3(0.0, 0.28, 0.05), {
		"area": "testing", "title": "Photo board — the working country",
		"desc": "Four more: a snake charmer, the Ashulia brickfields, a garment worker helped after Rana Plaza, and a farmer holding his rice. The testing corner's wall keeps the country's work in view.",
		"spec": [["photographs", "4, pinned"], ["licences", "CC0 / CC BY / CC BY-SA (see docs/ASSET_LICENSES.md)"], ["board", "plywood, 0.6 m"]],
		"sfx": "paper", "distance": 3.0,
	})


func _wayfinding() -> void:
	## The tidying pass: painted zone stencils on the concrete, so the shop reads
	## as five organised bays instead of one crowded room, placards over the two
	## storage shelves, and a directory board at the entrance. All baked through
	## the same SignCanvas as every other sign, at worn-paint roughness.
	var half_w: float = structure.half_w
	var half_l: float = structure.half_l
	# --- floor stencils: flat, top pointing north, so they read on the way in --
	var stencils: Array = [
		{"id": "zone_mech", "bn": "যন্ত্রকক্ষ", "en": "MECHANICAL", "pos": Vector3(-2.50, 0.008, 1.30), "w": 1.7},
		{"id": "zone_elec", "bn": "ইলেকট্রনিক্স", "en": "ELECTRONICS", "pos": Vector3(2.55, 0.008, 0.70), "w": 1.7},
		{"id": "zone_asm", "bn": "সংযোজন", "en": "ASSEMBLY", "pos": Vector3(-0.35, 0.008, 0.60), "w": 1.7},
		{"id": "zone_test", "bn": "পরীক্ষাগার", "en": "TEST & DIAGNOSTICS", "pos": Vector3(2.30, 0.008, -1.75), "w": 1.5},
	]
	for s: Dictionary in stencils:
		var w: float = float(s["w"])
		var stencil: MeshInstance3D = ShapeKit.plane(Vector2(w, w * 0.31), null, "ZoneStencil_" + String(s["id"]))
		stencil.position = s["pos"] as Vector3
		stencil.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		stencil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stencil)
		baker.apply_baked(stencil, _zone_stencil_spec(String(s["bn"]), String(s["en"])), String(s["id"]), 0.0, 0.9)
	# --- placards over the two storage shelves -------------------------------
	var placards: Array = [
		{"id": "placard_tools", "bn": "সরঞ্জাম", "en": "TOOLS & SPARES", "z": -1.15},
		{"id": "placard_store", "bn": "ভাণ্ডার", "en": "STORE", "z": -4.25},
	]
	for p: Dictionary in placards:
		var face: MeshInstance3D = ShapeKit.plane(Vector2(0.64, 0.22), null, "ShelfPlacard_" + String(p["id"]))
		face.position = Vector3(-half_w + 0.20, 2.48, float(p["z"]))
		face.rotation = Vector3(0.0, PI * 0.5, 0.0)
		add_child(face)
		baker.apply_baked(face, _placard_spec(String(p["bn"]), String(p["en"])), String(p["id"]), 0.0, 0.6)
	# --- the entrance directory, on the west pier beside the notice wall -----
	var directory: MeshInstance3D = ShapeKit.plane(Vector2(0.68, 0.86), null, "WorkshopDirectory")
	directory.position = Vector3(-3.72, 1.52, half_l - 0.21)
	directory.rotation = Vector3(0.0, PI, 0.0)
	add_child(directory)
	baker.apply_baked(directory, _directory_spec(), "directory", 0.0, 0.55)


func _zone_stencil_spec(bn: String, en: String) -> Dictionary:
	## A worn-paint floor stencil: big Bengali line over a small English one, no
	## board, no border — just paint on concrete. Transparent, so the slab's own
	## wear and stains read through it.
	return {
		"size": Vector2i(512, 160), "transparent": true,
		"layers": [
			{"type": "text", "name": "BN", "pos": Vector2(16, 8), "size": 66, "width": 480, "align": "center", "color": "#d3ccbd", "text": bn, "font": "bangla"},
			{"type": "text", "name": "EN", "pos": Vector2(16, 96), "size": 38, "width": 480, "align": "center", "color": "#b3ac9e", "text": en, "font": "mono"},
		],
	}


func _placard_spec(bn: String, en: String) -> Dictionary:
	## A dark board with a brass edge over a storage shelf.
	return {
		"size": Vector2i(256, 88), "transparent": false, "bg": "#2f3a34",
		"border": {"color": "#c9b98a", "width": 3.0},
		"layers": [
			{"type": "text", "name": "BN", "pos": Vector2(8, 6), "size": 34, "width": 240, "align": "center", "color": "#e8dfc8", "text": bn, "font": "bangla"},
			{"type": "text", "name": "EN", "pos": Vector2(8, 48), "size": 22, "width": 240, "align": "center", "color": "#c9b98a", "text": en, "font": "mono"},
		],
	}


func _directory_spec() -> Dictionary:
	## The entrance directory: a small plan of the shop, five named bays, north
	## at the top, the entrance at the bottom edge.
	var layers: Array = [
		{"type": "text", "name": "T", "pos": Vector2(8, 4), "size": 30, "width": 240, "align": "center", "color": "#efe7d4", "text": "কর্মশালার মানচিত্র", "font": "bangla"},
		{"type": "text", "name": "S", "pos": Vector2(8, 42), "size": 17, "width": 240, "align": "center", "color": "#c9b98a", "text": "WORKSHOP DIRECTORY", "font": "mono"},
		{"type": "rect", "pos": Vector2(20, 70), "sz": Vector2(216, 152), "color": "#c9b98a", "filled": false},
	]
	var bays: Array = [
		[Vector2(26, 76), Vector2(58, 52), "ভাণ্ডার", "STORE"],
		[Vector2(91, 76), Vector2(66, 52), "সংযোজন", "ASM"],
		[Vector2(164, 76), Vector2(66, 52), "পরীক্ষা", "TEST"],
		[Vector2(26, 146), Vector2(58, 68), "যন্ত্র", "MECH"],
		[Vector2(164, 146), Vector2(66, 68), "ইলেকট্র", "ELEC"],
	]
	for i: int in range(bays.size()):
		var b: Array = bays[i]
		var at: Vector2 = b[0] as Vector2
		var sz: Vector2 = b[1] as Vector2
		layers.append({"type": "rect", "pos": at, "sz": sz, "color": "#3a4a44", "filled": true})
		layers.append({"type": "rect", "pos": at, "sz": sz, "color": "#c9b98a", "filled": false})
		layers.append({"type": "text", "name": "B%d" % i, "pos": at + Vector2(0, 6), "size": 15, "width": int(sz.x), "align": "center", "color": "#e8dfc8", "text": String(b[2]), "font": "bangla"})
		layers.append({"type": "text", "name": "E%d" % i, "pos": at + Vector2(0, 28), "size": 11, "width": int(sz.x), "align": "center", "color": "#b9b2a4", "text": String(b[3]), "font": "mono"})
	layers.append({"type": "text", "name": "G", "pos": Vector2(20, 226), "size": 13, "width": 216, "align": "center", "color": "#9a9384", "text": "প্রবেশপথ · ENTRANCE", "font": "bangla"})
	return {"size": Vector2i(256, 320), "transparent": false, "bg": "#232823", "border": {"color": "#c9b98a", "width": 3.0}, "layers": layers}


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
	# the always-on bulbs, wired ahead of the switchboard to the incoming line: the
	# room is never dark, even before the player finds the main switch. Three hang
	# in this room (walk lane, mechanical bench, electronics bench); the testing
	# corner's and the store's are built by their own areas. See _always_on_bulb().
	_always_on_bulb(Vector3(0.0, structure.height - 0.25, 2.6))
	_always_on_bulb(Vector3(-2.4, structure.height - 0.22, 2.4), 0.55, 1.7, 7.0)
	_always_on_bulb(Vector3(2.0, structure.height - 0.25, 0.1))
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
	_place("towel_hanging", Vector3(-0.5, 2.92, 2.16), Vector3(0.0, 0.2, 0.0), {"length": 0.62})
	_place("towel_hanging", Vector3(1.3, 2.9, 2.28), Vector3(0.0, -0.3, 0.0), {"length": 0.5})
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
