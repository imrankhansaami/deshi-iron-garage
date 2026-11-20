extends Node
## Introspects the material UV and shadow properties actually present in this
## engine build, so the texture-scale fix uses real API rather than guesses.

func _ready() -> void:
	var tree: SceneTree = get_tree()
	await tree.process_frame
	var m := StandardMaterial3D.new()
	var uv_names: PackedStringArray = PackedStringArray()
	for p: Dictionary in m.get_property_list():
		var n: String = String(p.get("name", ""))
		if n.contains("triplanar") or n.begins_with("uv1") or n.begins_with("uv2") or n.contains("deccal") or n.contains("decal"):
			uv_names.append(n)
	print("UV: ", ", ".join(uv_names))
	var gi := GeometryInstance3D.new()
	var gi_names: PackedStringArray = PackedStringArray()
	for p2: Dictionary in gi.get_property_list():
		var n2: String = String(p2.get("name", ""))
		if n2.contains("shadow") or n2.contains("gi_mode") or n2.contains("lod"):
			gi_names.append(n2)
	print("GI: ", ", ".join(gi_names))
	var env := Environment.new()
	var env_names: PackedStringArray = PackedStringArray()
	for p3: Dictionary in env.get_property_list():
		var n3: String = String(p3.get("name", ""))
		if n3.contains("sdfgi") or n3.contains("volumetric") or n3.contains("tonemap") or n3.contains("adjustment"):
			env_names.append(n3)
	print("ENV: ", ", ".join(env_names))
	tree.quit()
