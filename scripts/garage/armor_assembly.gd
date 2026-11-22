extends Node
class_name ArmorAssembly
## The figure build: the shop's armour, assembled from THREE parts, low to
## high. The service base waits by the north wall and the legs, torso and head
## wait together on the build pallet at the front. Carry an assembly to the
## base — walking it up seats it (the snap, the latch, the light pulse, the base
## ring climbing a step) — legs first, then torso, then head; the order is
## enforced with a red correction. When the head seats, the whole figure powers
## up and the bolts walk the fit down on their own and seal it. E with the seal
## done strips the figure back to the pallet, so the build can be presented
## again.
##
## State lives here, not on the assemblies: each keeps the transform it was
## authored with (its home). Seating takes the held node over from the carry
## system (detach_held) and owns the snap animation. Glow materials are
## duplicated at bind time so every ramp stays local to the figure; the base
## ring is the progress meter, kept out of the pulse set.
##
## Deliberately unbranded: an homage in the reference palette, the shop's own
## build. No combat, no weapons — a fitting exercise.

var runtime: Node
var carry: Node
var figure: Node3D
var _player: Node = null

## The figure, in three assemblies, low to high. Sockets are in the service
## base's LOCAL space: the base's yaw is applied to the seat rotation, so a
## rotated base still builds right. Dictionary order IS the build order.
const PARTS: Dictionary = {
	"ArmorLegs": {"socket": Vector3(0.0, 0.05, 0.0), "yaw": 0.0,
		"label": "the legs and boots", "line": "the legs and boots stand on the base",
		"seat_sfx": "metal_thunk", "lock_sfx": "metal_clank"},
	"ArmorTorso": {"socket": Vector3(0.0, 0.62, 0.0), "yaw": 0.0,
		"label": "the torso and arms", "line": "the torso and arms drop onto the waist",
		"seat_sfx": "metal_clank", "lock_sfx": "metal_clank"},
	"ArmorHead": {"socket": Vector3(0.0, 1.52, 0.0), "yaw": 0.0,
		"label": "the head", "line": "the head closes the figure",
		"seat_sfx": "latch", "lock_sfx": "metal_tink"},
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
var _bolting: bool = false           ## the seal cascade is running
var _engaged: bool = false           ## the guide only exists once the job begins
var _beacon: Node3D = null           ## the shared beacon that marks the next step
var _arrows: Dictionary = {}         ## part name -> that spare's own floating arrow
var _sealed_ms: int = 0
var _last_wrong: Node = null         ## the wrong-order part already announced

## Where each assembly waits, for the tracker's next-step line. All three live
## together on the build pallet at the front of the garage (plan P).
const LOCATIONS: Dictionary = {
	"ArmorLegs": "on the build pallet, just inside the entrance",
	"ArmorTorso": "on the build pallet, just inside the entrance",
	"ArmorHead": "on the build pallet, just inside the entrance",
}

## The same place, short enough for the HUD rows.
const LOC_SHORT: Dictionary = {
	"ArmorLegs": "the build pallet at the front",
	"ArmorTorso": "the build pallet at the front",
	"ArmorHead": "the build pallet at the front",
}


func bind(p_runtime: Node, p_carry: Node, dressing: Node3D, p_player: Node = null) -> void:
	runtime = p_runtime
	carry = p_carry
	_player = p_player
	figure = dressing.get_node_or_null("ArmorBase") as Node3D
	if figure == null:
		push_warning("ArmorAssembly: no ArmorBase in the dressing")
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
	_build_arrows()
	set_process(true)


func _build_beacon() -> void:
	## The guide beacon: the shared full mark (a big floating arrow raised on a
	## column of light) that says what to carry and where to bring it. Hidden
	## until the job is engaged, so the morning room stays clean.
	_beacon = (load("res://scripts/garage/guide_beacon.gd") as GDScript).new()
	_beacon.name = "ArmorGuideBeacon"
	add_child(_beacon)
	_beacon.call("setup", true)
	_beacon.visible = false


func _build_arrows() -> void:
	## Every waiting spare gets its own big floating arrow, so the whole set
	## reads at a glance — the beacon then walks ahead over whichever is next.
	var script: GDScript = load("res://scripts/garage/guide_beacon.gd")
	for part_name: String in _parts:
		var arrow: Node3D = script.new()
		arrow.name = "GuideArrow_" + part_name
		add_child(arrow)
		arrow.call("setup", false)
		arrow.visible = false
		_arrows[part_name] = arrow


func engage() -> void:
	## The job begins: the beacon and the tracker come alive.
	_engaged = true


func _process(_delta: float) -> void:
	if _beacon == null or figure == null:
		return
	var held: Node3D = carry.held() if carry != null else null
	if held != _last_wrong:
		_last_wrong = null
	if not _engaged and held != null and _is_part(held):
		_engaged = true
	if not _engaged and _player != null:
		# walking up to the figure is enough: no looking, no clicking to wake it
		if _player.global_position.distance_to(figure.global_position) < 4.5:
			_engaged = true
		else:
			# the parts tray at the entrance wakes it too — the arrows are up
			# the moment anyone walks in past the spares
			for part_name: String in _parts:
				if _fitted.has(part_name):
					continue
				if _player.global_position.distance_to((_parts[part_name] as Node3D).global_position) < 3.5:
					_engaged = true
					break
	# ease: carrying a spare and walking it up is enough — it seats itself
	if not _busy and held != null and _is_part(held) and _player != null:
		if not _fitted.has(_name_of(held)) and _player.global_position.distance_to(figure.global_position) < 2.4:
			figure_action(null)
	var show: bool = _engaged and _locked.size() < PARTS.size()
	var target: Vector3 = Vector3.ZERO
	var beacon_part: String = ""
	if show:
		var carry_target: bool = held != null and _is_part(held) and not _fitted.has(_name_of(held))
		if carry_target:
			# carrying the right part: mark where it goes
			target = figure.global_position + Vector3.UP * 1.9
		else:
			beacon_part = guide_part()
			target = _marker_pos(beacon_part) if beacon_part != "" else figure.global_position + Vector3.UP * 1.9
	_beacon.visible = show
	if show:
		_beacon.call("place", target)
	_update_arrows(show, beacon_part, held)


func _marker_pos(part_name: String) -> Vector3:
	var node: Node3D = _parts[part_name]
	return node.global_position + Vector3.UP * (ShapeKit.node_bounds(node).size.y + 0.25)


func _update_arrows(show: bool, beacon_part: String, held: Node3D) -> void:
	## Every waiting spare carries its own big floating arrow, so the whole set
	## reads at a glance. The one the beacon already stands over is skipped (no
	## double mark), and a part in hand keeps its home spot unmarked.
	for part_name: String in _arrows:
		var arrow: Node3D = _arrows[part_name]
		var vis: bool = show and not _fitted.has(part_name) and part_name != beacon_part \
			and (held == null or held != _parts.get(part_name, null))
		arrow.visible = vis
		if vis:
			arrow.call("place", _marker_pos(part_name))


func arrow_visible(part_name: String) -> bool:
	return _arrows.has(part_name) and bool((_arrows[part_name] as Node3D).visible)


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
	## The next assembly in build order — the figure goes up low to high, so the
	## beacon always names legs, then torso, then head. The order is enforced, so
	## "nearest" would only lie.
	for part_name: String in PARTS:
		if not _fitted.has(part_name):
			return part_name
	return ""


func stage_line() -> String:
	## The tracker's step banner: three assemblies, low to high.
	if _locked.size() >= PARTS.size():
		return "COMPLETE · THE WHOLE FIGURE, SEALED AND STANDING"
	if _fitted.size() >= PARTS.size():
		return "STEP 3 OF 3 · THE WHOLE FIGURE POWERS UP"
	var n: int = _fitted.size()
	var line: String = ["THE LEGS GO ON FIRST", "THE TORSO ON TOP", "THE HEAD COMPLETES THE FIGURE"][n]
	return "STEP %d OF 3 · %s" % [n + 1, line]


func part_detail(part_name: String) -> String:
	## The third column of the tracker row: where it waits, or how far it is.
	var st: int = part_state(part_name)
	if st == 2:
		return "bolted down"
	if st == 1:
		return "seated"
	var node: Node3D = _parts.get(part_name, null) as Node3D
	var home: Dictionary = _homes.get(part_name, {})
	if node != null and not home.is_empty():
		if node.global_position.distance_to(home["position"] as Vector3) > 1.2:
			return "moved off the pallet"
	return String(LOC_SHORT.get(part_name, ""))


func next_line() -> String:
	## The one instruction for right now: an exact verb, the thing, the place
	## and a live distance, so anyone can follow it without knowing the room.
	var held: Node3D = carry.held() if carry != null else null
	if held != null and _is_part(held):
		if _fitted.has(_name_of(held)):
			return "that assembly is already on — put it down (right-click) and take the next one"
		if PARTS.keys().find(_name_of(held)) != _fitted.size():
			return "not that one yet — the figure builds low to high: legs, then torso, then head"
		return "NEXT — carry it to the base — the shop's armour on the NORTH WALL — and walk it up%s" % _dist_tail(figure.global_position)
	if _locked.size() >= PARTS.size():
		return "DONE — press E at the base to strip the figure back to the pallet · R resets the morning"
	if _fitted.size() >= PARTS.size():
		return "the bolts are sealing the whole figure — let it finish"
	if not _pending_locks().is_empty():
		return "seat the remaining assemblies — the bolts finish the fit after the head"
	var np: String = guide_part()
	if np != "":
		return "NEXT — left-click %s off the build pallet · just inside the entrance%s" % [
			String(PARTS[np]["label"]), _dist_tail(_parts[np].global_position)]
	return ""


func _dist_tail(pos: Vector3) -> String:
	if _player == null:
		return ""
	var d: int = int(round(_player.global_position.distance_to(pos)))
	# under a metre the player is there — the number would only be noise
	return "" if d <= 1 else " · %d m" % d


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
		EventBus.notification_requested.emit("the figure is built here — three assemblies, low to high: walk one up and it seats itself; the head completes it", "info")
	var held: Node3D = carry.held()
	if held != null:
		for part_name: String in PARTS:
			if _parts.get(part_name) == held:
				if _fitted.has(part_name):
					return "Press E — that assembly is already on the figure"
				if PARTS.keys().find(part_name) != _fitted.size():
					return "Press E — wrong order: the legs go first, then the torso, then the head"
				return "Press E to seat %s — or just walk it up" % String(PARTS[part_name]["label"])
		return "Press E — that isn't one of the figure's assemblies"
	var pending: Array = _pending_locks()
	if not pending.is_empty():
		return "Press E to seal the fit"
	if not _fitted.is_empty():
		return "Press E to strip the figure back to the pallet"
	return "Press E to inspect"


func figure_action(_player: Node) -> bool:
	## Returns true when the press concerned the build; false hands the press
	## back to the station's normal inspect behaviour.
	if figure == null or _parts.is_empty():
		return false
	_engaged = true
	var held: Node3D = carry.held()
	if held != null:
		for part_name: String in PARTS:
			if _parts.get(part_name) == held:
				if _fitted.has(part_name):
					if _locked.has(part_name):
						EventBus.notification_requested.emit("the figure is already sealed — press E at the base with empty hands to strip it, or R to reset the morning", "error")
					else:
						EventBus.notification_requested.emit("that assembly is already seated — take the next one up (the arrows mark them)", "error")
					AudioBank.play("ui_error", -6.0)
					return true
				if PARTS.keys().find(part_name) != _fitted.size():
					_announce_order(held)
					return true
				_seat(part_name)
				return true
		EventBus.notification_requested.emit("wrong part — the figure takes only its three assemblies: legs, then torso, then head — from the build pallet at the front", "error")
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


func _announce_order(held: Node) -> void:
	## The wrong build order answers in red once per part in hand, so the
	## automatic seat-by-walk does not repeat the message every frame.
	if _last_wrong == held:
		return
	_last_wrong = held
	AudioBank.play("ui_error", -4.0)
	EventBus.notification_requested.emit("wrong order — the figure builds low to high: the legs first, then the torso, then the head", "error")


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
		EventBus.notification_requested.emit("%s — the figure is whole. The core is catching — stand back, the bolts seal it from here" % String(info["line"]), "success")
		var catch_tw: Tween = create_tween()
		catch_tw.tween_interval(0.4)
		catch_tw.tween_callback(_power_on_moment)
		# and it finishes itself: the seal walks the locks down after the beat,
		# so the whole assembly is carry → walk up → (auto seat) ×4, done
		var seal_tw: Tween = create_tween()
		seal_tw.tween_interval(2.6)
		seal_tw.tween_callback(_auto_bolt)
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
	_bolting = true
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
	_bolting = false
	if _locked.size() >= PARTS.size():
		_seal()
	else:
		EventBus.notification_requested.emit("%d of %d bolted — take the remaining assemblies up (their arrows mark them), then the bolts finish the fit" % [_locked.size(), PARTS.size()], "warning")


func _auto_bolt() -> void:
	## The automatic finish: after the fourth seat's power-on beat the locks
	## walk themselves down. A manual press during the beat does it early.
	if _bolting:
		return
	var pending: Array = _pending_locks()
	if pending.is_empty():
		return
	_bolt_all(pending)


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
	# the job is out of the player's hands now: the guide sleeps and wakes
	# again by approach, by picking a spare up, or at the figure itself
	_engaged = false
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
		runtime.sys_log("THE FIGURE POWER-ON — HEAD SEAT")
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
	EventBus.notification_requested.emit("THE FIGURE — COMPLETE — legs, torso and head, sealed and standing", "success")
	if runtime != null:
		runtime.sys_log("THE FIGURE COMPLETE — SEALED")
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
			fig_st.description = "The whole figure stands here, built from its three assemblies: legs and boots on the base, torso and arms above, the head on top. The core lens and the eye slits are burning brighter, the base ring stands at full — the build checks out."
			fig_st.spec_rows = [["spares bolted", "4 of 4"], ["palette", "red over gold over alloy"], ["state", "fit checked, standing test"]]
		elif _fitted.is_empty():
			fig_st.display_name = String(o["title"])
			fig_st.description = String(o["desc"])
			fig_st.spec_rows = (o["spec"] as Array).duplicate()
		else:
			fig_st.display_name = "The shop's armour — %d of 3 on" % _fitted.size()
			fig_st.description = "The figure is going up low to high: %d of 3 assemblies on, %d bolted. The bolts seal the fit when the head sits." % [_fitted.size(), _locked.size()]
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
