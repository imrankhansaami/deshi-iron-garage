class_name CableGenerator
extends RefCounted
## Procedural cable and conduit geometry (Contribution D, docs/GRAPHICS_ALGORITHMS.md).
##
## Wires are the single most expensive-looking-per-triangle thing in an indoor
## workshop scene, and hand-modelling them in Blender is slow to iterate. This
## generator builds them at runtime from four physical parameters — span, sag,
## slack and thickness — using a catenary-ish path and a tube swept along it with
## parallel-transport frames.
##
## Why parallel transport instead of look-at framing: a naive up-vector frame
## flips whenever the tangent passes near the reference axis, which produces
## visible seams and twisted UVs mid-cable. Transporting each frame from the
## previous one by the shortest rotation keeps the ribbing continuous, which is
## what makes the sleeve weave in cable_material.gdshader read as one object.
##
## Bundling: several wires can be merged into ONE ArrayMesh. That is a real
## optimisation, not cosmetics — a 5-wire loom becomes a single draw call instead
## of five, which is measured in Experiment 4.

const TAU_C: float = 6.283185307179586

var last_stats: Dictionary = {}


# ===========================================================================
# Path construction
# ===========================================================================

static func sag_path(start: Vector3, end: Vector3, sag: float, slack: float, sideways: float, samples: int) -> PackedVector3Array:
	## Catenary approximation. `sag` drops the midpoint, `slack` inflates the
	## arc length so the wire bulges past a straight line, `sideways` bows it
	## laterally so runs along a wall do not look like a ruler.
	var pts: PackedVector3Array = PackedVector3Array()
	var n: int = maxi(samples, 3)
	var dir: Vector3 = end - start
	var len: float = maxf(dir.length(), 0.0001)
	var up: Vector3 = Vector3.UP
	var lateral: Vector3 = dir.cross(up)
	if lateral.length_squared() < 0.0001:
		lateral = Vector3.RIGHT
	lateral = lateral.normalized()
	for i: int in range(n):
		var t: float = float(i) / float(n - 1)
		var p: Vector3 = start.lerp(end, t)
		# parabolic sag is a good catenary stand-in at these aspect ratios;
		# sin(pi*t) keeps the ends exactly on their anchors
		var arc: float = sin(t * PI)
		p -= up * (sag * arc)
		p += lateral * (sideways * arc)
		# slack pushes the middle away from the chord in the sag plane too
		p -= up * (slack * sin(t * PI * 2.0) * 0.5)
		pts.append(p)
	return pts


static func hang_path(anchor_a: Vector3, anchor_b: Vector3, length_ratio: float, samples: int) -> PackedVector3Array:
	## Two-anchor hang used for the loose jumper cables: solves for the sag that
	## makes the polyline approximately `length_ratio` times the chord length.
	var chord: float = maxf(anchor_a.distance_to(anchor_b), 0.0001)
	var target: float = chord * clampf(length_ratio, 1.01, 3.0)
	var lo: float = 0.0
	var hi: float = maxf(chord, 0.5)
	var path: PackedVector3Array = sag_path(anchor_a, anchor_b, 0.0, 0.0, 0.0, samples)
	for iter: int in range(9):
		var mid: float = (lo + hi) * 0.5
		path = sag_path(anchor_a, anchor_b, mid, 0.0, 0.0, samples)
		var arc: float = polyline_length(path)
		if arc < target:
			lo = mid
		else:
			hi = mid
	return path


static func polyline_length(pts: PackedVector3Array) -> float:
	var total: float = 0.0
	for i: int in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	return total


# ===========================================================================
# Framing
# ===========================================================================

static func parallel_transport_frames(path: PackedVector3Array) -> Array:
	## Returns one [tangent, normal, binormal] triple per sample point.
	var frames: Array = []
	var n: int = path.size()
	if n < 2:
		return frames
	var tangents: PackedVector3Array = PackedVector3Array()
	for i: int in range(n):
		var a: Vector3 = path[maxi(i - 1, 0)]
		var b: Vector3 = path[mini(i + 1, n - 1)]
		var t: Vector3 = (b - a)
		if t.length_squared() < 0.000001:
			t = Vector3.FORWARD
		tangents.append(t.normalized())
	# seed the first frame perpendicular to the first tangent
	var t0: Vector3 = tangents[0]
	var seed: Vector3 = Vector3.UP
	if absf(t0.dot(seed)) > 0.95:
		seed = Vector3.RIGHT
	var normal: Vector3 = (t0.cross(seed)).normalized()
	var binormal: Vector3 = t0.cross(normal).normalized()
	frames.append([t0, normal, binormal])
	for i: int in range(1, n):
		var prev_t: Vector3 = tangents[i - 1]
		var cur_t: Vector3 = tangents[i]
		var axis: Vector3 = prev_t.cross(cur_t)
		if axis.length_squared() < 0.000001:
			normal = normal.normalized()
		else:
			axis = axis.normalized()
			var dot_v: float = clampf(prev_t.dot(cur_t), -1.0, 1.0)
			var angle: float = acos(dot_v)
			normal = normal.rotated(axis, angle)
			binormal = cur_t.cross(normal).normalized()
			normal = (binormal.cross(cur_t)).normalized()
		frames.append([cur_t, normal.normalized(), binormal.normalized()])
	return frames


# ===========================================================================
# Tube sweep
# ===========================================================================

## Builds one tube into a SurfaceTool. Returns the number of vertices added.
##
## Normals are analytic (radial offset minus a small tangent bias) rather than
## generated from the triangles: generated normals on a low-segment tube flatten
## the silhouette and destroy the weave alignment the sleeve shader depends on.
static func _sweep_into(st: SurfaceTool, path: PackedVector3Array, frames: Array, radius: float, radial: int, u_scale: float, taper: float) -> int:
	var n: int = path.size()
	if n < 2 or radial < 3:
		return 0
	var added: int = 0
	for i: int in range(n):
		var p: Vector3 = path[i]
		var f: Array = frames[i]
		var tan: Vector3 = f[0]
		var nor: Vector3 = f[1]
		var bin: Vector3 = f[2]
		var t: float = float(i) / float(n - 1)
		var r: float = radius * lerpf(1.0, taper, t * t)
		for j: int in range(radial):
			var a: float = TAU_C * float(j) / float(radial)
			var offset: Vector3 = nor * cos(a) + bin * sin(a)
			st.set_normal((offset - tan * 0.06).normalized())
			st.set_uv(Vector2(t * u_scale, float(j) / float(radial)))
			st.add_vertex(p + offset * r)
			added += 1
		if i > 0:
			for j: int in range(radial):
				var j2: int = (j + 1) % radial
				var a0: int = (i - 1) * radial + j
				var a1: int = (i - 1) * radial + j2
				var b0: int = i * radial + j
				var b1: int = i * radial + j2
				# wound CCW so the tube is front-facing from outside
				st.add_index(a0)
				st.add_index(b0)
				st.add_index(b1)
				st.add_index(a0)
				st.add_index(b1)
				st.add_index(a1)
	# end caps, so a cut cable does not show a hollow tube
	added += _cap(st, path, frames, radius, radial, n, 0, added, 1.0)
	added += _cap(st, path, frames, radius, radial, n, 1, added, taper)
	return added


static func _cap(st: SurfaceTool, path: PackedVector3Array, frames: Array, radius: float, radial: int, n: int, which: int, base: int, taper: float) -> int:
	var idx: int = 0 if which == 0 else n - 1
	var p: Vector3 = path[idx]
	var f: Array = frames[idx]
	var tan: Vector3 = f[0]
	var nor: Vector3 = f[1]
	var bin: Vector3 = f[2]
	var facing: Vector3 = tan if which == 1 else -tan
	var r: float = radius * taper
	st.set_normal(facing)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(p)
	for j: int in range(radial):
		var a: float = TAU_C * float(j) / float(radial)
		var offset: Vector3 = (nor * cos(a) + bin * sin(a)) * r
		st.set_normal(facing)
		st.set_uv(Vector2(0.5 + offset.x / maxf(r, 0.0001) * 0.5, 0.5 + offset.z / maxf(r, 0.0001) * 0.5))
		st.add_vertex(p + offset)
	for j: int in range(radial):
		var j2: int = (j + 1) % radial
		if which == 0:
			st.add_index(base)
			st.add_index(base + 1 + j)
			st.add_index(base + 1 + j2)
		else:
			st.add_index(base)
			st.add_index(base + 1 + j2)
			st.add_index(base + 1 + j)
	return radial + 1


# ===========================================================================
# Public API
# ===========================================================================

## Generates a single cable mesh.
## params: {
##   start, end, sag, slack, sideways, radius, radial_segments, length_segments,
##   u_scale, taper, material
## }
func generate(params: Dictionary) -> ArrayMesh:
	var t0: int = Time.get_ticks_usec()
	var start: Vector3 = params.get("start", Vector3.ZERO)
	var end: Vector3 = params.get("end", Vector3.ONE)
	var sag: float = float(params.get("sag", 0.35))
	var slack: float = float(params.get("slack", 0.0))
	var sideways: float = float(params.get("sideways", 0.0))
	var radius: float = maxf(float(params.get("radius", 0.018)), 0.001)
	var radial: int = clampi(int(params.get("radial_segments", 8)), 3, 64)
	var length_segments: int = clampi(int(params.get("length_segments", 24)), 2, 512)
	var u_scale: float = float(params.get("u_scale", 1.0))
	var taper: float = float(params.get("taper", 0.92))

	var path: PackedVector3Array = sag_path(start, end, sag, slack, sideways, length_segments + 1)
	var frames: Array = parallel_transport_frames(path)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: int = _sweep_into(st, path, frames, radius, radial, u_scale, taper)
	var tris: int = (path.size() - 1) * radial * 2 + radial
	var mat: Material = params.get("material", null)
	if mat != null:
		st.set_material(mat)
	var mesh: ArrayMesh = st.commit()

	var us: int = Time.get_ticks_usec() - t0
	last_stats = {
		"microseconds": us,
		"milliseconds": float(us) / 1000.0,
		"vertices": verts,
		"triangles": tris,
		"wires": 1,
		"draw_calls": 1,
		"length": polyline_length(path),
		"sag": sag,
		"radial": radial,
		"length_segments": length_segments,
		"bounding": _bounds(path, radius),
	}
	return mesh


## Generates several wires as ONE mesh: the draw-call optimisation measured in
## Experiment 4. Offsets spread the wires into a loom.
func generate_bundle(params: Dictionary) -> ArrayMesh:
	var t0: int = Time.get_ticks_usec()
	var wires: Array = params.get("wires", [])
	var radius: float = maxf(float(params.get("radius", 0.016)), 0.001)
	var radial: int = clampi(int(params.get("radial_segments", 7)), 3, 64)
	var length_segments: int = clampi(int(params.get("length_segments", 22)), 2, 512)
	var spread: float = float(params.get("spread", 0.026))
	var u_scale: float = float(params.get("u_scale", 1.0))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total_len: float = 0.0
	var tri_count: int = 0
	var vert_count: int = 0
	for w: int in range(wires.size()):
		var pair: Dictionary = wires[w]
		var start: Vector3 = pair.get("start", Vector3.ZERO)
		var end: Vector3 = pair.get("end", Vector3.ONE)
		var sag: float = float(pair.get("sag", radius * 6.0))
		var sideways: float = float(pair.get("sideways", 0.0))
		# fan the wires out along the run's lateral axis
		var dir: Vector3 = end - start
		var lat: Vector3 = dir.cross(Vector3.UP)
		lat = Vector3.RIGHT if lat.length_squared() < 0.0001 else lat.normalized()
		var off: float = (float(w) - float(wires.size() - 1) * 0.5) * spread
		start += lat * off
		end += lat * off
		var path: PackedVector3Array = sag_path(start, end, sag, float(pair.get("slack", 0.0)), sideways, length_segments + 1)
		var frames: Array = parallel_transport_frames(path)
		vert_count += _sweep_into(st, path, frames, radius, radial, u_scale, float(pair.get("taper", 0.94)))
		tri_count += (path.size() - 1) * radial * 2 + radial
		total_len += polyline_length(path)
	var mat: Material = params.get("material", null)
	if mat != null:
		st.set_material(mat)
	var mesh: ArrayMesh = st.commit()
	var us: int = Time.get_ticks_usec() - t0
	last_stats = {
		"microseconds": us,
		"milliseconds": float(us) / 1000.0,
		"wires": wires.size(),
		"vertices": vert_count,
		"triangles": tri_count,
		"length": total_len,
		"draw_calls": 1,
		"radial": radial,
		"length_segments": length_segments,
	}
	return mesh


static func _bounds(path: PackedVector3Array, radius: float) -> AABB:
	var aabb := AABB()
	if path.is_empty():
		return aabb
	aabb.position = path[0] - Vector3.ONE * radius
	aabb.end = path[0] + Vector3.ONE * radius
	for i: int in range(1, path.size()):
		aabb = aabb.expand(path[i] - Vector3.ONE * radius)
		aabb = aabb.expand(path[i] + Vector3.ONE * radius)
	return aabb


## Convenience: builds the mesh and returns a ready MeshInstance3D.
func make_node(params: Dictionary, name: String = "Cable") -> MeshInstance3D:
	## Bundles go through generate_bundle(); single wires through generate(). This
	## dispatch was missing, and the three loom call sites — the switchboard loom,
	## the workstation loom and the IPS leads — pass {"wires": [...]}, which
	## generate() does not read. It fell back to its defaults, so each "loom"
	## became one cable from (0,0,0) to (1,1,1): the loose diagonal cable hanging
	## through the middle of the room in every capture, in three colours.
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = generate_bundle(params) if params.has("wires") else generate(params)
	var mat: Material = params.get("material", null)
	if mat != null:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 128.0
	return mi


## Hangs a loom between two anchors and returns the node. Used by the workbench,
## the switchboard and the reactor feed.
func make_hang(anchor_a: Vector3, anchor_b: Vector3, ratio: float, radius: float, material: Material, segments: int = 26) -> MeshInstance3D:
	var path: PackedVector3Array = hang_path(anchor_a, anchor_b, ratio, segments + 1)
	var frames: Array = parallel_transport_frames(path)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sweep_into(st, path, frames, radius, 8, 1.0, 0.94)
	if material != null:
		st.set_material(material)
	var mi := MeshInstance3D.new()
	mi.name = "HangingCable"
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
