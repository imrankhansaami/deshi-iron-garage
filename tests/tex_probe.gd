extends SceneTree
## Minimal probe for the banded surface synthesis: one key, verbatim output.

func _initialize() -> void:
	var lib: Node = load("res://scripts/core/material_library.gd").new()
	lib.ensure_built()
	var out: Dictionary = lib.factory.surface("teak")
	print("PROBE out.keys=%s" % str(out.keys()))
	quit()
