extends Node3D
## The shop sign's RGB rig: two colour-cycling washes aimed at the board from
## below-left and below-right, and one omni spilling colour onto the awning and
## the street. Attached to the Signboard prop at build time; every light registers
## on circuit 0 — the incoming line — so the sign stays lit whatever the player
## does to the switchboard, exactly like the always-on bulbs inside.
##
## The rig travels with the sign: the lights are children of the sign node, so
## carrying the signboard with the mouse carries its glow too. The hue drift is
## deliberately slower than the LED frame's chase (a full rainbow in ~16 seconds)
## so the two read as one installation rather than two gimmicks.

var _lights: Array[Light3D] = []
var _phases: Array[float] = []
var _t: float = 0.0
var _speed: float = 0.062


func setup_rgb(rt: Node) -> void:
	## Build the washes in the sign's local space: the board faces +z, so the
	## spots sit below the board lip, outside its edges, aiming across it.
	var specs: Array = [
		{"kind": "spot", "pos": Vector3(-1.55, -0.45, 0.38), "aim": Vector3(0.35, 0.16, 0.03), "energy": 3.4, "range": 4.5, "angle": 44.0},
		{"kind": "spot", "pos": Vector3(1.55, -0.45, 0.38), "aim": Vector3(-0.35, 0.16, 0.03), "energy": 3.4, "range": 4.5, "angle": 44.0},
		{"kind": "omni", "pos": Vector3(0.0, -0.55, 0.6), "aim": Vector3.ZERO, "energy": 1.4, "range": 4.6, "angle": 0.0},
	]
	for i: int in range(specs.size()):
		var s: Dictionary = specs[i]
		var light: Light3D
		if String(s["kind"]) == "spot":
			var spot := SpotLight3D.new()
			spot.spot_angle = float(s["angle"])
			spot.spot_angle_attenuation = 0.7
			spot.spot_range = float(s["range"])
			spot.spot_attenuation = 1.3
			light = spot
		else:
			var omni := OmniLight3D.new()
			omni.omni_range = float(s["range"])
			omni.omni_attenuation = 1.4
			light = omni
		light.name = "SignRgb%d" % i
		light.position = s["pos"]
		light.light_energy = float(s["energy"])
		light.shadow_enabled = false
		add_child(light)
		if String(s["kind"]) == "spot":
			(light as SpotLight3D).look_at_from_position(s["pos"], s["aim"], Vector3.UP)
		rt.register_light(light, 0, &"sign_rgb", float(s["energy"]))
		_lights.append(light)
		_phases.append(float(i) * 0.33)
	set_process(true)


func _process(delta: float) -> void:
	if _lights.is_empty():
		return
	_t = fposmod(_t + delta * _speed, 1.0)
	for i: int in range(_lights.size()):
		var light: Light3D = _lights[i]
		if is_instance_valid(light):
			light.light_color = Color.from_hsv(fposmod(_t + _phases[i], 1.0), 0.82, 1.0)
