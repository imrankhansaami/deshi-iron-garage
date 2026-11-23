class_name CarrySystem
extends Node3D
## Pick up and put down just about anything in the garage, entirely with the mouse.
##
## **Why the selection is a ray against AABBs, not a physics query.** Every prop
## in this project builds its collision shapes as bare `CollisionShape3D` children,
## which only collide when a `CollisionObject3D` parents them — and for most props
## nothing does, because the props were never meant to be solid. A physics ray
## would pass straight through a spanner. Scanning the cached world boxes of the
## ~180 carryable props each frame costs almost nothing and cannot destabilise the
## player's own collision.
##
## **What can be picked up.** Everything loose, hand-sized up to furniture: tools,
## tins, tyres, drums, chairs, crates, the workbenches, the shelves, the bicycle,
## the courtyard drum and tea cart, the holo table. The cap is a single largest
## dimension (see MAX_CARRY_SIZE) and the short exclusion list below holds the few
## things that depend on exactly where they are — the gate, the windows, the flag
## mast, the prototype suit. The building shell is far larger than the cap and
## filters itself out. A moved prop keeps its inspection station: the two travel
## together, and the station's trigger is switched off while the object is in
## mid-air.
##
## **Why placement finds "surfaces" instead of raycasting down.** The bench's
## station box is 0.45 m taller than the bench top (it includes the tool rail), and
## the floor slab is a thick box, so neither a ray nor a box test alone lands an
## object where a person would. Instead the system gathers every wide, thin box in
## the built scene once — bench tops, desk top, shelf planks, crate lids, the
## platform deck, the floor slab, the courtyard — and a drop settles onto the
## highest of those under the aim, flatly and predictably.
##
## **Holding.** Large objects are carried by their bounds centre rather than their
## origin, so a workbench floats in front of the camera like a workbench instead of
## towering up from a point at eye level.
##
## Controls: left click picks up / places, the wheel spins the held object, right
## click puts it back exactly where it was. No dragging, no physics fighting, no
## way to lose an object.

const PICK_RANGE: float = 3.6
const MAX_CARRY_SIZE: float = 3.1        # largest dimension a thing may have
## Fitted things that stay fitted. The shell pieces are far larger than the cap and
## need no listing; these four are within the cap but depend on where they are: the
## gate is animated and frames the doorway, the windows sit in wall openings, the
## flag mast is 5.8 m of pole for a flag at its top, and the prototype suit is
## mid-animation content whose parts home to the stand.
const CARRY_EXCLUDE_PREFIXES: Array[String] = ["Shutter", "Window", "FlagPole", "PrototypeExosuit", "ArmorGhost"]
const HOLD_CLEARANCE: float = 0.22       # how far below the camera's aim it floats
const FOLLOW_RATE: float = 14.0          # exponential smoothing rate
const ROTATE_STEP: float = PI / 12.0     # one wheel notch
const SETTLE_TIME: float = 0.16
const SURFACE_MAX_HEIGHT: float = 0.25   # a "flat surface" is this thin or less
const SURFACE_MIN_AREA: float = 0.12     # ...and this wide in square metres

enum State { FREE, CARRYING, SETTLING }

var _player: Player
var _items: Array[Dictionary] = []       # { node, box }
var _surfaces: Array[Dictionary] = []    # { top, rect, owner }
var _state: State = State.FREE
var _target: Node3D = null
var _target_box: AABB = AABB()
var _highlight: MeshInstance3D
var _held: Node3D = null
var _held_offset: Vector3 = Vector3.ZERO
var _held_center_offset: Vector3 = Vector3.ZERO
var _held_reach: float = 0.8
var _home_position: Vector3 = Vector3.ZERO
var _home_rotation: Vector3 = Vector3.ZERO
var _yaw_extra: float = 0.0
var _hint: String = ""
var _tween: Tween
var _freed_station_shapes: Array[CollisionShape3D] = []


func setup(player: Player, dressing: Node3D, structure: GarageStructure) -> void:
	_player = player
	_gather_items(dressing, structure)
	_gather_surfaces(dressing)
	_gather_surfaces(structure)
	_build_highlight()
	set_process(true)
	set_process_unhandled_input(true)


func _build_highlight() -> void:
	## The selection box: the same translucent-cyan language as the reticle's focus
	## volume, so "the mouse can pick this up" is visible without reading the hint
	## line. Cheaper than outlining a mesh, and it cannot fight the reticle's
	## bracket material because it is its own material instance.
	var qm := BoxMesh.new()
	qm.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.31, 0.85, 1.0, 0.10)
	mat.emission_enabled = true
	mat.emission = Color("4fd8ff")
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.resource_name = "carry_highlight"
	_highlight = MeshInstance3D.new()
	_highlight.name = "CarryHighlight"
	_highlight.mesh = qm
	_highlight.material_override = mat
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_highlight.visible = false
	add_child(_highlight)


func _show_highlight() -> void:
	if _target == null or _target_box.size == Vector3.ZERO:
		_highlight.visible = false
		return
	_highlight.visible = true
	_highlight.global_position = _target_box.get_center()
	_highlight.scale = _target_box.size + Vector3.ONE * 0.02


# ===========================================================================
# gathering
# ===========================================================================

func _gather_items(dressing: Node3D, structure: Node3D) -> void:
	## Everything loose in the room and the yard: every dressing prop plus the yard
	## pieces the structure builds (the drum, the tea cart, the antenna, the meter
	## box). The cap and the exclusion list are the only filters — the shell and the
	## big fitted furniture filter themselves out by size.
	_items.clear()
	for host: Node3D in [dressing, structure]:
		for child: Node in host.get_children():
			if not (child is Node3D):
				continue
			var node: Node3D = child
			var name: String = String(node.name)
			if name.begins_with("Grime"):
				continue
			var excluded: bool = false
			for prefix: String in CARRY_EXCLUDE_PREFIXES:
				if name.begins_with(prefix):
					excluded = true
					break
			if excluded:
				continue
			var box: AABB = ShapeKit.node_bounds(node)
			if not box.has_volume():
				continue
			var s: Vector3 = box.size
			if maxf(s.x, maxf(s.y, s.z)) > MAX_CARRY_SIZE:
				continue
			_items.append({"node": node, "box": box})
	# the prototype suit's parts, one by one: fourteen pieces, each individually
	# pickable. The suit ROOT stays excluded — it is the assembly rig — but every
	# helmet, plate, limb and core can be lifted and set down like anything else.
	for child2: Node in dressing.get_children():
		if child2 is Node3D and String((child2 as Node3D).name) == "PrototypeExosuit":
			for part: Node in (child2 as Node3D).get_children():
				if not (part is Node3D):
					continue
				var pbox: AABB = ShapeKit.node_bounds(part)
				if pbox.has_volume():
					_items.append({"node": part, "box": pbox})
			break


func _gather_surfaces(host: Node) -> void:
	for child: Node in host.get_children():
		# the hologram is not a shelf: nothing stands on a ghost
		if child is Node3D and String((child as Node3D).name).begins_with("ArmorGhost"):
			continue
		_scan_surfaces(child, child)


func _scan_surfaces(node: Node, owner: Node) -> void:
	if node is MeshInstance3D:
		_add_surface(node as MeshInstance3D, owner)
	for child: Node in node.get_children():
		_scan_surfaces(child, owner)


func _add_surface(mi: MeshInstance3D, owner: Node) -> void:
	if mi.mesh == null:
		return
	var box: AABB = mi.global_transform * mi.get_aabb()
	var s: Vector3 = box.size
	if s.y <= 0.002 or s.y > SURFACE_MAX_HEIGHT:
		return
	if s.x * s.z < SURFACE_MIN_AREA:
		return
	_surfaces.append({
		"top": box.position.y + s.y,
		"rect": Rect2(box.position.x, box.position.z, s.x, s.z),
		"owner": owner,
	})


func _rescan_owner(owner: Node) -> void:
	## After a prop moves, its old surface entries are stale and its new ones do
	## not exist. Drop them and rescan just that prop.
	var kept: Array[Dictionary] = []
	for s: Dictionary in _surfaces:
		if s.get("owner") != owner:
			kept.append(s)
	_surfaces = kept
	_scan_surfaces(owner, owner)


# ===========================================================================
# per-frame
# ===========================================================================

func _process(delta: float) -> void:
	if _player == null or _player.camera == null:
		return
	var playing: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	match _state:
		State.FREE:
			_target = _pick_under_crosshair() if playing else null
			_set_hint("LEFT CLICK — PICK UP" if _target != null else "")
			_show_highlight()
		State.CARRYING:
			_update_held(delta)
			_highlight.visible = false
			_set_hint("LEFT CLICK — PLACE   ·   WHEEL — ROTATE   ·   RIGHT CLICK — PUT BACK" if playing else "")
		State.SETTLING:
			_highlight.visible = false


func _pick_under_crosshair() -> Node3D:
	var cam: Camera3D = _player.camera
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var best: Node3D = null
	var best_t: float = PICK_RANGE
	_target_box = AABB()
	for entry: Dictionary in _items:
		if not bool(entry.get("enabled", true)):
			continue
		var node: Variant = entry.get("node")
		if not (node is Node3D) or not is_instance_valid(node) or node == _held:
			continue
		var t: float = _ray_box(origin, dir, entry.get("box"))
		if t > 0.0 and t < best_t:
			best_t = t
			best = node
			_target_box = entry.get("box")
	return best


func _update_held(delta: float) -> void:
	var cam: Camera3D = _player.camera
	var fwd: Vector3 = -cam.global_transform.basis.z
	# hold it in front of whatever wall is ahead so it never buries itself
	var clearance: float = _forward_clearance(cam.global_position, fwd)
	var dist: float = clampf(minf(_held_reach, clearance - 0.12), 0.30, PICK_RANGE)
	# carry big objects by their bounds centre, not their origin: a workbench
	# should float in front of the camera, not tower up from a point at eye level
	var center_off: Vector3 = _held_center_offset.rotated(Vector3.UP, _yaw_extra)
	var want: Vector3 = cam.global_position + fwd * dist - Vector3.UP * HOLD_CLEARANCE - center_off
	var k: float = 1.0 - exp(-FOLLOW_RATE * delta)
	_held.global_position = _held.global_position.lerp(want, k)
	var want_yaw: float = _home_rotation.y + _yaw_extra
	_held.rotation = Vector3(
		_home_rotation.x,
		lerp_angle(_held.rotation.y, want_yaw, k),
		_home_rotation.z)


# ===========================================================================
# input
# ===========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if _state == State.CARRYING and mb.pressed:
			_yaw_extra += ROTATE_STEP * (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			get_viewport().set_input_as_handled()
		return
	if not mb.pressed:
		return
	match mb.button_index:
		MOUSE_BUTTON_LEFT:
			if _state == State.FREE and _target != null:
				_pick_up(_target)
				get_viewport().set_input_as_handled()
			elif _state == State.CARRYING:
				_place()
				get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			if _state == State.CARRYING:
				_put_back()
				get_viewport().set_input_as_handled()


# ===========================================================================
# pick up / place / put back
# ===========================================================================

func _pick_up(node: Node3D) -> void:
	var box: AABB = ShapeKit.node_bounds(node)
	_held = node
	_held_offset = box.position - node.global_position
	_held_center_offset = box.get_center() - node.global_position
	_held_reach = 0.55 + box.size.length() * 0.35
	_home_position = node.global_position
	_home_rotation = node.rotation
	_yaw_extra = 0.0
	_freed_station_shapes.clear()
	for child: Node in node.get_children():
		if child is Station:
			for sub: Node in child.get_children():
				if sub is CollisionShape3D:
					var cs: CollisionShape3D = sub
					cs.set_deferred("disabled", true)
					_freed_station_shapes.append(cs)
	_state = State.CARRYING
	_target = null
	AudioBank.play("ui_pick", -9.0)


func auto_pick(node: Node3D) -> bool:
	## A scripted pickup — the armour build's point-to-lift assist. Takes the
	## same path as a left click once the crosshair has rested on the part.
	if _state != State.FREE or node == null or not is_instance_valid(node):
		return false
	for entry: Dictionary in _items:
		if entry.get("node") == node and bool(entry.get("enabled", true)):
			_pick_up(node)
			return true
	return false


func _place() -> void:
	var node: Node3D = _held
	var target_y: float = _surface_under(node.global_position, node)
	var landing: Vector3 = node.global_position
	landing.y = target_y - _held_offset.y + 0.002
	_begin_settle(node, landing, node.rotation, "tool_place", 0.0)


func _put_back() -> void:
	## The safety net: right click returns the object exactly where it came from,
	## so experimenting is free and nothing can be lost or buried.
	_begin_settle(_held, _home_position, _home_rotation, "tool_place", 0.06)


func _begin_settle(node: Node3D, to_position: Vector3, to_rotation: Vector3, sfx: String, delay: float) -> void:
	_state = State.SETTLING
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.set_parallel(true)
	_tween.tween_property(node, "global_position", to_position, SETTLE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(node, "rotation", to_rotation, SETTLE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.chain().tween_callback(_finish_settle)
	AudioBank.play_at(sfx, node.global_position, -7.0)


func _finish_settle() -> void:
	var node: Node3D = _held
	_held = null
	_state = State.FREE
	if node != null and is_instance_valid(node):
		for cs: CollisionShape3D in _freed_station_shapes:
			if is_instance_valid(cs):
				cs.set_deferred("disabled", false)
		_freed_station_shapes.clear()
		# the moved prop's cached box and surfaces are stale now
		for entry: Dictionary in _items:
			if entry.get("node") == node:
				entry["box"] = ShapeKit.node_bounds(node)
				break
		_rescan_owner(node)


func _surface_under(point: Vector3, exclude: Node3D) -> float:
	var best: float = -1000.0
	var xz := Vector2(point.x, point.z)
	# an assembly module never stacks on another armour piece: dropped at the
	# build it seats (see ArmorAssembly), anywhere else it lands on floor or
	# bench like any other prop
	var drop_armor: bool = _held != null and String(_held.name).begins_with("Armor")
	for s: Dictionary in _surfaces:
		var owner: Node = s.get("owner") as Node
		if owner == exclude:
			continue
		if drop_armor and owner != null and String(owner.name).begins_with("Armor"):
			continue
		var rect: Rect2 = s.get("rect")
		if not rect.has_point(xz):
			continue
		var top: float = float(s.get("top"))
		if top <= point.y + 0.35 and top > best:
			best = top
	if best > -999.0:
		return best
	# nothing flat found: ask physics for the ground, then fall back to the slab
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 0.1, point + Vector3.DOWN * 6.0, 1)
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	if not hit.is_empty():
		return (hit.get("position", Vector3.ZERO) as Vector3).y
	return 0.0


func _forward_clearance(from: Vector3, dir: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + dir * 4.0, 1)
	q.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(q)
	if hit.is_empty():
		return 4.0
	return float(hit.get("distance", 4.0))


func _set_hint(text: String) -> void:
	if text == _hint:
		return
	_hint = text
	EventBus.carry_hint_changed.emit(text)


# ===========================================================================
# hand-off API — the fitting interactions (the armour assembly)
# ===========================================================================

func held() -> Node3D:
	## The node in the player's hands right now, or null. The armour figure reads
	## this to know which spare is being offered to a socket.
	return _held if _state == State.CARRYING else null


func settle_held(to_position: Vector3, to_rotation: Vector3, sfx: String = "servo") -> bool:
	## The caller owns the destination — an assembly socket — and the held item
	## rides the same settle tween a place/put-back would use.
	if _state != State.CARRYING or _held == null:
		return false
	_begin_settle(_held, to_position, to_rotation, sfx, 0.05)
	return true


func detach_held() -> Node3D:
	## The fitting interaction takes the held node over: the carry state clears
	## immediately and the caller owns the node's animation from here.
	if _state != State.CARRYING or _held == null:
		return null
	var node: Node3D = _held
	_held = null
	_state = State.FREE
	for cs: CollisionShape3D in _freed_station_shapes:
		if is_instance_valid(cs):
			cs.set_deferred("disabled", false)
	_freed_station_shapes.clear()
	_set_hint("")
	return node


func set_item_enabled(node: Node3D, enabled: bool) -> void:
	## Fitted furniture stays in the room but off the pick list: the armour
	## assembly disables a spare once it is seated and re-enables it on dismount.
	for entry: Dictionary in _items:
		if entry.get("node") == node:
			entry["enabled"] = enabled
			return


static func _ray_box(origin: Vector3, dir: Vector3, box: AABB) -> float:
	## Slab test. The box is shrunk a little so a glance along a bench top does
	## not count as aiming at every item sitting on it.
	var t_min: float = 0.0
	var t_max: float = 1.0e20
	for axis: int in range(3):
		var o: float = origin[axis]
		var d: float = dir[axis]
		var lo: float = box.position[axis] + 0.02
		var hi: float = box.position[axis] + box.size[axis] - 0.02
		if absf(d) < 0.000001:
			if o < lo or o > hi:
				return -1.0
		else:
			var t1: float = (lo - o) / d
			var t2: float = (hi - o) / d
			t_min = maxf(t_min, minf(t1, t2))
			t_max = minf(t_max, maxf(t1, t2))
	if t_max < t_min:
		return -1.0
	return t_min
