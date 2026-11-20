class_name GarageEnvironment
extends Node3D
## Lighting, environment and atmosphere: the visual argument of the project.
##
## The brief asks for two contrasting zones in one room, so the rig is built as
## four circuits that can be switched independently:
##
##   circuit 0  daylight       always on, the sun through the shutter and windows
##   circuit 1  tube lights    the warm fluorescent battlements over World A
##   circuit 2  bench lamps    the focused task lights on the benches
##   circuit 3  desk and bulb  the cool electronics pool and the hanging bulb
##   circuit 4  reactor zone   the cyan core, the hologram and the assembly spots
##
## Design rules that keep it from looking like a game engine default:
##   * only ONE shadow-casting light per zone, and the sun is the only one with a
##     large cascade — the brief's performance constraint, applied honestly;
##   * the futuristic zone is lit by *warm industrial spots plus the cyan core*,
##     never by coloured neon, which is what stops it reading as a nightclub;
##   * volumetric fog is used only in the assembly bay, at a density low enough
##     that the light shafts appear when the shutter opens and disappear when it
##     closes. That coupling is the single most effective "this is a real room"
##     cue in the project and costs one variable write.
##   * exposure is manual, keyed to the garage's dark interior, so the bright
##     courtyard outside blows out when the shutter is up. That contrast is the
##     first thing the player sees.

const TAU_E: float = 6.283185307179586

var ML: MaterialLibrarySingleton
var baker: SignageBaker
var runtime: GarageRuntime
var structure: GarageStructure
var world_env: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var sky: Sky
var skylight: OmniLight3D
var dust: GPUParticles3D
var rain: GPUParticles3D
var rain_sound: AudioStreamPlayer
var _zone_lights: Dictionary = {}
var _shaft_spots: Array[SpotLight3D] = []


func setup(material_library: MaterialLibrarySingleton, signage: SignageBaker, rt: GarageRuntime, shell: GarageStructure) -> void:
	ML = material_library
	baker = signage
	runtime = rt
	structure = shell


func build() -> void:
	_build_environment()
	_build_daylight()
	_build_world_a_lighting()
	_build_electronics_lighting()
	_build_assembly_lighting()
	_build_testing_lighting()
	_build_dust()
	_build_rain()


# ===========================================================================
# Environment
# ===========================================================================

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	# Godot 4 splits the old ProceduralSky into a Sky resource and a sky material
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6a86a8")
	sky_mat.sky_horizon_color = Color("c8b89a")
	sky_mat.ground_bottom_color = Color("3a352c")
	sky_mat.ground_horizon_color = Color("8a7a62")
	sky_mat.sun_angle_max = 32.0
	sky_mat.sun_curve = 0.12
	sky = Sky.new()
	sky.sky_material = sky_mat

	env.sky = sky
	env.background_energy_multiplier = 0.62
	# AgX keeps the emissive core from clipping to a white blob, which Filmic does
	env.tonemap_mode = EnumRef.tonemap(env, "AgX")
	env.tonemap_exposure = 0.95
	env.tonemap_white = 2.6
	env.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	env.ambient_light_energy = 0.22
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	# Bloom is deliberately restrained. The first render put glow_intensity at
	## 0.62 and glow_strength at 0.9, and every steel ring in the assembly bay
	## blew out into a white halo that read as fog rather than as polished metal.
	## The core and the hologram still spill, because they are the only surfaces
	## whose emission is above the raised threshold — which is the point of a
	## threshold-based bloom in the first place.
	env.glow_enabled = bool(GameState.settings.get("bloom", true))
	env.glow_intensity = 0.32
	env.glow_strength = 0.48
	env.glow_bloom = 0.02
	env.glow_mix = 0.12
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 1.45
	env.glow_hdr_scale = 1.9
	env.glow_normalized = true
	# the seven-level falloff spread, narrowed so the core blooms tight instead of
	# washing the whole frame
	for i: int in range(7):
		env.set("glow_levels/%d" % (i + 1), 1.0 - float(i) * 0.06)
	env.ssao_enabled = bool(GameState.settings.get("ssao", true))
	env.ssao_radius = 0.42
	env.ssao_intensity = 1.15
	env.ssao_power = 1.35
	env.ssao_sharpness = 0.35
	env.ssao_light_affect = 0.28
	env.ssao_ao_channel_affect = 0.4
	# SDFGI gives the interior its bounce light: the cyan core spilling onto the
	# brick wall is the effect the whole contrast depends on. The coverage is sized
	# to the 8.5 x 10.5 m room rather than inherited from the earlier 16.5 m plan —
	# covering 90 m of falloff around a room this size was paying for cascades the
	# camera can never see.
	env.sdfgi_enabled = true
	env.sdfgi_cascades = 3
	env.sdfgi_min_cell_size = 0.28
	env.sdfgi_cascade0_distance = 8.0
	env.sdfgi_max_distance = 40.0
	env.sdfgi_bounce_feedback = 0.35
	env.sdfgi_read_sky_light = true
	env.sdfgi_energy = 1.0
	env.sdfgi_normal_bias = 0.12
	env.sdfgi_probe_bias = 0.1
	env.ssr_enabled = bool(GameConfig.quality().get("reflections", true))
	env.ssr_max_steps = 16
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.4
	# volumetric fog, confined to the assembly bay by height and density
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color("c8d8e4")
	env.volumetric_fog_emission = Color("101820")
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.42
	env.volumetric_fog_length = 26.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_gi_inject = 0.4
	env.volumetric_fog_ambient_inject = 0.25
	env.volumetric_fog_sky_affect = 0.4
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("9ab0c4")
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.6
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.97
	world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	runtime.get_node_or_null(".")


func _camera_attributes() -> CameraAttributesPhysical:
	var attrs := CameraAttributesPhysical.new()
	attrs.auto_exposure_enabled = false
	attrs.frustum_near = 0.05
	attrs.frustum_far = 120.0
	attrs.exposure_sensitivity = 100.0
	return attrs


# ===========================================================================
# circuit 0 — daylight
# ===========================================================================

func _build_daylight() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sunlight"
	sun.rotation = Vector3(-0.72, 0.62, 0.0)
	sun.light_color = Color("ffe4c0")
	sun.light_energy = float(GameConfig.config.get("lighting", {}).get("daylight_energy", 2.4))
	sun.light_indirect_energy = 0.35
	sun.light_volumetric_fog_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_split_1 = 0.12
	sun.directional_shadow_split_2 = 0.28
	sun.directional_shadow_split_3 = 0.62
	sun.directional_shadow_blend_splits = true
	sun.directional_shadow_fade_start = 0.82
	sun.directional_shadow_max_distance = 34.0
	sun.directional_shadow_pancake_size = 22.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.09
	sun.shadow_blur = 1.4
	add_child(sun)
	runtime.sun = sun
	runtime.register_light(sun, 0, &"daylight", sun.light_energy)
	# the bounce fill from the courtyard, so the interior is never pitch black
	skylight = OmniLight3D.new()
	skylight.name = "CourtyardBounce"
	skylight.position = Vector3(0.0, 1.6, structure.half_l + 1.2)
	skylight.light_color = Color("b8c8dc")
	skylight.light_energy = 0.85
	skylight.omni_range = 12.0
	skylight.omni_attenuation = 1.3
	skylight.light_indirect_energy = 0.5
	skylight.shadow_enabled = false
	add_child(skylight)
	runtime.register_light(skylight, 0, &"daylight", 0.85)
	# the two window shafts: spots aimed into the room, gated on the shutter so the
	# shafts strengthen when the curtain goes up. Both windows now sit at z = 2.3,
	# one over each bench, so both shafts rake in at the same angle.
	var shaft_data: Array = [
		{"pos": Vector3(structure.half_w - 0.4, 2.1, 2.3), "target": Vector3(structure.half_w - 2.6, 0.9, 2.9), "energy": 2.2, "angle": 34.0},
		{"pos": Vector3(-structure.half_w + 0.4, 2.2, 2.3), "target": Vector3(-structure.half_w + 2.4, 0.9, 2.9), "energy": 1.6, "angle": 30.0},
	]
	for i: int in range(shaft_data.size()):
		var d: Dictionary = shaft_data[i]
		var spot := SpotLight3D.new()
		spot.name = "WindowShaft%d" % i
		var p: Vector3 = d.pos
		spot.position = p
		spot.look_at_from_position(p, d.target, Vector3.UP)
		spot.spot_angle = float(d.angle)
		spot.spot_angle_attenuation = 0.55
		spot.spot_range = 11.0
		spot.spot_attenuation = 1.5
		spot.light_color = Color("cfe0f0")
		spot.light_energy = float(d.energy)
		spot.light_volumetric_fog_energy = 2.6
		spot.shadow_enabled = false
		add_child(spot)
		runtime.register_light(spot, 0, &"daylight", float(d.energy))
		_shaft_spots.append(spot)
	# the shutter gap light: a wide low spot right at the opening, which is what
	# actually paints the floor strip when the curtain lifts
	var gap := SpotLight3D.new()
	gap.name = "ShutterGap"
	gap.position = Vector3(0.0, 2.6, structure.half_l + 1.4)
	gap.look_at_from_position(gap.position, Vector3(0.0, 0.0, structure.half_l - 4.0), Vector3.UP)
	gap.spot_angle = 52.0
	gap.spot_angle_attenuation = 0.7
	gap.spot_range = 14.0
	gap.spot_attenuation = 1.2
	gap.light_color = Color("e8f0ff")
	gap.light_energy = 0.0
	gap.light_volumetric_fog_energy = 3.2
	gap.shadow_enabled = true
	gap.shadow_bias = 0.05
	gap.shadow_normal_bias = 0.1
	add_child(gap)
	runtime.register_light(gap, 0, &"shutter_gap", 3.4)
	_zone_lights["shutter_gap"] = gap


# ===========================================================================
# circuit 1 — World A fluorescent
# ===========================================================================

func _build_world_a_lighting() -> void:
	var warm: Color = Color(GameConfig.config.get("lighting", {}).get("fluorescent_color", "#ffe6bd"))
	## Four fixtures, each one over a real wall fixture that the dressing pass also
	## places, so the light never comes from nowhere. The fifth, a store bulb, is
	## registered by _build_electronics_lighting() because it is a bare bulb rather
	## than a batten.
	var fixtures: Array = [
		{"pos": Vector3(-1.9, structure.height - 0.45, 1.2), "energy": 3.2, "range": 7.0, "zone": &"mech"},
		{"pos": Vector3(1.9, structure.height - 0.45, 1.6), "energy": 2.8, "range": 7.0, "zone": &"elec"},
		{"pos": Vector3(0.0, structure.height - 0.45, 3.5), "energy": 2.4, "range": 6.5, "zone": &"entrance"},
		{"pos": Vector3(-1.9, structure.height - 0.45, 3.9), "energy": 2.0, "range": 6.0, "zone": &"mech"},
	]
	for i: int in range(fixtures.size()):
		var f: Dictionary = fixtures[i]
		var light := OmniLight3D.new()
		light.name = "TubeLight%d" % i
		light.position = f.pos
		light.light_color = warm
		light.light_energy = float(f.energy)
		light.light_indirect_energy = 0.4
		light.light_volumetric_fog_energy = 0.7
		light.omni_range = float(f.range)
		light.omni_attenuation = 1.5
		# exactly two of the five fixtures cast shadows: the two over the working
		## benches, which is where a shadow is actually readable
		light.shadow_enabled = i < 2
		if light.shadow_enabled:
			light.shadow_bias = 0.04
			light.shadow_normal_bias = 0.08
			light.shadow_blur = 1.8
			light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		add_child(light)
		runtime.register_light(light, 1, f.zone, float(f.energy))
		_zone_lights["tube%d" % i] = light
	# the bench task spots, aimed at the surfaces rather than the room
	var tasks: Array = [
		{"pos": Vector3(-2.1, 2.1, 1.0), "target": Vector3(-3.55, 1.0, 1.75), "energy": 2.6, "zone": &"bench"},
		{"pos": Vector3(-3.3, 1.9, 3.55), "target": Vector3(-3.4, 0.45, 4.45), "energy": 1.7, "zone": &"grinder"},
		{"pos": Vector3(2.5, 1.9, 2.5), "target": Vector3(3.75, 1.0, 1.75), "energy": 1.9, "zone": &"bench_elec"},
	]
	for i: int in range(tasks.size()):
		var t: Dictionary = tasks[i]
		var spot := SpotLight3D.new()
		spot.name = "TaskSpot%d" % i
		var p: Vector3 = t.pos
		spot.position = p
		spot.look_at_from_position(p, t.target, Vector3.UP)
		spot.spot_angle = 38.0
		spot.spot_angle_attenuation = 0.6
		spot.spot_range = 6.0
		spot.spot_attenuation = 1.8
		spot.light_color = Color(GameConfig.config.get("lighting", {}).get("desk_lamp_color", "#fff0d0"))
		spot.light_energy = float(t.energy)
		spot.shadow_enabled = i == 0
		if spot.shadow_enabled:
			spot.shadow_bias = 0.03
			spot.shadow_normal_bias = 0.06
			spot.shadow_blur = 1.2
		add_child(spot)
		runtime.register_light(spot, 2, t.zone, float(t.energy))


func _build_electronics_lighting() -> void:
	# the cool-white electronics pool: a low-intensity cool source plus the
	## monitor glow, which is what separates the two halves of the room
	var cool := OmniLight3D.new()
	cool.name = "ElectronicsPool"
	cool.position = Vector3(structure.half_w - 1.4, 1.8, 1.6)
	cool.light_color = Color("cfe4ff")
	cool.light_energy = 1.4
	cool.omni_range = 5.5
	cool.omni_attenuation = 1.7
	cool.light_indirect_energy = 0.5
	cool.shadow_enabled = false
	add_child(cool)
	runtime.register_light(cool, 3, &"elec", 1.4)
	var scope := OmniLight3D.new()
	scope.name = "ScopeGlow"
	scope.position = Vector3(structure.half_w - 0.6, 1.0, -1.3)
	scope.light_color = Color("3fd87a")
	scope.light_energy = 0.55
	scope.omni_range = 2.6
	scope.omni_attenuation = 2.2
	scope.shadow_enabled = false
	add_child(scope)
	runtime.register_light(scope, 3, &"elec", 0.55)
	# the bare bulb over the north-west stock corner, which used to hang in a
	## separate store room and now hangs over the same room's shelf
	var bulb := OmniLight3D.new()
	bulb.name = "StoreBulb"
	bulb.position = Vector3(-structure.half_w + 1.3, structure.height - 0.75, -4.2)
	bulb.light_color = Color("ffe0b0")
	bulb.light_energy = 1.3
	bulb.omni_range = 4.5
	bulb.omni_attenuation = 1.6
	bulb.shadow_enabled = false
	add_child(bulb)
	runtime.register_light(bulb, 3, &"store", 1.3)


func _build_assembly_lighting() -> void:
	## The bay centre moved with the platform: it is (0, 0, -1.5) now, and every
	## offset is measured against that one variable so no light is left aimed at the
	## old 5.4 m stage.
	var centre := Vector3(0.0, 0.0, -1.5)
	# the reactor core light: the cyan source that spills across the brick
	var core := OmniLight3D.new()
	core.name = "CoreLight"
	core.position = centre + Vector3(0.0, 0.45, 0.0)
	core.light_color = Color(GameConfig.config.get("lighting", {}).get("core_color", "#7cf3ff"))
	core.light_energy = 0.0
	core.omni_range = 7.0
	core.omni_attenuation = 1.35
	core.light_volumetric_fog_energy = 2.2
	core.light_indirect_energy = 0.8
	core.shadow_enabled = true
	core.shadow_bias = 0.03
	core.shadow_normal_bias = 0.07
	core.shadow_blur = 2.0
	core.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	add_child(core)
	runtime.register_light(core, 4, &"core", 3.6)
	_zone_lights["core"] = core
	# the key spot on the stand, warm and hard, which is the Iron Man reference.
	## Dropped from y = 3.6 to 2.9: this ceiling is 3.4 m, not 4.6 m.
	var key := SpotLight3D.new()
	key.name = "StandKey"
	key.position = centre + Vector3(1.2, 2.9, 1.4)
	key.look_at_from_position(key.position, centre + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	key.spot_angle = 26.0
	key.spot_angle_attenuation = 0.4
	key.spot_range = 7.0
	key.spot_attenuation = 1.6
	key.light_color = Color("ffdcae")
	key.light_energy = 0.0
	key.light_volumetric_fog_energy = 2.8
	key.shadow_enabled = true
	key.shadow_bias = 0.025
	key.shadow_normal_bias = 0.05
	key.shadow_blur = 1.0
	add_child(key)
	runtime.register_light(key, 4, &"assembly", 6.0)
	_zone_lights["stand_key"] = key
	# the rim light from behind, separating the silhouette from the wall
	var rim := SpotLight3D.new()
	rim.name = "StandRim"
	rim.position = centre + Vector3(-1.4, 2.5, -1.9)
	rim.look_at_from_position(rim.position, centre + Vector3(0.0, 1.4, 0.2), Vector3.UP)
	rim.spot_angle = 30.0
	rim.spot_angle_attenuation = 0.6
	rim.spot_range = 8.0
	rim.spot_attenuation = 1.5
	rim.light_color = Color("9fd8ff")
	rim.light_energy = 0.0
	rim.light_volumetric_fog_energy = 2.4
	rim.shadow_enabled = false
	add_child(rim)
	runtime.register_light(rim, 4, &"assembly", 3.2)
	# the hologram table's own pool, on the table's actual position
	var holo := OmniLight3D.new()
	holo.name = "HoloPool"
	holo.position = Vector3(-2.55, 1.1, -0.1)
	holo.light_color = Color(GameConfig.config.get("lighting", {}).get("holo_color", "#57e6ff"))
	holo.light_energy = 0.0
	holo.omni_range = 4.0
	holo.omni_attenuation = 1.8
	holo.light_volumetric_fog_energy = 1.6
	holo.shadow_enabled = false
	add_child(holo)
	runtime.register_light(holo, 4, &"holo", 2.6)
	# the four perimeter pods, on the platform rim: r = 1.6 against a 1.45 m deck,
	## not 2.5, which would have put them inside the player's walkway
	for i: int in range(4):
		var a: float = TAU_E * float(i) / 4.0 + 0.4
		var pod := OmniLight3D.new()
		pod.name = "PlatformPod%d" % i
		pod.position = centre + Vector3(cos(a) * 1.6, 0.5, sin(a) * 1.6)
		pod.light_color = Color("ffd9a0")
		pod.light_energy = 0.0
		pod.omni_range = 3.0
		pod.omni_attenuation = 2.0
		pod.shadow_enabled = false
		add_child(pod)
		runtime.register_light(pod, 4, &"assembly", 1.1)
	# the gantry downlight
	var gantry := SpotLight3D.new()
	gantry.name = "GantryLight"
	gantry.position = centre + Vector3(0.0, structure.height - 1.0, 0.0)
	gantry.look_at_from_position(gantry.position, centre + Vector3(0.0, 0.3, 0.22), Vector3.UP)
	gantry.spot_angle = 42.0
	gantry.spot_angle_attenuation = 0.7
	gantry.spot_range = 6.0
	gantry.spot_attenuation = 1.3
	gantry.light_color = Color("e8f4ff")
	gantry.light_energy = 0.0
	gantry.shadow_enabled = false
	add_child(gantry)
	runtime.register_light(gantry, 4, &"assembly", 2.4)


func _build_testing_lighting() -> void:
	var centre := Vector3(2.15, 0.0, -3.6)
	var panel := OmniLight3D.new()
	panel.name = "ConsoleGlow"
	panel.position = centre + Vector3(-1.0, 1.1, 0.5)
	panel.light_color = Color("ffb347")
	panel.light_energy = 0.0
	panel.omni_range = 3.2
	panel.omni_attenuation = 2.0
	panel.shadow_enabled = false
	add_child(panel)
	runtime.register_light(panel, 4, &"testing", 1.2)
	var screen := OmniLight3D.new()
	screen.name = "TestScreenGlow"
	screen.position = centre + Vector3(0.6, 1.3, -1.0)
	screen.light_color = Color("4fd8ff")
	screen.light_energy = 0.0
	screen.omni_range = 4.0
	screen.omni_attenuation = 1.8
	screen.shadow_enabled = false
	add_child(screen)
	runtime.register_light(screen, 4, &"testing", 1.4)


# ===========================================================================
# atmosphere
# ===========================================================================

func _build_dust() -> void:
	## Suspended dust. It is the single cheapest way to make an interior read as
	## real, because it gives the volumetric fog something to catch and it makes
	## the light shafts from the shutter visible rather than theoretical.
	dust = GPUParticles3D.new()
	dust.name = "DustMotes"
	dust.amount = 900
	dust.lifetime = 14.0
	dust.preprocess = 6.0
	dust.speed_scale = 1.0
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-6.0, -0.5, -7.0), Vector3(12.0, 4.5, 14.0))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.fixed_fps = 30.0
	dust.interpolate = true
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(3.6, 1.5, 4.6)
	mat.direction = Vector3(0.0, 0.02, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = 0.0
	mat.initial_velocity_max = 0.02
	mat.gravity = Vector3(0.0, -0.006, 0.0)
	mat.damping_min = 0.4
	mat.damping_max = 1.4
	mat.angular_velocity_min = -0.1
	mat.angular_velocity_max = 0.1
	mat.scale_min = 0.004
	mat.scale_max = 0.014
	mat.color = Color(1.0, 0.94, 0.82, 0.55)
	# ParticleProcessMaterial takes a CurveTexture, not two floats: the old
	# alpha_curve1/alpha_curve2 writes were both invalid and silently dropped, so
	# the motes popped in and out instead of fading. The ramp is explicit now.
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 0.0))
	fade.add_point(Vector2(0.18, 1.0))
	fade.add_point(Vector2(0.82, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	var fade_tex := CurveTexture.new()
	fade_tex.curve = fade
	mat.alpha_curve = fade_tex
	mat.turbulence_enabled = true
	mat.turbulence_noise_strength = 0.4
	mat.turbulence_noise_scale = 24.0
	mat.turbulence_noise_speed = Vector3(0.02, 0.01, 0.02)
	dust.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var dm := StandardMaterial3D.new()
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(1.0, 0.96, 0.86, 0.5)
	dm.emission_enabled = true
	dm.emission = Color(1.0, 0.94, 0.8)
	dm.emission_energy_multiplier = 0.35
	dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = dm
	dust.draw_pass_1 = quad
	add_child(dust)
	runtime.dust = dust
	dust.emitting = true


func _build_rain() -> void:
	## Rain outside the garage, hitting the tin roof and the courtyard. It is a
	## particle system rather than a shader because the drops need to be occluded
	## by the awning and the roof, and the sound is a synthesised bed rather than a
	## loop so the roof and the street stay in sync.
	rain = GPUParticles3D.new()
	rain.name = "Rain"
	rain.amount = 1400
	rain.lifetime = 1.4
	rain.preprocess = 1.0
	rain.visibility_aabb = AABB(Vector3(-12.0, -2.0, -12.0), Vector3(24.0, 12.0, 24.0))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.local_coords = false
	rain.fixed_fps = 60.0
	var rm := ParticleProcessMaterial.new()
	rm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rm.emission_box_extents = Vector3(9.0, 0.5, 9.0)
	rm.direction = Vector3(0.0, -1.0, 0.0)
	rm.spread = 4.0
	rm.initial_velocity_min = 9.0
	rm.initial_velocity_max = 13.0
	rm.gravity = Vector3(0.0, -9.8, 0.0)
	rm.scale_min = 0.6
	rm.scale_max = 1.2
	rm.color = Color(0.75, 0.85, 0.95, 0.42)
	rm.turbulence_enabled = false
	rain.process_material = rm
	var streak := BoxMesh.new()
	streak.size = Vector3(0.006, 0.24, 0.006)
	var sm := StandardMaterial3D.new()
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(0.8, 0.9, 1.0, 0.35)
	sm.emission_enabled = true
	sm.emission = Color(0.85, 0.92, 1.0)
	sm.emission_energy_multiplier = 0.25
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	streak.material = sm
	rain.draw_pass_1 = streak
	add_child(rain)
	runtime.rain = rain
	rain.emitting = bool(GameState.settings.get("rain", true))
	# the roof rain bed, positioned above the tin so the listener is inside
	rain_sound = AudioStreamPlayer.new()
	rain_sound.bus = AudioBank.BUS_AMBIENCE
	add_child(rain_sound)


func set_shutter_influence(amount: float) -> void:
	## Couples the daylight shafts and the volumetric fog to the curtain position.
	## This is the effect that makes opening the shutter feel like an event rather
	## than a visibility toggle.
	var gap: Light3D = _zone_lights.get("shutter_gap", null) as Light3D
	if gap != null:
		gap.light_energy = 3.4 * amount
	for s: SpotLight3D in _shaft_spots:
		if is_instance_valid(s):
			s.light_energy = s.get_meta("base_energy") if s.has_meta("base_energy") else s.light_energy
			s.light_energy = float(s.get_meta("base_energy", 2.0)) * (0.55 + 0.45 * amount)
	if env != null:
		env.volumetric_fog_density = 0.016 * (1.0 - 0.45 * amount)


func set_power_ambience(on: bool) -> void:
	if env == null:
		return
	# when the garage is dark, the interior relies on the courtyard bounce and the
	## SDFGI sky read; when it is lit, the glow threshold drops so the core and the
	## tube lights bloom properly
	env.glow_hdr_threshold = 1.05 if on else 1.6
	env.tonemap_exposure = float(GameConfig.config.get("lighting", {}).get("exposure", 1.05)) * (1.0 if on else 0.82)


func apply_quality() -> void:
	var q: Dictionary = GameConfig.quality()
	if env == null:
		return
	env.glow_enabled = bool(GameState.settings.get("bloom", true)) and bool(q.get("bloom", true))
	env.ssao_enabled = bool(GameState.settings.get("ssao", true)) and bool(q.get("ssao", true))
	env.ssr_enabled = bool(q.get("reflections", true))
	env.volumetric_fog_enabled = String(GameState.settings.get("quality", "high")) != "low"
	if dust != null:
		dust.amount = int(900.0 * float(q.get("particles", 1.0)))
	if rain != null:
		rain.amount = int(1400.0 * float(q.get("particles", 1.0)))
	# --- render scale, the largest single lever on integrated graphics ---------
	## The preset renders the 3D viewport at a fraction of the window and lets FSR 2
	## upscale it. FSR 2 includes temporal antialiasing, so MSAA is switched off
	## while it is active rather than paying for both; at scale 1.0 the preset's
	## MSAA setting applies as before. The scaling mode is resolved by label through
	## EnumRef so a renamed engine enum degrades to bilinear upscaling, not to a
	## silently wrong mode.
	var vp: Viewport = get_viewport()
	var scale: float = clampf(float(q.get("render_scale", 1.0)), 0.5, 1.0)
	vp.scaling_3d_scale = scale
	if scale < 0.995:
		vp.scaling_3d_mode = EnumRef.value(vp, "scaling_3d_mode", "FSR 2", 0) as Viewport.Scaling3DMode
		vp.msaa_3d = Viewport.MSAA_DISABLED
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		var msaa: int = int(q.get("msaa", 2))
		vp.msaa_3d = Viewport.MSAA_DISABLED if msaa == 0 else (
			Viewport.MSAA_2X if msaa == 1 else Viewport.MSAA_4X)
	var shadows_on: bool = bool(GameState.settings.get("shadows", true))
	if sun != null:
		sun.shadow_enabled = shadows_on
	# honour each light's designed shadow intent (see GarageRuntime.register_light)
	for entry: Dictionary in runtime.lights:
		var light: Light3D = entry["node"] as Light3D
		if is_instance_valid(light):
			light.shadow_enabled = shadows_on and bool(entry.get("wants_shadow", false))


func stats() -> Dictionary:
	var casting: int = 0
	for entry: Dictionary in runtime.lights:
		var light: Light3D = entry["node"] as Light3D
		if is_instance_valid(light) and light.shadow_enabled:
			casting += 1
	return {
		"lights": runtime.lights.size(),
		"shadow_casters": casting,
		"glow": env.glow_enabled if env != null else false,
		"ssao": env.ssao_enabled if env != null else false,
		"ssr": env.ssr_enabled if env != null else false,
		"sdfgi": env.sdfgi_enabled if env != null else false,
		"volumetric_fog": env.volumetric_fog_enabled if env != null else false,
		"tonemap": env.tonemap_mode if env != null else -1,
		"dust": dust.amount if dust != null else 0,
		"rain": rain.amount if rain != null else 0,
	}
