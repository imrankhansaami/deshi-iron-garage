extends Node
class_name GameConfigSingleton
## Loads the JSON data files in res://data and exposes typed accessors.
## Every workshop prop, sign, component and objective is described here so the
## garage can be re-themed by editing data instead of rewriting gameplay code
## (requirement 22: localisation and customisation through configuration).

const CONFIG_PATH: String = "res://data/garage_config.json"
const COMPONENTS_PATH: String = "res://data/components.json"
const OBJECTS_PATH: String = "res://data/workshop_objects.json"
const OBJECTIVES_PATH: String = "res://data/objectives.json"

var config: Dictionary = {}
var components: Array = []
var object_defs: Dictionary = {}
var objectives: Array = []

var _component_index: Dictionary = {}
var _objective_index: Dictionary = {}


func _ready() -> void:
	config = _read_json(CONFIG_PATH)
	components = _read_json_array(COMPONENTS_PATH)
	object_defs = _read_json(OBJECTS_PATH)
	objectives = _read_json_array(OBJECTIVES_PATH)
	for c: Variant in components:
		var comp: Dictionary = c
		_component_index[String(comp.get("id", ""))] = comp
	for o: Variant in objectives:
		var obj: Dictionary = o
		_objective_index[String(obj.get("id", ""))] = obj


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = _parse(path)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _read_json_array(path: String) -> Array:
	var parsed: Variant = _parse(path)
	return parsed if typeof(parsed) == TYPE_ARRAY else []


func _parse(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("GameConfig: missing data file %s" % path)
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_error("GameConfig: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


# --- garage dimensions and theme ------------------------------------------

func preset_id() -> String:
	return String(config.get("active_preset", "deshi_garage"))


func preset() -> Dictionary:
	var presets: Dictionary = config.get("presets", {})
	return presets.get(preset_id(), presets.get("deshi_garage", {}))


func dimension(key: String, fallback: float) -> float:
	return float(preset().get("dimensions", {}).get(key, fallback))


func width() -> float:
	return dimension("width", 13.0)


func length() -> float:
	return dimension("length", 16.0)


func height() -> float:
	return dimension("height", 4.6)


func sign_bangla() -> String:
	return String(preset().get("sign_bangla", "স্বপ্নের গ্যারেজ"))


func sign_english() -> String:
	return String(preset().get("sign_english", "DREAM GARAGE"))


func subtitle_bangla() -> String:
	return String(preset().get("subtitle_bangla", "নিজের প্রযুক্তি, নিজের শক্তি"))


func exterior_tint() -> Color:
	return Color.from_string(String(preset().get("exterior_tint", "#8a7f6d")), Color("8a7f6d"))


func wall_style() -> String:
	return String(preset().get("wall_style", "brick_cement"))


func rain_default() -> bool:
	return bool(preset().get("rain_default", true))


# --- components ------------------------------------------------------------

func total_components() -> int:
	return components.size()


func component_label(id: String) -> String:
	return String(_component_index.get(id, {}).get("label", id))


func component_short(id: String) -> String:
	return String(_component_index.get(id, {}).get("short", ""))


func component_story(id: String) -> String:
	return String(_component_index.get(id, {}).get("story", ""))


func component_spec(id: String) -> Array:
	var v: Variant = _component_index.get(id, {}).get("spec", [])
	return v if typeof(v) == TYPE_ARRAY else []


func component_slot_color(id: String) -> Color:
	return Color.from_string(String(_component_index.get(id, {}).get("accent", "#4fd8ff")), Color("4fd8ff"))


func component_order() -> Array:
	var out: Array = []
	for c: Variant in components:
		out.append(String((c as Dictionary).get("id", "")))
	return out


# --- objectives ------------------------------------------------------------

func objective_text(id: String) -> String:
	return String(_objective_index.get(id, {}).get("text", ""))


func objective_hint(id: String) -> String:
	return String(_objective_index.get(id, {}).get("hint", ""))


func first_objective() -> String:
	if objectives.is_empty():
		return "open_shutter"
	return String((objectives[0] as Dictionary).get("id", ""))


func next_objective_after(id: String) -> String:
	for i: int in range(objectives.size()):
		if String((objectives[i] as Dictionary).get("id", "")) == id:
			if i + 1 < objectives.size():
				return String((objectives[i + 1] as Dictionary).get("id", ""))
			return ""
	return ""


# --- object catalogue (procedural layout) ----------------------------------

func layout_groups() -> Array:
	var v: Variant = object_defs.get("layouts", [])
	return v if typeof(v) == TYPE_ARRAY else []


func prop_pool(name: String) -> Array:
	var pools: Dictionary = object_defs.get("pools", {})
	var v: Variant = pools.get(name, [])
	return v if typeof(v) == TYPE_ARRAY else []


func bangla_labels() -> Dictionary:
	var v: Variant = object_defs.get("bangla_labels", {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


func label(key: String) -> String:
	return String(bangla_labels().get(key, key))


# --- settings and quality --------------------------------------------------

func default_settings() -> Dictionary:
	return {
		"mouse_sensitivity": 0.0022,
		"invert_y": false,
		"walk_speed": 3.4,
		"sprint_multiplier": 1.75,
		"master_volume": 0.8,
		"ambience_volume": 0.75,
		"effects_volume": 0.85,
		"ui_volume": 0.8,
		"quality": "high",
		"fov": 78.0,
		"bloom": true,
		"ssao": true,
		"shadows": true,
		"rain": true,
		"show_fps": false,
		"language": "en",
	}


func merge_defaults(saved: Dictionary) -> Dictionary:
	var out: Dictionary = default_settings()
	for key: String in out:
		if saved.has(key):
			out[key] = saved[key]
	return out


const QUALITY_PRESETS: Dictionary = {
	## `render_scale` is the number of pixels the 3D viewport renders at, upscaled
	## by FSR 2 — the single largest lever on integrated graphics. Below 1.0 MSAA is
	## switched off (see GarageEnvironment.apply_quality): FSR 2 brings its own
	## temporal antialiasing, and paying for both bought nothing but heat.
	"low": {
		"msaa": 0, "shadow_size": 1024, "max_lights": 6, "bloom": true,
		"ssao": false, "particles": 0.35, "texture_scale": 0.5, "reflections": false,
		"render_scale": 0.60,
	},
	"medium": {
		"msaa": 1, "shadow_size": 2048, "max_lights": 10, "bloom": true,
		"ssao": true, "particles": 0.7, "texture_scale": 1.0, "reflections": true,
		"render_scale": 0.75,
	},
	"high": {
		"msaa": 0, "shadow_size": 2048, "max_lights": 16, "bloom": true,
		"ssao": true, "particles": 1.0, "texture_scale": 1.5, "reflections": true,
		"render_scale": 0.85,
	},
}


func quality() -> Dictionary:
	var key: String = String(GameState.settings.get("quality", "high"))
	return QUALITY_PRESETS.get(key, QUALITY_PRESETS["high"])


func tex_scale() -> float:
	# 0.25 .. 1.5 maps to 128 .. 384 texels over the 256 default
	return clampf(float(quality().get("texture_scale", 1.0)), 0.25, 1.5)
