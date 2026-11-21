extends SceneTree
## Prints the world position, bounding size and box for named dressing props (or
## every match when several share a name), so placement clashes can be fixed from
## numbers instead of screenshots. Usage:
##   godot --headless --path . -s res://tests/where_is.gd -- Stool BatteryRack ScrapBin Bicycle

func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var scene: PackedScene = load("res://scenes/main/garage_world.tscn")
	var world: Node3D = scene.instantiate() as Node3D
	root.add_child(world)
	var frames: int = 0
	while not bool(world.get("build_complete")) and frames < 6000:
		await process_frame
		frames += 1
	var kit: GDScript = load("res://scripts/procedural/shape_kit.gd")
	var dressing: Node = world.get("dressing")
	var wanted: Array = args if args.size() > 0 else ["HoloTable"]
	for child: Node in dressing.get_children():
		if not (child is Node3D):
			continue
		var name: String = String(child.name)
		var match_any: bool = false
		for w: String in wanted:
			if name.begins_with(w):
				match_any = true
				break
		if not match_any:
			continue
		var box: AABB = kit.node_bounds(child)
		var p: Vector3 = (child as Node3D).global_position
		print("WHERE: %-22s pos=(%.2f, %.2f, %.2f)  box min=(%.2f, %.2f, %.2f) size=(%.2f, %.2f, %.2f)" % [
			name, p.x, p.y, p.z, box.position.x, box.position.y, box.position.z, box.size.x, box.size.y, box.size.z])
	quit()
