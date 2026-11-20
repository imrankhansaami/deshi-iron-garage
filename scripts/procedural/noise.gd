class_name NoiseTools
## Deterministic noise and hashing helpers used by the procedural texture and
## geometry layers.
##
## Why a hand-written noise module when Godot ships FastNoiseLite? FastNoiseLite
## (C++) is used for the large full-field base layers because it can fill a whole
## image in one call. These GDScript helpers cover the cases FastNoiseLite cannot
## express cheaply: integer hashing for scatter decisions, Worley cells for pitting
## and cracks, and per-object procedural variation that must be reproducible from a
## single seed for the benchmark harness (docs/EXPERIMENTS.md, "reproducibility").

const GOLDEN_X: int = 0x2545F491
const SPRITE_A: int = 0x9E3779B9


static func hash2i(x: int, y: int, seed: int) -> float:
	## Integer hash -> [0,1). Used for scatter/instancing decisions.
	var h: int = (x * GOLDEN_X) ^ (y * 0x27d4eb2d) ^ (seed * SPRITE_A)
	h = ((h >> 13) ^ h) * 0xc2b2ae35
	h = ((h >> 16) ^ h)
	return float(h & 0xFFFF) / 65535.0


static func hash1i(x: int, seed: int) -> float:
	return hash2i(x, 0x1234, seed)


static func _fade(t: float) -> float:
	## Quintic smootherstep, the classic Perlin improvement curve.
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


static func value_noise(x: float, y: float, seed: int) -> float:
	## Bicubic-smoothed 2D value noise in [0,1].
	var xi: int = int(floor(x))
	var yi: int = int(floor(y))
	var xf: float = x - float(xi)
	var yf: float = y - float(yi)
	var u: float = _fade(xf)
	var v: float = _fade(yf)
	var a: float = hash2i(xi, yi, seed)
	var b: float = hash2i(xi + 1, yi, seed)
	var c: float = hash2i(xi, yi + 1, seed)
	var d: float = hash2i(xi + 1, yi + 1, seed)
	return lerp(lerp(a, b, u), lerp(c, d, u), v)


static func fbm(x: float, y: float, octaves: int, frequency: float, lacunarity: float, gain: float, seed: int) -> float:
	## Fractal Brownian motion, normalised to [0,1].
	var amp: float = 1.0
	var sum: float = 0.0
	var norm: float = 0.0
	var fx: float = x * frequency
	var fy: float = y * frequency
	for i: int in range(octaves):
		sum += value_noise(fx, fy, seed + i * 77) * amp
		norm += amp
		amp *= gain
		fx *= lacunarity
		fy *= lacunarity
	return sum / maxf(norm, 0.0001)


static func ridged(x: float, y: float, octaves: int, frequency: float, seed: int) -> float:
	## Inverted-domain FBM: produces sharp creases, used for cracks and rust fronts.
	var amp: float = 1.0
	var sum: float = 0.0
	var norm: float = 0.0
	var fx: float = x * frequency
	var fy: float = y * frequency
	for i: int in range(octaves):
		var n: float = value_noise(fx, fy, seed + i * 131)
		n = 1.0 - absf(n * 2.0 - 1.0)
		sum += n * n * amp
		norm += amp
		amp *= 0.5
		fx *= 2.07
		fy *= 2.07
	return sum / maxf(norm, 0.0001)


static func worley(x: float, y: float, cells: float, seed: int) -> float:
	## Cellular distance (F1) in [0,1]. Cheap approximation: nearest of 27 candidate
	## feature points reduced to the 3x3 neighbourhood, which is exact for F1.
	var sx: float = x * cells
	var sy: float = y * cells
	var cx: int = int(floor(sx))
	var cy: int = int(floor(sy))
	var best: float = 1e9
	for j: int in range(-1, 2):
		for i: int in range(-1, 2):
			var px: float = float(cx + i) + hash2i(cx + i, cy + j, seed)
			var py: float = float(cy + j) + hash2i(cx + i, cy + j, seed + 911)
			var d: float = sqrt((px - sx) * (px - sx) + (py - sy) * (py - sy))
			best = minf(best, d)
	return clampf(best, 0.0, 1.0)


static func domain_warp(x: float, y: float, amount: float, seed: int) -> Vector2:
	## Warps sample coordinates by a low-frequency field; the reason organic grain,
	## drips and corrosion fronts stop looking like straight noise bands.
	var wx: float = value_noise(x * 0.6 + 3.1, y * 0.6 - 1.7, seed + 313) * 2.0 - 1.0
	var wy: float = value_noise(x * 0.6 - 4.2, y * 0.6 + 2.3, seed + 787) * 2.0 - 1.0
	return Vector2(x + wx * amount, y + wy * amount)


static func rng(seed: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = seed
	return r


static func srgb_to_linear(c: float) -> float:
	return c * c * c * (c * (c * 1.230409 - 3.237654) + 2.506395) if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


static func linear_to_srgb(c: float) -> float:
	c = clampf(c, 0.0, 1.0)
	return 12.92 * c if c <= 0.0031308 else 1.055 * pow(c, 1.0 / 2.4) - 0.055
