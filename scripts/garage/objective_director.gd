class_name ObjectiveDirector
extends Node
## Drives the 12-step progression from Section 5 and the HUD objective line.
##
## The chain is data (data/objectives.json); this node only evaluates triggers
## against GameState and emits the current text. Keeping the sequence in JSON is
## what lets the demonstration be re-ordered or a location re-themed without
## recompiling, and it means the thesis can point at one file to show the flow.
##
## Advancement is event-driven, never polled: each objective declares a trigger
## token and the director listens to the bus signals that produce it. A skipped
## objective (because the player did things out of order) is tolerated — the
## director re-evaluates the whole chain on every event and settles on the first
## unsatisfied one, so the guidance is always truthful about what is left.

const TRIGGER_MAP: Dictionary = {
	"shutter": "shutter",
	"power": "power",
	"computer": "computer",
	"notebook": "notebook",
	"hologram": "hologram",
	"assembly": "assembly",
	"core": "core",
	"diagnostics": "diagnostics",
	"none": "none",
}

var current_id: String = ""
var completed: Dictionary = {}
var hints_shown: Dictionary = {}
var _runtime: GarageRuntime
var _hint_timer: float = 0.0
var _stuck_since: float = 0.0


func _ready() -> void:
	set_process(true)
	EventBus.shutter_state_changed.connect(func(_o: bool) -> void: _evaluate("shutter"))
	EventBus.power_state_changed.connect(func(_o: bool) -> void: _evaluate("power"))
	EventBus.computer_state_changed.connect(func(_o: bool) -> void: _evaluate("computer"))
	EventBus.component_collected.connect(func(_c: String) -> void: _evaluate("component"))
	EventBus.assembly_stage_changed.connect(func(_s: int, _n: String) -> void: _evaluate("assembly"))
	EventBus.prototype_activated.connect(func() -> void: _evaluate("core"))


func bind(runtime: GarageRuntime) -> void:
	_runtime = runtime
	EventBus.interaction_performed.connect(_on_interaction)


func start() -> void:
	current_id = ""
	_evaluate("start")
	if not GameState.has_started:
		GameState.has_started = true


func _on_interaction(target: Node3D, action: String) -> void:
	if target is Station:
		var s: Station = target as Station
		match s.kind:
			Station.Kind.NOTEBOOK:
				_evaluate("notebook")
			Station.Kind.HOLO_TABLE:
				_evaluate("hologram")
			Station.Kind.ASSEMBLY:
				_evaluate("assembly")
			Station.Kind.CORE:
				_evaluate("core")
			Station.Kind.DIAGNOSTICS, Station.Kind.SUIT_DISPLAY:
				_evaluate("diagnostics")
			_:
				pass
	# reading the notebook or using the table are one-shot discoveries
	if action == "inspect":
		_evaluate("inspect")


func satisfied(token: String) -> bool:
	match token:
		"shutter":
			return GameState.shutter_open
		"power":
			return GameState.power_on
		"computer":
			return GameState.computer_on
		"notebook":
			return GameState.notebook_read
		"hologram":
			return GameState.hologram_used
		"assembly":
			return GameState.assembly_stage >= GameState.AssemblyStage.SHELL
		"core":
			return GameState.assembly_stage == GameState.AssemblyStage.ACTIVE
		"diagnostics":
			return GameState.diagnostics_run
		"component:frame_module":
			return GameState.has_component("frame_module")
		"component:energy_module":
			return GameState.has_component("energy_module")
		"component:armour_shell":
			return GameState.has_component("armour_shell")
		"":
			return true
		_:
			return false


func _evaluate(_cause: String) -> void:
	var chain: Array = GameConfig.objectives
	var next_id: String = ""
	for entry: Variant in chain:
		var obj: Dictionary = entry
		var id: String = String(obj.get("id", ""))
		var trigger: String = String(obj.get("trigger", ""))
		if id == "free_explore":
			next_id = id
			break
		if satisfied(trigger):
			completed[id] = true
			continue
		next_id = id
		break
	if next_id == current_id:
		return
	current_id = next_id
	var text: String = GameConfig.objective_text(current_id)
	if text != "":
		EventBus.objective_changed.emit(current_id, text)
		_stuck_since = 0.0
		hints_shown[current_id] = false


func _process(delta: float) -> void:
	if current_id == "" or current_id == "free_explore":
		return
	_stuck_since += delta
	# after 35 seconds without progress, offer the hint once per objective
	if _stuck_since > 35.0 and not hints_shown.get(current_id, false):
		hints_shown[current_id] = true
		var hint: String = GameConfig.objective_hint(current_id)
		if hint != "":
			EventBus.notification_requested.emit(hint, "info")
	_stuck_since = minf(_stuck_since, 120.0)


func progress_label() -> String:
	var chain: Array = GameConfig.objectives
	var done: int = 0
	for entry: Variant in chain:
		var obj: Dictionary = entry
		var id: String = String(obj.get("id", ""))
		if id == "free_explore":
			break
		if completed.get(id, false):
			done += 1
	var total: int = 0
	for entry: Variant in chain:
		var obj: Dictionary = entry
		if String(obj.get("id", "")) == "free_explore":
			break
		total += 1
	return "%d / %d" % [done, maxi(total, 1)]
