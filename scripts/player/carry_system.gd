class_name CarrySystem
extends Node
## Pick up and put down the garage's small things, entirely with the mouse.
##
## **Why the selection is a ray against AABBs, not a physics query.** Every prop
## in this project builds its collision shapes as bare `CollisionShape3D` children,
## which only collide when a `CollisionObject3D` parents them — and for most props
## nothing does, because the props were never meant to be solid. A physics ray
## would pass straight through a spanner. Scanning the cached world boxes of the
## ~100 carryable props each frame costs almost nothing and cannot destabilise the
## player's own collision.
##
## **Why placement finds "surfaces" instead of raycasting down.** The bench's
## station box is 0.45 m taller than the bench top (it includes the tool rail), and
## the floor slab is a thick box, so neither a ray nor a box test alone lands an
## object where a person would. Instead the system gathers every wide, thin box in
## the built scene once — bench tops, desk top, shelf planks, crate lids, the
## platform deck, the floor slab, the courtyard — and a drop settles onto the
## highest of those under the aim, flatly and predictably.
##
## Controls: left click picks up / places, the wheel spins the held object, right
## click puts it back exactly where it was. No dragging, no physics fighting, no
## way to lose an object.

const PICK_RANGE: float = 3.2
const MAX_CARRY_SIZE: float = 0.8        # largest dimension a thing may have
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
var _held: Node3D = null
var _held_offset: Vector3 = Vector3.ZERO
var _held_reach: float = 0.8
var _home_position: Vector3 = Vector3.ZERO
var _home_rotation: Vector3 = Vector3.ZERO
var _yaw_extra: float = 0.0
var _hint: String = ""
var _tween: Tween
var _freed_station_shapes: Array[CollisionShape3D] = []


func setup(player: Player, dressing: Node3D, structure: GarageStructure) -> void:
	_player = player
	_gather_items(dressing)
	_gather_surfaces(dressing)
	_gather_surfaces(structure)
	set_process(true)
	set_process_unhandled_input(true)


# ===========================================================================
# gathering
# ===========================================================================

func _gather_items(dressing: Node3D) -> void:
	_items.clear()
	for child: Node in dressing.get_children():
		if not (child is Node3D):
			continue
		var node: Node3D = child
		if String(node.name).begins_with("Grime"):
			continue
		var box: AABB = ShapeKit.node_bounds(node)
		if not box.has_volume():
			continue
		var s: Vector3 = box.size
		if maxf(s.x, maxf(s.y, s.z)) > MAX_CARRY_SIZE:
			continue
		_items.append({"node": node, "box": box})


func _gather_surfaces(host: Node) -> void:
	for child: Node in host.get_children():
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
		State.CARRYING:
			_update_held(delta)
			_set_hint("LEFT CLICK — PLACE   ·   WHEEL — ROTATE   ·   RIGHT CLICK — PUT BACK" if playing else "")
		State.SETTLING:
			pass


func _pick_under_crosshair() -> Node3D:
	var cam: Camera3D = _player.camera
	var origin: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var best: Node3D = null
	var best_t: float = PICK_RANGE
	for entry: Dictionary in _items:
		var node: Variant = entry.get("node")
		if not (node is Node3D) or not is_instance_valid(node) or node == _held:
			continue
		var t: float = _ray_box(origin, dir, entry.get("box"))
		if t > 0.0 and t < best_t:
			best_t = t
			best = node
	return best


func _update_held(delta: float) -> void:
	var cam: Camera3D = _player.camera
	var fwd: Vector3 = -cam.global_transform.basis.z
	# hold it in front of whatever wall is ahead so it never buries itself
	var clearance: float = _forward_clearance(cam.global_position, fwd)
	var dist: float = clampf(minf(_held_reach, clearance - 0.12), 0.30, PICK_RANGE)
	var want: Vector3 = cam.global_position + fwd * dist - Vector3.UP * HOLD_CLEARANCE
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
	for s: Dictionary in _surfaces:
		if s.get("owner") == exclude:
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
