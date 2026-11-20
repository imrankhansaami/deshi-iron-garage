class_name PropFactory
extends RefCounted
## The workshop object catalogue.
##
## Every prop in the garage is generated here from ShapeKit solids. Nothing is
## imported, so the whole asset set is reproducible from code and licence-free.
##
## The catalogue is organised by the five areas of the brief and split across two
## registers:
##   * MECHANICAL / ELECTRONICS / EVERYDAY / SCRAP  -> "World A", the real
##     Bangladeshi workshop vocabulary taken from the reference photographs
##     (motorcycle engine blocks, rickshaw parts, IPS batteries, tea glasses,
##     hanging tools, sack cloth, wall calendars).
##   * ASSEMBLY / DIAGNOSTIC -> "World B", the futuristic hardware, which is
##     deliberately built out of the same World A parts so it reads as something
##     the inventor could actually have made.
##
## Each generator returns a Node3D whose children are named, so interactions,
## animation targets and the benchmark harness can address sub-parts without
## the factory having to know about them.

const TAU_P: float = 6.283185307179586

var ML: MaterialLibrarySingleton
var _rng: RandomNumberGenerator
var built_counts: Dictionary = {}
var props_built: int = 0
## Extra generators contributed by the object families in scripts/procedural/
## props_*.gd. Registered here so the catalogue stays one dispatch table while
## the implementations stay in files sized for review.
var generators: Dictionary = {}


func _init(material_library: MaterialLibrarySingleton, seed_value: int = 1337) -> void:
	ML = material_library
	_rng = NoiseTools.rng(seed_value)
	MechProps.register(self)
	ElecProps.register(self)
	DailyProps.register(self)
	ProtoProps.register(self)


func rand() -> RandomNumberGenerator:
	return _rng


func catalogue() -> Array:
	var names: Array = []
	for k: String in _LOCAL_KINDS:
		names.append(k)
	for k: String in generators:
		names.append(k)
	names.sort()
	return names


const _LOCAL_KINDS: Array[String] = [
	"workbench", "bench_pegboard", "shelf_unit", "bamboo_rack", "wooden_stool",
	"plastic_chair", "storage_box", "crate_stack", "scrap_bin", "cot_bed",
	"desk_electronics", "spanner", "screwdriver", "pliers", "hammer", "hacksaw",
	"pipe_wrench", "adjustable_wrench", "tyre_lever", "chisel", "tape_measure",
	"spirit_level", "file_metal", "bolt", "bolt_cluster", "washer_pile", "nail_bag",
	"vice", "grindstone", "welding_mask", "welding_rod", "oil_can", "funnel",
	"brush_cup",
]


func _count(kind: String) -> void:
	props_built += 1
	built_counts[kind] = int(built_counts.get(kind, 0)) + 1


# ===========================================================================
# Dispatcher
# ===========================================================================

func build(kind: String, opts: Dictionary = {}) -> Node3D:
	var node: Node3D = _generate(kind, opts)
	if node == null:
		push_warning("PropFactory: unknown prop '%s'" % kind)
		node = fallback_crate(opts)
	node.set_meta("prop_kind", kind)
	_count(kind)
	return node


func _generate(kind: String, opts: Dictionary) -> Node3D:
	# Aliases: the object pools and the dressing pass use the names a workshop
	## would use, the catalogue uses the structural names. Resolved in one place
	## so a missing alias is a lookup miss rather than a silent fallback crate.
	match kind:
		"radio":
			return _generate("transistor_radio", opts)
		"wall_socket", "socket":
			return _generate("socket_wall", opts)
		"wall_switch":
			return _generate("switch_wall", opts)
		"chain_link", "bicycle_chain_link":
			# Dictionary.merge() mutates in place and returns void, so the alias
			## options are built explicitly rather than chained
			var chain_opts: Dictionary = opts.duplicate()
			if not chain_opts.has("links"):
				chain_opts["links"] = 6
			return _generate("bicycle_chain", chain_opts)
		"hacksaw_frame":
			return _generate("hacksaw", opts)
		"fuse_box", "distribution_board":
			return _generate("switchboard", opts)
		"led":
			return _generate("led_cluster", opts)
		"battery":
			return _generate("ups_battery", opts)
		"monitor":
			return _generate("lcd_monitor", opts)
		"fan":
			return _generate("pedestal_fan", opts)
		"tube":
			return _generate("fluorescent_battlement", opts)
		"ladder":
			return _generate("bamboo_rack", opts)
		"roof_antenna", "antenna":
			return _generate("antenna_roof", opts)
		"bucket":
			return _generate("tubewell_bucket", opts)
		"stool":
			return _generate("wooden_stool", opts)
		"chair":
			return _generate("plastic_chair", opts)
	match kind:
		# --- furniture and structures ---------------------------------
		"workbench":
			return workbench(opts)
		"bench_pegboard":
			return pegboard(opts)
		"shelf_unit":
			return shelf_unit(opts)
		"bamboo_rack":
			return bamboo_rack(opts)
		"wooden_stool":
			return wooden_stool(opts)
		"plastic_chair":
			return plastic_chair(opts)
		"storage_box":
			return storage_box(opts)
		"crate_stack":
			return crate_stack(opts)
		"scrap_bin":
			return scrap_bin(opts)
		"cot_bed":
			return cot_bed(opts)
		"desk_electronics":
			return desk_electronics(opts)
		# --- hand tools -----------------------------------------------
		"spanner":
			return spanner(opts)
		"screwdriver":
			return screwdriver(opts)
		"pliers":
			return pliers(opts)
		"hammer":
			return hammer(opts)
		"hacksaw":
			return hacksaw(opts)
		"pipe_wrench":
			return pipe_wrench(opts)
		"adjustable_wrench":
			return adjustable_wrench(opts)
		"tyre_lever":
			return tyre_lever(opts)
		"chisel":
			return chisel(opts)
		"tape_measure":
			return tape_measure(opts)
		"spirit_level":
			return spirit_level(opts)
		"file_metal":
			return file_metal(opts)
		"bolt":
			return ShapeKit.bolt(float(opts.get("d", 0.012)), float(opts.get("l", 0.03)), ML.steel(), "Bolt")
		"bolt_cluster":
			return bolt_cluster(opts)
		"washer_pile":
			return washer_pile(opts)
		"nail_bag":
			return nail_bag(opts)
		"vice":
			return bench_vice(opts)
		"grindstone":
			return grindstone(opts)
		"welding_mask":
			return welding_mask(opts)
		"welding_rod":
			return welding_rod(opts)
		"oil_can":
			return oil_can(opts)
		"funnel":
			return funnel(opts)
		"brush_cup":
			return brush_cup(opts)
		_:
			if generators.has(kind):
				var fn: Callable = generators[kind]
				return fn.call(self, opts)
			return null


## Anything unimplemented or missing from a family module still has to produce
## geometry, or a whole area of the garage would silently vanish.
func fallback_crate(opts: Dictionary) -> Node3D:
	var s: float = float(opts.get("size", 0.25))
	var root := Node3D.new()
	root.name = "FallbackProp"
	root.add_child(ShapeKit.box(Vector3(s, s * 0.8, s * 0.7), ML.plastic_faded(), "Body"))
	(root.get_child(0) as MeshInstance3D).position = Vector3(0.0, s * 0.4, 0.0)
	return root


# ===========================================================================
# Furniture and structures
# ===========================================================================

func workbench(opts: Dictionary) -> Node3D:
	## The heavy wooden bench from the reference photos: a thick scarred top, four
	## chunky legs, a lower shelf used for storage, and a tool rail at the back.
	var w: float = float(opts.get("w", 2.6))
	var d: float = float(opts.get("d", 0.85))
	var h: float = float(opts.get("h", 0.95))
	var t: float = float(opts.get("thickness", 0.075))
	var root := Node3D.new()
	root.name = String(opts.get("name", "Workbench"))
	var wood: StandardMaterial3D = ML.teak(2.0)
	var top: MeshInstance3D = ShapeKit.box(Vector3(w, t, d), wood, "Top")
	top.position = Vector3(0.0, h, 0.0)
	root.add_child(top)
	# plank seams, because a bench top this wide is three boards, not one
	for i: int in range(2):
		var seam: MeshInstance3D = ShapeKit.box(Vector3(w, t * 0.14, 0.012), ML.rust(), "Seam%d" % i)
		seam.position = Vector3(0.0, h + t * 0.5, -d * 0.28 + d * 0.56 * float(i))
		root.add_child(seam)
	var leg_wood: StandardMaterial3D = ML.teak(1.0)
	for sx: int in range(2):
		for sz: int in range(2):
			var leg: MeshInstance3D = ShapeKit.box(Vector3(0.09, h, 0.09), leg_wood, "Leg%d%d" % [sx, sz])
			leg.position = Vector3(
				(w * 0.5 - 0.1) * (1.0 if sx == 0 else -1.0),
				h * 0.5,
				(d * 0.5 - 0.09) * (1.0 if sz == 0 else -1.0),
			)
			root.add_child(leg)
			var brace: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.05, d - 0.2), leg_wood, "Brace%d%d" % [sx, sz])
			brace.position = Vector3(leg.position.x, h * 0.28, 0.0)
			root.add_child(brace)
	var shelf: MeshInstance3D = ShapeKit.box(Vector3(w - 0.24, 0.035, d - 0.24), ML.plywood(), "Shelf")
	shelf.position = Vector3(0.0, h * 0.3, 0.0)
	root.add_child(shelf)
	var rail: MeshInstance3D = ShapeKit.cyl(0.02, w - 0.3, ML.steel(), 10, Vector3i(1, 0, 0), "ToolRail")
	rail.position = Vector3(0.0, h + 0.42, -d * 0.5 + 0.03)
	root.add_child(rail)
	for i: int in range(2):
		var post: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.45, 0.05), leg_wood, "RailPost%d" % i)
		post.position = Vector3((w * 0.5 - 0.12) * (1.0 if i == 0 else -1.0), h + 0.22, -d * 0.5 + 0.05)
		root.add_child(post)
	root.add_child(ShapeKit.col_box(Vector3(w, h + t, d)))
	var body := StaticBody3D.new()
	body.name = "BenchBody"
	root.add_child(body)
	return root


func pegboard(opts: Dictionary) -> Node3D:
	## The perforated hardboard behind the bench that tools hang on. The holes are
	## real geometry in the texture, not decals, so the pattern survives any zoom.
	var w: float = float(opts.get("w", 2.4))
	var h: float = float(opts.get("h", 1.1))
	var root := Node3D.new()
	root.name = "Pegboard"
	var board: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.018), ML.plywood(), "Board")
	board.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(board)
	var hook_mat: StandardMaterial3D = ML.steel_dark()
	var cols: int = int(w / 0.16)
	var rows: int = int(h / 0.16)
	for r: int in range(rows):
		for c: int in range(cols):
			if _rng.randf() > 0.34:
				continue
			var hook: MeshInstance3D = ShapeKit.cyl(0.006, 0.075, hook_mat, 6, Vector3i(0, 0, 1), "Hook")
			hook.position = Vector3(-w * 0.5 + 0.1 + float(c) * 0.16, 0.12 + float(r) * 0.16, 0.03)
			hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(hook)
	return root


func shelf_unit(opts: Dictionary) -> Node3D:
	## Wooden/bamboo shelving against a wall, the main vertical storage in a
	## Bangladeshi repair shop.
	var w: float = float(opts.get("w", 1.9))
	var h: float = float(opts.get("h", 2.3))
	var d: float = float(opts.get("d", 0.42))
	var levels: int = clampi(int(opts.get("levels", 5)), 2, 9)
	var root := Node3D.new()
	root.name = String(opts.get("name", "ShelfUnit"))
	var frame_mat: StandardMaterial3D = ML.teak(1.0) if bool(opts.get("wood", true)) else ML.steel_dark()
	for sx: int in range(2):
		for sz: int in range(2):
			var upright: MeshInstance3D = ShapeKit.box(Vector3(0.07, h, 0.07), frame_mat, "Upright")
			upright.position = Vector3((w * 0.5 - 0.04) * (1.0 if sx == 0 else -1.0), h * 0.5, (d * 0.5 - 0.04) * (1.0 if sz == 0 else -1.0))
			root.add_child(upright)
	for i: int in range(levels):
		var y: float = 0.18 + float(i) * (h - 0.24) / float(levels - 1)
		var plank: MeshInstance3D = ShapeKit.box(Vector3(w, 0.028, d), ML.plywood(), "Level%d" % i)
		plank.position = Vector3(0.0, y, 0.0)
		root.add_child(plank)
		var lip: MeshInstance3D = ShapeKit.box(Vector3(w, 0.05, 0.02), frame_mat, "Lip%d" % i)
		lip.position = Vector3(0.0, y + 0.03, d * 0.5)
		root.add_child(lip)
	var back: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.014), ML.plywood(), "Back")
	back.position = Vector3(0.0, h * 0.5, -d * 0.5)
	root.add_child(back)
	root.add_child(ShapeKit.col_box(Vector3(w, h, d)))
	return root


func bamboo_rack(opts: Dictionary) -> Node3D:
	var h: float = float(opts.get("h", 2.2))
	var w: float = float(opts.get("w", 1.6))
	var root := Node3D.new()
	root.name = "BambooRack"
	var bam: StandardMaterial3D = ML.surface("bamboo")
	for i: int in range(4):
		var pole: MeshInstance3D = ShapeKit.cyl(0.028, h, bam, 10, Vector3i(0, 1, 0), "Pole")
		pole.position = Vector3((w * 0.5 - 0.05) * (1.0 if i % 2 == 0 else -1.0), h * 0.5, (0.2 - 0.05) * (1.0 if i < 2 else -1.0))
		root.add_child(pole)
	for j: int in range(4):
		var rail: MeshInstance3D = ShapeKit.cyl(0.022, w, bam, 8, Vector3i(1, 0, 0), "Rail")
		rail.position = Vector3(0.0, 0.35 + float(j) * (h - 0.5) / 3.0, 0.0)
		root.add_child(rail)
		# lashing cord at each joint
		var lash: MeshInstance3D = ShapeKit.torus(0.03, 0.006, ML.fabric(), 10, 5, "Lash")
		lash.position = Vector3(w * 0.5 - 0.05, 0.35 + float(j) * (h - 0.5) / 3.0, 0.15)
		lash.rotation = Vector3(0.0, PI * 0.5, 0.0)
		lash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(lash)
	return root


func wooden_stool(opts: Dictionary) -> Node3D:
	var h: float = float(opts.get("h", 0.46))
	var root := Node3D.new()
	root.name = "Stool"
	var seat: MeshInstance3D = ShapeKit.cyl(0.19, 0.045, ML.teak(), 14, Vector3i(0, 1, 0), "Seat")
	seat.position = Vector3(0.0, h, 0.0)
	root.add_child(seat)
	for i: int in range(4):
		var a: float = TAU_P * float(i) / 4.0 + 0.4
		var leg: MeshInstance3D = ShapeKit.cyl(0.022, h, ML.teak(), 8, Vector3i(0, 1, 0), "Leg")
		leg.position = Vector3(cos(a) * 0.13, h * 0.5, sin(a) * 0.13)
		leg.rotation = Vector3(sin(a) * 0.12, 0.0, -cos(a) * 0.12)
		root.add_child(leg)
	root.add_child(ShapeKit.col_cyl(0.2, h))
	return root


func plastic_chair(opts: Dictionary) -> Node3D:
	## The blue plastic chair that is in every shop in the country.
	var root := Node3D.new()
	root.name = "PlasticChair"
	var mat: StandardMaterial3D = ML.paint_blue(1.4)
	var seat: MeshInstance3D = ShapeKit.box(Vector3(0.42, 0.035, 0.42), mat, "Seat")
	seat.position = Vector3(0.0, 0.44, 0.0)
	seat.rotation.x = -0.04
	root.add_child(seat)
	var backrest: MeshInstance3D = ShapeKit.box(Vector3(0.42, 0.42, 0.03), mat, "Back")
	backrest.position = Vector3(0.0, 0.68, -0.2)
	backrest.rotation.x = 0.14
	root.add_child(backrest)
	# the two slots in the backrest every moulded chair has
	for i: int in range(2):
		var slot: MeshInstance3D = ShapeKit.box(Vector3(0.1, 0.05, 0.045), ML.plastic_black(), "Slot")
		slot.position = Vector3((0.11) * (1.0 if i == 0 else -1.0), 0.72, -0.2)
		slot.rotation.x = 0.14
		root.add_child(slot)
	for sx: int in range(2):
		for sz: int in range(2):
			var leg: MeshInstance3D = ShapeKit.box(Vector3(0.035, 0.44, 0.035), mat, "Leg")
			leg.position = Vector3(0.17 * (1.0 if sx == 0 else -1.0), 0.22, 0.17 * (1.0 if sz == 0 else -1.0))
			leg.rotation = Vector3(0.05 * (1.0 if sz == 0 else -1.0), 0.0, -0.05 * (1.0 if sx == 0 else -1.0))
			root.add_child(leg)
	root.add_child(ShapeKit.col_box(Vector3(0.45, 0.9, 0.45)))
	return root


func storage_box(opts: Dictionary) -> Node3D:
	## Local product carton: the printed tin/plastic boxes that hold spare parts.
	var w: float = float(opts.get("w", 0.34))
	var h: float = float(opts.get("h", 0.22))
	var d: float = float(opts.get("d", 0.24))
	var root := Node3D.new()
	root.name = "StorageBox"
	var body: MeshInstance3D = ShapeKit.box(Vector3(w, h, d), ML.paint_yellow(), "Body")
	body.position = Vector3(0.0, h * 0.5, 0.0)
	root.add_child(body)
	var lid: MeshInstance3D = ShapeKit.box(Vector3(w * 1.04, 0.03, d * 1.04), ML.plastic_faded(), "Lid")
	lid.position = Vector3(0.0, h + 0.015, 0.0)
	root.add_child(lid)
	var label: MeshInstance3D = ShapeKit.plane(Vector2(w * 0.8, h * 0.45), ML.paper(), "Label")
	label.position = Vector3(0.0, h * 0.55, d * 0.5 + 0.002)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(label)
	return root


func crate_stack(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CrateStack"
	var count: int = clampi(int(opts.get("count", 3)), 1, 6)
	for i: int in range(count):
		var s: float = 0.34 + _rng.randf_range(-0.05, 0.08)
		var b: Node3D = storage_box({"w": s, "h": s * 0.66, "d": s * 0.75, "name": "Crate%d" % i})
		b.position = Vector3(_rng.randf_range(-0.05, 0.05), _cum_h(i, s), _rng.randf_range(-0.05, 0.05))
		b.rotation.y = _rng.randf_range(-0.4, 0.4)
		root.add_child(b)
	return root


func _cum_h(index: int, size: float) -> float:
	var y: float = 0.0
	for i: int in range(index):
		y += size * 0.7
	return y


func scrap_bin(opts: Dictionary) -> Node3D:
	## The open steel skip the scrap parts live in — present in every workshop
	## photograph in the reference set.
	var w: float = float(opts.get("w", 0.9))
	var h: float = float(opts.get("h", 0.55))
	var root := Node3D.new()
	root.name = "ScrapBin"
	var mat: StandardMaterial3D = ML.rust()
	var floor_p: MeshInstance3D = ShapeKit.box(Vector3(w, 0.02, w), mat, "Floor")
	floor_p.position = Vector3(0.0, 0.01, 0.0)
	root.add_child(floor_p)
	for i: int in range(4):
		var a: float = float(i) * PI * 0.5
		var wall: MeshInstance3D = ShapeKit.box(Vector3(w, h, 0.02), mat, "Wall")
		wall.position = Vector3(sin(a) * w * 0.5, h * 0.5, cos(a) * w * 0.5)
		wall.rotation.y = a
		root.add_child(wall)
		# folded rim
		var rim: MeshInstance3D = ShapeKit.box(Vector3(w, 0.03, 0.05), ML.steel_dark(), "Rim")
		rim.position = wall.position + Vector3(0.0, h * 0.5, 0.0)
		rim.rotation.y = a
		root.add_child(rim)
	# heap of scrap inside
	var heap: MeshInstance3D = ShapeKit.sphere(w * 0.42, ML.rust(), 12, "Heap")
	heap.position = Vector3(0.0, h * 0.55, 0.0)
	heap.scale = Vector3(1.0, 0.5, 1.0)
	root.add_child(heap)
	for i: int in range(9):
		var shard: MeshInstance3D = ShapeKit.box(Vector3(_rng.randf_range(0.08, 0.24), 0.012, _rng.randf_range(0.08, 0.2)), ML.steel_dark(), "Shard")
		shard.position = Vector3(_rng.randf_range(-w * 0.3, w * 0.3), h * 0.6 + _rng.randf_range(-0.03, 0.1), _rng.randf_range(-w * 0.3, w * 0.3))
		shard.rotation = Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0, 3.14), _rng.randf_range(-0.6, 0.6))
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shard)
	root.add_child(ShapeKit.col_box(Vector3(w, h, w)))
	return root


func cot_bed(opts: Dictionary) -> Node3D:
	## The charpoi/cot the inventor naps on during long builds.
	var root := Node3D.new()
	root.name = "Cot"
	var w: float = 0.75
	var l: float = 1.9
	var h: float = 0.42
	var frame: StandardMaterial3D = ML.teak()
	for sx: int in range(2):
		var rail: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.06, l), frame, "Rail")
		rail.position = Vector3((w * 0.5) * (1.0 if sx == 0 else -1.0), h, 0.0)
		root.add_child(rail)
	for sz: int in range(2):
		var cross: MeshInstance3D = ShapeKit.box(Vector3(w, 0.06, 0.06), frame, "Cross")
		cross.position = Vector3(0.0, h, (l * 0.5 - 0.03) * (1.0 if sz == 0 else -1.0))
		root.add_child(cross)
	for sx: int in range(2):
		for sz: int in range(2):
			var leg: MeshInstance3D = ShapeKit.box(Vector3(0.055, h, 0.055), frame, "Leg")
			leg.position = Vector3((w * 0.5 - 0.03) * (1.0 if sx == 0 else -1.0), h * 0.5, (l * 0.5 - 0.03) * (1.0 if sz == 0 else -1.0))
			root.add_child(leg)
	# woven rope bed: two crossing sets of strands
	var rope: StandardMaterial3D = ML.gamcha()
	for i: int in range(14):
		var strand: MeshInstance3D = ShapeKit.box(Vector3(w - 0.1, 0.012, 0.02), rope, "StrandA")
		strand.position = Vector3(0.0, h + 0.03, -l * 0.45 + float(i) * l * 0.9 / 13.0)
		strand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(strand)
	for i: int in range(6):
		var strand2: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.012, l - 0.1), rope, "StrandB")
		strand2.position = Vector3(-w * 0.45 + float(i) * w * 0.9 / 5.0, h + 0.045, 0.0)
		strand2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(strand2)
	var blanket: MeshInstance3D = ShapeKit.box(Vector3(w * 0.8, 0.03, l * 0.5), ML.fabric(), "Blanket")
	blanket.position = Vector3(0.05, h + 0.06, l * 0.2)
	blanket.rotation = Vector3(0.02, 0.06, 0.01)
	root.add_child(blanket)
	root.add_child(ShapeKit.col_box(Vector3(w, h + 0.1, l)))
	return root


func desk_electronics(opts: Dictionary) -> Node3D:
	## The electronics bench: a lighter table with an anti-static mat, a raised
	## component tray and a cable duct at the back.
	var w: float = float(opts.get("w", 2.3))
	var d: float = float(opts.get("d", 0.75))
	var h: float = float(opts.get("h", 0.92))
	var root := Node3D.new()
	root.name = "ElectronicsDesk"
	var top: MeshInstance3D = ShapeKit.box(Vector3(w, 0.05, d), ML.plywood(), "Top")
	top.position = Vector3(0.0, h, 0.0)
	root.add_child(top)
	var mat: MeshInstance3D = ShapeKit.box(Vector3(w * 0.72, 0.006, d * 0.62), ML.rubber(), "Mat")
	mat.position = Vector3(-w * 0.08, h + 0.028, 0.0)
	root.add_child(mat)
	for sx: int in range(2):
		for sz: int in range(2):
			var leg: MeshInstance3D = ShapeKit.box(Vector3(0.06, h, 0.06), ML.steel_dark(), "Leg")
			leg.position = Vector3((w * 0.5 - 0.05) * (1.0 if sx == 0 else -1.0), h * 0.5, (d * 0.5 - 0.05) * (1.0 if sz == 0 else -1.0))
			root.add_child(leg)
	var tray: MeshInstance3D = ShapeKit.box(Vector3(w * 0.9, 0.05, 0.12), ML.plastic_faded(), "Tray")
	tray.position = Vector3(0.0, h + 0.05, -d * 0.42)
	root.add_child(tray)
	var duct: MeshInstance3D = ShapeKit.box(Vector3(w, 0.09, 0.07), ML.plastic_black(), "Duct")
	duct.position = Vector3(0.0, h - 0.12, -d * 0.5 + 0.04)
	root.add_child(duct)
	var drawer: MeshInstance3D = ShapeKit.box(Vector3(0.5, 0.22, d - 0.1), ML.plywood(), "Drawer")
	drawer.position = Vector3(w * 0.32, h - 0.16, 0.0)
	root.add_child(drawer)
	var knob: MeshInstance3D = ShapeKit.cyl(0.02, 0.03, ML.brass(), 8, Vector3i(0, 0, 1), "Knob")
	knob.position = Vector3(w * 0.32, h - 0.16, d * 0.5 - 0.04)
	root.add_child(knob)
	root.add_child(ShapeKit.col_box(Vector3(w, h, d)))
	return root


# ===========================================================================
# Hand tools
# ===========================================================================

func spanner(opts: Dictionary) -> Node3D:
	## Open-end + ring spanner, forged look.
	var l: float = float(opts.get("l", 0.24))
	var root := Node3D.new()
	root.name = "Spanner"
	var mat: StandardMaterial3D = ML.steel()
	var shaft: MeshInstance3D = ShapeKit.box(Vector3(l, 0.008, 0.022), mat, "Shaft")
	root.add_child(shaft)
	var open_jaw: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.009, 0.03), mat, "OpenJaw")
	open_jaw.position = Vector3(l * 0.5, 0.0, 0.0)
	root.add_child(open_jaw)
	var gap: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.012, 0.014), ML.plastic_black(), "Gap")
	gap.position = Vector3(l * 0.52, 0.0, 0.0)
	root.add_child(gap)
	var ring: MeshInstance3D = ShapeKit.torus(l * 0.11, l * 0.028, mat, 14, 6, "Ring")
	ring.position = Vector3(-l * 0.5, 0.0, 0.0)
	ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(ring)
	root.add_child(ShapeKit.col_box(Vector3(l, 0.014, 0.032)))
	return root


func screwdriver(opts: Dictionary) -> Node3D:
	var l: float = float(opts.get("l", 0.2))
	var root := Node3D.new()
	root.name = "Screwdriver"
	var handle: MeshInstance3D = ShapeKit.lathe(_screwdriver_profile(), 12, ML.plastic_red(), true, "Handle")
	handle.position = Vector3(0.0, 0.0, -l * 0.35)
	handle.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(handle)
	var shaft: MeshInstance3D = ShapeKit.cyl(0.005, l * 0.62, ML.chrome(), 8, Vector3i(0, 0, 1), "Shaft")
	shaft.position = Vector3(0.0, 0.0, l * 0.2)
	root.add_child(shaft)
	var tip: MeshInstance3D = ShapeKit.box(Vector3(0.002, 0.012, 0.02), ML.steel_dark(), "Tip")
	tip.position = Vector3(0.0, 0.0, l * 0.53)
	root.add_child(tip)
	return root


func _screwdriver_profile() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.011, 0.0), Vector2(0.014, 0.012),
		Vector2(0.016, 0.05), Vector2(0.015, 0.075), Vector2(0.011, 0.088),
		Vector2(0.006, 0.095), Vector2(0.0, 0.098),
	])


func pliers(opts: Dictionary) -> Node3D:
	var l: float = float(opts.get("l", 0.18))
	var root := Node3D.new()
	root.name = "Pliers"
	var mat: StandardMaterial3D = ML.steel_dark()
	for s: int in range(2):
		var sign: float = 1.0 if s == 0 else -1.0
		var jaw: MeshInstance3D = ShapeKit.box(Vector3(0.016, 0.055, 0.012), mat, "Jaw")
		jaw.position = Vector3(sign * 0.008, l * 0.35, 0.0)
		jaw.rotation.z = sign * 0.1
		root.add_child(jaw)
		var grip: MeshInstance3D = ShapeKit.box(Vector3(0.018, l * 0.5, 0.014), mat, "Grip")
		grip.position = Vector3(sign * 0.02, -l * 0.28, 0.0)
		grip.rotation.z = -sign * 0.09
		root.add_child(grip)
		var sleeve: MeshInstance3D = ShapeKit.box(Vector3(0.024, l * 0.34, 0.02), ML.plastic_red(), "Sleeve")
		sleeve.position = Vector3(sign * 0.026, -l * 0.36, 0.0)
		sleeve.rotation.z = -sign * 0.09
		root.add_child(sleeve)
	var pivot: MeshInstance3D = ShapeKit.cyl(0.009, 0.03, ML.chrome(), 8, Vector3i(0, 0, 1), "Pivot")
	pivot.position = Vector3(0.0, l * 0.05, 0.0)
	root.add_child(pivot)
	return root


func hammer(opts: Dictionary) -> Node3D:
	var l: float = float(opts.get("l", 0.3))
	var root := Node3D.new()
	root.name = "Hammer"
	var handle: MeshInstance3D = ShapeKit.lathe(_hammer_profile(l), 10, ML.teak(), true, "Handle")
	handle.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(handle)
	var head: MeshInstance3D = ShapeKit.cyl(0.019, 0.12, ML.cast_iron(), 12, Vector3i(1, 0, 0), "Head")
	head.position = Vector3(0.0, l * 0.48, 0.0)
	root.add_child(head)
	var claw: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.06, 0.02), ML.cast_iron(), "Claw")
	claw.position = Vector3(-0.06, l * 0.44, 0.0)
	claw.rotation.z = 0.5
	root.add_child(claw)
	var face: MeshInstance3D = ShapeKit.cyl(0.021, 0.012, ML.steel(), 12, Vector3i(1, 0, 0), "Face")
	face.position = Vector3(0.062, l * 0.48, 0.0)
	root.add_child(face)
	return root


func _hammer_profile(l: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.0, -l * 0.5), Vector2(0.014, -l * 0.5), Vector2(0.017, -l * 0.42),
		Vector2(0.013, -l * 0.1), Vector2(0.011, l * 0.3), Vector2(0.013, l * 0.44),
		Vector2(0.009, l * 0.5), Vector2(0.0, l * 0.5),
	])


func hacksaw(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Hacksaw"
	var frame_mat: StandardMaterial3D = ML.paint_blue()
	var bow: MeshInstance3D = ShapeKit.box(Vector3(0.5, 0.02, 0.018), frame_mat, "Bow")
	bow.position = Vector3(0.12, 0.06, 0.0)
	root.add_child(bow)
	var handle: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.09, 0.028), ML.plastic_black(), "Handle")
	handle.position = Vector3(-0.18, 0.0, 0.0)
	handle.rotation.z = -0.3
	root.add_child(handle)
	var tensioner: MeshInstance3D = ShapeKit.cyl(0.012, 0.05, ML.steel(), 8, Vector3i(0, 1, 0), "Tensioner")
	tensioner.position = Vector3(0.36, 0.06, 0.0)
	root.add_child(tensioner)
	var blade: MeshInstance3D = ShapeKit.box(Vector3(0.46, 0.008, 0.002), ML.chrome(), "Blade")
	blade.position = Vector3(0.12, -0.02, 0.0)
	root.add_child(blade)
	return root


func pipe_wrench(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "PipeWrench"
	var mat: StandardMaterial3D = ML.steel_dark()
	var upper: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.34, 0.016), mat, "Upper")
	upper.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(upper)
	var lower: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.3, 0.016), mat, "Lower")
	lower.position = Vector3(0.02, -0.12, 0.0)
	lower.rotation.z = 0.12
	root.add_child(lower)
	var jaw: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.06, 0.02), ML.cast_iron(), "Jaw")
	jaw.position = Vector3(-0.01, 0.29, 0.0)
	root.add_child(jaw)
	var knurl: MeshInstance3D = ShapeKit.cyl(0.016, 0.05, ML.brass(), 10, Vector3i(0, 0, 1), "Knurl")
	knurl.position = Vector3(0.01, 0.2, 0.0)
	root.add_child(knurl)
	return root


func adjustable_wrench(opts: Dictionary) -> Node3D:
	var l: float = float(opts.get("l", 0.26))
	var root := Node3D.new()
	root.name = "AdjustableWrench"
	var mat: StandardMaterial3D = ML.steel()
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.028, l, 0.014), mat, "Body")
	root.add_child(body)
	var head: MeshInstance3D = ShapeKit.box(Vector3(0.055, 0.07, 0.016), mat, "Head")
	head.position = Vector3(0.008, l * 0.5, 0.0)
	root.add_child(head)
	var worm: MeshInstance3D = ShapeKit.cyl(0.012, 0.04, ML.brass(), 10, Vector3i(0, 0, 1), "Worm")
	worm.position = Vector3(0.0, l * 0.42, 0.0)
	root.add_child(worm)
	var jaw: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.06, 0.014), mat, "Jaw")
	jaw.position = Vector3(-0.026, l * 0.5, 0.0)
	root.add_child(jaw)
	return root


func tyre_lever(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TyreLever"
	var lever: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.16, 0.006), ML.steel_dark(), "Lever")
	root.add_child(lever)
	var hook: MeshInstance3D = ShapeKit.box(Vector3(0.018, 0.03, 0.006), ML.steel_dark(), "Hook")
	hook.position = Vector3(0.0, 0.09, 0.006)
	hook.rotation.x = 0.6
	root.add_child(hook)
	return root


func chisel(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Chisel"
	var blade: MeshInstance3D = ShapeKit.box(Vector3(0.018, 0.11, 0.005), ML.steel(), "Blade")
	blade.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(blade)
	var edge: MeshInstance3D = ShapeKit.box(Vector3(0.022, 0.02, 0.003), ML.chrome(), "Edge")
	edge.position = Vector3(0.0, 0.115, 0.0)
	root.add_child(edge)
	var grip: MeshInstance3D = ShapeKit.cyl(0.016, 0.07, ML.plastic_red(), 10, Vector3i(0, 1, 0), "Grip")
	grip.position = Vector3(0.0, -0.03, 0.0)
	root.add_child(grip)
	return root


func tape_measure(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TapeMeasure"
	var case_b: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.065, 0.028), ML.paint_yellow(), "Case")
	root.add_child(case_b)
	var lock: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.015, 0.032), ML.plastic_black(), "Lock")
	lock.position = Vector3(0.02, -0.02, 0.0)
	root.add_child(lock)
	var tape: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.002, 0.012), ML.chrome(), "Tape")
	tape.position = Vector3(0.06, 0.02, 0.0)
	root.add_child(tape)
	return root


func spirit_level(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "SpiritLevel"
	var body: MeshInstance3D = ShapeKit.box(Vector3(0.4, 0.045, 0.03), ML.paint_green(), "Body")
	root.add_child(body)
	for i: int in range(3):
		var vial: MeshInstance3D = ShapeKit.cyl(0.011, 0.06, ML.glass_smoky(), 10, Vector3i(1, 0, 0), "Vial")
		vial.position = Vector3(-0.14 + float(i) * 0.14, 0.024, 0.0)
		root.add_child(vial)
	return root


func file_metal(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "File"
	var blade: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.24, 0.008), ML.steel_dark(), "Blade")
	blade.position = Vector3(0.0, 0.1, 0.0)
	root.add_child(blade)
	var tang: MeshInstance3D = ShapeKit.cyl(0.005, 0.04, ML.steel(), 6, Vector3i(0, 1, 0), "Tang")
	tang.position = Vector3(0.0, -0.04, 0.0)
	root.add_child(tang)
	var grip: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.016, 0.005), Vector2(0.019, 0.03), Vector2(0.014, 0.05), Vector2(0.0, 0.055),
	]), 10, ML.teak(), true, "Grip")
	grip.position = Vector3(0.0, -0.02, 0.0)
	grip.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	root.add_child(grip)
	return root


func bolt_cluster(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BoltCluster"
	var n: int = clampi(int(opts.get("n", 7)), 2, 20)
	var mat: StandardMaterial3D = ML.steel()
	for i: int in range(n):
		var b: Node3D = ShapeKit.bolt(_rng.randf_range(0.006, 0.014), _rng.randf_range(0.02, 0.06), mat, "Bolt")
		b.position = Vector3(_rng.randf_range(-0.07, 0.07), _rng.randf_range(0.0, 0.02), _rng.randf_range(-0.07, 0.07))
		b.rotation = Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(0, 3.14), _rng.randf_range(-0.5, 0.5))
		ShapeKit.set_cast(b, false)
		root.add_child(b)
	return root


func washer_pile(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WasherPile"
	var mat: StandardMaterial3D = ML.steel_dark()
	for i: int in range(11):
		var w: MeshInstance3D = ShapeKit.torus(_rng.randf_range(0.012, 0.02), 0.004, mat, 10, 5, "Washer")
		w.position = Vector3(_rng.randf_range(-0.03, 0.03), 0.004 + float(i) * 0.004, _rng.randf_range(-0.03, 0.03))
		w.rotation = Vector3(PI * 0.5 + _rng.randf_range(-0.2, 0.2), _rng.randf_range(0, 3.14), 0.0)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(w)
	return root


func nail_bag(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "NailBag"
	var bag: MeshInstance3D = ShapeKit.box(Vector3(0.11, 0.05, 0.08), ML.fabric(), "Bag")
	bag.position = Vector3(0.0, 0.025, 0.0)
	root.add_child(bag)
	for i: int in range(14):
		var nail: MeshInstance3D = ShapeKit.cyl(0.002, _rng.randf_range(0.03, 0.06), ML.steel_dark(), 5, Vector3i(0, 1, 0), "Nail")
		nail.position = Vector3(_rng.randf_range(-0.05, 0.05), 0.055, _rng.randf_range(-0.03, 0.03))
		nail.rotation = Vector3(_rng.randf_range(-1.2, 1.2), 0.0, _rng.randf_range(-1.2, 1.2))
		nail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(nail)
	return root


func bench_vice(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BenchVice"
	var cast: StandardMaterial3D = ML.cast_iron()
	var base: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.05, 0.12), cast, "Base")
	base.position = Vector3(0.0, 0.025, 0.0)
	root.add_child(base)
	var fixed: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.12, 0.1), cast, "FixedJaw")
	fixed.position = Vector3(-0.05, 0.11, 0.0)
	root.add_child(fixed)
	var movable: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.12, 0.1), cast, "MoveJaw")
	movable.position = Vector3(0.04, 0.11, 0.0)
	root.add_child(movable)
	var screw: MeshInstance3D = ShapeKit.cyl(0.012, 0.2, ML.steel(), 10, Vector3i(1, 0, 0), "Screw")
	screw.position = Vector3(0.06, 0.09, 0.0)
	root.add_child(screw)
	var handle: MeshInstance3D = ShapeKit.cyl(0.008, 0.14, ML.steel_dark(), 8, Vector3i(0, 0, 1), "Handle")
	handle.position = Vector3(0.16, 0.09, 0.0)
	root.add_child(handle)
	for i: int in range(2):
		var ball: MeshInstance3D = ShapeKit.sphere(0.014, ML.steel_dark(), 8, "Ball")
		ball.position = Vector3(0.16, 0.09, 0.07 * (1.0 if i == 0 else -1.0))
		root.add_child(ball)
	var pad: MeshInstance3D = ShapeKit.box(Vector3(0.008, 0.09, 0.09), ML.rubber(), "Pad")
	pad.position = Vector3(0.015, 0.11, 0.0)
	root.add_child(pad)
	return root


func grindstone(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Grindstone"
	var stone: MeshInstance3D = ShapeKit.cyl(0.16, 0.06, ML.surface("packed_earth"), 20, Vector3i(0, 0, 1), "Stone")
	stone.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(stone)
	var axle: MeshInstance3D = ShapeKit.cyl(0.014, 0.3, ML.steel(), 8, Vector3i(0, 0, 1), "Axle")
	axle.position = Vector3(0.0, 0.5, 0.0)
	root.add_child(axle)
	var motor: Node3D = _generate("electric_motor", {"scale": 0.7})
	motor.position = Vector3(0.0, 0.34, -0.22)
	root.add_child(motor)
	var belt: MeshInstance3D = ShapeKit.torus(0.14, 0.008, ML.rubber(), 16, 5, "Belt")
	belt.position = Vector3(0.0, 0.44, -0.11)
	belt.rotation = Vector3(0.3, 0.0, 0.0)
	root.add_child(belt)
	var stand: MeshInstance3D = ShapeKit.box(Vector3(0.3, 0.5, 0.24), ML.steel_dark(), "Stand")
	stand.position = Vector3(0.0, 0.25, -0.05)
	root.add_child(stand)
	var tray: MeshInstance3D = ShapeKit.box(Vector3(0.36, 0.04, 0.16), ML.steel(), "WaterTray")
	tray.position = Vector3(0.0, 0.32, 0.14)
	root.add_child(tray)
	root.add_child(ShapeKit.col_box(Vector3(0.4, 0.7, 0.4)))
	return root


func welding_mask(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WeldingMask"
	var shell: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.11, 0.005), Vector2(0.14, 0.06), Vector2(0.135, 0.16),
		Vector2(0.1, 0.22), Vector2(0.05, 0.25), Vector2(0.0, 0.26),
	]), 16, ML.paint_green(), false, "Shell")
	shell.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	root.add_child(shell)
	var glass: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.05, 0.004), ML.plastic_black(), "Glass")
	glass.position = Vector3(0.0, 0.14, 0.13)
	root.add_child(glass)
	var frame: MeshInstance3D = ShapeKit.box(Vector3(0.11, 0.07, 0.006), ML.steel_dark(), "Frame")
	frame.position = Vector3(0.0, 0.14, 0.124)
	root.add_child(frame)
	var band: MeshInstance3D = ShapeKit.torus(0.14, 0.01, ML.leather_like(), 16, 5, "Headband")
	band.position = Vector3(0.0, 0.16, -0.02)
	band.rotation = Vector3(0.4, 0.0, 0.0)
	root.add_child(band)
	return root


func welding_rod(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "WeldingRod"
	var holder: MeshInstance3D = ShapeKit.cyl(0.016, 0.14, ML.teak(), 10, Vector3i(0, 0, 1), "Holder")
	holder.position = Vector3(0.0, 0.0, -0.07)
	root.add_child(holder)
	var jaw: MeshInstance3D = ShapeKit.box(Vector3(0.012, 0.05, 0.06), ML.steel_dark(), "Jaw")
	jaw.position = Vector3(0.0, 0.0, 0.04)
	root.add_child(jaw)
	var rod: MeshInstance3D = ShapeKit.cyl(0.003, 0.3, ML.copper(), 6, Vector3i(0, 0, 1), "Rod")
	rod.position = Vector3(0.0, 0.0, 0.18)
	root.add_child(rod)
	var cable: MeshInstance3D = ShapeKit.hose(Vector3(0.0, 0.0, -0.14), Vector3(0.05, -0.1, -0.5), 0.008, 0.06, ML.cable_material(Color("#20140f")), "Lead")
	root.add_child(cable)
	return root


func oil_can(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "OilCan"
	var body: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.055, 0.02), Vector2(0.05, 0.11),
		Vector2(0.03, 0.14), Vector2(0.012, 0.16), Vector2(0.0, 0.165),
	]), 14, ML.paint_blue(), true, "Body")
	root.add_child(body)
	var spout: MeshInstance3D = ShapeKit.cyl(0.004, 0.16, ML.steel(), 6, Vector3i(0, 1, 0), "Spout")
	spout.position = Vector3(0.03, 0.24, 0.0)
	spout.rotation.z = -0.5
	root.add_child(spout)
	var handle: MeshInstance3D = ShapeKit.torus(0.04, 0.006, ML.steel(), 12, 5, "Handle")
	handle.position = Vector3(-0.05, 0.1, 0.0)
	handle.rotation = Vector3(0.0, PI * 0.5, 0.0)
	root.add_child(handle)
	return root


func funnel(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Funnel"
	var cone: MeshInstance3D = ShapeKit.tapered_cyl(0.012, 0.09, 0.11, ML.aluminium(), 16, "Cone")
	cone.position = Vector3(0.0, 0.055, 0.0)
	root.add_child(cone)
	var stem: MeshInstance3D = ShapeKit.cyl(0.011, 0.05, ML.aluminium(), 10, Vector3i(0, 1, 0), "Stem")
	stem.position = Vector3(0.0, -0.025, 0.0)
	root.add_child(stem)
	var lip: MeshInstance3D = ShapeKit.torus(0.092, 0.005, ML.aluminium(), 16, 5, "Lip")
	lip.position = Vector3(0.0, 0.11, 0.0)
	root.add_child(lip)
	return root


func brush_cup(opts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "BrushCup"
	var cup: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.048, 0.01), Vector2(0.05, 0.1),
		Vector2(0.048, 0.11), Vector2(0.042, 0.108), Vector2(0.04, 0.02), Vector2(0.0, 0.015),
	]), 14, ML.plastic_faded(), true, "Cup")
	root.add_child(cup)
	for i: int in range(5):
		var tool: MeshInstance3D = ShapeKit.cyl(0.005, _rng.randf_range(0.12, 0.2), ML.teak(), 6, Vector3i(0, 1, 0), "Tool")
		tool.position = Vector3(_rng.randf_range(-0.025, 0.025), 0.11, _rng.randf_range(-0.025, 0.025))
		tool.rotation = Vector3(_rng.randf_range(-0.12, 0.12), 0.0, _rng.randf_range(-0.12, 0.12))
		root.add_child(tool)
	return root
