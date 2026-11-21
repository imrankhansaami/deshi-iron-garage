extends SceneTree
## Surface synthesis bench: checksums + timing for a handful of representative
## keys, so the banded parallel pass can be proven bit-identical to itself across
## runs and measured against the old wall clock.
##
## Usage:  godot --headless --path . -s res://tests/surface_bench.gd

func _initialize() -> void:
	var lib: Node = load("res://scripts/core/material_library.gd").new()
	lib.ensure_built()
	var factory: RefCounted = lib.factory
	var keys: Array = ["brick_cement", "plaster_painted", "worn_concrete", "teak", "steel", "paint_red"]
	var t_all: int = Time.get_ticks_msec()
	for key: String in keys:
		var t0: int = Time.get_ticks_msec()
		var s: Dictionary = factory.surface(key)
		var dt: int = Time.get_ticks_msec() - t0
		var checksums: Array = []
		for tex_name: String in ["albedo", "orm", "normal"]:
			var tex: ImageTexture = s[tex_name]
			var ctx := HashingContext.new()
			ctx.start(HashingContext.HASH_MD5)
			ctx.update(tex.get_image().get_data())
			checksums.append(ctx.finish().hex_encode().substr(0, 12))
		print("BENCH: %-16s %4d ms  csum=%s|%s|%s  pc=%d" % [
			key, dt, checksums[0], checksums[1], checksums[2], OS.get_processor_count()])
	print("BENCH: total %d ms for %d surfaces" % [Time.get_ticks_msec() - t_all, keys.size()])
	quit()
