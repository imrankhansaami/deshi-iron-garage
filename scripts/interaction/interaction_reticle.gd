class_name InteractionReticle
extends Node3D
## The in-world focus indicator.
##
## Highlighting an interactable by swapping or overlaying its material is the
## obvious approach and the wrong one: material_overlay replaces the PBR shading
## of the object, so a spanner stops looking like steel the moment the player
## looks at it, and every interactable would need its own material instance.
##
## Instead this is four corner brackets sized to the target's bounding box and
## billboarded to the camera. It reads as an AR targeting aid — which is what the
## inventor's suit HUD would plausibly look like — costs nothing in draw terms,
## and behaves identically on a rusty spanner and on the exosuit.
##
## The brackets animate: they snap outward on acquisition, breathe slowly while
## held, and contract on release. Amber means "the game sees this object but you
## cannot use it yet", cyan means "E will do something". That distinction is the
## whole reason for the reticle existing.

const BRACKET_THICKNESS: float = 0.014
const BRACKET_DEPTH: float = 0.006
const SNAP_TIME: float = 0.12
const COLOR_READY: Color = Color("4fd8ff")
const COLOR_BLOCKED: Color = Color("ffb347")

var _target: Interactable = null
var _horiz: Array[MeshInstance3D] = []
var _vert: Array[MeshInstance3D] = []
var _box: MeshInstance3D
var _bracket_mat: StandardMaterial3D
var _box_mat: StandardMaterial3D
var _tween: Tween
var _phase: float = 0.0
var _open_amount: float = 0.0
var _pulse: float = 0.0
var _enabled: bool = true


func _ready() -> void:
	# Dedicated material instances: the reticle mutates emission every frame, and
	# a shared material from the library cache would leak that into whatever else
	# uses the same emissive colour.
	_bracket_mat = _emissive(COLOR_READY, 2.6)
	_box_mat = _emissive(COLOR_READY, 0.3)
	_box_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box_mat.albedo_color = Color(COLOR_READY, 0.06)
	_build()
	visible = false


static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.5)
	m.metallic = 0.0
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.resource_name = "reticle"
	return m


func _build() -> void:
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(1.0, BRACKET_THICKNESS, BRACKET_DEPTH)
	var v_mesh := BoxMesh.new()
	v_mesh.size = Vector3(BRACKET_THICKNESS, 1.0, BRACKET_DEPTH)
	for i: int in range(4):
		var horiz := MeshInstance3D.new()
		horiz.mesh = h_mesh
		horiz.material_override = _bracket_mat
		horiz.name = "BracketH%d" % i
		horiz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		horiz.top_level = false
		add_child(horiz)
		_horiz.append(horiz)
		var vert := MeshInstance3D.new()
		vert.mesh = v_mesh
		vert.material_override = _bracket_mat
		vert.name = "BracketV%d" % i
		vert.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(vert)
		_vert.append(vert)
	_box = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	_box.mesh = bm
	_box.material_override = _box_mat
	_box.name = "FocusVolume"
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_box)


func set_enabled(on: bool) -> void:
	_enabled = on
	if not on:
		_release()


func hide_now() -> void:
	_release()
	visible = false


func focus(t: Interactable) -> void:
	if not _enabled or t == null:
		return
	if t == _target:
		return
	_target = t
	visible = true
	_open_amount = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_open_amount", 1.0, SNAP_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func clear_focus() -> void:
	if _target == null:
		return
	_release()


func _release() -> void:
	_target = null
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_open_amount", 0.0, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_hide_if_idle)


func _hide_if_idle() -> void:
	if _target == null:
		visible = false


func _process(delta: float) -> void:
	if _target == null or not visible or not is_instance_valid(_target):
		return
	_phase += delta
	_pulse = 0.5 + 0.5 * sin(_phase * 3.4)
	var b: AABB = _target.bounds()
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and b.has_volume():
		look_at(cam.global_position, Vector3.UP)
	position = to_local(b.get_center())
	var pad: float = 0.06 + _open_amount * 0.05 + _pulse * 0.012
	var half: Vector3 = b.size * 0.5 + Vector3.ONE * pad
	var arm_x: float = maxf(half.x * 0.34, 0.05)
	var arm_y: float = maxf(half.y * 0.34, 0.05)
	for i: int in range(4):
		var sx: float = -1.0 if (i & 1) == 0 else 1.0
		var sy: float = -1.0 if i < 2 else 1.0
		_horiz[i].position = Vector3(sx * (half.x - arm_x), sy * half.y, 0.0)
		_horiz[i].scale = Vector3(arm_x * 2.0, 1.0, 1.0)
		_vert[i].position = Vector3(sx * half.x, sy * (half.y - arm_y), 0.0)
		_vert[i].scale = Vector3(1.0, arm_y * 2.0, 1.0)
	_box.position = Vector3.ZERO
	_box.scale = b.size + Vector3.ONE * pad * 1.6
	var available: bool = _target.is_available()
	var c: Color = COLOR_READY if available else COLOR_BLOCKED
	_bracket_mat.emission = c
	_bracket_mat.albedo_color = c.darkened(0.5)
	_bracket_mat.emission_energy_multiplier = 2.2 + _pulse * 0.9
	_box_mat.albedo_color = Color(c, 0.04 + _pulse * 0.03)
	_box_mat.emission = c
