extends SceneTree
## Final API sweep: every constant and property the remaining systems touch.

func _c(cls: String, needles: PackedStringArray) -> void:
	if not ClassDB.class_exists(cls):
		print("  MISSING ", cls)
		return
	var names: PackedStringArray = ClassDB.class_get_integer_constant_list(cls, false)
	var hits: PackedStringArray = PackedStringArray()
	for n: String in names:
		for nd: String in needles:
			if n.contains(nd):
				hits.append("%s=%d" % [n, ClassDB.class_get_integer_constant(cls, n)])
				break
	print("  %s: %s" % [cls, ", ".join(hits) if not hits.is_empty() else "(none)"])


func _p(cls: String, skip: PackedStringArray = PackedStringArray()) -> void:
	if not ClassDB.class_exists(cls):
		print("  MISSING ", cls)
		return
	var out: PackedStringArray = PackedStringArray()
	for p: Dictionary in ClassDB.class_get_property_list(cls, false):
		var nm: String = String(p.get("name", ""))
		var bad: bool = false
		for s: String in skip:
			if nm == s:
				bad = true
				break
		if not bad and not nm.begins_with("_"):
			out.append(nm)
	print("  %s: %s" % [cls, ", ".join(out)])


func _m(cls: String, needles: PackedStringArray) -> void:
	var ml: Array = ClassDB.class_get_method_list(cls, false)
	var hits: PackedStringArray = PackedStringArray()
	for m: Dictionary in ml:
		var nm: String = String(m.get("name", ""))
		for nd: String in needles:
			if nm.contains(nd):
				hits.append(nm)
				break
	print("  %s[%s]: %s" % [cls, "|".join(needles), ", ".join(hits) if not hits.is_empty() else "(none)"])


func _initialize() -> void:
	var base: PackedStringArray = PackedStringArray([
		"name", "unique_name_in_owner", "scene_file_path", "owner", "multiplayer",
		"process_mode", "process_priority", "process_physics_priority",
		"process_thread_group", "process_thread_group_order", "process_thread_messages",
		"physics_interpolation_mode", "auto_translate_mode", "editor_description",
		"resource_local_to_scene", "resource_name", "resource_path", "script",
		"visible", "position", "rotation", "rotation_degrees", "scale", "transform",
		"top_level", "y_sort_enabled", "z_range_configured", "z_min", "z_max",
		"translate_node_names", "duplicate_flags", "modulate", "self_modulate", "show_behind_parent",
		"light_mask", "visibility_parent", "pivot_offset", "size", "custom_minimum_size",
		"focus_mode", "mouse_filter", "mouse_default_cursor_shape", "layout_mode",
	])
	print("=== ENVIRONMENT ===")
	_c("Environment", PackedStringArray(["TONEMAP", "SSAO_QUALITY", "GLOW", "ADJUSTMENT", "BG", "AMBIENT", "VOLUMETRIC", "FOG_", "MSAA", "SDFGI", "REFLECTION", "TONEMAP_"]))
	_p("Environment", base)
	print("=== CONTROL / LABEL / BUTTON ===")
	_c("Control", PackedStringArray(["ALIGNMENT", "FOCUS_MODE", "SIZE_FLAG", "MOUSE_FILTER"]))
	_c("TextServer", PackedStringArray(["VERTICAL_ALIGNMENT", "HORIZONTAL_ALIGNMENT", "DIRECTION", "LINE_BREAK", "JUSTIFICATION"]))
	_p("Label", base)
	_p("Button", base)
	_p("RichTextLabel", base)
	print("=== LIGHTS ===")
	_p("DirectionalLight3D", base)
	_p("OmniLight3D", base)
	_p("SpotLight3D", base)
	_c("Light3D", PackedStringArray(["SHADOW", "LIGHT_"]))
	_c("OmniLight3D", PackedStringArray(["SHADOW", "LIGHT_"]))
	print("=== PARTICLES ===")
	_p("GPUParticles3D", base)
	_p("ParticleProcessMaterial", base)
	_c("GPUParticles3D", PackedStringArray(["EMITTING", "CAST_SHADOW", "LIFE"]))
	_c("ParticleProcessMaterial", PackedStringArray(["EMISSION_SHAPE", "DIRECTION", "ANGLE"]))
	print("=== ANIMATION / TWEEN ===")
	_m("AnimationPlayer", PackedStringArray(["play", "advance", "seek", "get_current_animation", "queue", "speed", "on", "paused"]))
	_m("Tween", PackedStringArray(["tween", "method", "interval", "chain", "set_", "stop", "finish", "bind", "playback"]))
	_c("Tween", PackedStringArray(["TRANS", "EASE", "TWEEN_"]))
	_m("AnimationLibrary", PackedStringArray(["add", "get", "has", "rename", "erase"]))
	_m("Animation", PackedStringArray(["add", "track", "value", "length", "loop"]))
	_c("Animation", PackedStringArray(["TRACK_TYPE", "LOOP_MODE", "UPDATE_CONTINUOUS"]))
	print("=== MESH / MULTIMESH ===")
	_p("MultiMesh", base)
	_p("MultiMeshInstance3D", base)
	_c("MultiMesh", PackedStringArray(["TRANSFORM_FORMAT", "COLOR_FORMAT"]))
	_m("PrimitiveMesh", PackedStringArray(["get_", "create"]))
	_m("ArrayMesh", PackedStringArray(["add_surface", "surface", "clear", "tool"]))
	_m("SurfaceTool", PackedStringArray(["commit", "generate", "set_", "add_", "begin", "index", "vertices"]))
	print("=== PHYSICS / COLLISION ===")
	_p("CharacterBody3D", base)
	_c("CharacterBody3D", PackedStringArray(["MOVEMENT_SLIDE", "SAFE"]))
	_p("CollisionShape3D", base)
	_p("BoxShape3D", base)
	_p("ConcaveShape3D", base)
	_p("HeightMapShape3D", base)
	_p("WorldBoundaryShape3D", base)
	print("=== AUDIO NODES ===")
	_p("AudioStreamPlayer", base)
	_p("AudioStreamPlayer3D", base)
	_p("AudioEffectReverb", base)
	_c("AudioStreamPlayer3D", PackedStringArray(["ATTENUATION", "MAX_DB", "UNIT"]))
	print("=== CAMERA / ATTRIBUTES ===")
	_p("Camera3D", base)
	_p("CameraAttributesPhysical", base)
	_p("WorldEnvironment", base)
	_p("Node3D", PackedStringArray([]))
	print("=== RENDERING / MISC ===")
	_c("RenderingServer", PackedStringArray(["RENDERING_INFO", "CANVAS_ITEM", "TEXTURE"]))
	_c("Viewport", PackedStringArray(["MSAA", "SCREEN_SPACE_AA", "DEBUG_DRAW", "RENDER_INFO", "SCALE_MODE", "STRETCH_MODE"]))
	_c("Window", PackedStringArray(["MODE_", "WINDOW_FLAG", "CONTENT_SCALE"]))
	_c("DisplayServer", PackedStringArray(["WINDOW_MODE", "SCREEN", "VSYNC"]))
	_c("Image", PackedStringArray(["FORMAT_"]))
	_c("BaseMaterial3D", PackedStringArray(["EMISSION", "DISABLED", "ENABLED", "AO", "REFLECTION", "NORMAL_MAP", "DECAL"]))
	_c("Material", PackedStringArray(["SHADER_MODE"]))
	_c("Shader", PackedStringArray(["CODE", "MODE", "STEP", "INCLUDE"]))
	_c("ResourceLoader", PackedStringArray(["CACHE", "MODE"]))
	_c("PhysicsServer3D", PackedStringArray(["BODY_", "MARGIN"]))
	_c("OS", PackedStringArray(["FEATURE", "NAME", "DELTA"]))
	quit()
