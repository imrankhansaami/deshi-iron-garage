extends SceneTree
## Carry audit: builds the garage headless and prints (a) every node the carry
## system could consider, with its true bounding size, host and verdict against
## the live cap, (b) what the carry system actually gathered, with exclusion
## checks, and (c) a functional pick/place probe over representative items — the
## largest dressing props, a station-bearing prop, a structure-yard prop — to
## prove the carry maths settles them back onto a real surface.
##
## Usage:  godot --headless --path . -s res://tests/carry_audit.gd
## Note: move capture.flag out of the project root first, or the world's capture
## driver will run its shot sequence while this script waits.

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
	print("AUDIT: build_complete=%s after %d frames" % [str(world.get("build_complete")), frames])
	var carry: Node = world.get("carry")
	if carry == null:
		print("AUDIT: no carry system")
		quit()
		return
	var caps: Dictionary = (carry.get_script() as GDScript).get_script_constant_map()
	var cap: float = float(caps.get("MAX_CARRY_SIZE", 0.8))
	var shape_kit: GDScript = load("res://scripts/procedural/shape_kit.gd")
	var dressing: Node = world.get("dressing")
	var structure: Node = world.get("structure")
	var rows: Array = []
	for host_pair: Array in [["dressing", dressing], ["structure", structure]]:
		var who: String = host_pair[0]
		var host: Node = host_pair[1]
		for child: Node in host.get_children():
			if not (child is Node3D):
				continue
			var box: AABB = shape_kit.node_bounds(child)
			if not box.has_volume():
				continue
			var s: Vector3 = box.size
			rows.append({
				"who": who, "name": String(child.name),
				"max": maxf(s.x, maxf(s.y, s.z)), "size": s,
			})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["max"] > b["max"])
	var carryable_now: int = 0
	for r: Dictionary in rows:
		if r["max"] <= cap:
			carryable_now += 1
	print("AUDIT: cap %.2f m, %d candidates, %d within the cap" % [cap, rows.size(), carryable_now])
	for r: Dictionary in rows:
		var s: Vector3 = r["size"]
		print("AUDIT: %-9s %-30s max %.2f   %.2f x %.2f x %.2f  %s" % [
			r["who"], r["name"], r["max"], s.x, s.y, s.z,
			"OK" if r["max"] <= cap else "over"])
	var items: Array = carry.get("_items")
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float((a["box"] as AABB).size.length()) > float((b["box"] as AABB).size.length()))
	print("AUDIT: the carry system gathered %d items; largest six:" % items.size())
	for i: int in range(mini(6, items.size())):
		var box: AABB = items[i]["box"]
		print("AUDIT:   #%d %s  size %.2f x %.2f x %.2f" % [
			i + 1, (items[i]["node"] as Node3D).name, box.size.x, box.size.y, box.size.z])
	var excluded_wanted: Array[String] = ["Shutter", "Window00", "Window01", "FlagPole", "PrototypeExosuit"]
	for want: String in excluded_wanted:
		var present: bool = false
		for e: Dictionary in items:
			if String((e["node"] as Node3D).name).begins_with(want):
				present = true
				break
		print("AUDIT: exclusion %-18s %s" % [want, "PRESENT (bad)" if present else "absent (good)"])
	await _probe(world)
	quit()


func _probe(world: Node3D) -> void:
	var carry: Node = world.get("carry")
	carry.set_process(false)
	var shape_kit: GDScript = load("res://scripts/procedural/shape_kit.gd")
	for want: String in ["Workbench", "Bicycle", "BigCoin", "SteelDrum", "Stool"]:
		var node: Node3D = _find_first(world.get("dressing"), want)
		if node == null:
			node = _find_first(world.get("structure"), want)
		if node == null:
			print("PROBE: %-12s not found (skipped)" % want)
			continue
		var box: AABB = shape_kit.node_bounds(node)
		var before: Vector3 = node.global_position
		var before_rot: Vector3 = node.rotation
		carry.call("_pick_up", node)
		node.global_position = Vector3(0.6, 1.1, 3.0)
		carry.call("_place")
		var waited: float = 0.0
		while int(carry.get("_state")) != 0 and waited < 1.2:
			await process_frame
			waited += 0.016
		print("PROBE: %-12s max %.2f  settle_state=%d  landed_y=%.3f  home_y=%.3f  wait %.2fs" % [
			want, maxf(box.size.x, maxf(box.size.y, box.size.z)), int(carry.get("_state")),
			node.global_position.y, before.y, waited])
		node.global_position = before
		node.rotation = before_rot
	carry.set_process(true)


func _find_first(root_node: Node, name_start: String) -> Node3D:
	if root_node == null:
		return null
	for child: Node in root_node.get_children():
		if child is Node3D and String(child.name).begins_with(name_start):
			return child as Node3D
	return null
