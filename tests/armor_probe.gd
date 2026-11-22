extends SceneTree
## The armour assembly + demo reset probe (plans A and E).
##
## Drives the real fitting path — hand a part to the carry system exactly as a
## mouse pick would, then call the figure's action — and asserts the socket
## positions, the fitted count, the light ramp, the dismount homes, and the full
## demo reset. Prints ARMOR: lines; every line ends OK or FAIL.
##
## Usage:  godot --headless --path . -s res://tests/armor_probe.gd

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
	var armor: Node = world.get("armor")
	var carry: Node = world.get("carry")
	var dressing: Node = world.get("dressing")
	var runtime: Node = world.get("runtime")
	if armor == null or carry == null or dressing == null:
		print("ARMOR: setup FAIL — armor=%s carry=%s dressing=%s" % [str(armor), str(carry), str(dressing)])
		quit()
		return
	var parts: Array = ["ArmorChestPlate", "ArmorHelmet", "ArmorGauntlet", "ArmorBoot"]
	var homes: Dictionary = {}
	for part_name: String in parts:
		var n: Node3D = dressing.get_node_or_null(part_name) as Node3D
		if n != null:
			homes[part_name] = n.global_position
	# 1. fit every spare through the interactive path
	var expect_fitted: int = 0
	for part_name: String in parts:
		var node: Node3D = dressing.get_node_or_null(part_name) as Node3D
		if node == null:
			print("ARMOR: %s FAIL — not found" % part_name)
			continue
		# the carry system's private state is set deliberately: this is a headless
		# stand-in for the left-click that would have picked it up
		carry.set("_held", node)
		carry.set("_state", 1)
		var handled: bool = armor.figure_action(null)
		await _wait(0.9)
		expect_fitted += 1
		var fig: Node3D = dressing.get_node_or_null("ArmorFigure") as Node3D
		var socket: Vector3 = fig.to_global(armor.PARTS[part_name]["socket"] as Vector3)
		var dist: float = node.global_position.distance_to(socket)
		print("ARMOR: fit %-16s handled=%s socket_dist=%.2f cm fitted=%d/%d %s" % [
			part_name, str(handled), dist * 100.0, int(armor.fitted_count()), parts.size(),
			"OK" if handled and dist < 0.05 and int(armor.fitted_count()) == expect_fitted else "FAIL"])
		print("ARMOR:   node at %s  socket at %s  carry_state=%s" % [
			str(node.global_position.snapped(Vector3(0.01, 0.01, 0.01))),
			str(socket.snapped(Vector3(0.01, 0.01, 0.01))), str(carry.get("_state"))])
		# 2. a mismatched part is refused with a buzz, not a crash
		if part_name == "ArmorBoot" and expect_fitted >= 4:
			var wrong: Node3D = dressing.get_node_or_null("ArmorBoot") as Node3D
			var boot_home: Vector3 = homes["ArmorBoot"] as Vector3
			carry.set("_held", wrong)
			carry.set("_state", 1)
			armor.figure_action(null)
			await _frames(10)
			# the carry loop moved the held boot toward the camera, exactly as it
			# would have; the guard's point is that the SOCKET did not take it
			var socket_cheat: float = wrong.global_position.distance_to(
				(dressing.get_node_or_null("ArmorFigure") as Node3D).to_global(armor.PARTS["ArmorBoot"]["socket"] as Vector3))
			var accepted: bool = socket_cheat < 5.0
			print("ARMOR: wrong-socket guard boot_still_held=%s %s" % [
				str(not accepted), "OK" if not accepted else "FAIL"])
			carry.set("_held", null)
			carry.set("_state", 0)
			wrong.global_position = boot_home
			wrong.rotation = Vector3.ZERO
	# 3. the fourth seat caught the core: the lights are up BEFORE any bolting
	var seat_energy: float = 0.0
	for child: Node in dressing.get_node_or_null("ArmorFigure").get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Core"):
			var cm: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if cm != null:
				seat_energy = cm.emission_energy_multiplier / maxf(float(cm.get_meta("base_energy", 2.0)), 0.001)
	print("ARMOR: power-on at fourth seat glow=%.2fx %s" % [seat_energy, "OK" if seat_energy > 1.3 else "FAIL"])
	# 4. stage two: one empty-handed press bolts the whole kit down in a cascade
	print("ARMOR: seated=%d locked=%d %s" % [
		int(armor.fitted_count()), int(armor.locked_count()),
		"OK" if int(armor.fitted_count()) == 4 and int(armor.locked_count()) == 0 else "FAIL"])
	var handled_bolt: bool = armor.figure_action(null)
	await _wait(2.2)
	print("ARMOR: bolt cascade handled=%s locked=%d/4 %s" % [
		str(handled_bolt), int(armor.locked_count()),
		"OK" if handled_bolt and int(armor.locked_count()) == 4 else "FAIL"])
	# 4. the power-up: the glow materials ride brighter than their base
	var glow_ok: bool = false
	for child: Node in dressing.get_node_or_null("ArmorFigure").get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Core"):
			var m: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if m != null:
				var base: float = float(m.get_meta("base_energy", 2.0))
				glow_ok = m.emission_energy_multiplier > base * 1.2
	print("ARMOR: power-up glow_boosted=%s %s" % [str(glow_ok), "OK" if glow_ok else "FAIL"])
	var fig_node: Node3D = dressing.get_node_or_null("ArmorFigure") as Node3D
	var fig_st: Node = null
	if fig_node != null:
		for child: Node in fig_node.get_children():
			# duck-check, not `is Station`: a -s probe must not statically depend on
			# game classes, or the whole station chain compiles before autoloads
			if child.get("display_name") != null:
				fig_st = child
	if fig_st != null:
		print("ARMOR: figure title \"%s\" %s" % [fig_st.display_name, "OK" if String(fig_st.display_name).contains("complete") else "FAIL"])
	# 4. dismount: every spare back to its authored home
	armor.dismount_all(true)
	await _frames(5)
	for part_name: String in parts:
		var node: Node3D = dressing.get_node_or_null(part_name) as Node3D
		var back: float = node.global_position.distance_to(homes[part_name] as Vector3)
		print("ARMOR: dismount %-16s home_dist=%.2f cm fitted=%d/%d %s" % [
			part_name, back * 100.0, int(armor.fitted_count()), parts.size(),
			"OK" if back < 0.02 and int(armor.fitted_count()) == 0 else "FAIL"])
	# 5. the demo reset end to end
	world.demo_reset()
	await _frames(5)
	var gs: Node = root.get_node("/root/GameState")
	print("ARMOR: reset flags power=%s computer_stage=%d stage=%d %s" % [
		str(runtime.power_on), int(runtime.computer_stage), int(gs.assembly_stage),
		"OK" if not bool(runtime.power_on) and int(runtime.computer_stage) == 0 else "FAIL"])
	print("ARMOR: reset components collected=%d %s" % [
		int(gs.collected_components.size()), "OK" if gs.collected_components.size() == 0 else "FAIL"])
	quit()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _wait(seconds: float) -> void:
	## Await in WALL time, not frames: the headless loop is unthrottled, so frame
	## counts mean milliseconds here while the tweens run in seconds.
	await create_timer(seconds).timeout
