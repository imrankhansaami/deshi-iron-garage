class_name AudioSynth
extends RefCounted
## Runtime audio synthesis: every sound in the garage is generated as PCM at
## load and wrapped in an AudioStreamWAV. No downloaded sound packs, so the
## licence ledger stays clean (docs/ASSET_LICENSES.md) and the asset set is
## self-contained like the textures.
##
## Techniques used, all standard and cheap:
##   * additive partial synthesis with inharmonic ratios  -> metal, bells, cores
##   * Karplus-Strong delay-line plucking                 -> struck steel, tools
##   * filtered noise (one-pole / biquad resonator)       -> rain, air, servo grit
##   * exponential and ADSR envelopes                     -> everything
##   * phase-coherent loop points                         -> the looping beds
##
## Loops are built so sample[0] continues smoothly from the last sample, which
## is what stops a 4-second fan bed from phasing when it wraps.

const RATE: int = 44100

# ---------------------------------------------------------------------------
# low-level helpers
# ---------------------------------------------------------------------------

static func _buf(seconds: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(maxi(1, int(seconds * RATE)))
	return out


static func _env_adsr(i: int, n: int, a: float, d: float, s: float, r: float) -> float:
	## Normalised ADSR, times and levels expressed as fractions of the buffer.
	if n <= 1:
		return 1.0
	var t: float = float(i) / float(n)
	if t < a:
		return t / maxf(a, 0.0001)
	if t < a + d:
		var k: float = (t - a) / maxf(d, 0.0001)
		return lerpf(1.0, s, k)
	if t < 1.0 - r:
		return s
	var k2: float = (t - (1.0 - r)) / maxf(r, 0.0001)
	return lerpf(s, 0.0, k2)


static func _exp_decay(i: int, n: int, rate: float) -> float:
	return exp(-rate * float(i) / float(maxi(n, 1)))


static func _soft_clip(x: float) -> float:
	return tanh(x * 1.25) / 1.25


static func _to_stream(samples: PackedFloat32Array, loop_start: int = -1, loop_end: int = -1, stereo: bool = false) -> AudioStreamWAV:
	var n: int = samples.size()
	var bytes: PackedByteArray = PackedByteArray()
	if stereo:
		bytes.resize(n * 4)
		for i: int in range(n):
			var l: float = clampf(samples[i], -1.0, 1.0)
			var idx: int = i * 4
			var v: int = int(l * 32767.0)
			bytes[idx] = v & 0xFF
			bytes[idx + 1] = (v >> 8) & 0xFF
			bytes[idx + 2] = v & 0xFF
			bytes[idx + 3] = (v >> 8) & 0xFF
	else:
		bytes.resize(n * 2)
		for i: int in range(n):
			var v: int = int(clampf(samples[i], -1.0, 1.0) * 32767.0)
			bytes[i * 2] = v & 0xFF
			bytes[i * 2 + 1] = (v >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = stereo
	wav.data = bytes
	if loop_start >= 0:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = loop_start
		wav.loop_end = mini(loop_end if loop_end > loop_start else n, n)
	wav.resource_local_to_scene = true
	return wav


static func _resonator(samples: PackedFloat32Array, freq: float, q: float) -> void:
	## State-variable band-pass, in place. Q controls the ring.
	var f: float = clampf(freq / float(RATE) * 2.0, 0.001, 0.45)
	var bandwidth: float = f / maxf(q, 0.5)
	var hp: float = 0.0
	var bp: float = 0.0
	var lp: float = 0.0
	for i: int in range(samples.size()):
		var in_v: float = samples[i]
		hp = in_v - lp - (bandwidth * bp)
		bp += hp * f
		lp += bp * f
		samples[i] = bp


static func _lowpass(samples: PackedFloat32Array, freq: float) -> void:
	var a: float = 1.0 - exp(-TAU * freq / float(RATE))
	var prev: float = samples[0] if samples.size() > 0 else 0.0
	for i: int in range(samples.size()):
		prev += a * (samples[i] - prev)
		samples[i] = prev


static func _highpass(samples: PackedFloat32Array, freq: float) -> void:
	var a: float = exp(-TAU * freq / float(RATE))
	var prev_in: float = 0.0
	var prev_out: float = 0.0
	for i: int in range(samples.size()):
		var x: float = samples[i]
		prev_out = a * (prev_out + x - prev_in)
		prev_in = x
		samples[i] = prev_out


static func _normalise(samples: PackedFloat32Array, peak: float = 0.89) -> void:
	var mx: float = 0.0001
	for i: int in range(samples.size()):
		mx = maxf(mx, absf(samples[i]))
	var g: float = peak / mx
	for i: int in range(samples.size()):
		samples[i] *= g


static func _noise(n: int, seed: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var r: RandomNumberGenerator = NoiseTools.rng(seed)
	for i: int in range(n):
		out[i] = r.randf_range(-1.0, 1.0)
	return out


## A footstep: a short filtered noise burst over a small body knock. `kind`
## selects the surface — 0 concrete, 1 packed earth, 2 steel deck, 3 plank — and
## `seed` varies each step so no two footfalls are identical. The old footstep was
## a struck-steel ping borrowed from the tool bank; this is an actual foot.
static func footstep(kind: int = 0, seed: int = 3) -> AudioStreamWAV:
	var k: int = clampi(kind, 0, 3)
	var n: int = int(0.22 * RATE) if k != 1 else int(0.28 * RATE)
	var body_hz: float = float([150.0, 92.0, 430.0, 195.0][k])
	var cut: float = float([1000.0, 400.0, 2800.0, 760.0][k])
	var decay: float = float([11.0, 7.5, 13.0, 10.0][k])
	var noise_amt: float = float([0.8, 1.0, 0.55, 0.85][k])
	var out: PackedFloat32Array = _noise(n, seed * 17 + k * 131 + 11)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var env: float = exp(-decay * t)
		out[i] = out[i] * noise_amt * env + sin(TAU * body_hz * t) * 0.5 * env
	_lowpass(out, cut)
	_highpass(out, 55.0)
	_normalise(out, 0.7)
	return _to_stream(out)


## The courtyard's nature bed — the project's music, and deliberately without a
## single musical instrument: wind through the palms (low-passed noise under two
## slow swells), leaves (sparse high rustles) and sparrows (chirp motifs, one
## two-note phrase, a trill). Loop-seamless via a tail crossfade.
static func nature_bed(size: float = 7.0, seed: int = 4242) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var m: int = int(0.7 * RATE)
	var total: int = n + m
	var r: RandomNumberGenerator = NoiseTools.rng(seed)
	var out: PackedFloat32Array = _noise(total, seed)
	_lowpass(out, 420.0)
	_lowpass(out, 420.0)
	for i: int in range(total):
		var t: float = float(i) / float(RATE)
		var lfo: float = 0.58 + 0.26 * sin(TAU * 0.071 * t) + 0.16 * sin(TAU * 0.113 * t + 1.7)
		out[i] = out[i] * lfo
	_normalise(out, 0.7)
	# leaves: sparse high rustles, quiet
	var i0: int = int(0.1 * RATE)
	while i0 < total:
		i0 += int(r.randf_range(0.22, 0.85) * RATE)
		var ln: int = int(r.randf_range(0.04, 0.1) * RATE)
		var amp: float = r.randf_range(0.04, 0.13)
		for j: int in range(mini(ln, total - i0)):
			out[i0 + j] += r.randf_range(-1.0, 1.0) * amp * exp(-6.0 * float(j) / float(ln))
	# birds: three motifs, spaced half a second to two apart
	var b: int = int(0.35 * RATE)
	while b < total - int(0.9 * RATE):
		b += int(r.randf_range(0.45, 2.2) * RATE)
		var style: float = r.randf()
		if style < 0.55:
			var at: int = b
			for c: int in range(r.randi_range(2, 4)):
				var mlen: int = int(r.randf_range(0.04, 0.08) * RATE)
				var f0: float = r.randf_range(2400.0, 3300.0)
				var f1: float = f0 * r.randf_range(1.15, 1.4)
				for j: int in range(mlen):
					if at + j >= total:
						break
					out[at + j] += sin(TAU * lerpf(f0, f1, float(j) / float(mlen)) * float(j) / float(RATE)) * sin(PI * float(j) / float(mlen)) * 0.14
				at += mlen + int(r.randf_range(0.04, 0.09) * RATE)
		elif style < 0.8:
			for pair: int in range(2):
				var at2: int = b + pair * int(0.24 * RATE)
				var mlen2: int = int((0.14 if pair == 0 else 0.17) * RATE)
				var ff: float = 1500.0 if pair == 0 else 1320.0
				for j: int in range(mlen2):
					if at2 + j >= total:
						break
					out[at2 + j] += sin(TAU * lerpf(ff, ff * 0.78, float(j) / float(mlen2)) * float(j) / float(RATE)) * sin(PI * float(j) / float(mlen2)) * 0.12
		else:
			var mlen3: int = int(0.1 * RATE)
			for j: int in range(mlen3):
				if b + j >= total:
					break
				var wob: float = sin(TAU * 26.0 * float(j) / float(RATE))
				out[b + j] += sin(TAU * 3600.0 * float(j) / float(RATE) + wob) * sin(PI * float(j) / float(mlen3)) * 0.09
	# fold the extra tail over the head: the wrap is continuous, not crossfaded
	var loop: PackedFloat32Array = PackedFloat32Array()
	loop.resize(n)
	for i: int in range(n):
		if i < m:
			var k2: float = float(i) / float(m)
			loop[i] = out[i] * k2 + out[n + i] * (1.0 - k2)
		else:
			loop[i] = out[i]
	_lowpass(loop, 7200.0)
	_normalise(loop, 0.62)
	return _to_stream(loop, 0, n)


## A single birdcall for 3D placement near the doorway. kind 0 is a sparrow
## flurry, kind 1 the two-note phrase.
static func bird_call(kind: int = 0, seed: int = 9) -> AudioStreamWAV:
	var n: int = int(0.7 * RATE)
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n)
	var r: RandomNumberGenerator = NoiseTools.rng(seed)
	if kind == 0:
		var at: int = int(0.05 * RATE)
		for c: int in range(3):
			var mlen: int = int(r.randf_range(0.05, 0.08) * RATE)
			var f0: float = r.randf_range(2500.0, 3400.0)
			for j: int in range(mlen):
				if at + j >= n:
					break
				out[at + j] += sin(TAU * lerpf(f0, f0 * 1.3, float(j) / float(mlen)) * float(j) / float(RATE)) * sin(PI * float(j) / float(mlen)) * 0.5
			at += mlen + int(r.randf_range(0.05, 0.1) * RATE)
	else:
		for pair: int in range(2):
			var at2: int = int((0.05 + pair * 0.26) * RATE)
			var mlen2: int = int(0.16 * RATE)
			var ff: float = 1450.0 if pair == 0 else 1280.0
			for j: int in range(mlen2):
				if at2 + j >= n:
					break
				out[at2 + j] += sin(TAU * lerpf(ff, ff * 0.76, float(j) / float(mlen2)) * float(j) / float(RATE)) * sin(PI * float(j) / float(mlen2)) * 0.45
	_normalise(out, 0.5)
	return _to_stream(out)


# ---------------------------------------------------------------------------
# Sound recipes. Each returns an AudioStreamWAV.
# ---------------------------------------------------------------------------

## Struck steel: Karplus-Strong pluck plus inharmonic partials and a noise transient.
static func metal_impact(size: float = 0.9, pitch: float = 220.0, bright: float = 1.0, seed: int = 7) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	# --- Karplus-Strong delay line
	var delay: int = maxi(2, int(float(RATE) / pitch))
	var line: PackedFloat32Array = _noise(delay + 2, seed)
	var damp: float = clampf(0.5 + 0.42 * bright, 0.3, 0.94)
	var last: float = 0.0
	for i: int in range(n):
		var read_v: float = line[i % delay]
		var next_v: float = (read_v + line[(i + 1) % delay]) * 0.5 * damp + last * (1.0 - damp) * 0.5
		last = read_v
		line[i % delay] = next_v
		out[i] = next_v
	_resonator(out, pitch * 3.4, 3.0)
	# --- inharmonic partials give the clang its metallic colouring
	var ratios: Array[float] = [1.0, 1.43, 2.11, 2.79, 3.66, 5.02]
	var decays: Array[float] = [9.0, 12.0, 17.0, 24.0, 33.0, 46.0]
	for p: int in range(ratios.size()):
		var f: float = pitch * ratios[p]
		var amp: float = 0.42 / float(p + 1)
		var d: float = decays[p]
		for i: int in range(n):
			var t: float = float(i) / float(RATE)
			out[i] += sin(TAU * f * t) * amp * exp(-d * t) * (1.0 - exp(-t * 900.0))
	# --- impact transient
	var tr: int = mini(n - 1, int(0.012 * RATE))
	var nz: PackedFloat32Array = _noise(tr, seed + 99)
	for i: int in range(tr):
		out[i] += nz[i] * (1.0 - float(i) / float(tr)) * 0.55
	_normalise(out)
	return _to_stream(out)


## Short click for tools being set down / latches.
static func tool_click(seed: int = 3) -> AudioStreamWAV:
	var size: float = 0.14
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, seed)
	_lowpass(nz, 3200.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		out[i] = nz[i] * exp(-t * 55.0) * 0.7 + sin(TAU * 1400.0 * t) * exp(-t * 120.0) * 0.35
	_normalise(out, 0.8)
	return _to_stream(out)


## Servo / robotic arm: pitch-swept whine, gear grit, loopable.
static func servo_sweep(from_hz: float = 140.0, to_hz: float = 420.0, size: float = 1.2, seed: int = 11) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var phase: float = 0.0
	var gear: float = 0.0
	var nz: PackedFloat32Array = _noise(n, seed)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var k: float = t / size
		var f: float = lerpf(from_hz, to_hz, k) + sin(TAU * 6.0 * t) * 4.0
		phase += f / float(RATE)
		var s: float = sin(TAU * phase) * 0.55 + sin(TAU * phase * 2.01) * 0.22 + sin(TAU * phase * 3.98) * 0.12
		gear = nz[i] * 0.16 * (0.5 + 0.5 * sin(TAU * f * 6.0 * t))
		out[i] = (s + gear) * _env_adsr(i, n, 0.06, 0.15, 0.8, 0.2)
	_normalise(out, 0.8)
	return _to_stream(out)


## Mains hum / electrical bed: 50 Hz fundamental with odd harmonics (Bangladesh
## runs on 50 Hz, 230 V), plus a faint 100 Hz magnetostriction buzz. Loopable.
static func electric_hum(size: float = 4.0) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var partials: Array = [[50.0, 0.5], [100.0, 0.34], [150.0, 0.12], [250.0, 0.05], [300.0, 0.03]]
	for p: Array in partials:
		var f: float = p[0]
		var amp: float = p[1]
		for i: int in range(n):
			var t: float = float(i) / float(RATE)
			out[i] += sin(TAU * f * t + f * 0.013) * amp
	var nz: PackedFloat32Array = _noise(n, 4242)
	_lowpass(nz, 900.0)
	for i: int in range(n):
		out[i] += nz[i] * 0.028
	_normalise(out, 0.42)
	# integer-period partials at 50 Hz keep the wrap seamless
	return _to_stream(out, 0, n)


## Ceiling/pedestal fan bed: low rumble plus blade whoosh, loopable.
static func fan_whir(size: float = 3.0, blade_hz: float = 34.0) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, 808)
	_lowpass(nz, 1600.0)
	var hp: PackedFloat32Array = nz.duplicate()
	_highpass(hp, 220.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var motor: float = sin(TAU * 24.0 * t) * 0.3 + sin(TAU * 48.0 * t) * 0.12
		var blades: float = sin(TAU * blade_hz * t) * 0.22 * (0.6 + 0.4 * sin(TAU * blade_hz * 0.5 * t))
		out[i] = motor + blades + nz[i] * 0.3 + hp[i] * 0.12
	_normalise(out, 0.5)
	return _to_stream(out, 0, n)


## Rain on a corrugated tin roof: dense filtered impulses over a noise floor.
## Loopable, and the reason the garage sounds like Bangladesh.
static func rain_tin(size: float = 6.0, intensity: float = 1.0, seed: int = 555) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, seed)
	_lowpass(nz, 900.0)
	for i: int in range(n):
		out[i] = nz[i] * 0.35
	var r: RandomNumberGenerator = NoiseTools.rng(seed + 1)
	var drops: int = int(size * 240.0 * intensity)
	for d: int in range(drops):
		var start: int = r.randi_range(0, n - 400)
		var dur: int = r.randi_range(40, 190)
		var f: float = r.randf_range(1400.0, 5200.0)
		var amp: float = r.randf_range(0.12, 0.6) * intensity
		var ring: float = r.randf_range(35.0, 130.0)
		for k: int in range(dur):
			var idx: int = start + k
			if idx >= n:
				break
			var tt: float = float(k) / float(RATE)
			out[idx] += sin(TAU * f * tt) * exp(-tt * ring) * amp
			out[idx] += nz[idx] * exp(-tt * ring * 2.0) * amp * 0.5
	_normalise(out, 0.62)
	return _to_stream(out, 0, n)


## Rolling shutter: motor drone with a rattling chain drive. Loopable.
static func shutter_motor(size: float = 2.0) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, 6161)
	_resonator(nz, 320.0, 1.4)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var drone: float = sin(TAU * 62.0 * t) * 0.4 + sin(TAU * 124.0 * t) * 0.16
		var rattle: float = sin(TAU * 17.0 * t) * 0.5 + 0.5
		out[i] = drone + nz[i] * 0.42 * rattle
	_normalise(out, 0.55)
	return _to_stream(out, 0, n)


## CRT/LED workstation power-up: rising sweep, two confirmation blips, relay clunk.
static func computer_boot(size: float = 2.6) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var phase: float = 0.0
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var k: float = t / size
		var f: float = lerpf(90.0, 900.0, k * k)
		phase += f / float(RATE)
		var env: float = clampf(k * 6.0, 0.0, 1.0) * (1.0 - clampf((k - 0.72) / 0.28, 0.0, 1.0))
		out[i] = (sin(TAU * phase) * 0.5 + sin(TAU * phase * 1.5) * 0.2) * env
		# relay clunks
		for c: int in range(3):
			var ct: float = 0.35 + float(c) * 0.18
			var dt: float = t - ct
			if dt > 0.0 and dt < 0.09:
				out[i] += sin(TAU * (260.0 - c * 40.0) * dt) * exp(-dt * 60.0) * 0.3
		# confirmation blips
		for b: int in range(2):
			var bt: float = 1.55 + float(b) * 0.22
			var dbt: float = t - bt
			if dbt > 0.0 and dbt < 0.16:
				var bf: float = 880.0 if b == 0 else 1320.0
				out[i] += sin(TAU * bf * dbt) * exp(-dbt * 18.0) * 0.32 * (1.0 - exp(-dbt * 400.0))
	var nz: PackedFloat32Array = _noise(n, 77)
	_lowpass(nz, 4000.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		if t > 1.4:
			out[i] += nz[i] * 0.05 * (1.0 - clampf((t - 1.4) / 1.2, 0.0, 1.0))
	_normalise(out, 0.8)
	return _to_stream(out)


## Energy core charging / activation: rising inharmonic shimmer + sub swell.
static func core_charge(size: float = 3.2, seed: int = 909) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, seed)
	_resonator(nz, 800.0, 6.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var k: float = t / size
		var base: float = lerpf(60.0, 210.0, k)
		var shimmer: float = 0.0
		for p: int in range(5):
			var f: float = base * (1.0 + float(p) * 0.618)
			shimmer += sin(TAU * f * t + float(p)) / float(p + 2)
		var env: float = clampf(k * 3.0, 0.0, 1.0) * lerpf(0.35, 1.0, k * k)
		out[i] = shimmer * env * 0.8 + sin(TAU * base * 0.5 * t) * env * 0.5 + nz[i] * k * 0.3
	_normalise(out, 0.85)
	return _to_stream(out)


## Sustained core idle hum, loopable.
static func core_idle(size: float = 2.5) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		out[i] = sin(TAU * 110.0 * t) * 0.3 + sin(TAU * 220.0 * t + 1.1) * 0.14 + sin(TAU * 331.0 * t) * 0.06
		out[i] += sin(TAU * 0.8 * t) * sin(TAU * 440.0 * t) * 0.05
	_normalise(out, 0.45)
	return _to_stream(out, 0, n)


## UI blips.
static func ui_blip(kind: String = "hover") -> AudioStreamWAV:
	var size: float = 0.11
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var f: float = {"hover": 1250.0, "confirm": 880.0, "back": 560.0, "error": 320.0, "pick": 1600.0}.get(kind, 1000.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var env: float = exp(-t * (28.0 if kind != "error" else 14.0)) * (1.0 - exp(-t * 500.0))
		var s: float = sin(TAU * f * t)
		if kind == "error":
			s = sin(TAU * f * t) + sin(TAU * f * 1.06 * t) * 0.8
		elif kind == "confirm":
			s = sin(TAU * f * t) + sin(TAU * f * 2.0 * t) * 0.4
		out[i] = s * env * 0.6
	_normalise(out, 0.7)
	return _to_stream(out)


## Page turn / paper.
static func paper_turn(seed: int = 21) -> AudioStreamWAV:
	var size: float = 0.34
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, seed)
	_highpass(nz, 1200.0)
	_lowpass(nz, 7000.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var swish: float = sin(TAU * 3.0 * t) * 0.5 + 0.5
		out[i] = nz[i] * exp(-t * 6.0) * swish * 0.8
	_normalise(out, 0.6)
	return _to_stream(out)


## Distant Dhaka street bed: traffic murmur, muffled horns, loopable.
static func street_bed(size: float = 8.0, seed: int = 1337) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, seed)
	_lowpass(nz, 620.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		var swell: float = 0.55 + 0.45 * sin(TAU * 0.11 * t + 0.7)
		out[i] = nz[i] * 0.55 * swell
	var r: RandomNumberGenerator = NoiseTools.rng(seed + 5)
	for h: int in range(4):
		var start: int = r.randi_range(0, n - int(1.4 * RATE))
		var f: float = r.randf_range(420.0, 700.0)
		var dur: int = int(r.randf_range(0.5, 1.2) * RATE)
		for k: int in range(dur):
			var idx: int = start + k
			if idx >= n:
				break
			var tt: float = float(k) / float(RATE)
			var env: float = clampf(tt * 8.0, 0.0, 1.0) * exp(-tt * 1.6)
			out[idx] += (sin(TAU * f * tt) * 0.5 + sin(TAU * f * 1.49 * tt) * 0.3) * env * 0.09
	_normalise(out, 0.4)
	return _to_stream(out, 0, n)


## Welding arc crackle (decorative, for the welding bench).
static func weld_crackle(size: float = 1.6, seed: int = 404) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	var nz: PackedFloat32Array = _noise(n, seed)
	_resonator(nz, 2400.0, 1.1)
	var r: RandomNumberGenerator = NoiseTools.rng(seed + 3)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		out[i] = nz[i] * 0.3 * (0.4 + 0.6 * sin(TAU * 9.0 * t))
	for s: int in range(int(size * 26.0)):
		var start: int = r.randi_range(0, n - 900)
		var amp: float = r.randf_range(0.3, 0.9)
		for k: int in range(r.randi_range(120, 700)):
			var idx: int = start + k
			if idx >= n:
				break
			var tt: float = float(k) / float(RATE)
			out[idx] += nz[idx] * amp * exp(-tt * 40.0)
	_normalise(out, 0.7)
	return _to_stream(out)


## Assembly success chord.
static func assembly_complete(size: float = 3.4) -> AudioStreamWAV:
	var n: int = int(size * RATE)
	var out: PackedFloat32Array = _buf(size)
	# a major-add9 stack, struck like a bell and allowed to ring
	var notes: Array[float] = [174.6, 261.6, 329.6, 392.0, 523.3, 784.0]
	for ni: int in range(notes.size()):
		var f: float = notes[ni]
		var onset: float = float(ni) * 0.055
		for i: int in range(n):
			var t: float = float(i) / float(RATE) - onset
			if t < 0.0:
				continue
			var partials: float = 0.0
			for p: int in range(1, 7):
				partials += sin(TAU * f * p * t * (1.0 + 0.0004 * float(p))) / float(p * p + 1)
			out[i] += partials * exp(-t * (2.2 + float(ni) * 0.5)) * (1.0 - exp(-t * 300.0)) * 0.35
	var nz: PackedFloat32Array = _noise(n, 12)
	_lowpass(nz, 2600.0)
	for i: int in range(n):
		var t: float = float(i) / float(RATE)
		out[i] += nz[i] * exp(-t * 3.4) * 0.1
	_normalise(out, 0.85)
	return _to_stream(out)
