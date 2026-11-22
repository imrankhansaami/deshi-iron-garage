extends Node3D
## The guide beacon: the one world-space mark the guide system uses, shared by
## both assemblies. A bobbing diamond in the shop's signal yellow over a soft
## column of light — the diamond says "this thing", the column says "over
## here" — so the next step reads from across the room. No shadow, additive,
## two tiny meshes.
##
## The owning guide calls place() every frame with the point just above its
## target (the next spare, the next crate, the stand, the console); the bob,
## spin and pulse run here so both guides move with one identity. At most one
## beacon stands at a time: the suit guide yields while the armour figure's own
## beacon is up, because that beam marks the job actually being worked.

const HEIGHT: float = 1.30        ## the column, base to diamond
const COL: Color = Color("ffd24a")

var _beam_mat: StandardMaterial3D
var _diamond: Node3D
var _t: float = 0.0


func _ready() -> void:
	_diamond = ShapeKit.box(Vector3(0.085, 0.085, 0.085), MaterialLibrary.led(COL, 3.0), "Diamond")
	_diamond.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
	_diamond.position = Vector3(0.0, HEIGHT, 0.0)
	_diamond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_diamond)
	# additive, so the column reads over bright walls and dark bays alike
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
	# the filament: a thin opaque core so the column reads on any background,
	# bright walls and dark bays alike (the soft shell alone washes out)
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
	## The point just above the target; the column rises from here.
	global_position = base


func _process(delta: float) -> void:
	_t += delta
	if _diamond != null:
		_diamond.position.y = HEIGHT + sin(_t * 2.4) * 0.05
		_diamond.rotation.y = _t * 1.1
	var pulse: float = 0.5 + 0.5 * sin(_t * 2.0)
	_beam_mat.albedo_color.a = 0.18 + 0.10 * pulse
	_beam_mat.emission_energy_multiplier = 1.7 + 0.6 * pulse
