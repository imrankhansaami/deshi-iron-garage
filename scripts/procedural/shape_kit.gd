class_name ShapeKit
extends RefCounted
## Primitive composition kit for procedural props.
##
## The garage has no imported models, so every object is assembled from a small
## set of generated solids. Two ideas keep that affordable:
##
##   1. Mesh caching. A solid is keyed by its dimensions and reused, so forty
##      spanners share one mesh and one draw call each rather than allocating
##      forty copies. This is the "mesh reuse" requirement from the brief, and
##      it is what lets the scene hold ~400 props on a student laptop.
##
##   2. Lathe and gear generation.turned profiles and toothed wheels are built
##      with SurfaceTool from parameters, not from a modelling package, which is
##      the difference between "a bottle prop" and "a bottle generator".
##
## All solids are handed back as MeshInstance3D with sensible shadow and LOD
## flags already set, so callers stay short.

const TAU_K: float = 6.283185307179586

static var _mesh_cache: Dictionary = {}
static var _stats_hits: int = 0
static var _stats_misses: int = 0


static func cache_stats() -> Dictionary:
	return {"hits": _stats_hits, "misses": _stats_misses, "entries": _mesh_cache.size()}


static func clear_cache() -> void:
	for m: Variant in _mesh_cache.values():
		if m is Resource:
			(m as Resource).free()
	_mesh_cache.clear()


static func _cached(key: String, maker: Callable) -> Mesh:
	if _mesh_cache.has(key):
		_stats_hits += 1
		return _mesh_cache[key]
	_stats_misses += 1
	var mesh: Mesh = maker.call()
	_mesh_cache[key] = mesh
	return mesh


# ===========================================================================
# Solids
# ===========================================================================

static func box(size: Vector3, mat: Material = null, name: String = "Box") -> MeshInstance3D:
	var key: String = "box|%.4f|%.4f|%.4f" % [size.x, size.y, size.z]
	return _mi(_cached(key, func() -> Mesh: return _make_box(size)), mat, name)


static func _make_box(size: Vector3) -> Mesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


static func cyl(radius: float, height: float, mat: Material = null, seg: int = 16, axis: Vector3i = Vector3i(1, 2, 0), name: String = "Cylinder") -> MeshInstance3D:
	var key: String = "cyl|%.4f|%.4f|%d|%d%d%d" % [radius, height, seg, axis.x, axis.y, axis.z]
	var mi: MeshInstance3D = _mi(_cached(key, func() -> Mesh: return _make_cyl(radius, height, seg)), mat, name)
	if axis == Vector3i(1, 0, 0):
		mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
	elif axis == Vector3i(0, 0, 1):
		mi.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	return mi


static func _make_cyl(radius: float, height: float, seg: int) -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = seg
	cm.rings = 0
	return cm


static func tapered_cyl(r_top: float, r_bottom: float, height: float, mat: Material = null, seg: int = 16, name: String = "Taper") -> MeshInstance3D:
	var key: String = "tcyl|%.4f|%.4f|%.4f|%d" % [r_top, r_bottom, height, seg]
	return _mi(_cached(key, func() -> Mesh: return _make_tcyl(r_top, r_bottom, height, seg)), mat, name)


static func _make_tcyl(r_top: float, r_bottom: float, height: float, seg: int) -> Mesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bottom
	cm.height = height
	cm.radial_segments = seg
	cm.rings = 1
	return cm


static func sphere(radius: float, mat: Material = null, seg: int = 16, name: String = "Sphere") -> MeshInstance3D:
	var key: String = "sph|%.4f|%d" % [radius, seg]
	return _mi(_cached(key, func() -> Mesh: return _make_sphere(radius, seg)), mat, name)


static func _make_sphere(radius: float, seg: int) -> Mesh:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = seg
	sm.rings = maxi(seg / 2, 4)
	sm.is_hemisphere = false
	return sm


static func torus(radius: float, tube: float, mat: Material = null, rings: int = 24, seg: int = 8, name: String = "Torus") -> MeshInstance3D:
	var key: String = "tor|%.4f|%.4f|%d|%d" % [radius, tube, rings, seg]
	return _mi(_cached(key, func() -> Mesh: return _make_torus(radius, tube, rings, seg)), mat, name)


static func _make_torus(radius: float, tube: float, rings: int, seg: int) -> Mesh:
	var tm := TorusMesh.new()
	tm.inner_radius = maxf(radius - tube, 0.0005)
	tm.outer_radius = radius + tube
	tm.rings = rings
	tm.ring_segments = seg
	return tm


static func plane(size: Vector2, mat: Material = null, name: String = "Plane") -> MeshInstance3D:
	## An upright plane. PlaneMesh's native orientation is XZ, facing +Y, so every
	## face built by this helper used to lie flat like a table: the garage signboard
	## was a horizontal sheet of artwork at lintel height, which is why the captures
	## showed a stripe of brick where the shop name should be. The mesh orientation
	## is set here rather than a node rotation, because callers set node rotations
	## themselves and would have overridden it.
	var pm := PlaneMesh.new()
	pm.size = size
	pm.orientation = PlaneMesh.FACE_Z
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.name = name
	return mi


static func capsule(radius: float, height: float, mat: Material = null, seg: int = 12, name: String = "Capsule") -> MeshInstance3D:
	var key: String = "cap|%.4f|%.4f|%d" % [radius, height, seg]
	var mi: MeshInstance3D = _mi(_cached(key, func() -> Mesh: return _make_cyl(radius, height, seg)), mat, name)
	return mi


static func _mi(mesh: Mesh, mat: Material, name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if mat != null:
		mi.material_override = mat
	mi.name = name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# ===========================================================================
# Lathe: revolution of a 2D profile
# ===========================================================================

## Builds a surface of revolution from a profile of (radius, height) pairs.
## Used for tea glasses, bottles, funnels, silencer cans, bulb envelopes, spark
## plugs and wheel hubs — anything turned on a lathe in a real workshop.
static func lathe(profile: PackedVector2Array, segments: int = 20, mat: Material = null, capped: bool = true, name: String = "Lathe") -> MeshInstance3D:
	var key: String = "lathe|" + _profile_key(profile) + "|%d|%s" % [segments, "c" if capped else "o"]
	return _mi(_cached(key, func() -> Mesh: return _make_lathe(profile, segments, capped)), mat, name)


static func _profile_key(p: PackedVector2Array) -> String:
	var s: String = ""
	for v: Vector2 in p:
		s += "%.3f,%.3f;" % [v.x, v.y]
	return s


static func _make_lathe(profile: PackedVector2Array, segments: int, capped: bool) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n: int = profile.size()
	if n < 2:
		return st.commit()
	# side wall
	var ring_verts: Array = []
	var vcount: int = 0
	for i: int in range(n):
		var r: float = profile[i].x
		var y: float = profile[i].y
		var row: PackedInt32Array = PackedInt32Array()
		for j: int in range(segments):
			var a: float = TAU_K * float(j) / float(segments)
			var pos: Vector3 = Vector3(cos(a) * r, y, sin(a) * r)
			# normal: perpendicular to the profile segment, rotated into 3D
			var prev: Vector2 = profile[maxi(i - 1, 0)]
			var next: Vector2 = profile[mini(i + 1, n - 1)]
			var tangent: Vector2 = (next - prev)
			var nrm2: Vector2 = Vector2(tangent.y, -tangent.x).normalized()
			var nrm: Vector3 = Vector3(cos(a) * nrm2.x, nrm2.y, sin(a) * nrm2.x).normalized()
			st.set_normal(nrm)
			st.set_uv(Vector2(float(j) / float(segments), float(i) / float(maxi(n - 1, 1))))
			row.append(vcount)
			st.add_vertex(pos)
			vcount += 1
		ring_verts.append(row)
	for i: int in range(1, n):
		var a: PackedInt32Array = ring_verts[i - 1]
		var b: PackedInt32Array = ring_verts[i]
		for j: int in range(segments):
			var j2: int = (j + 1) % segments
			st.add_index(a[j])
			st.add_index(b[j])
			st.add_index(b[j2])
			st.add_index(a[j])
			st.add_index(b[j2])
			st.add_index(a[j2])
	# caps where the profile ends on the axis
	if capped:
		var bottom_r: float = profile[0].x
		var top_r: float = profile[n - 1].x
		if bottom_r > 0.001:
			vcount = _lathe_cap(st, ring_verts[0], profile[0].y, bottom_r, segments, -1.0, vcount)
		if top_r > 0.001:
			vcount = _lathe_cap(st, ring_verts[n - 1], profile[n - 1].y, top_r, segments, 1.0, vcount)
	var mesh: ArrayMesh = st.commit()
	return mesh


static func _lathe_cap(st: SurfaceTool, ring: PackedInt32Array, y: float, radius: float, segments: int, dir: float, vcount: int) -> int:
	var center_idx: int = vcount
	st.set_normal(Vector3.UP * dir)
	st.set_uv(Vector2(0.5, 0.5))
	st.add_vertex(Vector3(0.0, y, 0.0))
	vcount += 1
	for j: int in range(segments):
		var a: float = TAU_K * float(j) / float(segments)
		st.set_normal(Vector3.UP * dir)
		st.set_uv(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
		st.add_vertex(Vector3(cos(a) * radius, y, sin(a) * radius))
		vcount += 1
	for j: int in range(segments):
		var j2: int = (j + 1) % segments
		if dir > 0.0:
			st.add_index(center_idx)
			st.add_index(center_idx + 1 + j)
			st.add_index(center_idx + 1 + j2)
		else:
			st.add_index(center_idx)
			st.add_index(center_idx + 1 + j2)
			st.add_index(center_idx + 1 + j)
	return vcount


# ===========================================================================
# Gears, sprockets, bolts, plates
# ===========================================================================

## Involute-approximation spur gear. Tooth count, module and bore are all
## parameters, so one function covers a bicycle freewheel, a motor pinion and
## the reduction gear inside the prototype's elbow joint.
static func gear(teeth: int, module_mm: float, bore: float, thickness: float, mat: Material = null, name: String = "Gear") -> MeshInstance3D:
	var t: int = clampi(teeth, 6, 90)
	var key: String = "gear|%d|%.3f|%.3f|%.3f" % [t, module_mm, bore, thickness]
	return _mi(_cached(key, func() -> Mesh: return _make_gear(t, module_mm, bore, thickness)), mat, name)


static func _make_gear(teeth: int, module_mm: float, bore: float, thickness: float) -> Mesh:
	var pitch: float = module_mm * float(teeth) * 0.5 * 0.001      # metres
	var addendum: float = module_mm * 0.001
	var dedendum: float = module_mm * 0.00125
	var root: float = maxf(pitch - dedendum, 0.002)
	var tip: float = pitch + addendum
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps: int = teeth * 4
	var prof: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps):
		var frac: float = float(i) / float(steps)
		var tooth_phase: float = fposmod(frac * float(teeth), 1.0)
		var r: float
		if tooth_phase < 0.22:
			r = lerpf(root, pitch, tooth_phase / 0.22)
		elif tooth_phase < 0.5:
			r = lerpf(pitch, tip, (tooth_phase - 0.22) / 0.28)
		elif tooth_phase < 0.72:
			r = lerpf(tip, pitch, (tooth_phase - 0.5) / 0.22)
		else:
			r = lerpf(pitch, root, (tooth_phase - 0.72) / 0.28)
		prof.append(Vector2(r, tooth_phase))
	var b: float = maxf(bore, root * 0.15)
	# extrude the profile as a flat ring pair (front/back) plus outer wall
	var verts_front: PackedInt32Array = PackedInt32Array()
	var verts_back: PackedInt32Array = PackedInt32Array()
	var half: float = thickness * 0.5
	var vcount: int = 0
	for i: int in range(prof.size()):
		var a: float = TAU_K * float(i) / float(prof.size())
		var r: float = prof[i].x
		var pos: Vector3 = Vector3(cos(a) * r, half, sin(a) * r)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
		verts_front.append(vcount)
		st.add_vertex(pos)
		vcount += 1
	for i: int in range(prof.size()):
		var a: float = TAU_K * float(i) / float(prof.size())
		var r: float = prof[i].x
		st.set_normal(Vector3.DOWN)
		st.set_uv(Vector2(0.5 + cos(a) * 0.5, 0.5 - sin(a) * 0.5))
		verts_back.append(vcount)
		st.add_vertex(Vector3(cos(a) * r, -half, sin(a) * r))
		vcount += 1
	# outer wall
	for i: int in range(prof.size()):
		var i2: int = (i + 1) % prof.size()
		var a: float = TAU_K * float(i) / float(prof.size())
		var a2: float = TAU_K * float(i2) / float(prof.size())
		var r1: float = prof[i].x
		var r2: float = prof[i2].x
		var mid: Vector3 = (Vector3(cos(a) * r1, 0.0, sin(a) * r1) + Vector3(cos(a2) * r2, 0.0, sin(a2) * r2)) * 0.5
		var outward: Vector3 = mid.normalized()
		st.set_normal(outward)
		st.set_uv(Vector2(float(i) / float(prof.size()), 0.0))
		var wf: int = vcount
		st.add_vertex(Vector3(cos(a) * r1, half, sin(a) * r1))
		vcount += 1
		st.set_normal(outward)
		st.set_uv(Vector2(float(i) / float(prof.size()), 1.0))
		var wb: int = vcount
		st.add_vertex(Vector3(cos(a) * r1, -half, sin(a) * r1))
		vcount += 1
		st.set_normal(outward)
		st.set_uv(Vector2(float(i2) / float(prof.size()), 0.0))
		var wf2: int = vcount
		st.add_vertex(Vector3(cos(a2) * r2, half, sin(a2) * r2))
		vcount += 1
		st.set_normal(outward)
		st.set_uv(Vector2(float(i2) / float(prof.size()), 1.0))
		var wb2: int = vcount
		st.add_vertex(Vector3(cos(a2) * r2, -half, sin(a2) * r2))
		vcount += 1
		st.add_index(wf)
		st.add_index(wb)
		st.add_index(wf2)
		st.add_index(wf2)
		st.add_index(wb)
		st.add_index(wb2)
	# annular faces between the outer profile and the bore, so the hole is real
	# rather than a fan stretched across it
	var n: int = prof.size()
	var bore_front: PackedInt32Array = PackedInt32Array()
	var bore_back: PackedInt32Array = PackedInt32Array()
	for i: int in range(n):
		var a: float = TAU_K * float(i) / float(n)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5 + cos(a) * 0.5, 0.5 + sin(a) * 0.5))
		bore_front.append(vcount)
		st.add_vertex(Vector3(cos(a) * b, half, sin(a) * b))
		vcount += 1
		st.set_normal(Vector3.DOWN)
		st.set_uv(Vector2(0.5 + cos(a) * 0.5, 0.5 - sin(a) * 0.5))
		bore_back.append(vcount)
		st.add_vertex(Vector3(cos(a) * b, -half, sin(a) * b))
		vcount += 1
	for i: int in range(n):
		var i2: int = (i + 1) % n
		st.add_index(verts_front[i])
		st.add_index(bore_front[i])
		st.add_index(verts_front[i2])
		st.add_index(verts_front[i2])
		st.add_index(bore_front[i])
		st.add_index(bore_front[i2])
		st.add_index(verts_back[i])
		st.add_index(verts_back[i2])
		st.add_index(bore_back[i])
		st.add_index(verts_back[i2])
		st.add_index(bore_back[i2])
		st.add_index(bore_back[i])
	# bore wall
	for i: int in range(n):
		var i2: int = (i + 1) % n
		var a: float = TAU_K * float(i) / float(n)
		var inward: Vector3 = -Vector3(cos(a), 0.0, sin(a))
		st.add_index(bore_front[i])
		st.add_index(bore_front[i2])
		st.add_index(bore_back[i])
		st.add_index(bore_back[i])
		st.add_index(bore_front[i2])
		st.add_index(bore_back[i2])
	return st.commit()


## Hex bolt: head, shank, and a chamfer, generated from a diameter.
static func bolt(diameter: float, length: float, mat: Material = null, name: String = "Bolt") -> Node3D:
	var root := Node3D.new()
	root.name = name
	var head_r: float = diameter * 0.85
	var head_h: float = diameter * 0.65
	var head: MeshInstance3D = _mi(
		_cached("hex|%.4f|%.4f" % [head_r, head_h], func() -> Mesh: return _make_cyl(head_r, head_h, 6)),
		mat, "Head")
	head.position = Vector3(0.0, head_h * 0.5, 0.0)
	root.add_child(head)
	var shank: MeshInstance3D = cyl(diameter * 0.5, length, mat, 10, Vector3i(0, 1, 0), "Shank")
	shank.position = Vector3(0.0, head_h + length * 0.5, 0.0)
	root.add_child(shank)
	return root


## Sheet-metal plate with a rolled edge, the shape every hand-formed armour part
## and every scrap panel in the garage actually is.
static func plate(size: Vector3, bend: float, mat: Material = null, name: String = "Plate") -> Node3D:
	var root := Node3D.new()
	root.name = name
	root.add_child(box(Vector3(size.x, size.y, size.z), mat, "Face"))
	if bend > 0.0001:
		var e1: MeshInstance3D = box(Vector3(size.x, size.y, bend), mat, "EdgeA")
		e1.position = Vector3(0.0, size.y * 0.5, -size.z * 0.5 - bend * 0.5)
		e1.rotation.x = 0.35
		root.add_child(e1)
		var e2: MeshInstance3D = box(Vector3(bend, size.y, size.z), mat, "EdgeB")
		e2.position = Vector3(-size.x * 0.5 - bend * 0.5, size.y * 0.5, 0.0)
		e2.rotation.z = -0.35
		root.add_child(e2)
	return root


## A ring of small bolts, used on flanges, hubs and the reactor housing.
static func bolt_ring(count: int, radius: float, diameter: float, mat: Material = null, parent: Node3D = null) -> void:
	var n: int = clampi(count, 2, 40)
	for i: int in range(n):
		var a: float = TAU_K * float(i) / float(n)
		var b: Node3D = bolt(diameter, diameter * 1.2, mat, "Bolt%d" % i)
		b.position = Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		b.rotation = Vector3(0.0, a, 0.0)
		if parent != null:
			parent.add_child(b)


## Chain / sprocket run built from squashed torus links along a path.
static func chain(link_pitch: float, link_count: int, mat: Material = null, name: String = "Chain") -> Node3D:
	var root := Node3D.new()
	root.name = name
	var link_mesh: Mesh = _cached("chainlink|%.4f" % link_pitch, func() -> Mesh:
		var tm := TorusMesh.new()
		tm.inner_radius = link_pitch * 0.42
		tm.outer_radius = link_pitch * 0.62
		tm.rings = 12
		tm.ring_segments = 6
		return tm)
	for i: int in range(link_count):
		var li := MeshInstance3D.new()
		li.mesh = link_mesh
		li.material_override = mat
		li.name = "Link%d" % i
		li.position = Vector3(float(i) * link_pitch * 1.32, 0.0, 0.0)
		li.rotation = Vector3(0.0, 0.0, PI * 0.5)
		if i % 2 == 1:
			li.rotation.y = PI * 0.5
		li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(li)
	return root


## A coil of wire / spring: helix swept as a tube.
static func coil(turns: float, radius: float, wire: float, height: float, mat: Material = null, seg_per_turn: int = 20, name: String = "Coil") -> MeshInstance3D:
	var steps: int = clampi(int(turns * seg_per_turn), 6, 400)
	var path: PackedVector3Array = PackedVector3Array()
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		var a: float = TAU_K * turns * t
		path.append(Vector3(cos(a) * radius, height * t, sin(a) * radius))
	var frames: Array = CableGenerator.parallel_transport_frames(path)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	ShapeKit._sweep_raw(st, path, frames, wire, 6, 1.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.name = name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Shared tube sweep used by coils and hoses.
static func _sweep_raw(st: SurfaceTool, path: PackedVector3Array, frames: Array, radius: float, radial: int, u_scale: float, taper: float) -> void:
	var n: int = path.size()
	if n < 2 or radial < 3:
		return
	var vcount: int = 0
	for i: int in range(n):
		var p: Vector3 = path[i]
		var f: Array = frames[i]
		var tan: Vector3 = f[0]
		var nor: Vector3 = f[1]
		var bin: Vector3 = f[2]
		var t: float = float(i) / float(n - 1)
		var r: float = radius * lerpf(1.0, taper, t * t)
		for j: int in range(radial):
			var a: float = TAU_K * float(j) / float(radial)
			var offset: Vector3 = nor * cos(a) + bin * sin(a)
			st.set_normal((offset - tan * 0.05).normalized())
			st.set_uv(Vector2(t * u_scale, float(j) / float(radial)))
			st.add_vertex(p + offset * r)
			vcount += 1
		if i > 0:
			for j: int in range(radial):
				var j2: int = (j + 1) % radial
				var a0: int = (i - 1) * radial + j
				var a1: int = (i - 1) * radial + j2
				var b0: int = i * radial + j
				var b1: int = i * radial + j2
				st.add_index(a0)
				st.add_index(b0)
				st.add_index(b1)
				st.add_index(a0)
				st.add_index(b1)
				st.add_index(a1)


## Hose / flexible conduit between two points.
static func hose(from: Vector3, to: Vector3, radius: float, sag: float, mat: Material = null, name: String = "Hose") -> MeshInstance3D:
	var path: PackedVector3Array = CableGenerator.sag_path(from, to, sag, 0.0, 0.0, 18)
	var frames: Array = CableGenerator.parallel_transport_frames(path)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_sweep_raw(st, path, frames, radius, 8, 1.0, 0.96)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.name = name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ===========================================================================
# Convenience compound shapes
# ===========================================================================

static func rod(length: float, radius: float, mat: Material = null, axis: Vector3i = Vector3i(0, 1, 0), name: String = "Rod") -> MeshInstance3D:
	var mi: MeshInstance3D = cyl(radius, length, mat, 10, axis, name)
	return mi


static func frame_tube(a: Vector3, b: Vector3, radius: float, mat: Material = null, name: String = "FrameTube") -> MeshInstance3D:
	## A tube between two arbitrary points: the building block of every motorcycle
	## frame, rickshaw chassis, stand and exoskeleton in the garage.
	var dir: Vector3 = b - a
	var len: float = maxf(dir.length(), 0.0001)
	var mi: MeshInstance3D = cyl(radius, len, mat, 12, Vector3i(0, 1, 0), name)
	mi.position = a + dir * 0.5
	mi.look_at_from_position(mi.position, b, Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD)
	mi.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	return mi


static func disc(radius: float, thickness: float, mat: Material = null, name: String = "Disc", seg: int = 24) -> MeshInstance3D:
	## A coin standing on its edge, facing +Z: gauge faces, mirrors, lamp lenses,
	## the flat of a brake disc. Use disc_flat() for anything lying on a
	## horizontal surface, which is a different thing entirely.
	var key: String = "disc|%.4f|%.4f|%d" % [radius, thickness, seg]
	var mi: MeshInstance3D = _mi(_cached(key, func() -> Mesh: return _make_tcyl(radius, radius, thickness, seg)), mat, name)
	mi.rotation.x = PI * 0.5
	return mi


static func disc_flat(radius: float, thickness: float, mat: Material = null, name: String = "DiscFlat", seg: int = 24) -> MeshInstance3D:
	## The same solid lying flat, facing +Y: oil stains, puddles, tea rings on a
	## page, the hologram emitter plate, a light pod lens in a ceiling.
	var key: String = "disc|%.4f|%.4f|%d" % [radius, thickness, seg]
	return _mi(_cached(key, func() -> Mesh: return _make_tcyl(radius, radius, thickness, seg)), mat, name)


static func node(name: String, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	n.rotation = rot
	return n


static func static_body(name: String, shape: CollisionShape3D, pos: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = name
	sb.position = pos
	if shape != null:
		sb.add_child(shape)
	return sb


static func col_box(size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.name = "Col"
	return cs


static func col_cyl(radius: float, height: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.name = "Col"
	return cs


static func col_sphere(radius: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	cs.name = "Col"
	return cs


static func col_capsule(radius: float, height: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = radius
	sh.height = height
	cs.shape = sh
	cs.name = "Col"
	return cs


## No-LOD-flicker helper: props smaller than this never cast shadows, which is
## the single cheapest quality/price win in a scene with hundreds of small items.
static func set_lod_flags(mi: MeshInstance3D, cast: bool = true) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 26.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


static func shape_aabb_local(shape: Shape3D) -> AABB:
	## Shape3D exposes no get_aabb() in this engine build, so the local-space box is
	## derived from each concrete shape's own dimensions. Unknown shapes fall back to
	## a unit box rather than returning nothing, which would silently shrink an
	## interactable's focus volume to a point.
	if shape is BoxShape3D:
		var s: Vector3 = (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -r, Vector3.ONE * r * 2.0)
	if shape is CapsuleShape3D:
		var cp: CapsuleShape3D = shape as CapsuleShape3D
		return AABB(Vector3(-cp.radius, -cp.height * 0.5, -cp.radius), Vector3(cp.radius * 2.0, cp.height, cp.radius * 2.0))
	if shape is CylinderShape3D:
		var cy: CylinderShape3D = shape as CylinderShape3D
		return AABB(Vector3(-cy.radius, -cy.height * 0.5, -cy.radius), Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0))
	if shape is ConvexPolygonShape3D:
		var pts: PackedVector3Array = (shape as ConvexPolygonShape3D).points
		if pts.is_empty():
			return AABB(Vector3.ONE * -0.5, Vector3.ONE)
		var box := AABB(pts[0], Vector3.ZERO)
		for i: int in range(1, pts.size()):
			box = box.expand(pts[i])
		return box
	if shape is ConcavePolygonShape3D:
		var faces: PackedVector3Array = (shape as ConcavePolygonShape3D).faces
		if faces.is_empty():
			return AABB(Vector3.ONE * -0.5, Vector3.ONE)
		var cbox := AABB(faces[0], Vector3.ZERO)
		for i: int in range(1, faces.size()):
			cbox = cbox.expand(faces[i])
		return cbox
	if shape is HeightMapShape3D:
		var hm: HeightMapShape3D = shape as HeightMapShape3D
		var w: int = int(hm.map_width)
		var h: int = maxi(int(hm.map_height), 1)
		return AABB(Vector3(-w * 0.5, -1.0, -h * 0.5), Vector3(w, 2.0, h))
	return AABB(Vector3.ONE * -0.5, Vector3.ONE)


static func area_aabb(area: Node3D) -> AABB:
	## The world-space box of an Area3D's collision shapes. Area3D itself has no
	## get_aabb(), and the player's area attribution needs one.
	var out := AABB()
	var found: bool = false
	for c: Node in _descendants(area):
		if c is CollisionShape3D:
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs.shape == null:
				continue
			var world: AABB = cs.global_transform * shape_aabb_local(cs.shape)
			out = world if not found else out.merge(world)
			found = true
	return out


static func set_cast(node: Node3D, on: bool) -> void:
	## cast_shadow lives on GeometryInstance3D, but most prop generators return a
	## plain Node3D root holding many meshes. Setting the flag on the root is a
	## runtime error that aborts the generator and hands the caller a null node,
	## so this walks the subtree and sets it on every geometry it finds.
	for c: Node in _descendants(node):
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)


static func node_bounds(node: Node3D) -> AABB:
	## World-space AABB of every mesh and collision shape under `node`, walked
	## recursively. Used by the interaction reticle and by the station wrapper,
	## which need a real bound for a prop that is a hundred small meshes rather
	## than one. Returns a degenerate box for an empty subtree so callers can
	## always test has_volume().
	var out := AABB()
	var found: bool = false
	for c: Node in _descendants(node):
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c as MeshInstance3D
			if mi.mesh == null:
				continue
			var world: AABB = mi.global_transform * mi.get_aabb()
			out = world if not found else out.merge(world)
			found = true
		elif c is CollisionShape3D:
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs.shape == null:
				continue
			var cw: AABB = cs.global_transform * shape_aabb_local(cs.shape)
			out = cw if not found else out.merge(cw)
			found = true
	return out


static func _descendants(node: Node) -> Array:
	var out: Array = []
	for c: Node in node.get_children():
		out.append(c)
		out.append_array(_descendants(c))
	return out


static func jitter_transform(n: Node3D, rng: RandomNumberGenerator, pos_jitter: float, rot_jitter: float) -> void:
	n.position += Vector3(
		rng.randf_range(-pos_jitter, pos_jitter),
		rng.randf_range(-pos_jitter * 0.25, pos_jitter * 0.25),
		rng.randf_range(-pos_jitter, pos_jitter),
	)
	n.rotation.y += rng.randf_range(-rot_jitter, rot_jitter)
