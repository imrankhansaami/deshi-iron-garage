class_name Station
extends Interactable
## The thin input surface for every interactive object in the garage.
##
## A Station knows *what it is* (kind), *what to say* (prompt, description, spec
## rows) and *who to ask* (the runtime). It holds no state of its own beyond the
## hover flag inherited from Interactable. That split is deliberate: the eleven
## lights, two fans and four monitors that respond to one switch are the
## runtime's problem, not this script's, so adding a new interactive object never
## requires understanding the power system.
##
## Kinds are grouped by the area they belong to. Anything not listed falls through
## to a generic "inspect" behaviour, so an unconfigured prop is still readable
## rather than silently dead.

enum Kind {
	NONE,
	SHUTTER,
	SWITCHBOARD,
	MCB,
	COMPUTER,
	CRT,
	LCD,
	HOLO_TABLE,
	CORE,
	ASSEMBLY,
	DIAGNOSTICS,
	SUIT_DISPLAY,
	NOTEBOOK,
	TOOLBOX,
	FAN_CEILING,
	FAN_PEDESTAL,
	FAN_TABLE,
	LAMP_BENCH,
	LAMP_DESK,
	TUBE_LIGHT,
	BULB,
	SOCKET,
	WALL_SWITCH,
	MODULE_FRAME,
	MODULE_ENERGY,
	MODULE_SHELL,
	TOOL,
	PART,
	ELECTRONIC,
	EVERYDAY,
	SIGN,
	CALENDAR,
	CLOCK,
	POSTER,
	TEA,
	SCRAP,
	MIRROR,
	RADIO,
	OSCILLOSCOPE,
	VARIAC,
	STABILIZER,
	BATTERY,
	WELDING,
}

@export var kind: Kind = Kind.NONE
@export var runtime: GarageRuntime
@export var fan_key: String = ""
@export var circuit: int = 0
@export var module_id: String = ""
@export var panel: StringName = &""

var state_on: bool = false


func _ready() -> void:
	super._ready()
	if id == "":
		id = "%s_%s" % [Kind.keys()[int(kind)].to_snake_case(), sanitize_node_name(name).to_snake_case()]
	if display_name == "":
		display_name = _default_title()
	if prompt == "Press E to interact":
		prompt = _default_prompt()


func _default_title() -> String:
	match kind:
		Kind.SHUTTER: return "Rolling shutter"
		Kind.SWITCHBOARD: return "Main switchboard"
		Kind.MCB: return "MCB bank"
		Kind.COMPUTER: return "Workstation"
		Kind.CRT: return "Salvaged CRT"
		Kind.LCD: return "Second-hand LCD"
		Kind.HOLO_TABLE: return "Holographic design table"
		Kind.CORE: return "Energy core"
		Kind.ASSEMBLY: return "Assembly station"
		Kind.DIAGNOSTICS: return "Diagnostic console"
		Kind.SUIT_DISPLAY: return "Exosuit MK-I"
		Kind.NOTEBOOK: return "Engineering notebook"
		Kind.TOOLBOX: return "Toolbox"
		Kind.FAN_CEILING: return "Ceiling fan"
		Kind.FAN_PEDESTAL: return "Pedestal fan"
		Kind.FAN_TABLE: return "Table fan"
		Kind.LAMP_BENCH: return "Workbench lamp"
		Kind.LAMP_DESK: return "Desk lamp"
		Kind.TUBE_LIGHT: return "Tube light"
		Kind.BULB: return "Hanging bulb"
		Kind.SOCKET: return "Wall socket"
		Kind.WALL_SWITCH: return "Light switch"
		Kind.MODULE_FRAME: return "Structural frame module"
		Kind.MODULE_ENERGY: return "Energy module"
		Kind.MODULE_SHELL: return "Armour shell module"
		Kind.CALENDAR: return "Wall calendar"
		Kind.CLOCK: return "Wall clock"
		Kind.SIGN: return "Signboard"
		Kind.BATTERY: return "IPS battery"
		Kind.OSCILLOSCOPE: return "Bench oscilloscope"
		Kind.VARIAC: return "Variac"
		Kind.STABILIZER: return "Voltage stabilizer"
		Kind.RADIO: return "Transistor radio"
		Kind.MIRROR: return "Wall mirror"
		Kind.WELDING: return "Welding station"
		_: return sanitize_node_name(name)


func _default_prompt() -> String:
	match kind:
		Kind.SHUTTER: return "Press E to check the shutter"
		Kind.SWITCHBOARD: return "Press E to work the main switch"
		Kind.MCB: return "Press E to isolate this circuit"
		Kind.COMPUTER: return "Press E to start the workstation"
		Kind.CRT: return "Press E to power the tube"
		Kind.LCD: return "Press E to wake the panel"
		Kind.HOLO_TABLE: return "Press E to raise the schematic"
		Kind.CORE: return "Press E to pulse the core"
		Kind.ASSEMBLY: return "Press E to open the assembly interface"
		Kind.DIAGNOSTICS: return "Press E to run diagnostics"
		Kind.SUIT_DISPLAY: return "Press E to wake the prototype"
		Kind.NOTEBOOK: return "Press E to read the notebook"
		Kind.TOOLBOX: return "Press E to open the toolbox"
		Kind.FAN_CEILING, Kind.FAN_PEDESTAL, Kind.FAN_TABLE:
			return "Press E to start the fan"
		Kind.LAMP_BENCH, Kind.LAMP_DESK, Kind.TUBE_LIGHT, Kind.BULB:
			return "Press E to switch the light"
		Kind.SOCKET, Kind.WALL_SWITCH: return "Press E to flip the switch"
		Kind.MODULE_FRAME, Kind.MODULE_ENERGY, Kind.MODULE_SHELL:
			return "Press E to recover the module"
		_: return "Press E to inspect"


# ===========================================================================
# E
# ===========================================================================

func _primary(player: Node) -> void:
	if runtime == null:
		return
	match kind:
		Kind.SHUTTER:
			# The garage runs open. This action can no longer lower the curtain —
			# it only guarantees it is up, because the workshop is meant to be
			# walked into (see GarageWorld build step 6b). The daylight shafts and
			# the volumetric fog read the same state, so they stay at full.
			if not GameState.shutter_open:
				GameState.shutter_open = true
				runtime.animate_shutter(true)
				EventBus.shutter_state_changed.emit(true)
				runtime.sys_log("SHUTTER OPEN")
			else:
				EventBus.notification_requested.emit("the curtain is chained up — the garage runs open", "info")
			AudioBank.play("latch", -8.0)
		Kind.SWITCHBOARD:
			runtime.set_power(not runtime.power_on)
			state_on = runtime.power_on
		Kind.MCB:
			runtime.toggle_circuit(circuit)
		Kind.COMPUTER:
			if runtime.power_on:
				runtime.boot_computer()
			else:
				_no_power()
		Kind.CRT, Kind.LCD:
			if not runtime.power_on:
				_no_power()
			else:
				EventBus.ui_panel_opened.emit("monitor")
		Kind.HOLO_TABLE:
			if not runtime.power_on:
				_no_power()
			else:
				var on: bool = not state_on
				state_on = on
				runtime.set_hologram_visible(on)
				if on:
					EventBus.ui_panel_opened.emit("schematic")
		Kind.CORE:
			if not runtime.power_on:
				_no_power()
			else:
				runtime.set_core_active(not runtime.core_active)
		Kind.ASSEMBLY:
			if not runtime.power_on:
				_no_power()
			else:
				EventBus.ui_panel_opened.emit("assembly")
		Kind.DIAGNOSTICS:
			if GameState.assembly_stage == GameState.AssemblyStage.ACTIVE:
				EventBus.ui_panel_opened.emit("diagnostics")
			else:
				EventBus.notification_requested.emit("nothing to diagnose yet", "warning")
		Kind.SUIT_DISPLAY:
			if GameState.assembly_stage == GameState.AssemblyStage.ACTIVE:
				runtime.run_diagnostics()
			else:
				EventBus.notification_requested.emit("prototype incomplete", "warning")
		Kind.NOTEBOOK:
			GameState.notebook_read = true
			EventBus.ui_panel_opened.emit("notebook")
		Kind.TOOLBOX:
			EventBus.ui_panel_opened.emit("toolbox")
		Kind.FAN_CEILING:
			runtime.set_fan_on(fan_key, not state_on)
			state_on = not state_on
		Kind.FAN_PEDESTAL, Kind.FAN_TABLE:
			if not runtime.power_on:
				_no_power()
				return
			runtime.set_fan_on(fan_key, not state_on)
			state_on = not state_on
		Kind.LAMP_BENCH, Kind.LAMP_DESK:
			runtime.toggle_circuit(2)
			state_on = bool(runtime.circuits_on.get(2, false))
		Kind.TUBE_LIGHT:
			runtime.toggle_circuit(1)
			state_on = bool(runtime.circuits_on.get(1, false))
		Kind.BULB:
			runtime.toggle_circuit(3)
			state_on = bool(runtime.circuits_on.get(3, false))
		Kind.SOCKET, Kind.WALL_SWITCH:
			runtime.toggle_circuit(1 if circuit == 0 else circuit)
		Kind.MODULE_FRAME:
			_collect("frame_module")
		Kind.MODULE_ENERGY:
			_collect("energy_module")
		Kind.MODULE_SHELL:
			_collect("armour_shell")
		Kind.CLOCK:
			state_on = not state_on
		_:
			# every other prop is readable, which is what makes the garage feel
			# dense: the player can inspect almost anything and get a real answer
			if inspectable:
				var payload: Dictionary = inspect(player)
				if not payload.is_empty():
					EventBus.ui_panel_opened.emit("inspect")


func _no_power() -> void:
	AudioBank.play("ui_error", -2.0)
	EventBus.notification_requested.emit("no power — the switchboard is locked out", "warning")


func _collect(component_id: String) -> void:
	if GameState.has_component(component_id):
		EventBus.notification_requested.emit("%s already recovered" % GameConfig.component_label(component_id), "info")
		return
	if GameState.collect_component(component_id):
		mark_used()
		visible = false
		AudioBank.play_at("metal_thunk", global_position, -4.0)
		runtime.sys_log("MODULE RECOVERED: %s" % GameConfig.component_short(component_id).to_upper())


# ===========================================================================
# F
# ===========================================================================

func _inspect(player: Node) -> void:
	super._inspect(player)
	if runtime != null:
		runtime.sys_log("INSPECT %s" % display_name.to_upper())


func describe() -> Dictionary:
	return {
		"id": id,
		"title": display_name,
		"body": description,
		"lore": lore,
		"spec": spec_rows,
		"kind": Kind.keys()[int(kind)],
		"area": String(area),
	}


## Driven once per frame by the runtime. Only the wall clock uses it: it reads the
## system time, so the prop is genuinely correct rather than frozen at a
## screenshot-friendly hour.
func tick(_delta: float) -> void:
	if kind != Kind.CLOCK:
		return
	var host: Node = get_parent()
	if host == null:
		return
	var t: Dictionary = Time.get_datetime_dict_from_system()
	var seconds: float = float(int(t.get("second", 0)))
	var minutes: float = float(int(t.get("minute", 0))) + seconds / 60.0
	var hours: float = float(int(t.get("hour", 0)) % 12) + minutes / 60.0
	_set_hand(host, "SecondHand", seconds * 6.0)
	_set_hand(host, "MinuteHand", minutes * 6.0)
	_set_hand(host, "HourHand", hours * 30.0)


static func _set_hand(host: Node, child_name: String, degrees: float) -> void:
	var n: Node = host.get_node_or_null(child_name)
	if n is Node3D:
		(n as Node3D).rotation.z = -degrees * PI / 180.0


static func sanitize_node_name(raw: String) -> String:
	return raw.replace("_", " ").strip_edges()
