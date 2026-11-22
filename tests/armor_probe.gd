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
	# 0. the guide is inert until engaged, then points at the helmet with its tag
	print("ARMOR: guide before engage tracker=%s beacon=%s %s" % [
		str(armor.tracker_visible()), str(armor.beacon_visible()),
		"OK" if not armor.tracker_visible() and not armor.beacon_visible() else "FAIL"])
	armor.engage()
	await _wait(0.15)
	var bcn: Node = armor.get_node_or_null("ArmorGuideBeacon")
	var bch: String = ""
	if bcn != null:
		for ch: Node in bcn.get_children():
			bch += String(ch.name) + " "
	print("ARMOR: guide engaged target=%s beacon=%s stage=\"%s\" next=\"%s\" %s" % [
		String(armor.guide_part()), str(armor.beacon_visible()),
		String(armor.stage_line()), String(armor.next_line()),
		"OK" if armor.PARTS.has(String(armor.guide_part())) and armor.beacon_visible()
			and String(armor.stage_line()).contains("STEP 1 OF 3")
			and String(armor.next_line()).contains("left-click the") else "FAIL"])
	print("ARMOR: beacon built node=%s children=[%s] pos=%s %s" % [
		str(bcn != null), bch.strip_edges(),
		str((bcn as Node3D).global_position) if bcn is Node3D else "n/a",
		"OK" if bcn is Node3D and bch.contains("Arrow") and bch.contains("Beam") and bch.contains("Filament") else "FAIL"])
	var bp: String = String(armor.guide_part())
	var av: String = ""
	var ar_ok: bool = true
	for p: String in ["ArmorLegs", "ArmorTorso", "ArmorHead"]:
		var vis: bool = bool(armor.arrow_visible(p))
		if vis:
			av += p + " "
		if vis == (p == bp):
			ar_ok = false
	print("ARMOR: assembly arrows over=[%s] beacon-part=%s %s" % [
		av.strip_edges(), bp, "OK" if ar_ok and not av.is_empty() else "FAIL"])
	var parts: Array = ["ArmorLegs", "ArmorTorso", "ArmorHead"]
	var homes: Dictionary = {}
	for part_name: String in parts:
		var n: Node3D = dressing.get_node_or_null(part_name) as Node3D
		if n != null:
			homes[part_name] = n.global_position
	var staged: bool = true
	for part_name: String in parts:
		var h: Vector3 = homes.get(part_name, Vector3.ZERO) as Vector3
		if h.z < 2.5 or h.y < 0.10 or h.y > 0.15:
			staged = false
	print("ARMOR: assemblies staged on the build pallet %s" % ["OK" if staged else "FAIL"])
	# 1. the order is enforced — the torso is refused until the legs are on
	var torso_node: Node3D = dressing.get_node_or_null("ArmorTorso") as Node3D
	carry.set("_held", torso_node)
	carry.set("_state", 1)
	var refused: bool = armor.figure_action(null)
	await _frames(5)
	print("ARMOR: wrong-order guard refused=%s fitted=%d/3 %s" % [
		str(refused), int(armor.fitted_count()),
		"OK" if refused and int(armor.fitted_count()) == 0 else "FAIL"])
	carry.set("_held", null)
	carry.set("_state", 0)
	# 2. build the figure low to high through the interactive path
	var expect_fitted: int = 0
	var fig: Node3D = dressing.get_node_or_null("ArmorBase") as Node3D
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
		var socket: Vector3 = fig.to_global(armor.PARTS[part_name]["socket"] as Vector3)
		var dist: float = node.global_position.distance_to(socket)
		print("ARMOR: fit %-16s handled=%s socket_dist=%.2f cm fitted=%d/%d %s" % [
			part_name, str(handled), dist * 100.0, int(armor.fitted_count()), parts.size(),
			"OK" if handled and dist < 0.05 and int(armor.fitted_count()) == expect_fitted else "FAIL"])
		print("ARMOR:   node at %s  socket at %s  carry_state=%s" % [
			str(node.global_position.snapped(Vector3(0.01, 0.01, 0.01))),
			str(socket.snapped(Vector3(0.01, 0.01, 0.01))), str(carry.get("_state"))])
	# 3. the head seat caught the core: the lights are up BEFORE the seal
	var seat_energy: float = 0.0
	for child: Node in dressing.get_node_or_null("ArmorTorso").get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Core"):
			var cm: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if cm != null:
				seat_energy = cm.emission_energy_multiplier / maxf(float(cm.get_meta("base_energy", 2.0)), 0.001)
	print("ARMOR: power-on at head seat glow=%.2fx %s" % [seat_energy, "OK" if seat_energy > 1.3 else "FAIL"])
	# 4. stage two: the seal is automatic now
	print("ARMOR: seated=%d locked=%d %s" % [
		int(armor.fitted_count()), int(armor.locked_count()),
		"OK" if int(armor.fitted_count()) == 3 and int(armor.locked_count()) == 0 else "FAIL"])
	await _wait(4.6)
	print("ARMOR: auto-seal locked=%d/3 %s" % [
		int(armor.locked_count()), "OK" if int(armor.locked_count()) == 3 else "FAIL"])
	print("ARMOR: guide after seal beacon=%s stage=\"%s\" %s" % [
		str(armor.beacon_visible()), String(armor.stage_line()),
		"OK" if not armor.beacon_visible() and String(armor.stage_line()).contains("COMPLETE") else "FAIL"])
	var any_arrow: bool = false
	for p: String in ["ArmorLegs", "ArmorTorso", "ArmorHead"]:
		any_arrow = any_arrow or bool(armor.arrow_visible(p))
	print("ARMOR: assembly arrows after seal any=%s %s" % [str(any_arrow), "OK" if not any_arrow else "FAIL"])
	# 4. the power-up: the glow materials ride brighter than their base
	var glow_ok: bool = false
	for child: Node in dressing.get_node_or_null("ArmorTorso").get_children():
		if child is MeshInstance3D and String(child.name).begins_with("Core"):
			var m: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if m != null:
				var base: float = float(m.get_meta("base_energy", 2.0))
				glow_ok = m.emission_energy_multiplier > base * 1.2
	print("ARMOR: power-up glow_boosted=%s %s" % [str(glow_ok), "OK" if glow_ok else "FAIL"])
	var fig_node: Node3D = dressing.get_node_or_null("ArmorBase") as Node3D
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
	print("ARMOR: guide sleeps after strip tracker=%s beacon=%s %s" % [
		str(armor.tracker_visible()), str(armor.beacon_visible()),
		"OK" if not armor.tracker_visible() and not armor.beacon_visible() else "FAIL"])
	# 5. the demo reset end to end
	world.demo_reset()
	await _frames(5)
	var gs: Node = root.get_node("/root/GameState")
	print("ARMOR: reset flags power=%s computer_stage=%d stage=%d %s" % [
		str(runtime.power_on), int(runtime.computer_stage), int(gs.assembly_stage),
		"OK" if not bool(runtime.power_on) and int(runtime.computer_stage) == 0 else "FAIL"])
	print("ARMOR: reset components collected=%d %s" % [
		int(gs.collected_components.size()), "OK" if gs.collected_components.size() == 0 else "FAIL"])
	# 6b. ease: carrying a spare up seats it — no look, no press
	var pl: Node3D = world.get("player") as Node3D
	var fig2: Node3D = dressing.get_node_or_null("ArmorBase") as Node3D
	var boot2: Node3D = dressing.get_node_or_null("ArmorLegs") as Node3D
	if pl != null and fig2 != null and boot2 != null:
		var pl_saved: Vector3 = pl.global_position
		pl.global_position = fig2.global_position + Vector3(1.1, 0.0, 1.1)
		carry.set("_held", boot2)
		carry.set("_state", 1)
		await _wait(0.8)
		print("ARMOR: auto-seat by approach fitted=%d/3 %s" % [
			int(armor.fitted_count()), "OK" if int(armor.fitted_count()) == 1 else "FAIL"])
		carry.set("_held", null)
		carry.set("_state", 0)
		armor.dismount_all(true)
		pl.global_position = pl_saved
	else:
		print("ARMOR: auto-seat by approach FAIL — nodes missing")
	# 6. the suit guide (the second assembly): quiet in the morning, then every
	# step of the journey — recover, install, assemble, check — with the beacon
	var guide: Node = world.get("assembly_guide")
	if guide == null:
		print("ARMOR: suit guide present=false FAIL")
	else:
		print("ARMOR: suit guide morning tracker=%s beacon=%s %s" % [
			str(guide.tracker_visible()), str(guide.beacon_visible()),
			"OK" if not guide.tracker_visible() and not guide.beacon_visible() else "FAIL"])
		runtime.set_power(true, true)
		await _frames(4)
		print("ARMOR: suit guide powered tracker=%s beacon=%s stage=\"%s\" next=\"%s\" %s" % [
			str(guide.tracker_visible()), str(guide.beacon_visible()),
			String(guide.stage_line()), String(guide.next_line()),
			"OK" if guide.tracker_visible() and guide.beacon_visible()
				and String(guide.stage_line()).contains("STEP 1 OF 3")
				and String(guide.next_line()).contains("recover the") else "FAIL"])
		print("ARMOR: suit crate arrows=%s %s %s %s" % [
			str(guide.crate_arrow_visible(0)), str(guide.crate_arrow_visible(1)), str(guide.crate_arrow_visible(2)),
			"OK" if not guide.crate_arrow_visible(0) and guide.crate_arrow_visible(1) and guide.crate_arrow_visible(2) else "FAIL"])
		gs.collect_component("frame_module")
		await _frames(2)
		print("ARMOR: suit guide mid-recovery state0=%d next=\"%s\" %s" % [
			int(guide.module_state(0)), String(guide.next_line()),
			"OK" if int(guide.module_state(0)) == 1 and String(guide.next_line()).contains("recover the") else "FAIL"])
		print("ARMOR: suit crate arrows mid=%s %s %s %s" % [
			str(guide.crate_arrow_visible(0)), str(guide.crate_arrow_visible(1)), str(guide.crate_arrow_visible(2)),
			"OK" if not guide.crate_arrow_visible(1) and guide.crate_arrow_visible(2) else "FAIL"])
		gs.collect_component("energy_module")
		gs.collect_component("armour_shell")
		await _frames(2)
		print("ARMOR: suit guide install step stage=\"%s\" next=\"%s\" %s" % [
			String(guide.stage_line()), String(guide.next_line()),
			"OK" if String(guide.stage_line()).contains("INSTALL")
				and String(guide.next_line()).contains("install the frame module") else "FAIL"])
		var any_crate_arrow: bool = false
		for i: int in range(3):
			any_crate_arrow = any_crate_arrow or bool(guide.crate_arrow_visible(i))
		print("ARMOR: suit crate arrows after recovery any=%s %s" % [
			str(any_crate_arrow), "OK" if not any_crate_arrow else "FAIL"])
		gs.call("set_assembly_stage", 1)
		await _frames(2)
		print("ARMOR: suit guide after frame module0=%d next=\"%s\" %s" % [
			int(guide.module_state(0)), String(guide.next_line()),
			"OK" if int(guide.module_state(0)) == 2
				and String(guide.next_line()).contains("install the energy module") else "FAIL"])
		gs.call("set_assembly_stage", 2)
		await _frames(2)
		print("ARMOR: suit guide after core module1=%d next=\"%s\" %s" % [
			int(guide.module_state(1)), String(guide.next_line()),
			"OK" if int(guide.module_state(1)) == 2
				and String(guide.next_line()).contains("install the shell module") else "FAIL"])
		gs.call("set_assembly_stage", 3)
		await _frames(2)
		print("ARMOR: suit guide ready next=\"%s\" %s" % [
			String(guide.next_line()),
			"OK" if String(guide.next_line()).contains("START ASSEMBLY SEQUENCE") else "FAIL"])
		gs.call("set_assembly_stage", 4)
		await _frames(2)
		print("ARMOR: suit guide assembling next=\"%s\" %s" % [
			String(guide.next_line()),
			"OK" if String(guide.next_line()).contains("let the sequence run") else "FAIL"])
		gs.call("set_assembly_stage", 5)
		await _frames(2)
		print("ARMOR: suit guide active next=\"%s\" %s" % [
			String(guide.next_line()),
			"OK" if String(guide.next_line()).contains("final check") else "FAIL"])
		gs.set("diagnostics_run", true)
		await _frames(2)
		print("ARMOR: suit guide complete stage=\"%s\" linger=%s %s" % [
			String(guide.stage_line()), str(guide.tracker_visible()),
			"OK" if String(guide.stage_line()).contains("COMPLETE") and guide.tracker_visible() else "FAIL"])
		guide.suppress()
		print("ARMOR: suit guide suppressed tracker=%s beacon=%s %s" % [
			str(guide.tracker_visible()), str(guide.beacon_visible()),
			"OK" if not guide.tracker_visible() and not guide.beacon_visible() else "FAIL"])
	quit()


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


func _wait(seconds: float) -> void:
	## Await in WALL time, not frames: the headless loop is unthrottled, so frame
	## counts mean milliseconds here while the tweens run in seconds.
	await create_timer(seconds).timeout
