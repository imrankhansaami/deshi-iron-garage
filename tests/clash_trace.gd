extends SceneTree
## Traces the exact mesh pairs behind a clash reported by overlap_deep.gd.
## Given two prop names (dressing children, matched by prefix), it walks the
## MeshInstance3D descendants of both and prints every intersecting mesh pair
## with node paths, world boxes and overlap sizes, worst first.
##
## Usage:  godot --headless --path . -s res://tests/clash_trace.gd -- Workbench HoloTable

func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		print("TRACE: needs two prop names, e.g. -- Workbench HoloTable")
		quit()
		return
	var scene: PackedScene = load("res://scenes/main/garage_world.tscn")
	var world: Node3D = scene.instantiate() as Node3D
	root.add_child(world)
	var frames: int = 0
	while not bool(world.get("build_complete")) and frames < 6000:
		await process_frame
		frames += 1
	var dressing: Node = world.get("dressing")
	var a: Node3D = _find(dressing, String(args[0]))
	var b: Node3D = _find(dressing, String(args[1]))
	if a == null or b == null:
		print("TRACE: %s -> %s, %s -> %s" % [args[0], "found" if a != null else "MISSING", args[1], "found" if b != null else "MISSING"])
		quit()
		return
	var ma: Array = []
	var mb: Array = []
	_collect(a, ma)
	_collect(b, mb)
	var hits: Array = []
	for ea: Dictionary in ma:
		for eb: Dictionary in mb:
			var ba: AABB = ea["box"]
			var bb: AABB = eb["box"]
			if not ba.intersects(bb):
				continue
			var inter: AABB = ba.intersection(bb)
			var vol: float = inter.size.x * inter.size.y * inter.size.z
			var thin: float = minf(inter.size.x, minf(inter.size.y, inter.size.z))
			if vol < 0.00001 or thin < 0.005:
				continue
			hits.append({"a": ea, "b": eb, "vol": vol, "inter": inter})
	hits.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["vol"] > y["vol"])
	print("TRACE: %s (%d meshes) x %s (%d meshes): %d intersecting mesh pairs" % [a.name, ma.size(), b.name, mb.size(), hits.size()])
	for h: Dictionary in hits:
		var ia: Dictionary = h["a"]
		var ib: Dictionary = h["b"]
		var inter: AABB = h["inter"]
		print("  #1 %s  box=(%.2f..%.2f, %.2f..%.2f, %.2f..%.2f)" % [
			ia["path"], ia["box"].position.x, ia["box"].end.x, ia["box"].position.y, ia["box"].end.y, ia["box"].position.z, ia["box"].end.z])
		print("  #2 %s  box=(%.2f..%.2f, %.2f..%.2f, %.2f..%.2f)" % [
			ib["path"], ib["box"].position.x, ib["box"].end.x, ib["box"].position.y, ib["box"].end.y, ib["box"].position.z, ib["box"].end.z])
		print("     overlap %.1f x %.1f x %.1f cm, %.0f cm3" % [inter.size.x * 100.0, inter.size.y * 100.0, inter.size.z * 100.0, inter.size.x * inter.size.y * inter.size.z * 1000000.0])
	quit()


func _find(dressing: Node, prefix: String) -> Node3D:
	for child: Node in dressing.get_children():
		if child is Node3D and String(child.name).begins_with(prefix):
			return child
	return null


func _collect(node: Node, out: Array) -> void:
	if node is MeshInstance3D:
		var self_mi: MeshInstance3D = node
		if self_mi.mesh != null:
			out.append({"path": node.get_path(), "box": self_mi.global_transform * self_mi.get_aabb()})
	for child: Node in node.get_children():
		_collect(child, out)
