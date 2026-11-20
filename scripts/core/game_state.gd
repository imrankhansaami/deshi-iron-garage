extends Node
class_name GameStateSingleton
## Authoritative progression state for the garage experience.
## Pure data + rules: it holds no scene references so it can be saved,
## reset, and queried by any module (HUD, computer UI, assembly station).

const SAVE_PATH: String = "user://deshi_iron_garage.save"
const SAVE_VERSION: int = 3

## Prototype assembly stages, in the order the player drives them.
enum AssemblyStage {
	DORMANT = 0,        ## stand empty, only the skeleton cradle
	FRAME = 1,          ## structural frame module installed
	CORE = 2,           ## energy module installed
	SHELL = 3,          ## armour shell installed
	ASSEMBLING = 4,     ## robotic assembly animation running
	ACTIVE = 5,         ## prototype complete and powered
}

const ASSEMBLY_STAGE_NAMES: Array[String] = [
	"STAND EMPTY",
	"FRAME ONLINE",
	"CORE ONLINE",
	"SHELL ONLINE",
	"ASSEMBLING",
	"PROTOTYPE ACTIVE",
]

## The three fictional prototype modules the player has to salvage.
const COMPONENT_IDS: Array[String] = ["frame_module", "energy_module", "armour_shell"]

var has_started: bool = false
var tour_mode: bool = false
var shutter_open: bool = false
var power_on: bool = false
var computer_on: bool = false
var notebook_read: bool = false
var hologram_used: bool = false
var assembly_stage: AssemblyStage = AssemblyStage.DORMANT
var collected_components: Dictionary = {}          ## id -> true
var inspected_objects: Dictionary = {}             ## interaction id -> true
var diagnostics_run: bool = false
var visited_areas: Dictionary = {}                 ## area name -> true
var settings: Dictionary = {}
var elapsed_seconds: float = 0.0
var playthroughs_completed: int = 0

@warning_ignore("shadowed_variable")
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

func _process(delta: float) -> void:
	if has_started and not Engine.is_editor_hint():
		elapsed_seconds += delta

# --- progression rules -----------------------------------------------------

func collect_component(id: String) -> bool:
	## Returns true when the component was newly picked up.
	if collected_components.get(id, false):
		return false
	collected_components[id] = true
	EventBus.component_collected.emit(id)
	var missing: int = GameConfig.total_components() - collected_components.size()
	EventBus.notification_requested.emit(
		"%s acquired   ·   %d module%s remaining" % [
			GameConfig.component_label(id),
			missing,
			"" if missing == 1 else "s",
		],
		"success",
	)
	return true

func has_component(id: String) -> bool:
	return collected_components.get(id, false) == true

func all_components_collected() -> bool:
	for id: String in COMPONENT_IDS:
		if not has_component(id):
			return false
	return true

func set_assembly_stage(stage: AssemblyStage) -> void:
	if stage == assembly_stage:
		return
	assembly_stage = stage
	EventBus.assembly_stage_changed.emit(int(stage), ASSEMBLY_STAGE_NAMES[int(stage)])

func component_installed(id: String) -> bool:
	match id:
		"frame_module":
			return assembly_stage >= AssemblyStage.FRAME
		"energy_module":
			return assembly_stage >= AssemblyStage.CORE
		"armour_shell":
			return assembly_stage >= AssemblyStage.SHELL
	return false

func mark_inspected(interaction_id: String) -> void:
	inspected_objects[interaction_id] = true

func was_inspected(interaction_id: String) -> bool:
	return inspected_objects.get(interaction_id, false) == true

func completion_ratio() -> float:
	## 0..1 progress used by the HUD ring and the computer status page.
	var total: float = 9.0
	var done: float = 0.0
	if shutter_open: done += 1.0
	if power_on: done += 1.0
	if computer_on: done += 1.0
	if notebook_read: done += 1.0
	if hologram_used: done += 1.0
	done += float(collected_components.size()) / 3.0
	if assembly_stage >= AssemblyStage.ASSEMBLING: done += 1.0
	if assembly_stage == AssemblyStage.ACTIVE: done += 1.0
	if diagnostics_run: done += 1.0
	return clampf(done / total, 0.0, 1.0)

func reset_run() -> void:
	has_started = false
	shutter_open = false
	power_on = false
	computer_on = false
	notebook_read = false
	hologram_used = false
	assembly_stage = AssemblyStage.DORMANT
	collected_components.clear()
	inspected_objects.clear()
	diagnostics_run = false
	visited_areas.clear()
	elapsed_seconds = 0.0

# --- persistence -----------------------------------------------------------

func save_run() -> void:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"shutter_open": shutter_open,
		"power_on": power_on,
		"computer_on": computer_on,
		"notebook_read": notebook_read,
		"hologram_used": hologram_used,
		"assembly_stage": int(assembly_stage),
		"collected_components": collected_components,
		"inspected_objects": inspected_objects,
		"diagnostics_run": diagnostics_run,
		"visited_areas": visited_areas,
		"elapsed_seconds": elapsed_seconds,
		"playthroughs_completed": playthroughs_completed,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: cannot write save (%s)" % error_string(FileAccess.get_open_error()))
		return
	file.store_var(payload)
	file.close()

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func load_run() -> bool:
	if not has_save():
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var data: Variant = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if int(d.get("version", 0)) != SAVE_VERSION:
		return false
	reset_run()
	shutter_open = bool(d.get("shutter_open", false))
	power_on = bool(d.get("power_on", false))
	computer_on = bool(d.get("computer_on", false))
	notebook_read = bool(d.get("notebook_read", false))
	hologram_used = bool(d.get("hologram_used", false))
	assembly_stage = int(d.get("assembly_stage", 0)) as AssemblyStage
	collected_components = d.get("collected_components", {})
	inspected_objects = d.get("inspected_objects", {})
	diagnostics_run = bool(d.get("diagnostics_run", false))
	visited_areas = d.get("visited_areas", {})
	elapsed_seconds = float(d.get("elapsed_seconds", 0.0))
	playthroughs_completed = int(d.get("playthroughs_completed", 0))
	return true

func save_settings() -> void:
	var file: FileAccess = FileAccess.open("user://settings.cfg", FileAccess.WRITE)
	if file == null:
		return
	file.store_var(settings)
	file.close()

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.cfg"):
		settings = GameConfig.default_settings()
		return
	var file: FileAccess = FileAccess.open("user://settings.cfg", FileAccess.READ)
	if file == null:
		settings = GameConfig.default_settings()
		return
	var data: Variant = file.get_var()
	file.close()
	settings = GameConfig.merge_defaults(
		data if typeof(data) == TYPE_DICTIONARY else {},
	)
