extends Node3D
## The guide beacon: the one world-space mark the guide system uses, shared by
## both assemblies. A BIG floating arrow — a bold signal-yellow down-arrow of a
## shaft and a cone head — so every assembly component is unmistakable from
## across the room. Two modes:
##
##   setup(true)   the full mark: the arrow raised on a column of light (a soft
##                 additive shell around a thin bright filament) — this is the
##                 NEXT step the tracker's line names.
##   setup(false)  the arrow alone, hovering low over a component that is still
##                 waiting its turn, so the whole set is visible at a glance.
##
## The owners call place() every frame with the point just above the component;
## the bob, spin and pulse run here so every mark moves with one identity. The
## suit's owner yields its marks while the armour figure's are up — at most one
## job's marks show at a time.

const HEIGHT: float = 1.30        ## full mode: the column, base to arrow tip
const HOVER: float = 0.55         ## arrow mode: tip height over the component
const COL: Color = Color("ffd24a")

var _full: bool = true
var _beam_mat: StandardMaterial3D
var _arrow: Node3D
var _t: float = 0.0


func setup(full: bool) -> void:
	_full = full
	var mat: StandardMaterial3D = MaterialLibrary.led(COL, 3.0)
	# the arrow, tip at the node origin: head cone 0.00-0.20, shaft 0.22-0.39
	_arrow = Node3D.new()
	_arrow.name = "Arrow"
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.14
	head_mesh.bottom_radius = 0.0
	head_mesh.height = 0.20
	head_mesh.radial_segments = 12
	head_mesh.rings = 1
	var head := MeshInstance3D.new()
	head.name = "Head"
	head.mesh = head_mesh
	head.material_override = mat
	head.position = Vector3(0.0, 0.10, 0.0)
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(head)
	var shaft: MeshInstance3D = ShapeKit.box(Vector3(0.075, 0.17, 0.075), mat, "Shaft")
	shaft.position = Vector3(0.0, 0.305, 0.0)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.add_child(shaft)
	_arrow.position = Vector3(0.0, HEIGHT if _full else HOVER, 0.0)
	add_child(_arrow)
	if _full:
		# the column, so the next step reads over any distance; additive soft
		# shell around a thin opaque filament (the shell alone washes out on
		# bright walls — the filament carries the read)
		_beam_mat = StandardMaterial3D.new()
		_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_beam_mat.albedo_color = Color(COL.r, COL.g, COL.b, 0.22)
		_beam_mat.emission_enabled = true
		_beam_mat.emission = COL
		_beam_mat.emission_energy_multiplier = 1.8
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.11
		cyl.height = HEIGHT
		cyl.radial_segments = 10
		cyl.rings = 1
		var beam := MeshInstance3D.new()
		beam.name = "Beam"
		beam.mesh = cyl
		beam.material_override = _beam_mat
		beam.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = 0.018
		core_mesh.bottom_radius = 0.024
		core_mesh.height = HEIGHT
		core_mesh.radial_segments = 6
		core_mesh.rings = 1
		var core := MeshInstance3D.new()
		core.name = "Filament"
		core.mesh = core_mesh
		core.material_override = MaterialLibrary.led(COL, 2.4)
		core.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(core)
	set_process(true)


func place(base: Vector3) -> void:
	## The point just above the component; the mark rises from here.
	global_position = base


func _process(delta: float) -> void:
	_t += delta
	if _arrow != null:
		var hover: float = HEIGHT if _full else HOVER
		_arrow.position.y = hover + sin(_t * 2.4) * 0.07
		_arrow.rotation.y = _t * 0.5
	if _beam_mat != null:
		var pulse: float = 0.5 + 0.5 * sin(_t * 2.0)
		_beam_mat.albedo_color.a = 0.18 + 0.10 * pulse
		_beam_mat.emission_energy_multiplier = 1.7 + 0.6 * pulse
