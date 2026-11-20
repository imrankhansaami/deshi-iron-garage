extends SceneTree
## Headless scene inspector, kept as a development tool: builds the garage and
## prints every node inside a radius of a given floor point, so an unidentified
## object in a capture can be named from the scene graph alone.
##
## Usage:  godot --headless --path . -s res://tests/dump_floor.gd -- <x> <z> <radius>
## Defaults to the walkway in front of the assembly platform.
##
## Note: move capture.flag out of the project root first, or the world's capture
## driver will run its shot sequence while this script waits.

func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var tx: float = float(args[0]) if args.size() > 0 else 0.8
	var tz: float = float(args[1]) if args.size() > 1 else 1.6
	var r: float = float(args[2]) if args.size() > 2 else 2.2
	var scene: PackedScene = load("res://scenes/main/garage_world.tscn")
	var world: Node3D = scene.instantiate() as Node3D
	root.add_child(world)
	var frames: int = 0
	while not bool(world.get("build_complete")) and frames < 6000:
		await process_frame
		frames += 1
	print("DUMP: build_complete=%s after %d frames" % [str(world.get("build_complete")), frames])
	var target := Vector3(tx, 0.0, tz)
	var rows: Array[String] = []
	_collect(world, target, r, rows)
	rows.sort()
	for row: String in rows:
		print("DUMP: ", row)
	print("DUMP: %d nodes within %.1f m of (%.1f, %.1f)" % [rows.size(), r, tx, tz])
	_dump_occupancy(world)
	quit()


func _dump_occupancy(world: Node) -> void:
	## The procedural layouts reject against the dressing pass's `_occupied` AABBs.
	## Two groups placed nothing at all, so print the boxes with their owning
	## stations and test representative layout points against them directly.
	var dressing: Node = world.get("dressing")
	if dressing == null:
		print("DUMP: no dressing")
		return
	var occ: Array = dressing.get("_occupied")
	print("DUMP: _occupied has %d boxes" % occ.size())
	## owner lookup: every CollisionShape3D under a Station, in world space
	var owners: Array[String] = []
	for st: Node in _stations(world):
		var label: String = String(st.get("display_name"))
		for c: Node in st.get_children():
			if c is CollisionShape3D:
				var cs: CollisionShape3D = c as CollisionShape3D
				if cs.shape != null:
					owners.append("%s  %s" % [label, str(cs.global_transform * ShapeKit.shape_aabb_local(cs.shape)).replace("\n", " ")])
	for o: String in owners:
		print("DUMP: station ", o)
	var probes: Array[Vector3] = [
		Vector3(-3.8, 1.1, 1.7),    # mech_bench_top, a y = 1.0 layout point + 0.1
		Vector3(-3.0, 0.13, 0.3),   # scrap_floor_cluster
		Vector3(-3.86, 1.69, -1.15),# mech_shelf_upper (this one works)
	]
	for probe: Vector3 in probes:
		var hits: int = 0
		var detail: String = ""
		for box: AABB in occ:
			if box.has_point(probe):
				hits += 1
				detail += " | %s" % str(box).replace("\n", " ")
		print("DUMP: probe %s -> %d box(es)%s" % [str(probe), hits, detail])
	_bounds_audit(world, "HoloTable")
	_bounds_audit(world, "Workbench")


func _find(node: Node, target: String) -> Node3D:
	for child: Node in node.get_children():
		if child is Node3D and String(child.name) == target:
			return child as Node3D
		var deeper: Node3D = _find(child, target)
		if deeper != null:
			return deeper
	return null


func _bounds_audit(world: Node, node_name: String) -> void:
	## Prints what each child contributes to a node's world bounds, so a box that
	## came out far larger than the object can be traced to the mesh that inflated it.
	var node: Node3D = _find(world, node_name)
	if node == null:
		print("DUMP: audit: %s not found" % node_name)
		return
	var total: AABB = ShapeKit.node_bounds(node)
	print("DUMP: audit %s total %s size %s" % [node_name, str(total.position).replace("\n", " "), str(total.size)])
	for c: Node in node.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh == null:
				continue
			var world_box: AABB = mi.global_transform * mi.get_aabb()
			print("DUMP: audit   %-22s size %s  at %s" % [String(mi.name), str(world_box.size), str(world_box.position).replace("\n", " ")])
		elif c is CollisionShape3D:
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs.shape == null:
				continue
			var cbox: AABB = cs.global_transform * ShapeKit.shape_aabb_local(cs.shape)
			print("DUMP: audit   %-22s size %s  at %s" % [String(cs.name), str(cbox.size), str(cbox.position).replace("\n", " ")])


func _stations(node: Node) -> Array[Node]:
	## Reference the station script by path rather than by class name: a `-s` test
	## script compiles before the project's autoloads exist, and `Station`'s own
	## script mentions them, so naming the class here fails to compile.
	var out: Array[Node] = []
	for child: Node in node.get_children():
		var scr: Script = child.get_script()
		if scr != null and String(scr.resource_path).ends_with("station.gd"):
			out.append(child)
		out.append_array(_stations(child))
	return out


func _collect(node: Node, target: Vector3, r: float, rows: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Node3D and not (child is Light3D):
			var p: Vector3 = (child as Node3D).global_position
			var mi: MeshInstance3D = child as MeshInstance3D
			var mesh_name: String = ""
			if mi != null and mi.mesh != null:
				mesh_name = mi.mesh.get_class()
			# generated cables are single meshes in world-space vertices with the
			# node parked at the origin, so their position says nothing; their AABB
			# does, and the material names their colour.
			if mi != null and mi.mesh is ArrayMesh:
				var box: AABB = mi.mesh.get_aabb()
				var centre: Vector3 = box.get_center()
				var mat_name: String = ""
				var mat: Material = mi.material_override
				if mat is StandardMaterial3D:
					mat_name = (mat as StandardMaterial3D).albedo_color.to_html(false)
				if Vector2(centre.x - target.x, centre.z - target.z).length() <= r:
					rows.append("%-34s CABLESHAPE size=%s centre=(%6.2f, %5.2f, %6.2f) colour=%s" % [
						String(child.name), str(box.size), centre.x, centre.y, centre.z, mat_name])
				continue
			if Vector2(p.x - target.x, p.z - target.z).length() <= r:
				rows.append("%-34s %-18s %-10s (%6.2f, %5.2f, %6.2f)" % [
					String(child.name), child.get_class(), mesh_name, p.x, p.y, p.z])
		_collect(child, target, r, rows)
