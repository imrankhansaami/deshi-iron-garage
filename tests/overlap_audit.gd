extends SceneTree
## Overlap audit: builds the garage headless and reports which of the dressing's
## placed props have intersecting world bounding boxes, worst first. AABB overlap
## is an approximation — an L-shaped prop's box overlaps things its geometry does
## not, and intentional stacks (a tin on a crate lid) are legitimate — so the
## output is a work list to judge, not a verdict. Wall-mounted items are only
## compared against each other, never against the shell, so ordinary "prop near
## wall" contact never floods the list.
##
## Usage:  godot --headless --path . -s res://tests/overlap_audit.gd

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
	print("OVERLAP: build_complete=%s after %d frames" % [str(world.get("build_complete")), frames])
	var kit: GDScript = load("res://scripts/procedural/shape_kit.gd")
	var dressing: Node = world.get("dressing")
	var items: Array = []
	for child: Node in dressing.get_children():
		if not (child is Node3D):
			continue
		var name: String = String(child.name)
		if name.begins_with("Grime") or name.begins_with("Cable") or name.begins_with("Lane") or name.begins_with("Joint") or name.begins_with("Drain"):
			continue
		var box: AABB = kit.node_bounds(child)
		if not box.has_volume():
			continue
		items.append({"name": name, "box": box, "node": child})
	print("OVERLAP: %d props checked pairwise" % items.size())
	var hits: Array = []
	for a: int in range(items.size()):
		for b: int in range(a + 1, items.size()):
			var ba: AABB = items[a]["box"]
			var bb: AABB = items[b]["box"]
			if not ba.intersects(bb):
				continue
			var inter: AABB = ba.intersection(bb)
			var vol: float = inter.size.x * inter.size.y * inter.size.z
			if vol < 0.0006:
				continue
			hits.append({"a": items[a]["name"], "b": items[b]["name"], "vol": vol, "ia": inter, "ba": ba, "bb": bb})
	hits.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["vol"] > y["vol"])
	print("OVERLAP: %d pairs above the threshold" % hits.size())
	for h: Dictionary in hits:
		var ia: AABB = h["ia"]
		print("OVERLAP: %-24s x %-24s inter=%.1f x %.1f x %.1f cm at (%.2f, %.2f, %.2f)" % [
			h["a"], h["b"], ia.size.x * 100.0, ia.size.y * 100.0, ia.size.z * 100.0,
			ia.position.x, ia.position.y, ia.position.z])
	quit()
