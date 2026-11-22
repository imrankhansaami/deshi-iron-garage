extends Node
class_name ArmorAssembly
## The armour assembly (presentation plan A), two-stage and by hand. The shop's
## four spare shells — helmet, chest plate, gauntlet, boot — are TEST-FITTED onto
## the practice figure first (carry a part to the figure, press E: it snaps into
## its socket), and then BOLTED DOWN: one more E at the figure walks the whole
## kit through its locks with a cascade of clacks, punching the scale and the
## base ring's glow one step per bolt. When the fourth bolt lands, the figure
## powers up. E once more with everything bolted strips it all back home, so the
## sequence can be presented again and again.
##
## State lives here, not on the parts: each part keeps the transform it was
## authored with (its home). The fitting takes the held node over from the carry
## system (detach_held) and owns the snap animation. Glow materials are duplicated
## at bind time so every ramp stays local to the armour; the base ring is the
## progress meter, kept out of the pulse set.
##
## Deliberately unbranded: the parts are the shop's own spare shells, and the
## stations say so. No combat, no weapons — a fitting exercise.

var runtime: Node
var carry: Node
var figure: Node3D
var _player: Node = null

## name -> socket data. Sockets are in the figure's LOCAL space: the figure's
## yaw is applied to the seat rotation, so a rotated figure still fits right.
const PARTS: Dictionary = {
	"ArmorHelmet": {"socket": Vector3(0.0, 1.525, 0.0), "yaw": 0.0,
		"label": "spare helmet", "line": "helmet seated over the practice head",
		"seat_sfx": "latch", "lock_sfx": "metal_tink"},
	"ArmorChestPlate": {"socket": Vector3(0.0, 1.10, 0.12), "yaw": 0.0,
		"label": "spare chest plate", "line": "chest plate slipped over the figure's front",
		"seat_sfx": "metal_thunk", "lock_sfx": "metal_clank"},
	"ArmorGauntlet": {"socket": Vector3(0.36, 0.585, 0.03), "yaw": 0.0,
		"label": "spare gauntlet", "line": "gauntlet drawn over the right forearm",
		"seat_sfx": "servo", "lock_sfx": "metal_tink"},
	"ArmorBoot": {"socket": Vector3(-0.11, 0.0, 0.02), "yaw": 0.0,
		"label": "spare boot", "line": "boot set on the left foot",
		"seat_sfx": "tool_place", "lock_sfx": "metal_clank"},
}

var _parts: Dictionary = {}          ## name -> Node3D
var _homes: Dictionary = {}          ## name -> {position, rotation}
var _fitted: Dictionary = {}         ## name -> true (seated, not yet bolted)
var _locked: Dictionary = {}         ## name -> true (bolted down)
var _glow_mats: Array = []           ## duplicated emissive materials (pulses)
var _ring_mat: StandardMaterial3D = null   ## the base ring, the progress meter
var _ring_base: float = 3.0
var _orig: Dictionary = {}           ## station -> {title, desc, spec} originals
var _hinted: bool = false
var _busy: bool = false
var _engaged: bool = false           ## the guide only exists once the job begins
var _beacon: Node3D = null           ## the floating tag that marks the next step
var _beacon_t: float = 0.0
var _sealed_ms: int = 0

## Where each spare waits, for the tracker's next-step line.
const LOCATIONS: Dictionary = {
	"ArmorHelmet": "on the mechanical bench, north end",
	"ArmorChestPlate": "on the bench's lower shelf",
	"ArmorGauntlet": "on the store shelf, north-west corner",
	"ArmorBoot": "on the floor beside the figure",
}


func bind(p_runtime: Node, p_carry: Node, dressing: Node3D, p_player: Node = null) -> void:
	runtime = p_runtime
	carry = p_carry
	_player = p_player
	figure = dressing.get_node_or_null("ArmorFigure") as Node3D
	if figure == null:
		push_warning("ArmorAssembly: no ArmorFigure in the dressing")
		return
	for part_name: String in PARTS:
		var node: Node3D = dressing.get_node_or_null(part_name) as Node3D
		if node == null:
			continue
		_parts[part_name] = node
		_homes[part_name] = {"position": node.global_position, "rotation": node.rotation}
	_duplicate_glow()
	if _ring_mat != null:
		_ring_mat.emission_energy_multiplier = _ring_base * 0.5
	_snapshot_texts()
	_build_beacon()
	set_process(true)


func _build_beacon() -> void:
	## The guide tag: a small bobbing diamond in the shop's signal yellow that
	## marks what to carry and where to bring it. Hidden until the job is engaged,
	## so the morning room stays clean.
	var mat: StandardMaterial3D = MaterialLibrary.led(Color("ffd24a"), 1.6)
	var tag: MeshInstance3D = ShapeKit.box(Vector3(0.065, 0.065, 0.065), mat, "ArmorGuide")
	tag.rotation = Vector3(PI * 0.25, 0.0, PI * 0.25)
	tag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tag)
	_beacon = tag
	_beacon.visible = false


func engage() -> void:
	## The job begins: the beacon and the tracker come alive.
	_engaged = true


func _process(delta: float) -> void:
	if _beacon == null or figure == null:
		return
	var held: Node3D = carry.held() if carry != null else null
	if not _engaged and held != null and _is_part(held):
		_engaged = true
	if not _engaged and _player != null:
		# walking up to the figure is enough: no looking, no clicking to wake it
		if _player.global_position.distance_to(figure.global_position) < 4.5:
			_engaged = true
	var show: bool = _engaged and _locked.size() < PARTS.size()
	_beacon.visible = show
	if not show:
		return
	_beacon_t += delta
	var target: Vector3
	if held != null and _is_part(held) and not _fitted.has(_name_of(held)):
		# carrying the right part: mark where it goes
		target = figure.global_position + Vector3.UP * 2.05
	else:
		var np: String = guide_part()
		if np != "":
			var node: Node3D = _parts[np]
			target = node.global_position + Vector3.UP * (ShapeKit.node_bounds(node).size.y + 0.25)
		else:
			target = figure.global_position + Vector3.UP * 2.05
	_beacon.global_position = target + Vector3.UP * sin(_beacon_t * 2.4) * 0.045
	_beacon.rotation.y = _beacon_t * 1.1


func beacon_visible() -> bool:
	return _beacon != null and _beacon.visible


func tracker_visible() -> bool:
	## The HUD tracker lives while the job is open, then lingers a few seconds
	## past the seal so the completion is seen.
	if not _engaged:
		return false
	if _locked.size() < PARTS.size():
		return true
	return Time.get_ticks_msec() - _sealed_ms < 12000


func guide_part() -> String:
	## The nearest spare still at its place — whatever is easiest to reach next,
	## so anyone can start with the part they happen to be standing by. Falls back
	## to the story order (head, chest, arm, foot) when no player reference exists.
	var best: String = ""
	var best_d: float = 0.0
	for part_name: String in PARTS:
		if _fitted.has(part_name):
			continue
		if _player == null:
			return part_name
		var node: Node3D = _parts.get(part_name, null) as Node3D
		if node == null:
			continue
		var d: float = _player.global_position.distance_to(node.global_position)
		if best == "" or d < best_d:
			best = part_name
			best_d = d
	return best


func guide_line() -> String:
	## The tracker's one-line instruction, from wherever the player is.
	var held: Node3D = carry.held() if carry != null else null
	if held != null and _is_part(held):
		return "carry it to the figure — E to test-fit"
	if _locked.size() >= PARTS.size():
		return "complete — E at the figure strips the kit for a second run"
	if not _pending_locks().is_empty():
		return "E at the figure bolts the kit down"
	var np: String = guide_part()
	if np != "":
		return "next: carry the %s — %s" % [String(PARTS[np]["label"]), String(LOCATIONS[np])]
	return ""


func _is_part(node: Node3D) -> bool:
	return node != null and _parts.values().has(node)


func _name_of(node: Node3D) -> String:
	for part_name: String in _parts:
		if _parts[part_name] == node:
			return part_name
	return ""


# ===========================================================================
# prompts and the E press
# ===========================================================================

func figure_prompt() -> String:
	if not _hinted:
		_hinted = true
		_engaged = true
		EventBus.notification_requested.emit("the figure takes the four spares — helmet, chest plate, gauntlet, boot. Bring one and press E to test-fit it", "info")
	var held: Node3D = carry.held()
	if held != null:
		for part_name: String in PARTS:
			if _parts.get(part_name) == held and not _fitted.has(part_name):
				return "Press E to test-fit the %s" % String(PARTS[part_name]["label"])
		return "Press E — that part doesn't socket here"
	var pending: Array = _pending_locks()
	if pending.size() == 1:
		return "Press E to bolt the %s down" % String(PARTS[pending[0]]["label"])
	if not pending.is_empty():
		return "Press E to bolt the kit down (%d in reach)" % pending.size()
	if not _fitted.is_empty():
		return "Press E to strip the spares back to their places"
	return "Press E to inspect"


func figure_action(_player: Node) -> bool:
	## Returns true when the press concerned the fitting; false hands the press
	## back to the station's normal inspect behaviour.
	if figure == null or _parts.is_empty():
		return false
	_engaged = true
	var held: Node3D = carry.held()
	if held != null:
		for part_name: String in PARTS:
			if _parts.get(part_name) == held:
				if _fitted.has(part_name):
					EventBus.notification_requested.emit("%s is already seated" % String(PARTS[part_name]["label"]), "info")
					return true
				_seat(part_name)
				return true
		EventBus.notification_requested.emit("that part doesn't socket here — helmet, chest plate, gauntlet, boot", "warning")
		AudioBank.play("ui_error", -4.0)
		return true
	var pending: Array = _pending_locks()
	if not pending.is_empty():
		_bolt_all(pending)
		return true
	if not _fitted.is_empty():
		dismount_all(false)
		return true
	return false


# ===========================================================================
# stage one: the seat
# ===========================================================================

func _seat(part_name: String) -> void:
	if _busy:
		return
	var node: Node3D = _parts[part_name]
	var info: Dictionary = PARTS[part_name]
	var handed: Node3D = carry.detach_held()
	if handed != node:
		return
	_busy = true
	carry.set_item_enabled(node, false)
	_fitted[part_name] = true
	var to_pos: Vector3 = figure.to_global(info["socket"] as Vector3)
	var to_rot: Vector3 = Vector3(0.0, figure.rotation.y + float(info["yaw"]), 0.0)
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	# TRANS_BACK overshoots a hair and settles: the snap of a part finding its seat
	tw.tween_property(node, "global_position", to_pos, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", to_rot, 0.34).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	AudioBank.play_at(String(info["seat_sfx"]), to_pos, -7.0)
	_pulse(1.35)
	_update_texts()
	var n: int = _fitted.size()
	if n >= PARTS.size():
		EventBus.notification_requested.emit("%s — all four seated. The core is catching — press E again to bolt the kit down and seal the fit" % String(info["line"]), "success")
		var catch_tw: Tween = create_tween()
		catch_tw.tween_interval(0.4)
		catch_tw.tween_callback(_power_on_moment)
	else:
		EventBus.notification_requested.emit("%s — %d of 4 seated" % [String(info["line"]), n], "success")
	if runtime != null:
		runtime.sys_log("ARMOUR SEAT: %s (%d/4)" % [part_name.to_upper(), n])
	var tw2: Tween = create_tween()
	tw2.tween_interval(0.45)
	tw2.tween_callback(func() -> void: _busy = false)


# ===========================================================================
# stage two: bolt the kit down, one clack at a time
# ===========================================================================

func _pending_locks() -> Array:
	var pending: Array = []
	for part_name: String in PARTS:
		if _fitted.has(part_name) and not _locked.has(part_name):
			pending.append(part_name)
	return pending


func _bolt_all(pending: Array) -> void:
	var delay: float = 0.0
	for part_name: String in pending:
		_bolt_one(part_name, delay)
		delay += 0.28
	var watch: Tween = create_tween()
	watch.tween_interval(delay + 0.15)
	watch.tween_callback(_after_bolts)


func _bolt_one(part_name: String, delay: float) -> void:
	var node: Node3D = _parts[part_name]
	var info: Dictionary = PARTS[part_name]
	var tw: Tween = create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func() -> void:
		_locked[part_name] = true
		AudioBank.play_at(String(info["lock_sfx"]), node.global_position, -6.0)
		# the part takes the torque: a quick pump of scale
		var pump: Tween = create_tween()
		pump.tween_property(node, "scale", Vector3.ONE * 1.04, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pump.tween_property(node, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ring_step()
		_pulse(1.5)
		_update_texts()
		if runtime != null:
			runtime.sys_log("ARMOUR BOLT: %s (%d/4)" % [part_name.to_upper(), _locked.size()])
	)


func _after_bolts() -> void:
	if _locked.size() >= PARTS.size():
		_seal()
	else:
		EventBus.notification_requested.emit("%d of 4 bolted — seat the rest, then E again" % _locked.size(), "info")


func _ring_step() -> void:
	if _ring_mat == null:
		return
	var target: float = _ring_base * (0.5 + 0.25 * float(_locked.size()))
	var tw: Tween = create_tween()
	tw.tween_property(_ring_mat, "emission_energy_multiplier", target, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func dismount_all(instant: bool = false) -> void:
	## Strip every fitted spare back to its authored home — seated or bolted.
	if _fitted.is_empty():
		if not instant:
			EventBus.notification_requested.emit("no spares are fitted", "info")
		return
	for part_name: String in _fitted.keys():
		var node: Node3D = _parts[part_name]
		var home: Dictionary = _homes[part_name]
		carry.set_item_enabled(node, true)
		node.scale = Vector3.ONE
		if instant:
			node.global_position = home["position"] as Vector3
			node.rotation = home["rotation"] as Vector3
		else:
			var tw: Tween = create_tween()
			tw.set_parallel(true)
			tw.tween_property(node, "global_position", home["position"] as Vector3, 0.55) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(node, "rotation", home["rotation"] as Vector3, 0.55)
		AudioBank.play_at("tool_place", node.global_position, -8.0)
	_fitted.clear()
	_locked.clear()
	for m: StandardMaterial3D in _glow_mats:
		if not is_instance_valid(m):
			continue
		var base: float = float(m.get_meta("base_energy", 2.0))
		if instant:
			m.emission_energy_multiplier = base
		else:
			var tw2: Tween = create_tween()
			tw2.tween_property(m, "emission_energy_multiplier", base, 0.5)
	if _ring_mat != null:
		var target: float = _ring_base * 0.5
		if instant:
			_ring_mat.emission_energy_multiplier = target
		else:
			var tw3: Tween = create_tween()
			tw3.tween_property(_ring_mat, "emission_energy_multiplier", target, 0.5)
	_update_texts()
	if not instant:
		EventBus.notification_requested.emit("spares stripped back — the figure stands as it was", "info")
		if runtime != null:
			runtime.sys_log("ARMOUR DISMOUNTED")


func fit_all_instant() -> void:
	## Used by the capture harness so the finished-garage shots show the armour
	## complete — seated, bolted and lit.
	for part_name: String in PARTS:
		var node: Node3D = _parts.get(part_name, null) as Node3D
		if node == null or _fitted.has(part_name):
			continue
		var info: Dictionary = PARTS[part_name]
		carry.set_item_enabled(node, false)
		node.global_position = figure.to_global(info["socket"] as Vector3)
		node.rotation = Vector3(0.0, figure.rotation.y + float(info["yaw"]), 0.0)
		_fitted[part_name] = true
		_locked[part_name] = true
	for m: StandardMaterial3D in _glow_mats:
		if is_instance_valid(m):
			m.emission_energy_multiplier = float(m.get_meta("base_energy", 2.0)) * 1.9
	if _ring_mat != null:
		_ring_mat.emission_energy_multiplier = _ring_base * 2.1
	_update_texts()


# ===========================================================================
# the lights: duplicate the shared LED materials so ramps stay local
# ===========================================================================

func _duplicate_glow() -> void:
	_snatch_glow(figure)
	for part_name: String in _parts:
		_snatch_glow(_parts[part_name])


func _snatch_glow(node: Node) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			var nm: String = String(mi.name)
			if nm.begins_with("Eye") or nm.begins_with("Core") or nm.begins_with("GlowRing") or nm.begins_with("Slit"):
				var src: StandardMaterial3D = mi.get_active_material(0) as StandardMaterial3D
				if src != null and src.emission_enabled:
					var dup: StandardMaterial3D = src.duplicate() as StandardMaterial3D
					dup.set_meta("base_energy", dup.emission_energy_multiplier)
					mi.material_override = dup
					if nm.begins_with("GlowRing"):
						# the base ring is the progress meter, not a pulse target
						_ring_mat = dup
						_ring_base = dup.emission_energy_multiplier
					else:
						_glow_mats.append(dup)
		_snatch_glow(child)


func _pulse(mult: float) -> void:
	for m: StandardMaterial3D in _glow_mats:
		if not is_instance_valid(m):
			continue
		var base: float = float(m.get_meta("base_energy", 2.0))
		var tw: Tween = create_tween()
		tw.tween_property(m, "emission_energy_multiplier", base * mult, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(m, "emission_energy_multiplier", base, 0.5) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _power_on_moment() -> void:
	## The last part seats and the core catches: the lights ramp up for the first
	## time — the power-up the sequence promised. The bolt-down then seals it.
	_ramp_glows(2.1, 1.55)
	if _ring_mat != null:
		var ring_tw: Tween = create_tween()
		ring_tw.tween_property(_ring_mat, "emission_energy_multiplier", _ring_base * 2.4, 0.4) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ring_tw.tween_property(_ring_mat, "emission_energy_multiplier", _ring_base * 1.7, 0.8)
	AudioBank.play_at("core_charge", figure.global_position, -6.0)
	if runtime != null:
		runtime.sys_log("ARMOUR POWER-ON — FOURTH SEAT")
	_update_texts()


func _seal() -> void:
	## The fourth bolt: the fit is sealed and certified — a second surge over the
	## running lights, a touch brighter than the power-on settle.
	_ramp_glows(2.4, 1.9)
	if _ring_mat != null:
		var ring_tw: Tween = create_tween()
		ring_tw.tween_property(_ring_mat, "emission_energy_multiplier", _ring_base * 2.8, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ring_tw.tween_property(_ring_mat, "emission_energy_multiplier", _ring_base * 2.1, 0.7)
	AudioBank.play_at("core_charge", figure.global_position, -4.0, 1.15)
	EventBus.notification_requested.emit("ARMOUR MK-I — COMPLETE — all four spares fitted, bolted and sealed", "success")
	if runtime != null:
		runtime.sys_log("ARMOUR MK-I COMPLETE — SEALED")
	_update_texts()


func _ramp_glows(peak: float, settle: float) -> void:
	for m: StandardMaterial3D in _glow_mats:
		if not is_instance_valid(m):
			continue
		var base: float = float(m.get_meta("base_energy", 2.0))
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "emission_energy_multiplier", base * peak, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(m, "emission_energy_multiplier", base * settle, 0.9)


# ===========================================================================
# the texts: the figure and the four part stations say what state they are in
# ===========================================================================

func _snapshot_texts() -> void:
	var fig_st: Node = _station_of(figure)
	if fig_st != null:
		_orig[fig_st] = {"title": fig_st.display_name, "desc": fig_st.description, "spec": fig_st.spec_rows.duplicate()}
	for part_name: String in _parts:
		var st: Node = _station_of(_parts[part_name])
		if st != null:
			_orig[st] = {"title": st.display_name, "desc": st.description, "spec": st.spec_rows.duplicate()}


func _update_texts() -> void:
	var fig_st: Node = _station_of(figure)
	if fig_st != null and _orig.has(fig_st):
		var o: Dictionary = _orig[fig_st]
		if _locked.size() >= PARTS.size():
			fig_st.display_name = "The shop's armour — complete"
			fig_st.description = "All four spare shells are test-fitted and bolted down: helmet over the head, chest plate over the front, gauntlet on the right forearm, boot on the left foot. The core lens and the eye slits are burning brighter, the base ring stands at full — the fit checks out."
			fig_st.spec_rows = [["spares bolted", "4 of 4"], ["palette", "red over gold over alloy"], ["state", "fit checked, standing test"]]
		elif _fitted.is_empty():
			fig_st.display_name = String(o["title"])
			fig_st.description = String(o["desc"])
			fig_st.spec_rows = (o["spec"] as Array).duplicate()
		else:
			fig_st.display_name = "The shop's armour — %d seated, %d bolted" % [_fitted.size(), _locked.size()]
			fig_st.description = "The spare shells are being test-fitted onto the figure: %d seated, %d already bolted down. One more E at the figure walks the rest through their locks." % [_fitted.size(), _locked.size()]
			fig_st.spec_rows = [["spares seated", "%d of 4" % _fitted.size()], ["spares bolted", "%d of 4" % _locked.size()], ["palette", "red over gold over alloy"]]
	for part_name: String in _parts:
		var st: Node = _station_of(_parts[part_name])
		if st == null or not _orig.has(st):
			continue
		var o2: Dictionary = _orig[st]
		if _locked.has(part_name):
			st.display_name = String(o2["title"]) + " — bolted"
			st.description = String(o2["desc"]) + " Right now it is seated on the figure and bolted down."
		elif _fitted.has(part_name):
			st.display_name = String(o2["title"]) + " — seated"
			st.description = String(o2["desc"]) + " Right now it is seated on the figure, waiting for the bolt-down."
		else:
			st.display_name = String(o2["title"])
			st.description = String(o2["desc"])
		st.spec_rows = (o2["spec"] as Array).duplicate()


func _station_of(node: Node) -> Node:
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is Station:
			return child
	return null


func fitted_count() -> int:
	return _fitted.size()


func locked_count() -> int:
	return _locked.size()


func part_state(part_name: String) -> int:
	## 0 at its place · 1 seated (test-fitted) · 2 bolted down. Read by the
	## console's armour checklist.
	if _locked.has(part_name):
		return 2
	if _fitted.has(part_name):
		return 1
	return 0
