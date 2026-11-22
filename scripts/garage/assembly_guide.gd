extends Node
## The prototype suit's assembly guide — the second half of the guide system the
## armour figure began. Nothing is drawn here: the HUD reads the strings and the
## shared beacon is the one world-space mark.
##
## State comes from GameState (modules recovered, install stage, diagnostics)
## and the live runtime (power); the crate, stand and console positions come
## from the runtime's own station registry, so the guide follows the dressing
## instead of a copied map of it.
##
## Visibility: from the moment the shop is powered — the morning belongs to the
## objective panel — until the final check is done, plus a short linger so the
## completion is read. The capture harness suppresses it for clean frames, and
## the beacon yields whenever the armour figure's own beacon is up (that one
## marks the job actually being worked).

const AS_STAGE := GameStateSingleton.AssemblyStage

## The three modules, in install order (index == assembly stage while installing).
## loc = where the crate waits, shown on the HUD rows and in the next-step line.
const MODULES: Array = [
	{"id": "frame_module", "name": "frame module", "loc": "mechanical bench, south end"},
	{"id": "energy_module", "name": "energy module", "loc": "battery rack, east wall"},
	{"id": "armour_shell", "name": "shell module", "loc": "floor by the stage"},
]

var runtime: Node
var _player: Node = null
var _beacon: Node3D = null
var _crate_arrows: Array = []
var _done_ms: int = 0
var _suppressed: bool = false
var _crate_kinds: Array = []


func bind(p_runtime: Node, p_player: Node = null) -> void:
	runtime = p_runtime
	_player = p_player
	_crate_kinds = [
		Station.Kind.MODULE_FRAME,
		Station.Kind.MODULE_ENERGY,
		Station.Kind.MODULE_SHELL,
	]
	var script: GDScript = load("res://scripts/garage/guide_beacon.gd")
	_beacon = script.new()
	_beacon.name = "SuitGuideBeacon"
	add_child(_beacon)
	_beacon.call("setup", true)
	_beacon.visible = false
	for i: int in range(3):
		var arrow: Node3D = script.new()
		arrow.name = "CrateArrow_%d" % i
		add_child(arrow)
		arrow.call("setup", false)
		arrow.visible = false
		_crate_arrows.append(arrow)
	set_process(true)


func suppress() -> void:
	## The capture harness: the finished-garage frames stay clean of guides.
	_suppressed = true
	if _beacon != null:
		_beacon.visible = false


# ===========================================================================
# the strings the HUD and the probe read
# ===========================================================================

func tracker_visible() -> bool:
	## From power-on until the final check, plus a linger past completion.
	if runtime == null or not bool(runtime.power_on) or _suppressed:
		return false
	if not _done():
		return true
	return Time.get_ticks_msec() - _done_ms < 12000


func is_complete() -> bool:
	return _done()


func stage_line() -> String:
	if runtime == null or not bool(runtime.power_on):
		return "STEP 0 OF 3 · POWER THE SHOP — E AT THE SWITCHBOARD"
	if _collected() < MODULES.size():
		return "STEP 1 OF 3 · RECOVER THE THREE MODULES"
	var stage: int = int(GameState.assembly_stage)
	if stage < AS_STAGE.SHELL:
		return "STEP 2 OF 3 · INSTALL THE MODULES AT THE STAGE"
	if stage == AS_STAGE.SHELL:
		return "STEP 2 OF 3 · READY TO ASSEMBLE"
	if stage == AS_STAGE.ASSEMBLING:
		return "STEP 2 OF 3 · THE ARMS ARE FITTING THE SUIT"
	if not _done():
		return "STEP 3 OF 3 · RUN THE FINAL CHECK"
	return "COMPLETE · CERTIFIED END TO END"


func module_state(i: int) -> int:
	## 0 at its crate · 1 recovered · 2 installed — the HUD's row marks.
	var id: String = String(MODULES[i]["id"])
	if GameState.component_installed(id):
		return 2
	if GameState.has_component(id):
		return 1
	return 0


func module_detail(i: int) -> String:
	match module_state(i):
		2:
			return "installed"
		1:
			return "recovered — at the stage"
	return String(MODULES[i]["loc"])


func next_line() -> String:
	## The one instruction for right now: an exact verb, the thing, the place
	## and a live distance, so anyone can follow it without knowing the room.
	if _collected() < MODULES.size():
		var i: int = _nearest_uncollected()
		return "NEXT — recover the %s: press E on its crate · %s%s" % [
			String(MODULES[i]["name"]), String(MODULES[i]["loc"]),
			_dist_tail(int(_crate_kinds[i]), 0.45)]
	var stage: int = int(GameState.assembly_stage)
	if stage < AS_STAGE.SHELL:
		return "NEXT — install the %s at the stage: press E on the stand%s" % [
			String(MODULES[stage]["name"]), _dist_tail(Station.Kind.ASSEMBLY, 1.5)]
	if stage == AS_STAGE.SHELL:
		return "NEXT — press START ASSEMBLY SEQUENCE — the button is in the stand's panel"
	if stage == AS_STAGE.ASSEMBLING:
		return "the arms are fitting the modules — let the sequence run"
	if not _done():
		return "NEXT — run the final check: press E at the diagnostic console · testing corner%s" % _dist_tail(Station.Kind.DIAGNOSTICS, 0.8)
	return "DONE — certified end to end · R resets the morning for a second run"


func beacon_visible() -> bool:
	return _beacon != null and _beacon.visible


# ===========================================================================
# the beacon, and the state helpers behind the strings
# ===========================================================================

func _process(_delta: float) -> void:
	if _beacon == null:
		return
	var target: Variant = _beacon_target()
	var armour_up: bool = runtime != null and runtime.armor != null and bool(runtime.armor.beacon_visible())
	var show: bool = target != null and tracker_visible() and not armour_up
	_beacon.visible = show
	if show:
		_beacon.call("place", target as Vector3)
	# every un-recovered crate carries its own big floating arrow while the
	# suit's marks are live; the beacon's crate is skipped (no double mark),
	# and the armour figure's job takes priority when it is being worked
	var beacon_crate: int = _nearest_uncollected() if _collected() < MODULES.size() else -1
	for i: int in range(_crate_arrows.size()):
		var arrow: Node3D = _crate_arrows[i]
		var vis: bool = show and not GameState.has_component(String(MODULES[i]["id"])) and i != beacon_crate
		if vis:
			var pos: Variant = _station_pos(int(_crate_kinds[i]), 0.45)
			vis = pos != null
			if vis:
				arrow.call("place", pos as Vector3)
		arrow.visible = vis


func crate_arrow_visible(i: int) -> bool:
	return i < _crate_arrows.size() and bool((_crate_arrows[i] as Node3D).visible)


func _beacon_target() -> Variant:
	## Where the beam stands right now — the next crate, the stand, the console
	## — or null when nothing is being asked (sequence running, job done).
	if runtime == null or not bool(runtime.power_on) or _suppressed:
		return null
	if _collected() < MODULES.size():
		var i: int = _nearest_uncollected()
		return _station_pos(int(_crate_kinds[i]), 0.45)
	var stage: int = int(GameState.assembly_stage)
	if stage <= AS_STAGE.SHELL:
		return _station_pos(Station.Kind.ASSEMBLY, 1.5)
	if stage == AS_STAGE.ACTIVE and not _done():
		return _station_pos(Station.Kind.DIAGNOSTICS, 0.8)
	return null


func _nearest_uncollected() -> int:
	## Whatever crate is easiest to reach next, so anyone can start with the
	## module they happen to be standing by.
	var best: int = 0
	var best_d: float = -1.0
	for i: int in range(MODULES.size()):
		if GameState.has_component(String(MODULES[i]["id"])):
			continue
		var st: Node = runtime.station(int(_crate_kinds[i])) if runtime != null else null
		var d: float = 0.0
		if st is Node3D and _player != null:
			d = _player.global_position.distance_to((st as Node3D).global_position)
		if best_d < 0.0 or d < best_d:
			best = i
			best_d = d
	return best


func _station_pos(kind: int, lift: float) -> Variant:
	var st: Node = runtime.station(kind) if runtime != null else null
	if st is Node3D:
		return (st as Node3D).global_position + Vector3.UP * lift
	return null


func _dist_tail(kind: int, lift: float) -> String:
	var pos: Variant = _station_pos(kind, lift)
	if pos == null or _player == null:
		return ""
	var d: int = int(round(_player.global_position.distance_to(pos as Vector3)))
	# under a metre the player is there — the number would only be noise
	return "" if d <= 1 else " · %d m" % d


func _collected() -> int:
	var n: int = 0
	for m: Dictionary in MODULES:
		if GameState.has_component(String(m["id"])):
			n += 1
	return n


func _done() -> bool:
	## True once the final check has run; latches the moment for the linger.
	var done: bool = bool(GameState.diagnostics_run)
	if done and _done_ms == 0:
		_done_ms = Time.get_ticks_msec()
	return done
