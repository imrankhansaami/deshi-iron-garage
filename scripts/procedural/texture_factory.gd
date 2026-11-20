class_name TextureFactory
extends RefCounted
## Procedural PBR texture synthesis (Contribution A, docs/GRAPHICS_ALGORITHMS.md).
##
## Every surface in the garage is built at runtime from noise: no downloaded image
## packs, no photogrammetry. For each material the factory produces an aligned
## channel set:
##
##   albedo  RGB8   base colour + mottling + grime + edge wear + scratches
##   orm     RGB8   packed occlusion / roughness / metallic (Godot's ORM convention)
##   normal  RGB8   tangent-space normal derived from a height field by Sobel gradient
##
## The height field is the single source of truth: albedo tint, roughness and
## normal all read from the same noise samples, so pores stay dark AND rough AND
## recessed instead of disagreeing with each other. That coherence is what makes
## a procedural surface read as real.
##
## Cost is paid once per material at load and cached for the session; the benchmark
## harness reports generation time per surface.

## Measured on the target hardware (Intel UHD 620, Godot 4.7.2): one surface costs
## ~440 ms at 256, ~1.0 s at 384 and ~1.7 s at 512, and the cost is the per-texel
## arithmetic loop in GDScript rather than the noise itself — the C++ field
## generation is already off the critical path. 256 is therefore the default,
## scaled up to 384 only on the high preset, because the garage touches roughly
## twenty surfaces and load time is what the player actually waits for.
## Tiling hides the resolution: every wall repeats these maps 2-6 times anyway.
const DEFAULT_SIZE: int = 256

var _cache: Dictionary = {}
var _recipes: Dictionary = {}
var _gen_times: Dictionary = {}
var _size: int = DEFAULT_SIZE
var _rng_seed_base: int = 0x5E1A


func _init(size: int = DEFAULT_SIZE, seed_base: int = 0x5E1A) -> void:
	_size = maxi(64, size)
	_rng_seed_base = seed_base


func generation_time(key: String) -> float:
	return float(_gen_times.get(key, 0.0))


func total_generation_ms() -> float:
	var sum: float = 0.0
	for k: String in _gen_times:
		sum += float(_gen_times[k])
	return sum


func cached_keys() -> Array:
	return _cache.keys()


# ===========================================================================
# Public entry points
# ===========================================================================

## Returns { albedo: ImageTexture, orm: ImageTexture, normal: ImageTexture, uv_scale: Vector2 }
func surface(key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var t0: int = Time.get_ticks_usec()
	var spec: Dictionary = _recipe(key)
	var out: Dictionary = _synthesize(key, spec)
	_gen_times[key] = float(Time.get_ticks_usec() - t0) / 1000.0
	_cache[key] = out
	return out


func clear_cache() -> void:
	_cache.clear()
	_gen_times.clear()


# ===========================================================================
# Channel synthesis
# ===========================================================================

## Looks up a surface recipe. Unknown keys fall back to a neutral plaster so a
## typo in a builder degrades visually instead of crashing the load.
func _recipe(key: String) -> Dictionary:
	if _recipes.is_empty():
		_recipes = recipes()
	var found: Variant = _recipes.get(key, null)
	if found == null:
		push_warning("TextureFactory: unknown surface '%s', falling back to plaster" % key)
		return _recipes.get("cement_plaster", {}) as Dictionary
	return found as Dictionary


## Produces one noise field as raw R8 bytes.
##
## The cost model here is the reason the whole factory is written this way:
## evaluating noise per texel in GDScript measured 7.8 s for a single 512x512
## surface, which is unusable. FastNoiseLite fills the same field in C++ in a few
## milliseconds, so every scalar field is generated as an Image, converted to R8
## and read back as a PackedByteArray. The per-texel loop then does arithmetic on
## byte indices only, and the finished channel maps are uploaded in one
## create_from_data call instead of 262144 set_pixel calls.
##
## Under --headless the RenderingServer is a dummy and get_image() returns an
## empty Image, so there is a GDScript fallback path. It is slow, and that is
## acceptable: it only ever runs in CI, never in the shipped game.
func _field_bytes(seed: int, cycles: float, octaves: int, type: int, size: int) -> PackedByteArray:
	var fn := FastNoiseLite.new()
	fn.seed = seed
	fn.noise_type = type
	fn.frequency = maxf(cycles, 0.01) / float(size)
	fn.fractal_octaves = clampi(octaves, 1, 8)
	fn.fractal_lacunarity = 2.05
	fn.fractal_gain = 0.52
	var img: Image = fn.get_image(size, size)
	if img != null and not img.is_empty() and img.get_size() == Vector2i(size, size):
		if img.get_format() != Image.FORMAT_R8:
			img.convert(Image.FORMAT_R8)
		var bytes: PackedByteArray = img.get_data()
		if bytes.size() == size * size:
			return bytes
	# headless fallback
	var out: PackedByteArray = PackedByteArray()
	out.resize(size * size)
	var f: float = maxf(cycles, 0.01)
	for y: int in range(size):
		for x: int in range(size):
			var u: float = float(x) / float(size) * f
			var v: float = float(y) / float(size) * f
			var n: float
			match type:
				FastNoiseLite.TYPE_CELLULAR:
					n = 1.0 - NoiseTools.worley(u / maxf(f, 0.001), v / maxf(f, 0.001), f, seed)
				FastNoiseLite.TYPE_VALUE:
					n = NoiseTools.value_noise(u, v, seed)
				_:
					n = NoiseTools.fbm(u, v, clampi(octaves, 1, 6), 1.0, 2.05, 0.52, seed)
			out[y * size + x] = int(clampf(n, 0.0, 1.0) * 255.0)
	return out


func _synthesize(key: String, spec: Dictionary) -> Dictionary:
	var size: int = int(spec.get("size", _size))
	var seed: int = _rng_seed_base + key.hash() % 100000
	var repeat_u: float = maxf(0.25, float(spec.get("repeat", [1.0, 1.0])[0]))
	var repeat_v: float = maxf(0.25, float(spec.get("repeat", [1.0, 1.0])[1]))

	# --- 1. field buffers ------------------------------------------------
	var height: PackedFloat32Array = PackedFloat32Array()
	var rough: PackedFloat32Array = PackedFloat32Array()
	var metal: PackedFloat32Array = PackedFloat32Array()
	var ao: PackedFloat32Array = PackedFloat32Array()
	var col: PackedFloat32Array = PackedFloat32Array()   # linear RGB triples
	height.resize(size * size)
	rough.resize(size * size)
	metal.resize(size * size)
	ao.resize(size * size)
	col.resize(size * size * 3)

	var base: Color = Color.from_string(String(spec.get("base", "#808080")), Color.GRAY)
	var tint_a: Color = Color.from_string(String(spec.get("tint_a", "#604f42")), Color.BROWN)
	var tint_b: Color = Color.from_string(String(spec.get("tint_b", "#9a9a9a")), Color.LIGHT_GRAY)
	var grain: float = float(spec.get("grain", 0.25))
	var grain_scale: float = float(spec.get("grain_scale", 8.0))
	var mottle_scale: float = float(spec.get("mottle_scale", 1.6))
	var rough_base: float = clampf(float(spec.get("rough", 0.6)), 0.0, 1.0)
	var rough_var: float = clampf(float(spec.get("rough_var", 0.2)), 0.0, 0.6)
	var metal_base: float = clampf(float(spec.get("metal", 0.0)), 0.0, 1.0)
	var metal_var: float = clampf(float(spec.get("metal_var", 0.0)), 0.0, 1.0)
	var wear: float = clampf(float(spec.get("wear", 0.0)), 0.0, 1.0)
	var pits: float = clampf(float(spec.get("pits", 0.0)), 0.0, 1.0)
	var streaks: float = clampf(float(spec.get("streaks", 0.0)), 0.0, 1.0)
	var pattern: String = String(spec.get("pattern", "none"))
	var pattern_scale: float = float(spec.get("pattern_scale", 8.0))
	var height_amp: float = float(spec.get("height_amp", 1.0))
	var bump: float = float(spec.get("bump", 1.0))

	# Every scalar field the surface needs, generated in one bulk C++ pass each.
	# Twelve FastNoiseLite fills cost tens of milliseconds at 512x512; evaluating
	# the same twelve per texel in GDScript cost 7.8 seconds, which is what made
	# the original implementation unusable.
	var fb_mottle: PackedByteArray = _field_bytes(seed, mottle_scale, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, size)
	var fb_grain: PackedByteArray = _field_bytes(seed + 977, grain_scale, 2, FastNoiseLite.TYPE_VALUE, size)
	var fb_fine: PackedByteArray = _field_bytes(seed + 3313, 26.0, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, size)
	var fb_wear: PackedByteArray = _field_bytes(seed + 5501, 3.5, 1, FastNoiseLite.TYPE_CELLULAR, size)
	var fb_front: PackedByteArray = _field_bytes(seed + 401, 3.2, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, size)
	var fb_pit: PackedByteArray = _field_bytes(seed + 811, pattern_scale * 5.0 + 6.0, 1, FastNoiseLite.TYPE_CELLULAR, size)
	var fb_streak: PackedByteArray = _field_bytes(seed + 1201, pattern_scale * 2.4, 2, FastNoiseLite.TYPE_VALUE, size)
	var fb_along: PackedByteArray = _field_bytes(seed + 1223, pattern_scale * 2.4, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, size)
	var fb_scratch: PackedByteArray = _field_bytes(seed + 2011, 90.0, 2, FastNoiseLite.TYPE_VALUE, size)
	var fb_pat_a: PackedByteArray = _field_bytes(seed + 71, pattern_scale * 1.2, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, size)
	var fb_pat_b: PackedByteArray = _field_bytes(seed + 173, pattern_scale * 9.0, 2, FastNoiseLite.TYPE_VALUE, size)
	var fb_pat_c: PackedByteArray = _field_bytes(seed + 91, pattern_scale * 4.0, 1, FastNoiseLite.TYPE_CELLULAR, size)
	var inv: float = 1.0 / 255.0

	# --- 2. per-texel evaluation ---------------------------------------
	for y: int in range(size):
		for x: int in range(size):
			var i: int = y * size + x
			var u: float = float(x) / float(size)
			var v: float = float(y) / float(size)
			# byte reads, not noise evaluation: this is the whole point of the
			# precomputed field layer above
			var m: float = float(fb_mottle[i]) * inv * 2.0 - 1.0
			var g: float = float(fb_grain[i]) * inv * 2.0 - 1.0
			var f: float = float(fb_fine[i]) * inv * 2.0 - 1.0
			var wr: float = float(fb_wear[i]) * inv
			var n_a: float = float(fb_pat_a[i]) * inv
			var n_b: float = float(fb_pat_b[i]) * inv
			var n_c: float = float(fb_pat_c[i]) * inv

			var h: float = m * 0.5 + g * 0.28 + f * 0.22
			var c: Color = base.lerp(tint_a, clampf(m * 0.5 + 0.5, 0.0, 1.0) * grain)
			c = c.lerp(tint_b, clampf(-m * 0.5 + 0.5, 0.0, 1.0) * grain * 0.7)
			var rgh: float = rough_base + m * rough_var * 0.6 + g * rough_var * 0.4
			var mt: float = metal_base
			var occ: float = 1.0

			# ---- pattern layers ----------------------------------------
			match pattern:
				"brick":
					var b: Dictionary = _brick_field(u, v, pattern_scale, seed, n_a)
					h = b.h
					c = b.color
					rgh = b.rough
					occ = b.ao
				"corrugation":
					var wave: float = sin(v * TAU * pattern_scale)
					h = wave * 0.9 + f * 0.12
					rgh = rough_base + absf(wave) * 0.12
					c = base.lerp(tint_b, 0.5 + wave * 0.5)
				"weave":
					var wx: float = sin(u * TAU * pattern_scale)
					var wy: float = sin(v * TAU * pattern_scale + 1.5708)
					h = maxf(wx, wy) * 0.7 + f * 0.3
					c = base.lerp(tint_a, 0.5 + wx * wy * 0.5)
				"wood_grain":
					var rings: float = n_a
					var fibre: float = n_b
					h = rings * 0.55 + fibre * 0.45
					var t: float = clampf(rings * 1.4 + fibre * 0.3, 0.0, 1.0)
					c = base.lerp(tint_a, t)
					rgh = rough_base + t * 0.18 - fibre * 0.06
				"circuit":
					var p: Dictionary = _pcb_field(u, v, pattern_scale, n_a, n_b, n_c)
					h = p.h
					c = p.color
					rgh = p.rough
					mt = p.metal
				"panel_lines":
					var pl: float = _panel_gaps(u, v, pattern_scale)
					h = -pl
					rgh = rough_base + pl * 0.35
					occ = 1.0 - pl * 0.55
				"tile_grid":
					var tg: Dictionary = _tile_field(u, v, pattern_scale, n_a, n_b)
					h = tg.h
					c = tg.color
					rgh = tg.rough
					occ = tg.ao
				_:
					pass

			# ---- corrosion / paint loss --------------------------------
			# a corrosion front: wherever the precomputed field crosses the
			# threshold set by `wear`, the coating is gone
			if wear > 0.0:
				var front: float = float(fb_front[i]) * inv
				var mask: float = clampf((front - (1.0 - wear)) / 0.28, 0.0, 1.0) * wr
				c = c.lerp(tint_b, mask)
				mt = lerpf(mt, 1.0, mask * 0.9)
				rgh = lerpf(rgh, clampf(rgh + 0.28, 0.0, 1.0), mask)
				h -= mask * 0.35
				occ = lerpf(occ, 0.72, mask)

			# ---- pitting ------------------------------------------------
			if pits > 0.0:
				# cellular field: 0 at a feature point, 1 between them, so
				# inverting it puts the damage in the cell centres
				var cell: float = float(fb_pit[i]) * inv
				var pit: float = clampf(1.0 - cell / (0.14 + pits * 0.2), 0.0, 1.0)
				h -= pit * pits * 2.2
				rgh = clampf(rgh + pit * pits * 0.5, 0.0, 1.0)
				c = c.darkened(pit * pits * 0.55)
				occ = lerpf(occ, occ - 0.35, pit * pits)

			# ---- vertical grime streaks (rain / oil running down) -------
			if streaks > 0.0:
				var sx: float = float(fb_streak[i]) * inv
				var along: float = float(fb_along[i]) * inv
				var drip: float = clampf((along - 0.52) * 2.6, 0.0, 1.0) * sx * streaks
				c = c.darkened(drip * 0.42)
				rgh = clampf(rgh - drip * 0.14, 0.05, 1.0)
				h += drip * 0.12

			# ---- micro scratches on metals -----------------------------
			if metal_base > 0.4:
				var sc: float = float(fb_scratch[i]) * inv
				var line: float = clampf(absf(sc - 0.5) * 34.0 - 16.0, 0.0, 1.0)
				rgh = clampf(rgh - line * 0.22, 0.03, 1.0)
				h += line * 0.05

			# ---- store -------------------------------------------------
			var o: int = i * 3
			col[o] = c.r
			col[o + 1] = c.g
			col[o + 2] = c.b
			height[i] = h * height_amp
			rough[i] = clampf(rgh, 0.02, 1.0)
			metal[i] = clampf(mt + (metal_var * (g * 0.5 + 0.5) - metal_var * 0.5), 0.0, 1.0)
			ao[i] = clampf(occ, 0.0, 1.0)

	# --- 3. pack channels into images -----------------------------------
	# One create_from_data per channel. set_pixel() per texel measured as a
	# significant share of the original 7.8 s, and the byte buffers are already in
	# the exact RGB8 layout the Image expects.
	var albedo_bytes: PackedByteArray = PackedByteArray()
	albedo_bytes.resize(size * size * 3)
	var orm_bytes: PackedByteArray = PackedByteArray()
	orm_bytes.resize(size * size * 3)
	for i: int in range(size * size):
		var o: int = i * 3
		var r: float = clampf(col[o], 0.0, 1.0)
		var gg: float = clampf(col[o + 1], 0.0, 1.0)
		var bb: float = clampf(col[o + 2], 0.0, 1.0)
		albedo_bytes[o] = int(r * 255.0)
		albedo_bytes[o + 1] = int(gg * 255.0)
		albedo_bytes[o + 2] = int(bb * 255.0)
		orm_bytes[o] = int(clampf(ao[i], 0.0, 1.0) * 255.0)
		orm_bytes[o + 1] = int(clampf(rough[i], 0.0, 1.0) * 255.0)
		orm_bytes[o + 2] = int(clampf(metal[i], 0.0, 1.0) * 255.0)

	var albedo_img: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGB8, albedo_bytes)
	var orm_img: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGB8, orm_bytes)
	var normal_img: Image = _height_to_normal(height, size, bump)

	var tex_albedo: ImageTexture = ImageTexture.create_from_image(albedo_img)
	var tex_orm: ImageTexture = ImageTexture.create_from_image(orm_img)
	var tex_normal: ImageTexture = ImageTexture.create_from_image(normal_img)

	return {
		"albedo": tex_albedo,
		"orm": tex_orm,
		"normal": tex_normal,
		"uv_scale": Vector2(repeat_u, repeat_v),
		"size": size,
	}


# ===========================================================================
# Normal derivation
# ===========================================================================

func _height_to_normal(height: PackedFloat32Array, size: int, strength: float) -> Image:
	## Sobel gradient of the wrapped height field -> tangent-space normal, encoded
	## as (n * 0.5 + 0.5). Wrapping keeps the map tileable, which matters because
	## every wall and floor in the garage repeats these textures many times.
	## Built as a byte buffer and uploaded in one call, for the same reason as the
	## albedo and ORM channels.
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size * size * 3)
	var s: float = strength * 6.0
	for y: int in range(size):
		var ym: int = (y - 1 + size) % size
		var yp: int = (y + 1) % size
		for x: int in range(size):
			var xm: int = (x - 1 + size) % size
			var xp: int = (x + 1) % size
			var tl: float = height[ym * size + xm]
			var t: float = height[ym * size + x]
			var tr: float = height[ym * size + xp]
			var l: float = height[y * size + xm]
			var r: float = height[y * size + xp]
			var bl: float = height[yp * size + xm]
			var b: float = height[yp * size + x]
			var br: float = height[yp * size + xp]
			var dx: float = (tr + 2.0 * r + br) - (tl + 2.0 * l + bl)
			var dy: float = (bl + 2.0 * b + br) - (tl + 2.0 * t + tr)
			var nx: float = -dx * s
			var ny: float = -dy * s
			var inv_len: float = 1.0 / sqrt(nx * nx + ny * ny + 1.0)
			var o: int = (y * size + x) * 3
			bytes[o] = int((nx * inv_len * 0.5 + 0.5) * 255.0)
			bytes[o + 1] = int((ny * inv_len * 0.5 + 0.5) * 255.0)
			bytes[o + 2] = int((1.0 * inv_len * 0.5 + 0.5) * 255.0)
	return Image.create_from_data(size, size, false, Image.FORMAT_RGB8, bytes)


# ===========================================================================
# Pattern fields
# ===========================================================================

func _brick_field(u: float, v: float, courses: float, seed: int, face_noise: float) -> Dictionary:
	## Stretcher-bond brick with mortar joints. Returns height/colour/rough/ao.
	## Every other course is offset by half a brick so the bond reads correctly
	## instead of the vertical-grout look a naive grid produces. `face_noise` is
	## the precomputed per-texel value; the per-brick tint comes from a hash, which
	## is cheap because it is one lookup per brick rather than per texel.
	var rows: float = courses
	var cols: float = courses * 2.2
	var row: float = v * rows
	var row_idx: int = int(floor(row))
	var offset: float = 0.5 if (row_idx % 2 == 0) else 0.0
	var col_pos: float = fposmod(u * cols + offset, cols)
	var col_idx: int = int(floor(col_pos))
	var fx: float = col_pos - float(col_idx)
	var fy: float = row - float(row_idx)

	var mortar_w: float = 0.075
	var in_x: float = minf(fx, 1.0 - fx)
	var in_y: float = minf(fy, 1.0 - fy)
	var joint: float = 1.0 - clampf(minf(in_x, in_y) / mortar_w, 0.0, 1.0)

	# per-brick variation from an integer hash, so bricks differ but stay stable
	var bh: float = NoiseTools.hash2i(col_idx, row_idx, seed)
	var face: float = face_noise
	var edge_dark: float = clampf(joint, 0.0, 1.0)

	var brick_a: Color = Color.from_string("#7d3f2e", Color.WHITE)
	var brick_b: Color = Color.from_string("#94553a", Color.WHITE)
	var brick_c: Color = Color.from_string("#5e2c22", Color.WHITE)
	var c: Color = brick_a.lerp(brick_b, bh)
	c = c.lerp(brick_c, clampf(face * 0.75 - 0.15, 0.0, 1.0) * 0.6)
	c = c.lerp(Color("#b9b0a1"), edge_dark * 0.92)          # mortar

	var h: float = -edge_dark * 1.15 + (face - 0.5) * 0.34 * (1.0 - edge_dark)
	var rgh: float = lerpf(0.86, 0.95, edge_dark) + (face - 0.5) * 0.1
	var occ: float = 1.0 - edge_dark * 0.62
	return {"h": h, "color": c, "rough": clampf(rgh, 0.2, 1.0), "ao": clampf(occ, 0.0, 1.0)}


func _pcb_field(u: float, v: float, density: float, n_a: float, n_b: float, n_c: float) -> Dictionary:
	## FR4 board: solder mask over copper traces, silkscreen legends, plated
	## through-holes and pads. Traces run on 45° bends the way real routing does.
	var g: float = density
	var gx: float = u * g
	var gy: float = v * g
	var cell: Vector2i = Vector2i(int(floor(gx)), int(floor(gy)))
	var r: float = n_a
	var trace: float = 0.0
	var pad: float = 0.0

	# trace segments: horizontal, vertical or diagonal depending on cell hash
	var local: Vector2 = Vector2(fposmod(gx, 1.0), fposmod(gy, 1.0))
	var kind: int = int(r * 4.0) % 4
	var width_t: float = 0.16
	match kind:
		0:
			trace = 1.0 - clampf(absf(local.y - 0.5) / width_t, 0.0, 1.0)
		1:
			trace = 1.0 - clampf(absf(local.x - 0.5) / width_t, 0.0, 1.0)
		2:
			trace = 1.0 - clampf(absf(local.x - local.y) / (width_t * 1.414), 0.0, 1.0)
		3:
			trace = 1.0 - clampf(absf(local.x + local.y - 1.0) / (width_t * 1.414), 0.0, 1.0)
	trace = clampf(trace, 0.0, 1.0)

	# pads at cell corners for a fraction of cells
	var pr: float = n_b
	if pr > 0.62:
		var d: float = local.length()
		pad = clampf(1.0 - absf(d - 0.17) / 0.06, 0.0, 1.0)

	# silkscreen reference ticks
	var sr: float = n_c
	var silk: float = 0.0
	if sr > 0.84:
		silk = clampf(1.0 - absf(local.y - 0.78) / 0.02, 0.0, 1.0) * clampf(1.0 - absf(local.x - 0.5) / 0.3, 0.0, 1.0)

	var mask: Color = Color.from_string("#123b2c", Color.BLACK)
	var mask_alt: Color = Color.from_string("#0d5a3c", Color.BLACK)
	var copper: Color = Color.from_string("#c9a227", Color.WHITE)
	var solder: Color = Color.from_string("#d8d2c4", Color.WHITE)
	var silk_c: Color = Color.from_string("#e8e6df", Color.WHITE)

	var c: Color = mask.lerp(mask_alt, n_a)
	c = c.lerp(copper, trace)
	c = c.lerp(solder, pad * 0.9)
	c = c.lerp(silk_c, silk)

	var h: float = trace * 0.22 + pad * 0.42 - (1.0 - silk) * 0.0
	var rgh: float = lerpf(0.62, 0.28, maxf(trace, pad))
	var mt: float = clampf(maxf(trace * 0.85, pad * 0.95), 0.0, 1.0)
	return {"h": h, "color": c, "rough": rgh, "metal": mt}


func _tile_field(u: float, v: float, n: float, hv: float, speck_v: float) -> Dictionary:
	var gx: float = u * n
	var gy: float = v * n
	var lx: float = fposmod(gx, 1.0)
	var ly: float = fposmod(gy, 1.0)
	var joint: float = 1.0 - clampf(minf(minf(lx, 1.0 - lx), minf(ly, 1.0 - ly)) / 0.06, 0.0, 1.0)
	var ci: Vector2i = Vector2i(int(floor(gx)), int(floor(gy)))
	var hv2: float = hv
	var c: Color = Color.from_string("#8e8a80", Color.WHITE).lerp(Color.from_string("#a5a094", Color.WHITE), hv2)
	c = c.lerp(Color("#6f6b62"), joint * 0.8)
	var speck: float = speck_v
	c = c.darkened(clampf(speck - 0.72, 0.0, 1.0) * 1.6)
	return {"h": -joint * 0.9 + (speck - 0.5) * 0.08, "color": c, "rough": lerpf(0.55, 0.9, joint), "ao": 1.0 - joint * 0.5}


func _panel_gaps(u: float, v: float, n: float) -> float:
	var lx: float = fposmod(u * n, 1.0)
	var ly: float = fposmod(v * n, 1.0)
	return 1.0 - clampf(minf(minf(lx, 1.0 - lx), minf(ly, 1.0 - ly)) / 0.045, 0.0, 1.0)


# ===========================================================================
# The recipe table. Colours are sRGB hex; noise scales are cycles per texture.
# "wear" adds a corrosion front, "pits" adds Worley pitting, "streaks" adds
# vertical grime, metal_base drives the micro-scratch pass.
# ===========================================================================

## Physical tiling density per surface, in metres covered by one texture repeat.
## This is the number that decides whether a wall reads as brick or as camouflage,
## so it is stated once, in metres, rather than being buried as an ad-hoc uv_scale
## at each call site. Chosen from real dimensions: a brick course with a mortar
## joint is about 110 mm, so nine courses is roughly a metre; a corrugated tin
## sheet is about 1.2 m wide; a 400 mm concrete block, four of them per repeat.
const TILE_METERS: Dictionary = {
	"brick_wall": 1.0, "cement_plaster": 2.6, "concrete_block": 1.7,
	"worn_concrete": 3.2, "sealed_concrete": 4.0, "packed_earth": 2.0,
	"corrugated_tin": 1.2, "rust_sheet": 1.5,
	"steel_brushed": 0.45, "steel_dark": 0.4, "cast_iron": 0.3, "chrome": 0.25,
	"brass": 0.2, "copper": 0.2, "aluminium": 0.4, "lead_grey": 0.25,
	"painted_red": 0.5, "painted_blue": 0.5, "painted_green": 0.5, "painted_yellow": 0.5,
	"armour_red": 0.35, "armour_gold": 0.3,
	"teak": 0.8, "bamboo": 0.6, "plywood": 0.9, "rattan": 0.5,
	"rubber": 0.25, "plastic_black": 0.2, "plastic_faded": 0.3, "plastic_red": 0.2,
	"glass_smoky": 0.5, "circuit_board": 0.14,
	"fabric": 0.4, "gamcha": 0.35, "newspaper": 0.3, "paper_notebook": 0.22,
}


static var _stamped: Dictionary = {}


## The recipe table with its physical tiling density attached. Cached because the
## material library asks for it on every surface it builds.
static func recipes() -> Dictionary:
	if not _stamped.is_empty():
		return _stamped
	var raw: Dictionary = _raw_recipes()
	for key: String in raw:
		var r: Dictionary = raw[key]
		if not r.has("meters_per_tile"):
			r["meters_per_tile"] = float(TILE_METERS.get(key, 1.0))
		_stamped[key] = r
	return _stamped


static func _raw_recipes() -> Dictionary:
	return {
		# --- structure ---------------------------------------------------
		"brick_wall": {
			"base": "#6f4030", "tint_a": "#8a5540", "tint_b": "#b9b0a1",
			"pattern": "brick", "pattern_scale": 9.0, "grain": 0.35, "grain_scale": 12.0,
			"rough": 0.85, "rough_var": 0.12, "height_amp": 1.35, "bump": 1.5,
			"streaks": 0.35, "repeat": [1.0, 1.0],
		},
		"cement_plaster": {
			"base": "#a9a49a", "tint_a": "#8e8a82", "tint_b": "#c2beb4",
			"grain": 0.5, "grain_scale": 22.0, "mottle_scale": 2.2,
			"rough": 0.88, "rough_var": 0.16, "height_amp": 0.7, "bump": 0.8,
			"streaks": 0.3, "pits": 0.12, "wear": 0.12, "repeat": [1.0, 1.0],
		},
		"concrete_block": {
			"base": "#94918c", "tint_a": "#7d7a75", "tint_b": "#adaaa4",
			"pattern": "panel_lines", "pattern_scale": 4.0, "grain": 0.55, "grain_scale": 30.0,
			"rough": 0.9, "rough_var": 0.1, "height_amp": 0.9, "bump": 1.0, "pits": 0.2, "repeat": [1.0, 1.0],
		},
		"worn_concrete": {
			"base": "#7c7a76", "tint_a": "#666460", "tint_b": "#94928c",
			"grain": 0.6, "grain_scale": 34.0, "mottle_scale": 1.2,
			"rough": 0.78, "rough_var": 0.22, "height_amp": 0.55, "bump": 0.7,
			"pits": 0.22, "streaks": 0.25, "wear": 0.1, "repeat": [1.0, 1.0],
		},
		"sealed_concrete": {
			"base": "#6e6f70", "tint_a": "#5a5b5c", "tint_b": "#85868a",
			"grain": 0.4, "grain_scale": 26.0, "rough": 0.45, "rough_var": 0.18,
			"height_amp": 0.3, "bump": 0.4, "pattern": "panel_lines", "pattern_scale": 2.0, "repeat": [1.0, 1.0],
		},
		"packed_earth": {
			"base": "#7a6248", "tint_a": "#5f4a35", "tint_b": "#93795c",
			"grain": 0.75, "grain_scale": 40.0, "mottle_scale": 1.0,
			"rough": 0.95, "rough_var": 0.08, "height_amp": 0.9, "bump": 1.1, "pits": 0.3, "repeat": [1.0, 1.0],
		},
		"corrugated_tin": {
			"base": "#8b8f96", "tint_a": "#6d7178", "tint_b": "#a8adb4",
			"pattern": "corrugation", "pattern_scale": 14.0, "grain": 0.3, "grain_scale": 18.0,
			"metal": 0.85, "metal_var": 0.1, "rough": 0.42, "rough_var": 0.25,
			"height_amp": 1.6, "bump": 1.8, "wear": 0.28, "repeat": [1.0, 1.0],
		},
		"rust_sheet": {
			"base": "#6d4a2f", "tint_a": "#4a2e1c", "tint_b": "#8c5a34",
			"grain": 0.7, "grain_scale": 28.0, "mottle_scale": 1.4,
			"rough": 0.92, "rough_var": 0.1, "metal": 0.15, "metal_var": 0.2,
			"height_amp": 1.1, "bump": 1.3, "wear": 0.55, "pits": 0.4, "repeat": [1.0, 1.0],
		},

		# --- metals ------------------------------------------------------
		"steel_brushed": {
			"base": "#9aa0a6", "tint_a": "#7e848a", "tint_b": "#b6bcc2",
			"metal": 1.0, "metal_var": 0.04, "rough": 0.34, "rough_var": 0.16,
			"grain": 0.2, "grain_scale": 60.0, "height_amp": 0.25, "bump": 0.5, "repeat": [1.0, 1.0],
		},
		"steel_dark": {
			"base": "#4c5157", "tint_a": "#33373c", "tint_b": "#666b72",
			"metal": 0.95, "rough": 0.44, "rough_var": 0.2, "grain": 0.3, "grain_scale": 44.0,
			"height_amp": 0.4, "bump": 0.7, "wear": 0.18, "repeat": [1.0, 1.0],
		},
		"cast_iron": {
			"base": "#5a5c60", "tint_a": "#3e4044", "tint_b": "#75787d",
			"metal": 0.8, "metal_var": 0.15, "rough": 0.68, "rough_var": 0.18,
			"grain": 0.55, "grain_scale": 36.0, "height_amp": 0.8, "bump": 1.0, "pits": 0.3, "wear": 0.2, "repeat": [1.0, 1.0],
		},
		"chrome": {
			"base": "#c9ced4", "tint_a": "#aab0b8", "tint_b": "#e6eaee",
			"metal": 1.0, "rough": 0.09, "rough_var": 0.06, "grain": 0.1, "grain_scale": 70.0,
			"height_amp": 0.08, "bump": 0.15, "repeat": [1.0, 1.0],
		},
		"brass": {
			"base": "#b08d3f", "tint_a": "#8a6c2c", "tint_b": "#d8b45c",
			"metal": 1.0, "rough": 0.24, "rough_var": 0.2, "grain": 0.3, "grain_scale": 40.0,
			"height_amp": 0.3, "bump": 0.5, "wear": 0.15, "pits": 0.1, "repeat": [1.0, 1.0],
		},
		"copper": {
			"base": "#a5623c", "tint_a": "#7d452b", "tint_b": "#c98a5a",
			"metal": 1.0, "rough": 0.3, "rough_var": 0.25, "grain": 0.35, "grain_scale": 46.0,
			"height_amp": 0.35, "bump": 0.6, "wear": 0.22, "repeat": [1.0, 1.0],
		},
		"aluminium": {
			"base": "#b9bec4", "tint_a": "#9aa0a6", "tint_b": "#d6dbe0",
			"metal": 1.0, "rough": 0.38, "rough_var": 0.18, "grain": 0.25, "grain_scale": 52.0,
			"height_amp": 0.22, "bump": 0.4, "repeat": [1.0, 1.0],
		},
		"painted_red": {
			"base": "#a83226", "tint_a": "#7d2118", "tint_b": "#c8473a",
			"metal": 0.05, "rough": 0.33, "rough_var": 0.22, "grain": 0.2, "grain_scale": 34.0,
			"height_amp": 0.3, "bump": 0.5, "wear": 0.3, "pits": 0.12, "repeat": [1.0, 1.0],
		},
		"painted_blue": {
			"base": "#2a4f86", "tint_a": "#1c3560", "tint_b": "#3c6aa8",
			"metal": 0.05, "rough": 0.36, "rough_var": 0.22, "grain": 0.22, "grain_scale": 34.0,
			"height_amp": 0.3, "bump": 0.5, "wear": 0.28, "repeat": [1.0, 1.0],
		},
		"painted_green": {
			"base": "#2f6b4a", "tint_a": "#1f4a33", "tint_b": "#428a5f",
			"metal": 0.05, "rough": 0.42, "rough_var": 0.2, "grain": 0.25, "grain_scale": 32.0,
			"height_amp": 0.35, "bump": 0.6, "wear": 0.25, "repeat": [1.0, 1.0],
		},
		"painted_yellow": {
			"base": "#c9a227", "tint_a": "#9a7a18", "tint_b": "#e0c04a",
			"metal": 0.08, "rough": 0.4, "rough_var": 0.2, "grain": 0.25, "grain_scale": 32.0,
			"height_amp": 0.35, "bump": 0.6, "wear": 0.3, "repeat": [1.0, 1.0],
		},
		"lead_grey": {
			"base": "#6a6d70", "tint_a": "#4e5154", "tint_b": "#8b8f93",
			"metal": 0.9, "metal_var": 0.1, "rough": 0.62, "rough_var": 0.2,
			"grain": 0.45, "grain_scale": 40.0, "height_amp": 0.5, "bump": 0.8,
			"pits": 0.18, "wear": 0.1, "repeat": [1.0, 1.0],
		},
		"armour_red": {
			"base": "#8f1f18", "tint_a": "#6b130e", "tint_b": "#c03428",
			"metal": 0.85, "rough": 0.21, "rough_var": 0.14, "grain": 0.12, "grain_scale": 48.0,
			"height_amp": 0.16, "bump": 0.3, "wear": 0.16, "pattern": "panel_lines", "pattern_scale": 2.0, "repeat": [1.0, 1.0],
		},
		"armour_gold": {
			"base": "#a8801f", "tint_a": "#7d5c14", "tint_b": "#d4ab3c",
			"metal": 1.0, "rough": 0.19, "rough_var": 0.16, "grain": 0.12, "grain_scale": 50.0,
			"height_amp": 0.18, "bump": 0.3, "wear": 0.14, "repeat": [1.0, 1.0],
		},

		# --- organics ----------------------------------------------------
		"teak": {
			"base": "#8a5f38", "tint_a": "#5f3f22", "tint_b": "#a87c4e",
			"pattern": "wood_grain", "pattern_scale": 5.0, "grain": 0.3, "grain_scale": 30.0,
			"rough": 0.62, "rough_var": 0.2, "height_amp": 0.7, "bump": 0.9, "wear": 0.1, "repeat": [1.0, 1.0],
		},
		"bamboo": {
			"base": "#c2a25c", "tint_a": "#9c7f3e", "tint_b": "#ddc07a",
			"pattern": "wood_grain", "pattern_scale": 3.0, "grain": 0.25, "grain_scale": 40.0,
			"rough": 0.48, "rough_var": 0.18, "height_amp": 0.4, "bump": 0.6, "repeat": [1.0, 1.0],
		},
		"plywood": {
			"base": "#b08a52", "tint_a": "#8c6a3a", "tint_b": "#c9a56c",
			"pattern": "weave", "pattern_scale": 22.0, "grain": 0.3, "grain_scale": 36.0,
			"rough": 0.7, "rough_var": 0.15, "height_amp": 0.35, "bump": 0.5, "repeat": [1.0, 1.0],
		},
		"rattan": {
			"base": "#c8a878", "tint_a": "#a08256", "tint_b": "#e0c49a",
			"pattern": "weave", "pattern_scale": 30.0, "grain": 0.3, "grain_scale": 30.0,
			"rough": 0.75, "rough_var": 0.12, "height_amp": 0.8, "bump": 1.1, "repeat": [1.0, 1.0],
		},
		"rubber": {
			"base": "#26282b", "tint_a": "#161819", "tint_b": "#3a3d40",
			"rough": 0.88, "rough_var": 0.1, "grain": 0.4, "grain_scale": 48.0,
			"height_amp": 0.35, "bump": 0.5, "pattern": "panel_lines", "pattern_scale": 12.0, "repeat": [1.0, 1.0],
		},
		"plastic_black": {
			"base": "#22252a", "tint_a": "#141619", "tint_b": "#363a41",
			"rough": 0.42, "rough_var": 0.2, "grain": 0.25, "grain_scale": 44.0,
			"height_amp": 0.2, "bump": 0.35, "wear": 0.12, "repeat": [1.0, 1.0],
		},
		"plastic_faded": {
			"base": "#8f8f88", "tint_a": "#6e6e68", "tint_b": "#a8a8a0",
			"rough": 0.6, "rough_var": 0.22, "grain": 0.35, "grain_scale": 38.0,
			"height_amp": 0.3, "bump": 0.5, "wear": 0.2, "streaks": 0.15, "repeat": [1.0, 1.0],
		},
		"plastic_red": {
			"base": "#b03a2c", "tint_a": "#85261c", "tint_b": "#d05a48",
			"rough": 0.35, "rough_var": 0.2, "grain": 0.2, "grain_scale": 42.0,
			"height_amp": 0.2, "bump": 0.35, "repeat": [1.0, 1.0],
		},
		"glass_smoky": {
			"base": "#4a5158", "tint_a": "#2e343a", "tint_b": "#666e76",
			"rough": 0.08, "rough_var": 0.05, "grain": 0.1, "grain_scale": 60.0,
			"height_amp": 0.05, "bump": 0.1, "streaks": 0.2, "repeat": [1.0, 1.0],
		},
		"circuit_board": {
			"base": "#0d4a33", "tint_a": "#093726", "tint_b": "#c9a227",
			"pattern": "circuit", "pattern_scale": 12.0, "grain": 0.15, "grain_scale": 50.0,
			"rough": 0.5, "rough_var": 0.2, "height_amp": 0.5, "bump": 0.7, "repeat": [1.0, 1.0],
		},
		"fabric": {
			"base": "#6b5f52", "tint_a": "#4e453b", "tint_b": "#8a7d6c",
			"pattern": "weave", "pattern_scale": 40.0, "grain": 0.4, "grain_scale": 30.0,
			"rough": 0.92, "rough_var": 0.08, "height_amp": 0.6, "bump": 0.8, "streaks": 0.1, "repeat": [1.0, 1.0],
		},
		"gamcha": {
			"base": "#8a8f7a", "tint_a": "#5f6b4a", "tint_b": "#b0b89a",
			"pattern": "weave", "pattern_scale": 34.0, "grain": 0.45, "grain_scale": 26.0,
			"rough": 0.9, "rough_var": 0.1, "height_amp": 0.7, "bump": 1.0, "repeat": [1.0, 1.0],
		},
		"newspaper": {
			"base": "#cfc9b8", "tint_a": "#b0a894", "tint_b": "#e4dfd0",
			"grain": 0.3, "grain_scale": 50.0, "mottle_scale": 1.0,
			"rough": 0.8, "rough_var": 0.1, "height_amp": 0.2, "bump": 0.3, "pattern": "panel_lines", "pattern_scale": 26.0, "repeat": [1.0, 1.0],
		},
		"paper_notebook": {
			"base": "#e6e0cc", "tint_a": "#cfc8b0", "tint_b": "#f4efdd",
			"grain": 0.2, "grain_scale": 60.0, "rough": 0.85, "rough_var": 0.06,
			"height_amp": 0.12, "bump": 0.2, "repeat": [1.0, 1.0],
		},
	}
