class_name GarageStructure
extends Node3D
## The building shell: floor, walls, roof, columns, shutter opening, courtyard and
## the plinth the garage sits on.
##
## Dimensions come from GameConfig, so switching the active preset in
## data/garage_config.json rebuilds the whole shell without touching this file —
## that is the asset-swap localisation requirement from the brief, applied to the
## architecture itself.
##
## Construction rules that matter visually:
##   * walls are built as separate inner and outer skins with a gap, because a
##     single plane reads as a paper set when the camera is close to a corner;
##   * the corrugated roof is a *gable* of two pitched sheets on trusses, not a
##     flat ceiling — the pitch is what makes a tin shed look like a tin shed;
##   * every surface that a player can walk past receives a real collision shape,
##     but only the shell does. Props carry their own, so the physics world stays
##     at roughly a dozen static bodies instead of four hundred.

const WALL_THICKNESS: float = 0.26
const ROOF_PITCH: float = 0.42
const TRUSS_SPACING: float = 2.0
const COLUMN_SECTION: float = 0.2

var width: float = 8.5
var length: float = 10.5
var height: float = 3.4
var ML: MaterialLibrarySingleton
var props: PropFactory
var baker: SignageBaker
var rng: RandomNumberGenerator

## Interior extents, exposed so the dressing and lighting passes can share one
## coordinate convention instead of recomputing it.
var half_w: float = 4.25
var half_l: float = 5.25
## The opening is sized to the building rather than to a car: a single-leaf shop
## shutter in a garage this small is about 2.6 m wide and 2.25 m high, which is
## wide enough to wheel a motorcycle through and no wider.
var shutter_width: float = 2.6
var shutter_height: float = 2.25


func setup(material_library: MaterialLibrarySingleton, prop_factory: PropFactory, signage: SignageBaker) -> void:
	ML = material_library
	props = prop_factory
	baker = signage
	width = GameConfig.width()
	length = GameConfig.length()
	height = GameConfig.height()
	half_w = width * 0.5
	half_l = length * 0.5
	rng = NoiseTools.rng(0x9A7F + int(width * 100.0))


func build() -> void:
	_build_floor()
	_build_plinth_and_courtyard()
	_build_walls()
	_build_columns()
	_build_roof()
	_build_shutter_frame()
	_build_window_openings()
	_build_interior_details()


# ===========================================================================
# Floor
# ===========================================================================

func _build_floor() -> void:
	var floor_style: String = String(GameConfig.preset().get("floor_style", "worn_concrete"))
	var mat: StandardMaterial3D = ML.surface(floor_style, {"uv_scale": Vector3(5.0, 5.0, 5.0), "normal_scale": 0.9})
	var slab: MeshInstance3D = ShapeKit.box(Vector3(width + 1.2, 0.22, length + 3.2), mat, "FloorSlab")
	slab.position = Vector3(0.0, -0.11, 0.6)
	slab.set_meta("floor_kind", "concrete")
	add_child(slab)
	var col := StaticBody3D.new()
	col.name = "FloorBody"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width + 1.2, 0.22, length + 3.2)
	cs.shape = shape
	col.add_child(cs)
	col.position = slab.position
	add_child(col)
	# Floor wear. The first version laid a 1.4 x 7 m strip of the oil-stain albedo
	# down the middle of the room, which in the overhead capture read as a black
	# VOID rather than as a stain: the stain material is 0.18 roughness with a
	# near-black albedo, so it absorbed the ceiling lights and the floor simply
	# disappeared. A real workshop floor is not one long spill either — it is many
	# small patches where machines have dripped, plus a painted walkway. So: small
	# stains, a painted lane, and the drain.
	var rng_floor: RandomNumberGenerator = NoiseTools.rng(0x51AB)
	for i: int in range(14):
		var spot: MeshInstance3D = ShapeKit.disc_flat(
			rng_floor.randf_range(0.28, 0.72), 0.004, ML.floor_stain(), "FloorStain%d" % i)
		spot.position = Vector3(
			rng_floor.randf_range(-half_w + 0.8, half_w - 0.8), 0.003,
			rng_floor.randf_range(-half_l + 1.0, half_l - 1.0))
		spot.rotation.y = rng_floor.randf_range(0.0, TAU)
		spot.set_meta("floor_kind", "concrete")
		add_child(spot)
	# the painted walkway from the shutter to the assembly platform, and the drain
	# in front of it. Both are scaled to the new extents: a 7.4 m lane in a 10.5 m
	# room would run from the shutter to the back wall with nothing at either end.
	var lane: MeshInstance3D = ShapeKit.box(Vector3(0.95, 0.005, 5.2), ML.walkway_paint(), "WalkLane")
	lane.position = Vector3(0.0, 0.003, 2.5)
	lane.set_meta("floor_kind", "concrete")
	add_child(lane)
	for i: int in range(2):
		var edge: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.006, 5.2), ML.walkway_paint(), "LaneEdge%d" % i)
		edge.position = Vector3(0.5 * (1.0 if i == 0 else -1.0), 0.004, 2.5)
		add_child(edge)
	var channel: MeshInstance3D = ShapeKit.box(Vector3(width - 0.5, 0.02, 0.2), ML.steel_dark(), "DrainChannel")
	channel.position = Vector3(0.0, 0.005, half_l - 0.85)
	add_child(channel)
	var grate: MeshInstance3D = ShapeKit.box(Vector3(width - 0.5, 0.012, 0.18), ML.tread_plate(), "Grate")
	grate.position = channel.position + Vector3(0.0, 0.012, 0.0)
	add_child(grate)
	# one expansion joint down the centre of the slab
	var joint: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.006, length - 0.4), ML.steel_dark(), "Joint")
	joint.position = Vector3(0.0, 0.004, 0.3)
	add_child(joint)


# ===========================================================================
# Plinth, courtyard, exterior
# ===========================================================================

func _build_plinth_and_courtyard() -> void:
	var plinth_h: float = 0.3
	var plinth: MeshInstance3D = ShapeKit.box(Vector3(width + 1.3, plinth_h, length + 3.2), ML.surface("concrete_block", {"uv_scale": Vector3(3.0, 3.0, 3.0)}), "Plinth")
	plinth.position = Vector3(0.0, -plinth_h * 0.5 - 0.02, 0.7)
	add_child(plinth)
	# courtyard ground outside the shutter, packed earth
	var yard: MeshInstance3D = ShapeKit.box(Vector3(width + 5.0, 0.1, 4.6), ML.surface("packed_earth", {"uv_scale": Vector3(4.0, 4.0, 4.0)}), "Courtyard")
	yard.position = Vector3(0.0, -0.19, half_l + 2.8)
	yard.set_meta("floor_kind", "earth")
	add_child(yard)
	var yard_col := StaticBody3D.new()
	yard_col.name = "YardBody"
	yard_col.add_child(ShapeKit.col_box(Vector3(width + 5.0, 0.1, 4.6), false))
	yard_col.position = yard.position
	add_child(yard_col)
	# the boundary wall to the south and the neighbour's wall to the east
	var boundary: Node3D = props.build("exterior_facade", {"width": 6.5})
	boundary.position = Vector3(0.0, 0.0, half_l + 4.4)
	boundary.rotation.y = PI
	add_child(boundary)
	var neighbour: MeshInstance3D = ShapeKit.box(Vector3(0.3, 3.0, length + 3.0), ML.plaster(), "NeighbourWall")
	neighbour.position = Vector3(half_w + 2.9, 1.5, 0.5)
	add_child(neighbour)
	var neighbour2: MeshInstance3D = neighbour.duplicate() as MeshInstance3D
	neighbour2.position = Vector3(-half_w - 2.9, 1.5, 0.5)
	neighbour2.name = "NeighbourWallB"
	add_child(neighbour2)
	# exterior props. Reduced from five to three: at 8.5 m of frontage, a drum, a
	# tea cart and an antenna are an approach; five objects crowd it. They stand on
	# the packed earth at y = -0.14, the courtyard's real surface.
	var drum: Node3D = props.build("steel_drum", {})
	drum.position = Vector3(half_w - 1.2, -0.14, half_l + 1.8)
	add_child(drum)
	var bench: Node3D = props.build("tea_stall_box", {})
	bench.position = Vector3(-half_w + 2.0, -0.14, half_l + 2.6)
	bench.rotation.y = 0.4
	add_child(bench)
	var antenna: Node3D = props.build("roof_antenna", {})
	antenna.position = Vector3(half_w - 1.0, height + 0.3, -half_l + 1.6)
	add_child(antenna)
	var meter: Node3D = props.build("meter_box", {})
	meter.position = Vector3(half_w - 1.2, 1.75, half_l + 0.1)
	meter.rotation.y = -PI * 0.5
	add_child(meter)


# ===========================================================================
# Walls
# ===========================================================================

func _build_walls() -> void:
	var style: String = String(GameConfig.preset().get("wall_style", "brick_cement"))
	var brick_key: String = "brick_wall" if style == "brick_cement" else style
	var outer_mat: StandardMaterial3D = ML.surface(brick_key, {
		"uv_scale": Vector3(2.4, 1.4, 2.4),
		"uv2_scale": Vector3(1.6, 1.6, 1.6),
		"uv2_triplanar": true,
	})
	var inner_mat: StandardMaterial3D = ML.plaster()
	# Every wall is authored axis-aligned: the thickness is whichever horizontal
	# axis is the small one, and `inward` says which way the room lies. No
	# rotations, so texture tiling and the inner-skin offset stay predictable on
	# all four walls.
	_wall_segment(Vector3(0.0, height * 0.5, -half_l), Vector3(width + WALL_THICKNESS * 2.0, height, WALL_THICKNESS), Vector3.FORWARD, outer_mat, inner_mat, "NorthWall")
	_wall_segment(Vector3(-half_w, height * 0.5, 0.0), Vector3(WALL_THICKNESS, height, length), Vector3.RIGHT, outer_mat, inner_mat, "WestWall")
	_wall_segment(Vector3(half_w, height * 0.5, 0.0), Vector3(WALL_THICKNESS, height, length), Vector3.LEFT, outer_mat, inner_mat, "EastWall")
	var side_w: float = (width - shutter_width) * 0.5
	_wall_segment(Vector3(-(shutter_width * 0.5 + side_w * 0.5), height * 0.5, half_l), Vector3(side_w, height, WALL_THICKNESS), Vector3.BACK, outer_mat, inner_mat, "SouthWallL")
	_wall_segment(Vector3((shutter_width * 0.5 + side_w * 0.5), height * 0.5, half_l), Vector3(side_w, height, WALL_THICKNESS), Vector3.BACK, outer_mat, inner_mat, "SouthWallR")
	# the lintel band above the shutter
	var lintel: MeshInstance3D = ShapeKit.box(Vector3(shutter_width + 0.6, height - shutter_height - 0.2, WALL_THICKNESS + 0.04), outer_mat, "ShutterLintel")
	lintel.position = Vector3(0.0, shutter_height + (height - shutter_height) * 0.5, half_l)
	add_child(lintel)
	# interior dado: a painted lower band, extremely common in Bangladeshi workshops
	var dado_mat: StandardMaterial3D = ML.paint_green()
	var dado_h: float = 1.05
	var dado_specs: Array = [
		[Vector3(width, 0.05, 0.04), Vector3(0.0, dado_h, -half_l + WALL_THICKNESS * 0.5 + 0.03)],
		[Vector3(0.04, 0.05, length - 0.6), Vector3(-half_w + WALL_THICKNESS * 0.5 + 0.03, dado_h, 0.0)],
		[Vector3(0.04, 0.05, length - 0.6), Vector3(half_w - WALL_THICKNESS * 0.5 - 0.03, dado_h, 0.0)],
	]
	for spec: Array in dado_specs:
		var band: MeshInstance3D = ShapeKit.box(spec[0] as Vector3, dado_mat, "Dado")
		band.position = spec[1] as Vector3
		add_child(band)


func _wall_segment(center: Vector3, size: Vector3, inward: Vector3, outer: StandardMaterial3D, inner: StandardMaterial3D, node_name: String) -> void:
	## Two skins with a gap: the outer skin carries the brick or block texture and
	## the inner the plaster, so a corner where two walls meet shows the correct
	## material on each side instead of one texture wrapping around.
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	var outer_skin: MeshInstance3D = ShapeKit.box(size, outer, "Outer")
	root.add_child(outer_skin)
	var thickness: float = minf(size.x, size.z)
	var inner_size := Vector3(size.x, size.y * 0.99, size.z)
	if absf(inward.x) > 0.5:
		inner_size.x = thickness * 0.3
	else:
		inner_size.z = thickness * 0.3
	var inner_skin: MeshInstance3D = ShapeKit.box(inner_size, inner, "Inner")
	inner_skin.position = inward * (thickness * 0.35 + 0.01)
	root.add_child(inner_skin)
	var col := StaticBody3D.new()
	col.name = "Body"
	col.add_child(ShapeKit.col_box(size, false))
	root.add_child(col)
	add_child(root)


# ===========================================================================
# Columns and roof
# ===========================================================================

func _build_columns() -> void:
	## Four columns, not six. A 8.5 x 10.5 m bay needs mid-span support at one
	## point along each long wall; anything more turns a small workshop into a
	## colonnade and eats the floor area the props need.
	var mat: StandardMaterial3D = ML.surface("concrete_block", {"uv_scale": Vector3(1.0, 3.0, 1.0)})
	var steel_col: StandardMaterial3D = ML.steel_dark()
	var positions: Array[Vector3] = [
		Vector3(-half_w + 0.3, 0.0, -half_l + 2.2),
		Vector3(half_w - 0.3, 0.0, -half_l + 2.2),
		Vector3(-half_w + 0.3, 0.0, half_l - 2.4),
		Vector3(half_w - 0.3, 0.0, half_l - 2.4),
	]
	for i: int in range(positions.size()):
		var p: Vector3 = positions[i]
		var col: MeshInstance3D = ShapeKit.box(Vector3(COLUMN_SECTION, height, COLUMN_SECTION), mat, "Column%02d" % i)
		col.position = p + Vector3(0.0, height * 0.5, 0.0)
		add_child(col)
		var cap: MeshInstance3D = ShapeKit.box(Vector3(COLUMN_SECTION + 0.07, 0.055, COLUMN_SECTION + 0.07), steel_col, "Cap")
		cap.position = p + Vector3(0.0, height - 0.03, 0.0)
		add_child(cap)
		var base: MeshInstance3D = cap.duplicate() as MeshInstance3D
		base.position = p + Vector3(0.0, 0.03, 0.0)
		base.name = "Base"
		add_child(base)
		var body := StaticBody3D.new()
		body.name = "ColumnBody%02d" % i
		body.add_child(ShapeKit.col_box(Vector3(COLUMN_SECTION, height, COLUMN_SECTION), false))
		body.position = col.position
		add_child(body)


func _build_roof() -> void:
	## Gable of two pitched corrugated sheets on trusses, with the ridge vent. The
	## underside is what the player sees, so it gets the tin material and the rust
	## streaking; the topside is a simple sheet for the rain to hit.
	##
	## The geometry is derived from explicit ridge and eave heights rather than from
	## a free-standing pitch angle. The angle-first version had its sheets rotated
	## outward-downward, so the ridge ends landed *below* the wall top and sky showed
	## through the gap — invisible in the code, obvious in a screenshot. Deriving the
	## rotation from the two endpoints makes that impossible to get backwards.
	var span: float = width + 1.4
	var half_span: float = span * 0.5
	var ridge_y: float = height + 1.05
	var eave_y: float = height - 0.14
	var slope_len: float = sqrt(half_span * half_span + (ridge_y - eave_y) * (ridge_y - eave_y)) + 0.25
	var pitch: float = atan2(ridge_y - eave_y, half_span)
	var tin: StandardMaterial3D = ML.roof_tin()
	var tin_inner: StandardMaterial3D = ML.surface("corrugated_tin", {
		"cull_disabled": true, "albedo_mix": Color("#8a8f96"), "no_world_triplanar": true,
		"uv_scale": Vector3(0.7, 0.3, 0.7),
	})
	for i: int in range(2):
		var sign: float = 1.0 if i == 0 else -1.0
		var centre := Vector3(sign * half_span * 0.5, (ridge_y + eave_y) * 0.5, 0.0)
		var sheet: MeshInstance3D = ShapeKit.box(Vector3(slope_len, 0.06, length + 1.6), tin, "RoofSheet%s" % ("N" if sign < 0.0 else "S"))
		sheet.position = centre
		sheet.rotation = Vector3(0.0, 0.0, -sign * pitch)
		add_child(sheet)
		var under: MeshInstance3D = ShapeKit.box(Vector3(slope_len, 0.03, length + 1.4), tin_inner, "RoofUnder")
		under.position = centre - Vector3(0.0, 0.06, 0.0)
		under.rotation = sheet.rotation
		under.set_meta("floor_kind", "tin")
		add_child(under)
	# gable ends close the triangle above the north and south walls; without them
	# the roof reads as a lid floating over an open box
	for i: int in range(2):
		var gz: float = (length * 0.5 + 0.72) * (1.0 if i == 0 else -1.0)
		var courses: int = 6
		for c: int in range(courses):
			# a stepped triangle of concrete-course bands, which is how a real
			# gable is built up rather than as a single swept plane
			var frac: float = 1.0 - float(c) / float(courses)
			var w: float = span * frac
			if w <= 0.2:
				continue
			var band: MeshInstance3D = ShapeKit.box(Vector3(w, (ridge_y - height) / float(courses) + 0.02, 0.24), ML.surface("concrete_block"), "GableBand")
			band.position = Vector3(0.0, height + (ridge_y - height) * (float(c) + 0.5) / float(courses), gz)
			add_child(band)
	# trusses
	var truss_count: int = int((length + 1.0) / TRUSS_SPACING)
	for t: int in range(truss_count + 1):
		var z: float = -half_l - 0.5 + float(t) * TRUSS_SPACING
		if z > half_l + 0.6:
			break
		_truss(z, span, ridge_y, eave_y, pitch)
	# ridge vent cap
	var ridge: MeshInstance3D = ShapeKit.box(Vector3(0.5, 0.18, length + 1.2), ML.steel_dark(), "Ridge")
	ridge.position = Vector3(0.0, ridge_y + 0.08, 0.0)
	add_child(ridge)
	var vent_gap: MeshInstance3D = ShapeKit.box(Vector3(0.34, 0.06, length + 1.0), ML.rust(), "VentSlot")
	vent_gap.position = ridge.position + Vector3(0.0, -0.1, 0.0)
	add_child(vent_gap)
	# purlins sit on the sheet slope, spaced across the span
	for i: int in range(5):
		var x: float = -half_span + 0.7 + float(i) * (span - 1.4) / 4.0
		var drop: float = absf(x) / half_span
		var y: float = ridge_y - (ridge_y - eave_y) * drop
		var purlin: MeshInstance3D = ShapeKit.box(Vector3(0.07, 0.07, length + 1.2), ML.surface("bamboo") if i % 2 == 0 else ML.steel_dark(), "Purlin%02d" % i)
		purlin.position = Vector3(x, y - 0.13, 0.0)
		add_child(purlin)


func _truss(z: float, span: float, ridge_y: float, eave_y: float, pitch: float) -> void:
	var steel: StandardMaterial3D = ML.steel_dark()
	var root := Node3D.new()
	root.name = "Truss"
	root.position = Vector3(0.0, 0.0, z)
	add_child(root)
	var half_span: float = span * 0.5
	# bottom chord ties the two eaves together
	var chord: MeshInstance3D = ShapeKit.box(Vector3(span, 0.09, 0.09), steel, "Chord")
	chord.position = Vector3(0.0, eave_y + 0.06, 0.0)
	root.add_child(chord)
	# rafters rise from each eave to the ridge
	var rafter_len: float = sqrt(half_span * half_span + (ridge_y - eave_y) * (ridge_y - eave_y))
	for i: int in range(2):
		var sign: float = 1.0 if i == 0 else -1.0
		var rafter: MeshInstance3D = ShapeKit.box(Vector3(rafter_len, 0.08, 0.08), steel, "Rafter")
		rafter.position = Vector3(sign * half_span * 0.5, (ridge_y + eave_y) * 0.5, 0.0)
		rafter.rotation.z = -sign * pitch
		root.add_child(rafter)
	# king post and webs
	var king: MeshInstance3D = ShapeKit.box(Vector3(0.07, ridge_y - eave_y, 0.07), steel, "KingPost")
	king.position = Vector3(0.0, (ridge_y + eave_y) * 0.5, 0.0)
	root.add_child(king)
	for i: int in range(4):
		var sign: float = 1.0 if i < 2 else -1.0
		var web: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.44, 0.05), steel, "Web")
		web.position = Vector3(sign * half_span * (0.18 + float(i % 2) * 0.16), eave_y + (ridge_y - eave_y) * 0.4, 0.0)
		web.rotation.z = sign * 0.55
		root.add_child(web)
	# the sagging cable under a couple of trusses, a real detail in tin sheds
	if rng.randf() > 0.6:
		var cable: MeshInstance3D = ShapeKit.hose(
			Vector3(-half_span * 0.9, eave_y + 0.02, 0.0), Vector3(half_span * 0.9, eave_y + 0.02, 0.0),
			0.008, 0.28, ML.cable_material(Color("#2a2c30")), "SagCable")
		root.add_child(cable)


# ===========================================================================
# Shutter opening and windows
# ===========================================================================

func _build_shutter_frame() -> void:
	var frame_mat: StandardMaterial3D = ML.steel_dark()
	var jamb_l: MeshInstance3D = ShapeKit.box(Vector3(0.14, shutter_height + 0.3, WALL_THICKNESS + 0.08), frame_mat, "ShutterJambL")
	jamb_l.position = Vector3(-shutter_width * 0.5 - 0.07, (shutter_height + 0.3) * 0.5, half_l)
	add_child(jamb_l)
	var jamb_r: MeshInstance3D = jamb_l.duplicate() as MeshInstance3D
	jamb_r.position = Vector3(shutter_width * 0.5 + 0.07, (shutter_height + 0.3) * 0.5, half_l)
	jamb_r.name = "ShutterJambR"
	add_child(jamb_r)
	var head: MeshInstance3D = ShapeKit.box(Vector3(shutter_width + 0.3, 0.16, WALL_THICKNESS + 0.08), frame_mat, "ShutterHead")
	head.position = Vector3(0.0, shutter_height + 0.36, half_l)
	add_child(head)
	# the shutter itself, parked half-open at start
	var shutter: Node3D = props.build("rolling_shutter", {
		"width": shutter_width, "height": shutter_height, "slat_height": 0.115,
	})
	shutter.name = "Shutter"
	shutter.position = Vector3(0.0, 0.0, half_l + 0.02)
	add_child(shutter)
	# the interior sill step
	var sill: MeshInstance3D = ShapeKit.box(Vector3(shutter_width + 0.2, 0.06, 0.3), ML.surface("concrete_block"), "Sill")
	sill.position = Vector3(0.0, 0.03, half_l - 0.18)
	sill.set_meta("floor_kind", "concrete")
	add_child(sill)


func _build_window_openings() -> void:
	## Two windows now, not three. At 3.4 m headroom a high north-wall ventilator
	## would sit in the roof pitch, so the light comes from the two side windows:
	## one over the electronics bench (which motivates the cool zone) and one over
	## the mechanical bench.
	var openings: Array = [
		{"pos": Vector3(half_w - 0.02, 1.95, 2.3), "size": Vector3(0.28, 0.95, 1.5), "yaw": 0.0, "bars": true},
		{"pos": Vector3(-half_w + 0.02, 2.05, 2.3), "size": Vector3(0.28, 0.85, 1.3), "yaw": 0.0, "bars": true},
	]
	for i: int in range(openings.size()):
		var o: Dictionary = openings[i]
		var pos: Vector3 = o["pos"]
		var sz: Vector3 = o["size"]
		var root := Node3D.new()
		root.name = "Window%02d" % i
		root.position = pos
		add_child(root)
		# frame
		var frame_mat: StandardMaterial3D = ML.teak()
		var is_x_wall: bool = sz.x > sz.z
		var t: float = 0.07
		if is_x_wall:
			for s: int in range(2):
				var rail: MeshInstance3D = ShapeKit.box(Vector3(t, sz.y + t, t * 0.9), frame_mat, "Jamb")
				rail.position = Vector3(0.0, 0.0, (sz.z * 0.5) * (1.0 if s == 0 else -1.0))
				root.add_child(rail)
			for s: int in range(2):
				var head: MeshInstance3D = ShapeKit.box(Vector3(t, t, sz.z + t), frame_mat, "Rail")
				head.position = Vector3(0.0, (sz.y * 0.5) * (1.0 if s == 0 else -1.0), 0.0)
				root.add_child(head)
		else:
			for s: int in range(2):
				var rail: MeshInstance3D = ShapeKit.box(Vector3(t * 0.9, sz.y + t, t), frame_mat, "Jamb")
				rail.position = Vector3((sz.x * 0.5) * (1.0 if s == 0 else -1.0), 0.0, 0.0)
				root.add_child(rail)
			for s: int in range(2):
				var head: MeshInstance3D = ShapeKit.box(Vector3(sz.x + t, t, t), frame_mat, "Rail")
				head.position = Vector3(0.0, 0.0, (sz.z * 0.5) * (1.0 if s == 0 else -1.0))
				root.add_child(head)
		# glass
		var pane: MeshInstance3D = ShapeKit.box(Vector3(sz.x * 0.5, sz.y * 0.92, sz.z * 0.92), ML.glass_smoky(), "Pane")
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(pane)
		# security bars, the reason the windows read as Bangladesh immediately
		if bool(o.get("bars", false)):
			var bar_count: int = int(maxf(sz.z, sz.x) / 0.16)
			for b: int in range(bar_count):
				var bar: MeshInstance3D = ShapeKit.cyl(0.012, sz.y * 0.95, ML.steel_dark(), 6, Vector3i(0, 1, 0), "Bar")
				if is_x_wall:
					bar.position = Vector3(0.0, 0.0, -sz.z * 0.45 + float(b) * sz.z * 0.9 / float(maxi(bar_count - 1, 1)))
				else:
					bar.position = Vector3(-sz.x * 0.45 + float(b) * sz.x * 0.9 / float(maxi(bar_count - 1, 1)), 0.0, 0.0)
				bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(bar)
		# the sill board and a small ledge prop
		var sill: MeshInstance3D = ShapeKit.box(Vector3(sz.x * 0.6 + 0.06, 0.05, sz.z * 0.6 + 0.06), ML.surface("concrete_block"), "WindowSill")
		sill.position = Vector3(0.0, -sz.y * 0.5 - 0.02, 0.0)
		root.add_child(sill)


# ===========================================================================
# Interior fittings
# ===========================================================================

func _build_interior_details() -> void:
	## The previous interior had a partition wall, a mezzanine loft with four posts
	## and a nine-rung bamboo ladder. In a 13 x 16.5 m bay those read as a working
	## building; in 8.5 x 10.5 m at 3.4 m headroom they would consume a third of the
	## volume and leave nowhere to stand. What a small single-room workshop actually
	## has instead is ceiling beams, one hanging line, and everything else on the
	## walls and floor — which is also what the reference photographs show.
	#
	# two ceiling beams rather than three, spanning the short axis
	for i: int in range(2):
		var beam: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.14, width - 0.5), ML.teak(), "CeilingBeam%d" % i)
		beam.rotation.y = PI * 0.5
		beam.position = Vector3(0.0, height - 0.11, -1.7 + float(i) * 3.4)
		add_child(beam)
	# the rope line across the room for towels and rags
	var rope: MeshInstance3D = ShapeKit.hose(
		Vector3(-half_w + 0.35, height - 0.42, 2.0), Vector3(half_w - 0.35, height - 0.46, 2.5),
		0.008, 0.28, ML.thread_material(), "ClothesLine")
	add_child(rope)
	# The shelf-bracket pair on the west wall is gone: it was two 0.22 m bars with
	# no board between them, and in the smaller room the store shelf now occupies
	# the wall they were on.
	# the drain outside and one puddle, because a courtyard in Dhaka has one
	var puddle: MeshInstance3D = ShapeKit.disc_flat(1.1, 0.004, ML.water(), "Puddle")
	puddle.position = Vector3(1.3, -0.14, half_l + 2.0)
	add_child(puddle)


func area_volumes() -> Array:
	## Six named areas. `store` is gone: in a single-room workshop this size there is
	## no separate store to name, and the shelves are simply the north-west corner of
	## the same room. The volumes deliberately overlap at their thresholds so the
	## player's area attribution never gaps as they walk through a doorway.
	return [
		{"name": "entrance", "pos": Vector3(0.0, 1.4, half_l - 1.3), "size": Vector3(shutter_width + 1.4, 2.8, 2.8)},
		{"name": "mechanical", "pos": Vector3(-half_w * 0.6, 1.4, 1.8), "size": Vector3(width * 0.5, 2.8, length * 0.56)},
		{"name": "electronics", "pos": Vector3(half_w * 0.6, 1.4, 1.8), "size": Vector3(width * 0.5, 2.8, length * 0.56)},
		{"name": "assembly", "pos": Vector3(0.0, 1.5, -1.6), "size": Vector3(width * 0.9, 3.0, length * 0.52)},
		{"name": "testing", "pos": Vector3(1.9, 1.4, -half_l + 1.7), "size": Vector3(4.2, 2.8, 3.4)},
		{"name": "exterior", "pos": Vector3(0.0, 1.4, half_l + 3.0), "size": Vector3(width + 5.0, 3.2, 5.6)},
	]
