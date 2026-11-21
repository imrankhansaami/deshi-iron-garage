extends SceneTree
## Weather-machine probe: forces every state and prints the rain particle load,
## the shared concrete slab's wet numbers, and the drift transition, so the
## "the garage has weather" claim is backed by numbers.
##
## Usage:  godot --headless --path . -s res://tests/weather_probe.gd

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
	var env: Node = world.get("environment")
	# autoloads are not compile-time identifiers in -s scripts; reach them by node
	var ml: Node = root.get_node("/root/MaterialLibrary")
	var gs: Node = root.get_node("/root/GameState")
	var slab: StandardMaterial3D = ml.surface("worn_concrete", {"uv_scale": Vector3(5.0, 5.0, 5.0), "normal_scale": 0.9})
	print("WEATHER start: rain_emitting=%s amount=%d rough=%.3f alb=%.2f" % [
		str(env.rain.emitting), env.rain.amount, slab.roughness, slab.albedo_color.r])
	for state: int in [1, 2, 3, 0]:
		env.set_weather(state)
		print("WEATHER state %d: emitting=%s amount=%d rough=%.3f alb=%.2f damp=%.2f" % [
			state, str(env.rain.emitting), env.rain.amount, slab.roughness, slab.albedo_color.r, env._wet_damp])
	# drift: park in RAIN, shorten the dwell, and let the machine step once
	env.set_weather(2)
	env._weather_left = 0.01
	await process_frame
	await process_frame
	print("WEATHER drift: after dwell, state=%d (expect 3 AFTER_RAIN), damp=%.2f rough=%.3f" % [
		env.weather, env._wet_damp, slab.roughness])
	# master toggle off: the machine parks dry and the slab starts drying
	gs.settings["rain"] = false
	await process_frame
	await process_frame
	print("WEATHER toggle-off: emitting=%s state=%d (expect 0 DRY) damp=%.2f" % [
		str(env.rain.emitting), env.weather, env._wet_damp])
	gs.settings["rain"] = true
	quit()
