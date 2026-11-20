class_name ExosuitFactory
extends RefCounted
## The original powered exosuit (Section 9 of the brief).
##
## Design intent: an Iron-Man-adjacent engineering silhouette that is NOT a
## reproduction. The differences are deliberate and structural, not cosmetic:
##
##   * an asymmetric shoulder — a ring on the left, a layered pauldron on the
##     right, because the inventor only had one usable stamping die;
##   * exposed hydraulics at every joint instead of smooth continuous armour;
##   * brass and bare steel left unpainted wherever a plate was hand-formed, so
##     the suit reads as fabricated rather than manufactured;
##   * a chest core set in a salvaged brake-drum bezel;
##   * a helmet with a horizontal visor slit and an external jaw guard, not the
##     movie's faceplate.
##
## The suit is modular by requirement: ten named parts, each with a home
## transform on the assembly stand, so the assembly sequence can attach them in
## order and the diagnostics pass can address any one of them.
##
## No rigging. The parts are posed by transforms on a static skeleton, which is
## the honest scope for a single-student project and is what the brief asks for.

const SUIT_HEIGHT: float = 1.86

## Part identifiers in assembly order. The three crate modules resolve to these
## groups: frame -> spine/pelvis, energy -> core, shell -> the plate set.
const PART_IDS: Array[String] = [
	"spine", "pelvis", "chest", "back", "helmet",
	"arm_left", "arm_right", "forearm_left", "forearm_right",
	"hand_left", "hand_right", "leg_left", "leg_right", "core",
]

var ML: MaterialLibrarySingleton
var f: PropFactory


func _init(props: PropFactory) -> void:
	f = props
	ML = props.ML


func part_list() -> Array[String]:
	return PART_IDS


## Builds the complete suit. Returns { root: Node3D, parts: Dictionary }.
func build(opts: Dictionary = {}) -> Dictionary:
	var root := Node3D.new()
	root.name = "PrototypeExosuit"
	var parts: Dictionary = {}
	var scale: float = float(opts.get("scale", 1.0))

	# --- internal skeleton: the World A donor frame, always visible -----------
	parts["spine"] = _spine()
	parts["pelvis"] = _pelvis()
	parts["chest"] = _chest()
	parts["back"] = _back()
	parts["helmet"] = _helmet()
	parts["arm_left"] = _arm(1)
	parts["arm_right"] = _arm(-1)
	parts["forearm_left"] = _forearm(1)
	parts["forearm_right"] = _forearm(-1)
	parts["hand_left"] = _hand(1)
	parts["hand_right"] = _hand(-1)
	parts["leg_left"] = _leg(1)
	parts["leg_right"] = _leg(-1)
	parts["core"] = _core()

	for id: String in parts:
		var n: Node3D = parts[id]
		root.add_child(n)
		_apply_home(n, id)
	# the pose: a slight ready stance, asymmetric because it is bolted to a stand
	root.rotation.y = 0.0
	for id: String in ["arm_left", "arm_right"]:
		(parts[id] as Node3D).rotation.z = 0.12 * (1.0 if id == "arm_left" else -1.0)
	(parts["helmet"] as Node3D).rotation.y = -0.12
	(parts["forearm_left"] as Node3D).rotation.x = -0.22
	root.scale = Vector3.ONE * scale
	return {"root": root, "parts": parts}


## Home transforms on the stand, expressed once so the assembly animation, the
## hologram schematic and the diagnostic pass all agree on where parts live.
func _apply_home(n: Node3D, id: String) -> void:
	match id:
		"spine":
			n.position = Vector3(0.0, 0.98, -0.02)
		"pelvis":
			n.position = Vector3(0.0, 0.86, 0.0)
		"chest":
			n.position = Vector3(0.0, 1.34, 0.0)
		"back":
			n.position = Vector3(0.0, 1.32, -0.13)
		"helmet":
			n.position = Vector3(0.0, 1.68, 0.0)
		"arm_left":
			n.position = Vector3(0.24, 1.42, 0.0)
		"arm_right":
			n.position = Vector3(-0.24, 1.42, 0.0)
		"forearm_left":
			n.position = Vector3(0.28, 1.06, 0.02)
		"forearm_right":
			n.position = Vector3(-0.28, 1.06, 0.02)
		"hand_left":
			n.position = Vector3(0.3, 0.82, 0.04)
		"hand_right":
			n.position = Vector3(-0.3, 0.82, 0.04)
		"leg_left":
			n.position = Vector3(0.12, 0.62, 0.0)
		"leg_right":
			n.position = Vector3(-0.12, 0.62, 0.0)
		"core":
			n.position = Vector3(0.0, 1.34, 0.11)


static func home_offset(id: String) -> Vector3:
	## Static mirror of _apply_home, used by the assembly animation and the
	## hologram without instantiating a factory.
	match id:
		"spine": return Vector3(0.0, 0.98, -0.02)
		"pelvis": return Vector3(0.0, 0.86, 0.0)
		"chest": return Vector3(0.0, 1.34, 0.0)
		"back": return Vector3(0.0, 1.32, -0.13)
		"helmet": return Vector3(0.0, 1.68, 0.0)
		"arm_left": return Vector3(0.24, 1.42, 0.0)
		"arm_right": return Vector3(-0.24, 1.42, 0.0)
		"forearm_left": return Vector3(0.28, 1.06, 0.02)
		"forearm_right": return Vector3(-0.28, 1.06, 0.02)
		"hand_left": return Vector3(0.3, 0.82, 0.04)
		"hand_right": return Vector3(-0.3, 0.82, 0.04)
		"leg_left": return Vector3(0.12, 0.62, 0.0)
		"leg_right": return Vector3(-0.12, 0.62, 0.0)
		"core": return Vector3(0.0, 1.34, 0.11)
	return Vector3.ZERO


# ===========================================================================
# Parts
# ===========================================================================

func _red() -> StandardMaterial3D:
	return ML.armour_red()


func _gold() -> StandardMaterial3D:
	return ML.armour_gold()


func _dark() -> StandardMaterial3D:
	return ML.steel_dark()


func _spine() -> Node3D:
	## The structural spine: recycled chrome-moly tubing with the rickshaw axle
	## bracket welded on as the pelvis interface.
	var n := Node3D.new()
	n.name = "Spine"
	var vert: MeshInstance3D = ShapeKit.cyl(0.045, 0.34, ML.steel(), 12, Vector3i(0, 1, 0), "Column")
	n.add_child(vert)
	for i: int in range(4):
		var ring: MeshInstance3D = ShapeKit.torus(0.05, 0.012, _dark(), 14, 6, "Vertebra%02d" % i)
		ring.position = Vector3(0.0, -0.13 + float(i) * 0.09, 0.0)
		n.add_child(ring)
		var damper: MeshInstance3D = ShapeKit.cyl(0.014, 0.1, ML.chrome(), 8, Vector3i(0, 1, 0), "Damper")
		damper.position = Vector3(0.055, -0.09 + float(i) * 0.09, -0.02)
		n.add_child(damper)
	var bracket: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.06, 0.1), ML.weld_bead(), "AxleBracket")
	bracket.position = Vector3(0.0, -0.19, 0.02)
	n.add_child(bracket)
	var rail_a: MeshInstance3D = ShapeKit.frame_tube(Vector3(-0.06, 0.17, 0.0), Vector3(-0.06, -0.17, 0.04), 0.014, ML.steel_dark(), "GuideRailA")
	n.add_child(rail_a)
	var rail_b: MeshInstance3D = ShapeKit.frame_tube(Vector3(0.06, 0.17, 0.0), Vector3(0.06, -0.17, 0.04), 0.014, ML.steel_dark(), "GuideRailB")
	n.add_child(rail_b)
	return n


func _pelvis() -> Node3D:
	var n := Node3D.new()
	n.name = "Pelvis"
	var belt: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.1, -0.05), Vector2(0.15, -0.04), Vector2(0.16, 0.0), Vector2(0.155, 0.05),
		Vector2(0.11, 0.06), Vector2(0.1, 0.05),
	]), 20, _red(), false, "Belt")
	n.add_child(belt)
	for i: int in range(2):
		var hip: MeshInstance3D = ShapeKit.sphere(0.06, _dark(), 12, "HipSocket")
		hip.position = Vector3(0.12 * (1.0 if i == 0 else -1.0), -0.02, 0.0)
		hip.scale = Vector3(0.8, 1.0, 0.9)
		n.add_child(hip)
		var guard: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
			Vector2(0.03, 0.0), Vector2(0.075, 0.01), Vector2(0.085, 0.05), Vector2(0.06, 0.09),
			Vector2(0.03, 0.1),
		]), 14, _gold(), false, "HipGuard")
		guard.position = hip.position + Vector3(0.02 * (1.0 if i == 0 else -1.0), -0.06, 0.02)
		guard.rotation = Vector3(0.2, 0.0, 0.3 * (1.0 if i == 0 else -1.0))
		n.add_child(guard)
	var cell: MeshInstance3D = ShapeKit.box(Vector3(0.12, 0.05, 0.06), _dark(), "BufferCell")
	cell.position = Vector3(0.0, -0.01, -0.09)
	n.add_child(cell)
	var led: MeshInstance3D = ShapeKit.sphere(0.008, ML.hologram_glow(Color("5fd08a"), 0.0), 8, "StatusLed")
	led.position = Vector3(0.0, 0.02, 0.09)
	n.add_child(led)
	return n


func _chest() -> Node3D:
	## The chest plate: hand-formed from a roof sheet, with the core bezel, the
	## collar, the shoulder yokes and the vent louvres.
	var n := Node3D.new()
	n.name = "Chest"
	var shell: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.02, -0.2), Vector2(0.19, -0.19), Vector2(0.23, -0.1), Vector2(0.24, 0.02),
		Vector2(0.21, 0.14), Vector2(0.14, 0.2), Vector2(0.05, 0.22), Vector2(0.02, 0.2),
	]), 24, _red(), false, "Shell")
	shell.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	shell.scale = Vector3(1.0, 1.0, 0.62)
	n.add_child(shell)
	# sternum ridge, the crease a hand-beaten sheet always keeps
	var ridge: MeshInstance3D = ShapeKit.box(Vector3(0.03, 0.3, 0.05), _gold(), "Sternum")
	ridge.position = Vector3(0.0, 0.0, 0.13)
	n.add_child(ridge)
	# core bezel, from a salvaged brake drum
	var bezel: MeshInstance3D = ShapeKit.torus(0.085, 0.02, ML.cast_iron(), 22, 7, "CoreBezel")
	bezel.position = Vector3(0.0, 0.02, 0.14)
	n.add_child(bezel)
	ShapeKit.bolt_ring(6, 0.085, 0.008, ML.steel_dark(), n)
	(bezel.get_parent() as Node3D).set_meta("bezel_path", "CoreBezel")
	var housing: MeshInstance3D = ShapeKit.cyl(0.08, 0.05, _dark(), 20, Vector3i(0, 0, 1), "CoreHousing")
	housing.position = Vector3(0.0, 0.02, 0.1)
	n.add_child(housing)
	# vent louvres
	for i: int in range(4):
		var louver: MeshInstance3D = ShapeKit.box(Vector3(0.11, 0.008, 0.02), _dark(), "Louver%02d" % i)
		louver.position = Vector3(0.09, -0.12 + float(i) * 0.03, 0.12)
		louver.rotation.x = 0.4
		n.add_child(louver)
	# collar and neck ring
	var collar: MeshInstance3D = ShapeKit.torus(0.075, 0.022, _gold(), 18, 6, "Collar")
	collar.position = Vector3(0.0, 0.22, 0.0)
	n.add_child(collar)
	# asymmetric shoulders: layered pauldron right, open ring left
	var pauldron: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.02, 0.0), Vector2(0.11, 0.005), Vector2(0.13, 0.04), Vector2(0.12, 0.08),
		Vector2(0.06, 0.1), Vector2(0.02, 0.1),
	]), 18, _red(), false, "PauldronRight")
	pauldron.position = Vector3(-0.22, 0.16, 0.0)
	pauldron.rotation = Vector3(0.0, 0.0, 1.35)
	n.add_child(pauldron)
	var layer: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.04, 0.0), Vector2(0.1, 0.01), Vector2(0.105, 0.03), Vector2(0.06, 0.04),
	]), 16, _gold(), false, "PauldronLayer")
	layer.position = Vector3(-0.24, 0.19, 0.0)
	layer.rotation = Vector3(0.0, 0.0, 1.35)
	n.add_child(layer)
	var ring: MeshInstance3D = ShapeKit.torus(0.1, 0.024, _red(), 20, 7, "ShoulderRingLeft")
	ring.position = Vector3(0.22, 0.16, 0.0)
	ring.rotation = Vector3(PI * 0.5, 0.3, 0.0)
	n.add_child(ring)
	var hoop: MeshInstance3D = ShapeKit.torus(0.115, 0.012, _gold(), 20, 6, "HoopLeft")
	hoop.position = ring.position
	hoop.rotation = Vector3(PI * 0.5, 0.3, 0.4)
	n.add_child(hoop)
	# hydraulic lifters from chest to shoulders
	for i: int in range(2):
		var s: float = 1.0 if i == 0 else -1.0
		n.add_child(ShapeKit.frame_tube(Vector3(0.05 * s, 0.1, -0.06), Vector3(0.2 * s, 0.16, 0.0), 0.016, ML.chrome(), "Lifter"))
		n.add_child(ShapeKit.frame_tube(Vector3(0.09 * s, 0.02, -0.08), Vector3(0.21 * s, 0.1, 0.01), 0.012, _dark(), "TieRod"))
	# rivets along the plate edge
	for i: int in range(10):
		var a: float = -0.6 + float(i) * 0.13
		var rivet: MeshInstance3D = ShapeKit.sphere(0.007, _gold(), 6, "Rivet")
		rivet.position = Vector3(sin(a) * 0.2, cos(a) * 0.19, 0.12)
		rivet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(rivet)
	return n


func _back() -> Node3D:
	## The back plate and the buffer pack it carries.
	var n := Node3D.new()
	n.name = "Back"
	var plate: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.02, -0.16), Vector2(0.17, -0.15), Vector2(0.2, -0.05), Vector2(0.19, 0.09),
		Vector2(0.13, 0.16), Vector2(0.04, 0.18), Vector2(0.02, 0.16),
	]), 22, _dark(), false, "Plate")
	plate.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	plate.scale = Vector3(1.0, 1.0, 0.6)
	n.add_child(plate)
	var pack: MeshInstance3D = ShapeKit.box(Vector3(0.22, 0.26, 0.09), _red(), "BufferPack")
	pack.position = Vector3(0.0, 0.0, -0.07)
	n.add_child(pack)
	for i: int in range(3):
		var cell: MeshInstance3D = ShapeKit.cyl(0.035, 0.2, ML.lead_terminal(), 12, Vector3i(0, 1, 0), "Cell%02d" % i)
		cell.position = Vector3(-0.06 + float(i) * 0.06, 0.02, -0.12)
		n.add_child(cell)
	var fin: MeshInstance3D = ShapeKit.box(Vector3(0.24, 0.02, 0.12), ML.aluminium(), "HeatFin")
	fin.position = Vector3(0.0, 0.16, -0.08)
	n.add_child(fin)
	for i: int in range(6):
		var blade: MeshInstance3D = ShapeKit.box(Vector3(0.006, 0.05, 0.11), ML.aluminium(), "Blade")
		blade.position = Vector3(-0.1 + float(i) * 0.04, 0.19, -0.08)
		blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(blade)
	var strap_a: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.3, 0.01), ML.leather_like(), "Strap")
	strap_a.position = Vector3(0.09, 0.0, 0.0)
	n.add_child(strap_a)
	var strap_b: MeshInstance3D = strap_a.duplicate() as MeshInstance3D
	strap_b.position = Vector3(-0.09, 0.0, 0.0)
	strap_b.name = "StrapB"
	n.add_child(strap_b)
	var port: MeshInstance3D = ShapeKit.cyl(0.022, 0.03, _gold(), 12, Vector3i(0, 0, 1), "UmbilicalPort")
	port.position = Vector3(0.0, -0.1, -0.11)
	n.add_child(port)
	return n


func _helmet() -> Node3D:
	## The helmet: a horizontal visor slit, an external jaw guard, the side
	## intakes and the rear sensor stalk. Deliberately unlike the movie's
	## faceplate, and visibly hand-formed.
	var n := Node3D.new()
	n.name = "Helmet"
	var skull: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.02, -0.11), Vector2(0.085, -0.1), Vector2(0.105, -0.04), Vector2(0.108, 0.03),
		Vector2(0.095, 0.09), Vector2(0.06, 0.125), Vector2(0.02, 0.135),
	]), 22, _red(), false, "Skull")
	n.add_child(skull)
	# brow band in brass
	var brow: MeshInstance3D = ShapeKit.torus(0.1, 0.014, _gold(), 22, 6, "Brow")
	brow.position = Vector3(0.0, 0.03, 0.0)
	n.add_child(brow)
	# visor slit with the glow
	var slit: MeshInstance3D = ShapeKit.box(Vector3(0.14, 0.022, 0.02), _dark(), "VisorFrame")
	slit.position = Vector3(0.0, 0.02, 0.095)
	n.add_child(slit)
	var eye_l: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.014, 0.006), ML.hologram_glow(Color("9ff0ff"), 0.0), "EyeLeft")
	eye_l.position = Vector3(0.036, 0.022, 0.106)
	n.add_child(eye_l)
	var eye_r: MeshInstance3D = eye_l.duplicate() as MeshInstance3D
	eye_r.position = Vector3(-0.036, 0.022, 0.106)
	eye_r.name = "EyeRight"
	n.add_child(eye_r)
	# jaw guard
	var jaw: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.02, -0.09), Vector2(0.09, -0.085), Vector2(0.1, -0.05), Vector2(0.085, -0.02),
		Vector2(0.03, -0.015),
	]), 18, _dark(), false, "JawGuard")
	jaw.rotation = Vector3(0.35, 0.0, 0.0)
	jaw.position = Vector3(0.0, -0.02, 0.02)
	n.add_child(jaw)
	# side intakes
	for i: int in range(2):
		var s: float = 1.0 if i == 0 else -1.0
		var intake: MeshInstance3D = ShapeKit.cyl(0.028, 0.03, _gold(), 12, Vector3i(0, 0, 1), "Intake")
		intake.position = Vector3(0.095 * s, -0.01, 0.02)
		intake.rotation.y = PI * 0.5 * s
		n.add_child(intake)
		for k: int in range(3):
			var slot: MeshInstance3D = ShapeKit.box(Vector3(0.004, 0.03, 0.05), _dark(), "Slot")
			slot.position = intake.position + Vector3(0.016 * s, 0.0, -0.012 + float(k) * 0.012)
			slot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(slot)
		# ear pivot
		var pivot: MeshInstance3D = ShapeKit.sphere(0.022, _red(), 10, "EarPivot")
		pivot.position = Vector3(0.1 * s, 0.03, -0.01)
		n.add_child(pivot)
	# rear sensor stalk
	var stalk: MeshInstance3D = ShapeKit.cyl(0.008, 0.07, ML.steel(), 8, Vector3i(0, 0, 1), "SensorStalk")
	stalk.position = Vector3(0.05, 0.09, -0.09)
	stalk.rotation = Vector3(-0.6, 0.3, 0.0)
	n.add_child(stalk)
	var lens: MeshInstance3D = ShapeKit.sphere(0.012, ML.hologram_glow(Color("ffb347"), 0.0), 8, "SensorLens")
	lens.position = stalk.position + Vector3(0.0, 0.02, -0.03)
	n.add_child(lens)
	# crest ridge
	var crest: MeshInstance3D = ShapeKit.box(Vector3(0.02, 0.03, 0.14), _gold(), "Crest")
	crest.position = Vector3(0.0, 0.12, -0.01)
	n.add_child(crest)
	n.set_meta("eye_left_path", "EyeLeft")
	n.set_meta("eye_right_path", "EyeRight")
	return n


func _arm(side: float) -> Node3D:
	## Upper arm: a socket, a tube, an exposed biceps hydraulic and the elbow.
	var n := Node3D.new()
	n.name = "Arm"
	var socket: MeshInstance3D = ShapeKit.sphere(0.055, _dark(), 14, "Socket")
	n.add_child(socket)
	var cap: MeshInstance3D = ShapeKit.torus(0.05, 0.012, _gold(), 16, 6, "SocketCap")
	n.add_child(cap)
	var upper: MeshInstance3D = ShapeKit.cyl(0.042, 0.28, _red(), 14, Vector3i(0, 1, 0), "Upper")
	upper.position = Vector3(0.0, -0.16, 0.0)
	n.add_child(upper)
	var plate: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.03, 0.0), Vector2(0.055, 0.01), Vector2(0.058, 0.1), Vector2(0.05, 0.16),
		Vector2(0.03, 0.17),
	]), 16, _red(), false, "BicepGuard")
	plate.position = Vector3(0.0, -0.24, 0.03)
	plate.scale = Vector3(1.0, 1.0, 0.7)
	n.add_child(plate)
	# exposed hydraulic
	var cyl_body: MeshInstance3D = ShapeKit.cyl(0.018, 0.14, ML.chrome(), 10, Vector3i(0, 1, 0), "Hydraulic")
	cyl_body.position = Vector3(0.045 * side, -0.15, -0.03)
	n.add_child(cyl_body)
	var sleeve: MeshInstance3D = ShapeKit.cyl(0.024, 0.07, _dark(), 10, Vector3i(0, 1, 0), "HydraulicSleeve")
	sleeve.position = Vector3(0.045 * side, -0.22, -0.03)
	n.add_child(sleeve)
	# elbow
	var elbow: MeshInstance3D = ShapeKit.cyl(0.042, 0.07, _dark(), 14, Vector3i(0, 0, 1), "Elbow")
	elbow.position = Vector3(0.0, -0.31, 0.0)
	n.add_child(elbow)
	var gear: MeshInstance3D = ShapeKit.gear(14, 3.0, 0.012, 0.014, ML.steel_hardened(), "ElbowGear")
	gear.position = Vector3(0.038 * side, -0.31, 0.0)
	gear.rotation.z = PI * 0.5
	n.add_child(gear)
	var led: MeshInstance3D = ShapeKit.sphere(0.007, ML.hologram_glow(Color("4fd8ff"), 0.0), 8, "JointLed")
	led.position = Vector3(0.0, -0.31, 0.045)
	n.add_child(led)
	return n


func _forearm(side: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Forearm"
	var body: MeshInstance3D = ShapeKit.cyl(0.038, 0.26, _red(), 14, Vector3i(0, 1, 0), "Body")
	body.position = Vector3(0.0, -0.13, 0.0)
	n.add_child(body)
	var cuff: MeshInstance3D = ShapeKit.torus(0.042, 0.014, _gold(), 18, 6, "Cuff")
	cuff.position = Vector3(0.0, -0.01, 0.0)
	n.add_child(cuff)
	# the forearm tool housing: three vented modules, the DIY answer to
	# "the suit needs a diagnostic emitter here"
	var housing: MeshInstance3D = ShapeKit.box(Vector3(0.06, 0.14, 0.05), _dark(), "ToolHousing")
	housing.position = Vector3(0.032 * side, -0.14, 0.02)
	n.add_child(housing)
	for i: int in range(3):
		var vent: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.008, 0.006), ML.hologram_glow(Color("4fd8ff"), 0.0), "Vent%02d" % i)
		vent.position = housing.position + Vector3(0.0, -0.04 + float(i) * 0.04, 0.028)
		vent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(vent)
	var emitter: MeshInstance3D = ShapeKit.cyl(0.016, 0.03, _gold(), 12, Vector3i(0, 1, 0), "Emitter")
	emitter.position = housing.position + Vector3(0.0, 0.09, 0.0)
	n.add_child(emitter)
	# knuckle guard
	var guard: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.02, 0.0), Vector2(0.048, 0.005), Vector2(0.052, 0.04), Vector2(0.04, 0.06),
		Vector2(0.02, 0.062),
	]), 14, _red(), false, "KnuckleGuard")
	guard.position = Vector3(0.0, -0.27, 0.0)
	n.add_child(guard)
	var wrist: MeshInstance3D = ShapeKit.cyl(0.03, 0.04, _dark(), 12, Vector3i(0, 1, 0), "Wrist")
	wrist.position = Vector3(0.0, -0.29, 0.0)
	n.add_child(wrist)
	return n


func _hand(side: float) -> Node3D:
	## A gloved manipulator: palm block, four fingers and an opposable thumb.
	## No weapons, no claws — the brief requires a non-weaponised prototype.
	var n := Node3D.new()
	n.name = "Hand"
	var palm: MeshInstance3D = ShapeKit.box(Vector3(0.055, 0.085, 0.03), _dark(), "Palm")
	n.add_child(palm)
	var back_plate: MeshInstance3D = ShapeKit.box(Vector3(0.05, 0.07, 0.008), _red(), "BackPlate")
	back_plate.position = Vector3(0.0, 0.005, 0.019)
	n.add_child(back_plate)
	var knuckle: MeshInstance3D = ShapeKit.torus(0.028, 0.008, _gold(), 14, 5, "Knuckle")
	knuckle.position = Vector3(0.0, 0.045, 0.0)
	n.add_child(knuckle)
	for i: int in range(4):
		var finger := Node3D.new()
		finger.name = "Finger%d" % i
		finger.position = Vector3(-0.021 + float(i) * 0.014, 0.055, 0.0)
		n.add_child(finger)
		var p1: MeshInstance3D = ShapeKit.box(Vector3(0.012, 0.028, 0.014), _dark(), "P1")
		p1.position = Vector3(0.0, 0.014, 0.0)
		finger.add_child(p1)
		var p2: MeshInstance3D = ShapeKit.box(Vector3(0.011, 0.024, 0.013), _red(), "P2")
		p2.position = Vector3(0.0, 0.038, 0.004)
		p2.rotation.x = -0.35
		finger.add_child(p2)
		var tip: MeshInstance3D = ShapeKit.sphere(0.007, ML.rubber(), 6, "Tip")
		tip.position = Vector3(0.0, 0.052, 0.012)
		finger.add_child(tip)
	var thumb := Node3D.new()
	thumb.name = "Thumb"
	thumb.position = Vector3(0.03 * side, 0.01, 0.015)
	thumb.rotation = Vector3(0.4, 0.0, 0.9 * side)
	n.add_child(thumb)
	var t1: MeshInstance3D = ShapeKit.box(Vector3(0.014, 0.03, 0.016), _dark(), "T1")
	t1.position = Vector3(0.0, 0.015, 0.0)
	thumb.add_child(t1)
	var t2: MeshInstance3D = ShapeKit.box(Vector3(0.013, 0.026, 0.015), _red(), "T2")
	t2.position = Vector3(0.0, 0.038, 0.004)
	t2.rotation.x = -0.3
	thumb.add_child(t2)
	return n


func _leg(side: float) -> Node3D:
	## Thigh, knee with the gear reduction, shin, and the boot with the ankle
	## hydraulic. The legs carry the suit's weight on the stand, so they are the
	## heaviest-plated parts.
	var n := Node3D.new()
	n.name = "Leg"
	var socket: MeshInstance3D = ShapeKit.sphere(0.06, _dark(), 12, "HipSocket")
	n.add_child(socket)
	var thigh: MeshInstance3D = ShapeKit.cyl(0.052, 0.36, _red(), 14, Vector3i(0, 1, 0), "Thigh")
	thigh.position = Vector3(0.0, -0.2, 0.0)
	n.add_child(thigh)
	var guard: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.035, 0.0), Vector2(0.068, 0.01), Vector2(0.072, 0.14), Vector2(0.06, 0.24),
		Vector2(0.035, 0.26),
	]), 18, _red(), false, "ThighGuard")
	guard.position = Vector3(0.0, -0.34, 0.035 * side)
	guard.scale = Vector3(1.0, 1.0, 0.7)
	n.add_child(guard)
	var hydraulic: MeshInstance3D = ShapeKit.cyl(0.02, 0.18, ML.chrome(), 10, Vector3i(0, 1, 0), "ThighHydraulic")
	hydraulic.position = Vector3(0.035 * side, -0.2, -0.04)
	n.add_child(hydraulic)
	# knee
	var knee: MeshInstance3D = ShapeKit.cyl(0.05, 0.08, _dark(), 14, Vector3i(0, 0, 1), "Knee")
	knee.position = Vector3(0.0, -0.4, 0.0)
	n.add_child(knee)
	var gear: MeshInstance3D = ShapeKit.gear(16, 3.4, 0.014, 0.016, ML.steel_hardened(), "KneeGear")
	gear.position = Vector3(0.048 * side, -0.4, 0.0)
	gear.rotation.z = PI * 0.5
	n.add_child(gear)
	var cap: MeshInstance3D = ShapeKit.sphere(0.04, _gold(), 12, "KneeCap")
	cap.position = Vector3(0.0, -0.4, 0.045)
	cap.scale = Vector3(1.0, 1.0, 0.6)
	n.add_child(cap)
	# shin
	var shin: MeshInstance3D = ShapeKit.cyl(0.045, 0.34, _red(), 14, Vector3i(0, 1, 0), "Shin")
	shin.position = Vector3(0.0, -0.62, 0.0)
	n.add_child(shin)
	var shin_guard: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.03, 0.0), Vector2(0.058, 0.01), Vector2(0.062, 0.12), Vector2(0.05, 0.22),
		Vector2(0.03, 0.24),
	]), 16, _gold(), false, "ShinGuard")
	shin_guard.position = Vector3(0.0, -0.76, 0.03)
	shin_guard.scale = Vector3(1.0, 1.0, 0.65)
	n.add_child(shin_guard)
	var calf: MeshInstance3D = ShapeKit.cyl(0.026, 0.2, _dark(), 10, Vector3i(0, 1, 0), "Calf")
	calf.position = Vector3(0.0, -0.62, -0.045)
	n.add_child(calf)
	# ankle and boot
	var ankle: MeshInstance3D = ShapeKit.sphere(0.038, _dark(), 10, "Ankle")
	ankle.position = Vector3(0.0, -0.81, 0.0)
	n.add_child(ankle)
	var boot: MeshInstance3D = ShapeKit.box(Vector3(0.09, 0.06, 0.2), _red(), "Boot")
	boot.position = Vector3(0.0, -0.86, 0.045)
	n.add_child(boot)
	var sole: MeshInstance3D = ShapeKit.box(Vector3(0.095, 0.02, 0.21), ML.rubber(), "Sole")
	sole.position = Vector3(0.0, -0.895, 0.045)
	n.add_child(sole)
	var toe: MeshInstance3D = ShapeKit.lathe(PackedVector2Array([
		Vector2(0.02, 0.0), Vector2(0.045, 0.005), Vector2(0.05, 0.03), Vector2(0.03, 0.04),
	]), 12, _gold(), false, "ToeCap")
	toe.position = Vector3(0.0, -0.88, 0.15)
	toe.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	n.add_child(toe)
	var toe_led: MeshInstance3D = ShapeKit.sphere(0.008, ML.hologram_glow(Color("4fd8ff"), 0.0), 8, "StepLed")
	toe_led.position = Vector3(0.0, -0.85, 0.16)
	n.add_child(toe_led)
	return n


func _core() -> Node3D:
	## The fictional chest core. Geometry only; the energy-core system swaps in
	## the shader material and drives the pulse.
	var n := Node3D.new()
	n.name = "PowerCore"
	var body: MeshInstance3D = ShapeKit.sphere(0.055, null, 22, "CoreBody")
	n.add_child(body)
	var face: MeshInstance3D = ShapeKit.disc(0.052, 0.008, null, "CoreFace", 22)
	face.position = Vector3(0.0, 0.0, 0.03)
	n.add_child(face)
	var ring_a: MeshInstance3D = ShapeKit.torus(0.062, 0.008, _gold(), 20, 6, "RingA")
	n.add_child(ring_a)
	var ring_b: MeshInstance3D = ShapeKit.torus(0.07, 0.006, ML.steel(), 20, 6, "RingB")
	n.add_child(ring_b)
	var ring_c: MeshInstance3D = ShapeKit.torus(0.078, 0.005, _gold(), 22, 6, "RingC")
	ring_c.rotation = Vector3(0.6, 0.4, 0.0)
	n.add_child(ring_c)
	for i: int in range(6):
		var a: float = ShapeKit.TAU_K * float(i) / 6.0
		var lug: MeshInstance3D = ShapeKit.box(Vector3(0.012, 0.012, 0.02), _dark(), "Lug%02d" % i)
		lug.position = Vector3(cos(a) * 0.062, sin(a) * 0.062, 0.0)
		lug.rotation.z = a
		lug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(lug)
	n.set_meta("core_body", "CoreBody")
	n.set_meta("core_face", "CoreFace")
	n.set_meta("ring_paths", PackedStringArray(["RingA", "RingB", "RingC"]))
	return n


# ===========================================================================
# Assembly staging
# ===========================================================================

## Groups the fourteen parts into the three crate modules, so installing a module
## reveals a coherent body section rather than one arbitrary mesh.
static func module_parts(module_id: String) -> Array[String]:
	match module_id:
		"frame_module":
			return ["spine", "pelvis", "leg_left", "leg_right"]
		"energy_module":
			return ["core", "back"]
		"armour_shell":
			return ["chest", "helmet", "arm_left", "arm_right", "forearm_left",
				"forearm_right", "hand_left", "hand_right"]
	return []


## The order parts attach in during the assembly animation.
static func attach_order() -> Array[String]:
	return ["spine", "pelvis", "leg_left", "leg_right", "back", "core",
		"chest", "arm_left", "arm_right", "forearm_left", "forearm_right",
		"hand_left", "hand_right", "helmet"]
