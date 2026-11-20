extends SceneTree
## Entrance / courtyard walkability probe: builds the garage headless, takes
## control of the real player, and drives it — after settling on the yard — into
## the shop, back out, and sideways across the courtyard. It logs position, floor
## contact and stalls, because "the entrance is hard" has several candidate causes
## (the yard-to-slab lip, the threshold, the doorway, the yard's edges) and
## guessing between them from pictures is how the last two bugs were born.
##
## Usage:  godot --headless --path . -s res://tests/walk_in.gd
## Note: move capture.flag out of the project root first.

func _initialize() -> void:
	_run()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/garage_world.tscn")
	var world: Node3D = scene.instantiate() as Node3D
	var gs: Node = root.get_node_or_null("GameState")
	if gs != null:
		gs.set("tour_mode", false)
	root.add_child(world)
	var frames: int = 0
	while not bool(world.get("build_complete")) and frames < 6000:
		await process_frame
		frames += 1
	print("WALK: build_complete=%s after %d frames" % [str(world.get("build_complete")), frames])
	var player: Node3D = world.get("player") as Node3D
	if player == null:
		print("WALK: no player")
		quit()
		return
	player.set("ui_locked", false)
	print("WALK: spawn %s" % str(player.global_position))
	# settle on the yard: let the spawn drop finish before any walking
	for i: int in range(120):
		await physics_frame
	print("WALK: settled %s  on_floor=%s" % [str(player.global_position), str(player.is_on_floor())])
	await _march(player, "move_forward", 8.0, "IN")
	player.rotation.y = PI
	await _march(player, "move_forward", 5.0, "OUT")
	player.rotation.y = PI * 0.5
	await _march(player, "move_forward", 4.0, "SIDE+")
	player.rotation.y = PI * 1.5
	await _march(player, "move_forward", 6.0, "SIDE-")
	quit()


func _march(player: Node3D, action: String, seconds: float, label: String) -> void:
	Input.action_press(action)
	var ticks: int = int(seconds * 60.0)
	var last: Vector3 = player.global_position
	var stall: float = 0.0
	var stall_reported: bool = false
	for i: int in range(ticks):
		await physics_frame
		if i % 30 == 0:
			var p: Vector3 = player.global_position
			var moved: float = Vector2(p.x - last.x, p.z - last.z).length()
			if moved < 0.05:
				stall += 0.5
			else:
				stall = 0.0
			print("WALK %s t=%.1f  pos=(%.2f, %.2f, %.2f)  floor=%s  stall=%.1f" % [
				label, float(i) / 60.0, p.x, p.y, p.z, str(player.is_on_floor()), stall])
			last = p
			if stall >= 1.0 and not stall_reported:
				stall_reported = true
				print("WALK %s STALLED at (%.2f, %.2f, %.2f):" % [label, p.x, p.y, p.z])
				for c: int in range(player.get_slide_collision_count()):
					var col: KinematicCollision3D = player.get_slide_collision(c)
					var other: Object = col.get_collider()
					var oname: String = "<%s>" % type_string(typeof(other))
					if other is Node:
						oname = (other as Node).name
					print("WALK %s   sliding against %s  at %s  normal %s" % [
						label, oname, str(col.get_position()), str(col.get_normal())])
	Input.action_release(action)
	var end: Vector3 = player.global_position
	print("WALK %s end  pos=(%.2f, %.2f, %.2f)  floor=%s" % [
		label, end.x, end.y, end.z, str(player.is_on_floor())])
