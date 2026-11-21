extends SceneTree
## Deep overlap audit v2 — mesh-level clash detection that survives checking.
##
## v1 transformed each mesh's local AABB by the node transform, which inflates
## boxes for rotated props (a yawed cylinder's box grows up to 41%), so a long
## list of "clashes" were rotation ghosts. v2:
##   1. computes each mesh's true world box from its vertices (tight AABB);
##   2. for meshes with many triangles (cables, rings, curls) samples the actual
##      vertices against the other mesh's box — a cable passing clear above a
##      shape no longer reports;
##   3. for box-like pairs, requires a real sink in every axis.
##
## Usage:  godot --headless --path . -s res://tests/overlap_deep.gd

const CURVE_TRIS: int = 160
const MIN_SINK: float = 0.02
const BOX_SINK: float = 0.035
const MIN_VOL: float = 0.00012

## Contacts that are part of the build, not mistakes — gripped, clamped, seated or
## hidden by design. Reported separately so the "genuine" count stays honest.
const DESIGNED: Array = [
	{"a": "AssemblyPlatform", "b": "PrototypeExosuit", "why": "the suit's lower legs pass into the reactor pedestal drum; the feet are inside it, out of sight"},
	{"a": "AssemblyPlatform", "b": "SuitStand", "why": "the stand's collar seats inside the pit and the braces land on the cradle's backplate"},
	{"a": "Workbench", "b": "WorkbenchLamp", "why": "the lamp's clamp grips the bench top"},
	{"a": "SuitStand", "b": "PrototypeExosuit", "why": "the cradle and head yoke grip the suit"},
]

var _face_cache: Dictionary = {}


func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/garage_world.tscn")
	var world: Node3D = scene.instantiate() as Node3D
	root.add_child(world)
	var frames: int = 0
	while not bool(world.get("build_complete")) and frames < 6000:
		await process_frame
		frames += 1
	var dressing: Node = world.get("dressing")
	var items: Array = []
	for child: Node in dressing.get_children():
		if not (child is Node3D):
			continue
		var item_name: String = String(child.name)
		if item_name.begins_with("Grime") or item_name.begins_with("Cable") or item_name.begins_with("@") or item_name.begins_with("Lane") or item_name.begins_with("Joint") or item_name.begins_with("Drain") or item_name.begins_with("Course"):
			continue
		var meshes: Array = []
		_collect(child, meshes)
		if meshes.is_empty():
			continue
		items.append({"name": item_name, "meshes": meshes})
	print("DEEP: %d items, mesh-level pairwise (tight boxes, vertex sampling)" % items.size())
	var hits: Array = []
	for a: int in range(items.size()):
		for b: int in range(a + 1, items.size()):
			var found: Dictionary = _pair_worst(items[a]["meshes"], items[b]["meshes"])
			if not found.is_empty():
				found["a"] = items[a]["name"]
				found["b"] = items[b]["name"]
				hits.append(found)
	hits.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["vol"] > y["vol"])
	var designed: Array = []
	var genuine: Array = []
	for h: Dictionary in hits:
		if _is_designed(String(h["a"]), String(h["b"])):
			designed.append(h)
		else:
			genuine.append(h)
	print("DEEP: %d genuine clashes, %d designed contacts" % [genuine.size(), designed.size()])
	for h: Dictionary in genuine:
		var sz: Vector3 = h["sz"]
		print("DEEP: %-24s x %-24s %-6s vol=%.0f cm3  sink=%.1f/%.1f/%.1f cm  at (%.2f, %.2f, %.2f)" % [
			h["a"], h["b"], h["kind"], h["vol"] * 1000000.0,
			sz.x * 100.0, sz.y * 100.0, sz.z * 100.0, h["at"].x, h["at"].y, h["at"].z])
	for h: Dictionary in designed:
		print("DESIGNED: %s x %s — %s" % [h["a"], h["b"], _why_designed(String(h["a"]), String(h["b"]))])


func _is_designed(a: String, b: String) -> bool:
	for d: Dictionary in DESIGNED:
		if (String(d["a"]) == a and String(d["b"]) == b) or (String(d["a"]) == b and String(d["b"]) == a):
			return true
	return false


func _why_designed(a: String, b: String) -> String:
	for d: Dictionary in DESIGNED:
		if (String(d["a"]) == a and String(d["b"]) == b) or (String(d["a"]) == b and String(d["b"]) == a):
			return String(d["why"])
	return ""


func _pair_worst(ma: Array, mb: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_vol: float = 0.0
	for ea: Dictionary in ma:
		for eb: Dictionary in mb:
			var ba: AABB = ea["aabb"]
			var bb: AABB = eb["aabb"]
			if not ba.intersects(bb):
				continue
			var inter: AABB = ba.intersection(bb)
			var vol: float = inter.size.x * inter.size.y * inter.size.z
			if vol < MIN_VOL:
				continue
			var verdict: Dictionary = _refine(ea, eb, inter)
			if verdict.is_empty():
				continue
			if vol > best_vol:
				best_vol = vol
				best = {"vol": vol, "at": inter.get_center(), "kind": verdict["kind"], "sz": inter.size}
	return best


func _refine(ea: Dictionary, eb: Dictionary, inter: AABB) -> Dictionary:
	var curved_a: bool = ea["tris"] > CURVE_TRIS
	var curved_b: bool = eb["tris"] > CURVE_TRIS
	if curved_a or curved_b:
		# sample the curved mesh's vertices against the other's box
		var deep_a: float = 0.0
		if curved_a:
			deep_a = _points_inside(ea["points"], eb["aabb"])
		var deep_b: float = 0.0
		if curved_b:
			deep_b = _points_inside(eb["points"], ea["aabb"])
		var deep: float = 0.0
		if curved_a and curved_b:
			# two curves: require the mutual sample, otherwise one curve's
			# bounding box manufactures a hit for the other's points
			deep = minf(deep_a, deep_b)
		else:
			deep = maxf(deep_a, deep_b)
		if deep >= MIN_SINK:
			return {"kind": "curve"}
		return {}
	else:
		var sink: float = minf(inter.size.x, minf(inter.size.y, inter.size.z))
		if sink >= BOX_SINK:
			# A long rotated box's AABB can cover a small box's AABB while the
			# real meshes are far apart (the conduit-vs-fence-post case: boxes
			# touch, the tube passes 40 cm away). A box-tier clash also needs a
			# vertex of one mesh inside the other's box, or a sink deep enough
			# that no corner geometry could miss it.
			var corner: float = maxf(_points_inside(ea["points"], eb["aabb"]), _points_inside(eb["points"], ea["aabb"]))
			if corner >= 0.02 or sink >= 0.12:
				return {"kind": "box"}
		return {}


func _points_inside(points: PackedVector3Array, box: AABB) -> float:
	var deep: float = 0.0
	for p: Vector3 in points:
		if p.x <= box.position.x or p.x >= box.end.x:
			continue
		if p.y <= box.position.y or p.y >= box.end.y:
			continue
		if p.z <= box.position.z or p.z >= box.end.z:
			continue
		var d: float = minf(minf(p.x - box.position.x, box.end.x - p.x),
			minf(minf(p.y - box.position.y, box.end.y - p.y),
				minf(p.z - box.position.z, box.end.z - p.z)))
		if d > deep:
			deep = d
	return deep


func _collect(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node
		if mi.mesh != null:
			var key: int = mi.mesh.get_instance_id()
			var local_points: PackedVector3Array
			var local_min: Vector3
			var local_max: Vector3
			if _face_cache.has(key):
				var cached: Array = _face_cache[key]
				local_points = cached[0]
				local_min = cached[1]
				local_max = cached[2]
			else:
				local_points = mi.mesh.get_faces()
				local_min = Vector3(INF, INF, INF)
				local_max = Vector3(-INF, -INF, -INF)
				for p: Vector3 in local_points:
					local_min = local_min.min(p)
					local_max = local_max.max(p)
				_face_cache[key] = [local_points, local_min, local_max]
			var world_points := PackedVector3Array()
			world_points.resize(local_points.size())
			var xf: Transform3D = mi.global_transform
			var box := AABB()
			var first: bool = true
			for i: int in range(local_points.size()):
				var wp: Vector3 = xf * local_points[i]
				world_points[i] = wp
				if first:
					box = AABB(wp, Vector3.ZERO)
					first = false
				else:
					box = box.expand(wp)
			out.append({"aabb": box, "points": world_points, "tris": local_points.size() / 3})
	for child: Node in node.get_children():
		_collect(child, out)
