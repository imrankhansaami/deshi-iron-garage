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

const WALL_THICKNESS: float = 0.28
const ROOF_PITCH: float = 0.38          # radians, ~22 degrees
const TRUSS_SPACING: float = 2.2
const COLUMN_SECTION: float = 0.24

var width: float = 13.0
var length: float = 16.5
var height: float = 4.6
var ML: MaterialLibrarySingleton
var props: PropFactory
var baker: SignageBaker
var rng: RandomNumberGenerator

## Interior extents, exposed so the dressing and lighting passes can share one
## coordinate convention instead of recomputing it.
var half_w: float = 6.5
var half_l: float = 8.25
var shutter_width: float = 3.6
var shutter_height: float = 3.0


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
	# the grease paths and the drainage channel every workshop floor has
	var stain: MeshInstance3D = ShapeKit.box(Vector3(1.4, 0.004, 7.0), ML.oil_stain(), "GreasePath")
	stain.position = Vector3(-1.2, 0.002, 1.0)
	stain.set_meta("floor_kind", "concrete")
	add_child(stain)
	var channel: MeshInstance3D = ShapeKit.box(Vector3(width - 0.6, 0.02, 0.22), ML.steel_dark(), "DrainChannel")
	channel.position = Vector3(0.0, 0.005, half_l - 1.1)
	add_child(channel)
	var grate: MeshInstance3D = ShapeKit.box(Vector3(width - 0.6, 0.012, 0.2), ML.tread_plate(), "Grate")
	grate.position = channel.position + Vector3(0.0, 0.012, 0.0)
	add_child(grate)


# ===========================================================================
# Plinth, courtyard, exterior
# ===========================================================================

func _build_plinth_and_courtyard() -> void:
	var plinth_h: float = 0.32
	var plinth: MeshInstance3D = ShapeKit.box(Vector3(width + 1.6, plinth_h, length + 4.0), ML.surface("concrete_block", {"uv_scale": Vector3(3.0, 3.0, 3.0)}), "Plinth")
	plinth.position = Vector3(0.0, -plinth_h * 0.5 - 0.02, 0.8)
	add_child(plinth)
	# courtyard ground outside the shutter, packed earth
	var yard: MeshInstance3D = ShapeKit.box(Vector3(width + 6.0, 0.1, 6.0), ML.surface("packed_earth", {"uv_scale": Vector3(4.0, 4.0, 4.0)}), "Courtyard")
	yard.position = Vector3(0.0, -0.2, half_l + 3.6)
	yard.set_meta("floor_kind", "earth")
	add_child(yard)
	var yard_col := StaticBody3D.new()
	yard_col.name = "YardBody"
	yard_col.add_child(ShapeKit.col_box(Vector3(width + 6.0, 0.1, 6.0)))
	yard_col.position = yard.position
	add_child(yard_col)
	# the boundary wall to the south and the neighbour's wall to the east
	var boundary: Node3D = props.build("exterior_facade", {"width": 8.0})
	boundary.position = Vector3(0.0, 0.0, half_l + 5.6)
	boundary.rotation.y = PI
	add_child(boundary)
	var neighbour: MeshInstance3D = ShapeKit.box(Vector3(0.3, 3.4, length + 4.0), ML.plaster(), "NeighbourWall")
	neighbour.position = Vector3(half_w + 3.4, 1.7, 0.6)
	add_child(neighbour)
	var neighbour2: MeshInstance3D = neighbour.duplicate() as MeshInstance3D
	neighbour2.position = Vector3(-half_w - 3.4, 1.7, 0.6)
	neighbour2.name = "NeighbourWallB"
	add_child(neighbour2)
	# a few exterior props so the approach is not empty
	var drum: Node3D = props.build("steel_drum", {})
	drum.position = Vector3(half_w - 1.2, 0.0, half_l + 2.2)
	add_child(drum)
	var pole: Node3D = props.build("bamboo_pole", {})
	pole.position = Vector3(-half_w + 0.8, 0.0, half_l + 3.0)
	add_child(pole)
	var bench: Node3D = props.build("tea_stall_box", {})
	bench.position = Vector3(-half_w + 2.6, 0.0, half_l + 3.4)
	bench.rotation.y = 0.4
	add_child(bench)
	var antenna: Node3D = props.build("roof_antenna", {})
	antenna.position = Vector3(half_w - 1.0, height + 0.4, -half_l + 2.0)
	add_child(antenna)
	var meter: Node3D = props.build("meter_box", {})
	meter.position = Vector3(half_w - 1.4, 1.9, half_l + 0.1)
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
	col.add_child(ShapeKit.col_box(size))
	root.add_child(col)
	add_child(root)


# ===========================================================================
# Columns and roof
# ===========================================================================

func _build_columns() -> void:
	var mat: StandardMaterial3D = ML.surface("concrete_block", {"uv_scale": Vector3(1.0, 3.0, 1.0)})
	var steel_col: StandardMaterial3D = ML.steel_dark()
	var positions: Array[Vector3] = [
		Vector3(-half_w + 0.35, 0.0, -half_l + 2.0),
		Vector3(half_w - 0.35, 0.0, -half_l + 2.0),
		Vector3(-half_w + 0.35, 0.0, 0.0),
		Vector3(half_w - 0.35, 0.0, 0.0),
		Vector3(-half_w + 0.35, 0.0, half_l - 2.0),
		Vector3(half_w - 0.35, 0.0, half_l - 2.0),
	]
	for i: int in range(positions.size()):
		var p: Vector3 = positions[i]
		var col: MeshInstance3D = ShapeKit.box(Vector3(COLUMN_SECTION, height, COLUMN_SECTION), mat, "Column%02d" % i)
		col.position = p + Vector3(0.0, height * 0.5, 0.0)
		add_child(col)
		var cap: MeshInstance3D = ShapeKit.box(Vector3(COLUMN_SECTION + 0.08, 0.06, COLUMN_SECTION + 0.08), steel_col, "Cap")
		cap.position = p + Vector3(0.0, height - 0.03, 0.0)
		add_child(cap)
		var base: MeshInstance3D = cap.duplicate() as MeshInstance3D
		base.position = p + Vector3(0.0, 0.03, 0.0)
		base.name = "Base"
		add_child(base)
		var body := StaticBody3D.new()
		body.name = "ColumnBody%02d" % i
		body.add_child(ShapeKit.col_box(Vector3(COLUMN_SECTION, height, COLUMN_SECTION)))
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
	## Two windows: one above the electronics bench (the light that motivates the
	## cool zone) and a small ventilator high on the north wall. Each is a hole in
	## the wall skin, a frame, a grille and a glass pane.
	var openings: Array = [
		{"pos": Vector3(half_w - 0.02, 2.05, 3.4), "size": Vector3(0.3, 1.15, 1.7), "yaw": 0.0, "bars": true},
		{"pos": Vector3(-half_w + 0.02, 2.35, -2.6), "size": Vector3(0.3, 0.9, 1.4), "yaw": 0.0, "bars": true},
		{"pos": Vector3(2.2, 3.3, -half_l + 0.02), "size": Vector3(1.2, 0.7, 0.3), "yaw": 0.0, "bars": false},
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
	# the partition between the assembly bay and the store room
	var partition: MeshInstance3D = ShapeKit.box(Vector3(0.12, 2.6, 4.4), ML.plaster(), "Partition")
	partition.position = Vector3(half_w - 2.4, 1.3, -half_l + 2.4)
	add_child(partition)
	var part_col := StaticBody3D.new()
	part_col.name = "PartitionBody"
	part_col.add_child(ShapeKit.col_box(Vector3(0.12, 2.6, 4.4)))
	part_col.position = partition.position
	add_child(part_col)
	# the mezzanine loft above the store room, reached by a ladder
	var loft: MeshInstance3D = ShapeKit.box(Vector3(3.4, 0.1, 4.0), ML.plywood(), "Loft")
	loft.position = Vector3(half_w - 1.9, 2.7, -half_l + 2.2)
	add_child(loft)
	for i: int in range(4):
		var post: MeshInstance3D = ShapeKit.box(Vector3(0.1, 2.7, 0.1), ML.teak(), "LoftPost")
		post.position = Vector3(
			half_w - 1.9 + (1.6 if i % 2 == 0 else -1.6) * 0.95,
			1.35,
			-half_l + 2.2 + (2.0 if i < 2 else -2.0) * 0.9,
		)
		add_child(post)
	var rail: MeshInstance3D = ShapeKit.box(Vector3(3.3, 0.06, 0.06), ML.teak(), "LoftRail")
	rail.position = Vector3(half_w - 1.9, 3.1, -half_l + 0.3)
	add_child(rail)
	# the ladder
	var ladder := Node3D.new()
	ladder.name = "LoftLadder"
	ladder.position = Vector3(half_w - 3.3, 0.0, -half_l + 1.2)
	ladder.rotation.x = -0.22
	add_child(ladder)
	for s: int in range(2):
		var stringer: MeshInstance3D = ShapeKit.box(Vector3(0.05, 3.0, 0.05), ML.teak(), "Stringer")
		stringer.position = Vector3(0.2 * (1.0 if s == 0 else -1.0), 1.5, 0.0)
		ladder.add_child(stringer)
	for r: int in range(9):
		var rung: MeshInstance3D = ShapeKit.cyl(0.022, 0.44, ML.surface("bamboo"), 8, Vector3i(1, 0, 0), "Rung")
		rung.position = Vector3(0.0, 0.28 + float(r) * 0.3, 0.0)
		ladder.add_child(rung)
	# the ceiling beam the fan and the lights hang from
	var beam: MeshInstance3D = ShapeKit.box(Vector3(0.16, 0.16, length - 1.0), ML.teak(), "CeilingBeam")
	beam.position = Vector3(0.0, height - 0.12, 0.0)
	add_child(beam)
	var beam2: MeshInstance3D = beam.duplicate() as MeshInstance3D
	beam2.position = Vector3(-3.6, height - 0.12, 0.0)
	beam2.name = "CeilingBeamL"
	add_child(beam2)
	var beam3: MeshInstance3D = beam.duplicate() as MeshInstance3D
	beam3.position = Vector3(3.6, height - 0.12, 0.0)
	beam3.name = "CeilingBeamR"
	add_child(beam3)
	# the rope line across the room for towels and rags
	var rope: MeshInstance3D = ShapeKit.hose(
		Vector3(-half_w + 0.4, height - 0.5, 2.2), Vector3(half_w - 0.4, height - 0.55, 3.0),
		0.008, 0.35, ML.thread_material(), "ClothesLine")
	add_child(rope)
	# the drain outside and the puddle
	var puddle: MeshInstance3D = ShapeKit.disc_flat(1.4, 0.004, ML.water(), "Puddle")
	puddle.position = Vector3(1.6, -0.14, half_l + 2.4)
	add_child(puddle)
	var puddle2: MeshInstance3D = ShapeKit.disc_flat(0.9, 0.004, ML.water(), "Puddle2")
	puddle2.position = Vector3(-2.8, -0.14, half_l + 3.6)
	add_child(puddle2)


func area_volumes() -> Array:
	## The five named areas of Section 6, as Area3D volumes in the "garage_areas"
	## group. The player tests its position against these for objective and
	## ambience switching, so they overlap deliberately at the thresholds.
	return [
		{"name": "entrance", "pos": Vector3(0.0, 1.5, half_l - 1.6), "size": Vector3(shutter_width + 1.6, 3.0, 3.4)},
		{"name": "mechanical", "pos": Vector3(-half_w * 0.55, 1.5, 1.6), "size": Vector3(width * 0.42, 3.2, length * 0.62)},
		{"name": "electronics", "pos": Vector3(half_w * 0.6, 1.5, 3.2), "size": Vector3(width * 0.34, 3.2, length * 0.42)},
		{"name": "assembly", "pos": Vector3(0.0, 1.8, -2.2), "size": Vector3(7.2, 3.6, 7.4)},
		{"name": "testing", "pos": Vector3(1.6, 1.5, -half_l + 2.0), "size": Vector3(5.6, 3.0, 4.0)},
		{"name": "store", "pos": Vector3(half_w - 1.9, 1.5, -half_l + 2.2), "size": Vector3(3.6, 3.0, 4.4)},
		{"name": "exterior", "pos": Vector3(0.0, 1.5, half_l + 3.4), "size": Vector3(width + 6.0, 3.4, 6.4)},
	]
