extends Node
## Measures one surface at three resolutions so the default texture size is
## chosen from a measurement rather than a guess.

func _ready() -> void:
	var tree: SceneTree = get_tree()
	await tree.process_frame
	var timings: Dictionary = {}
	for size: int in [256, 384, 512]:
		var f = load("res://scripts/procedural/texture_factory.gd").new(size)
		var t0: int = Time.get_ticks_usec()
		var s: Dictionary = f.surface("brick_wall")
		var dt: float = float(Time.get_ticks_usec() - t0) / 1000.0
		var ok: bool = s.get("albedo") != null and (s["albedo"] as Texture2D).get_width() == size
		timings[size] = dt
		print("TIMING size=%d  ms=%.1f  ok=%s" % [size, dt, ok])
		# TextureFactory is a RefCounted: it releases when the scope drops, and
		# calling free() on it is a runtime error rather than a no-op
	var per_512: float = float(timings.get(512, 0.0))
	print("PREDICT 25 surfaces at 512: %.0f ms" % (per_512 * 25.0))
	print("PREDICT 25 surfaces at 384: %.0f ms" % (float(timings.get(384, 0.0)) * 25.0))
	print("TIMING DONE")
	tree.quit()
