extends Node
class_name ArmorAssembly
## The armour assembly (presentation plan A): the shop's spare plates are
## test-fitted onto the practice figure by hand. Carry a part to the figure and
## its station offers the matching socket; the part settles into place with a
## latch, the figure's own lights pulse, and when all four are seated the figure
## powers up. E with empty hands at the figure strips them all back to their
## places, so the sequence can be presented again and again.
##
## State lives here, not on the parts: each part keeps the transform it was
## authored with (its home), and fitting is a settle tween to a socket offset on
## the figure. The glow materials of the figure and the spares are duplicated at
## bind time, so the light ramps stay local to the armour and never touch other
## props that share the cached LED materials.
##
## Deliberately unbranded: the parts are the shop's own spare shells, and the
## stations say so. No combat, no weapons — a fitting exercise.

var runtime: Node
var carry: Node
var figure: Node3D

## name -> socket data. Sockets are in the figure's LOCAL space: the figure's
## yaw is applied to the seat rotation, so a rotated figure still fits right.
const PARTS: Dictionary = {
	"ArmorHelmet": {"socket": Vector3(0.0, 1.525, 0.0), "yaw": 0.0,
		"label": "spare helmet", "line": "helmet seated over the practice head"},
	"ArmorChestPlate": {"socket": Vector3(0.0, 1.10, 0.12), "yaw": 0.0,
		"label": "spare chest plate", "line": "chest plate slipped over the figure's front"},
	"ArmorGauntlet": {"socket": Vector3(0.36, 0.585, 0.03), "yaw": 0.0,
		"label": "spare gauntlet", "line": "gauntlet drawn over the right forearm"},
	"ArmorBoot": {"socket": Vector3(-0.11, 0.0, 0.02), "yaw": 0.0,
		"label": "spare boot", "line": "boot set on the left foot"},
}

var _parts: Dictionary = {}          ## name -> Node3D
var _homes: Dictionary = {}          ## name -> {position, rotation}
var _fitted: Dictionary = {}         ## name -> true
var _glow_mats: Array = []           ## duplicated StandardMaterial3D instances
var _orig: Dictionary = {}           ## station -> {title, desc, spec} originals
var _busy: bool = false


func bind(p_runtime: Node, p_carry: Node, dressing: Node3D) -> void:
	runtime = p_runtime
	carry = p_carry
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
	_snapshot_texts()


# ===========================================================================
# prompts and the E press
# ===========================================================================

func figure_prompt() -> String:
	var held: Node3D = carry.held()
	if held != null:
		for part_name: String in PARTS:
			if _parts.get(part_name) == held and not _fitted.has(part_name):
				return "Press E to test-fit the %s" % String(PARTS[part_name]["label"])
		return "Press E — that part doesn't socket here"
	if not _fitted.is_empty():
		return "Press E to strip the spares back to their places"
	return "Press E to inspect"


func figure_action(_player: Node) -> bool:
	## Returns true when the press concerned the fitting; false hands the press
	## back to the station's normal inspect behaviour.
	if figure == null or _parts.is_empty():
		return false
	var held: Node3D = carry.held()
	if held != null:
		for part_name: String in PARTS:
			if _parts.get(part_name) == held:
				if _fitted.has(part_name):
					EventBus.notification_requested.emit("%s is already seated" % String(PARTS[part_name]["label"]), "info")
					return true
				_fit(part_name)
				return true
		EventBus.notification_requested.emit("that part doesn't socket here — helmet, chest plate, gauntlet, boot", "warning")
		AudioBank.play("ui_error", -4.0)
		return true
	if not _fitted.is_empty():
		dismount_all(false)
		return true
	return false


func _fit(part_name: String) -> void:
	if _busy:
		return
	var node: Node3D = _parts[part_name]
	var info: Dictionary = PARTS[part_name]
	var to_pos: Vector3 = figure.to_global(info["socket"] as Vector3)
	var to_rot: Vector3 = Vector3(0.0, figure.rotation.y + float(info["yaw"]), 0.0)
	_busy = true
	if not bool(carry.settle_held(to_pos, to_rot, "servo")):
		_busy = false
		return
	_fitted[part_name] = true
	carry.set_item_enabled(node, false)
	AudioBank.play_at("latch", to_pos, -8.0)
	_pulse(1.7)
	_update_texts()
	var n: int = _fitted.size()
	EventBus.notification_requested.emit("%s — %d of 4 fitted" % [String(info["line"]), n], "success")
	if runtime != null:
		runtime.sys_log("ARMOUR FIT: %s (%d/4)" % [part_name.to_upper(), n])
	var tw: Tween = create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(func() -> void: _busy = false)
	if n >= PARTS.size():
		var tw2: Tween = create_tween()
		tw2.tween_interval(0.75)
		tw2.tween_callback(_powerup)


func dismount_all(instant: bool = false) -> void:
	## Strip every fitted spare back to its authored home. Instant is for the
	## demo reset; the animated form is what the figure's station offers.
	if _fitted.is_empty():
		if not instant:
			EventBus.notification_requested.emit("no spares are fitted", "info")
		return
	for part_name: String in _fitted.keys():
		var node: Node3D = _parts[part_name]
		var home: Dictionary = _homes[part_name]
		carry.set_item_enabled(node, true)
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
	for m: StandardMaterial3D in _glow_mats:
		if not is_instance_valid(m):
			continue
		var base: float = float(m.get_meta("base_energy", 2.0))
		if instant:
			m.emission_energy_multiplier = base
		else:
			var tw2: Tween = create_tween()
			tw2.tween_property(m, "emission_energy_multiplier", base, 0.5)
	_update_texts()
	if not instant:
		EventBus.notification_requested.emit("spares stripped back — the figure stands as it was", "info")
		if runtime != null:
			runtime.sys_log("ARMOUR DISMOUNTED")


func fit_all_instant() -> void:
	## Used by the capture harness so the finished-garage shots show the armour
	## complete, and by the demo reset's inverse if it ever needs one.
	for part_name: String in PARTS:
		var node: Node3D = _parts.get(part_name, null) as Node3D
		if node == null or _fitted.has(part_name):
			continue
		var info: Dictionary = PARTS[part_name]
		carry.set_item_enabled(node, false)
		node.global_position = figure.to_global(info["socket"] as Vector3)
		node.rotation = Vector3(0.0, figure.rotation.y + float(info["yaw"]), 0.0)
		_fitted[part_name] = true
	for m: StandardMaterial3D in _glow_mats:
		if is_instance_valid(m):
			m.emission_energy_multiplier = float(m.get_meta("base_energy", 2.0)) * 1.55
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


func _powerup() -> void:
	for m: StandardMaterial3D in _glow_mats:
		if not is_instance_valid(m):
			continue
		var base: float = float(m.get_meta("base_energy", 2.0))
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(m, "emission_energy_multiplier", base * 2.1, 0.5) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(m, "emission_energy_multiplier", base * 1.55, 0.9)
	AudioBank.play_at("core_charge", figure.global_position, -6.0)
	EventBus.notification_requested.emit("ARMOUR MK-I — COMPLETE — all four spares test-fitted", "success")
	if runtime != null:
		runtime.sys_log("ARMOUR MK-I COMPLETE")
	_update_texts()


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
		if _fitted.size() >= PARTS.size():
			fig_st.display_name = "The shop's armour — complete"
			fig_st.description = "All four spare shells are test-fitted onto the figure: helmet over the head, chest plate over the front, gauntlet on the right forearm, boot on the left foot. The core lens and the eye slits are burning brighter — the fit checks out."
			fig_st.spec_rows = [["spares fitted", "4 of 4"], ["palette", "red over gold over alloy"], ["state", "fit checked, standing test"]]
		elif _fitted.is_empty():
			fig_st.display_name = String(o["title"])
			fig_st.description = String(o["desc"])
			fig_st.spec_rows = (o["spec"] as Array).duplicate()
		else:
			fig_st.display_name = "The shop's armour — %d of 4 fitted" % _fitted.size()
			fig_st.description = "The spare shells are being test-fitted onto the figure. %d seated so far." % _fitted.size()
			fig_st.spec_rows = [["spares fitted", "%d of 4" % _fitted.size()], ["palette", "red over gold over alloy"], ["state", "fitting in progress"]]
	for part_name: String in _parts:
		var st: Node = _station_of(_parts[part_name])
		if st == null or not _orig.has(st):
			continue
		var o2: Dictionary = _orig[st]
		if _fitted.has(part_name):
			st.display_name = String(o2["title"]) + " — fitted"
			st.description = String(o2["desc"]) + " Right now it is seated on the figure."
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
