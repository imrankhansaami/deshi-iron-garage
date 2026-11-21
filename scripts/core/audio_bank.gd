extends Node
class_name AudioBankSingleton
## Procedural audio bank. Synthesises every stream on first use, routes them
## through three buses (Ambience / Effects / Interface) and provides pooled 2D
## and 3D playback with distance attenuation tuned for a single-room space.
##
## 3D attenuation uses inverse-square-ish volume plus a low-pass that widens with
## distance, which is what makes the far welding bench and the near work lamp
## sit in the right place in the room instead of floating on top of the mix.

const AudioSynthClass := preload("res://scripts/procedural/audio_synth.gd")

const BUS_MASTER: String = "Master"
const BUS_AMBIENCE: String = "Ambience"
const BUS_EFFECTS: String = "Effects"
const BUS_UI: String = "Interface"

## name -> { synth: String, args: Array, bus: String, db: float,
##           atten: float, max_dist: float, pool: int }
const RECIPES: Dictionary = {
	"metal_clank": {"synth": "metal_impact", "args": [0.9, 210.0, 1.0, 7], "bus": BUS_EFFECTS, "db": -3.0, "atten": 1.6, "max_dist": 9.0},
	"metal_thunk": {"synth": "metal_impact", "args": [0.7, 120.0, 0.55, 21], "bus": BUS_EFFECTS, "db": -2.0, "atten": 1.5, "max_dist": 10.0},
	"metal_tink": {"synth": "metal_impact", "args": [0.4, 720.0, 1.0, 33], "bus": BUS_EFFECTS, "db": -6.0, "atten": 1.8, "max_dist": 6.0},
	"tool_place": {"synth": "tool_click", "args": [3], "bus": BUS_EFFECTS, "db": -5.0, "atten": 1.7, "max_dist": 6.0},
	"latch": {"synth": "tool_click", "args": [17], "bus": BUS_EFFECTS, "db": -8.0, "atten": 1.4, "max_dist": 8.0},
	"switch_throw": {"synth": "metal_impact", "args": [0.28, 340.0, 0.8, 5], "bus": BUS_EFFECTS, "db": -4.0, "atten": 1.3, "max_dist": 9.0},
	"relay": {"synth": "metal_impact", "args": [0.32, 190.0, 0.7, 9], "bus": BUS_EFFECTS, "db": -5.0, "atten": 1.4, "max_dist": 9.0},
	"servo": {"synth": "servo_sweep", "args": [150.0, 430.0, 1.1, 11], "bus": BUS_EFFECTS, "db": -7.0, "atten": 1.5, "max_dist": 12.0},
	"servo_slow": {"synth": "servo_sweep", "args": [80.0, 190.0, 1.8, 27], "bus": BUS_EFFECTS, "db": -8.0, "atten": 1.5, "max_dist": 12.0},
	"boot": {"synth": "computer_boot", "args": [2.6], "bus": BUS_EFFECTS, "db": -4.0, "atten": 1.2, "max_dist": 12.0},
	"core_charge": {"synth": "core_charge", "args": [3.2, 909], "bus": BUS_EFFECTS, "db": -2.0, "atten": 1.3, "max_dist": 16.0},
	"paper": {"synth": "paper_turn", "args": [21], "bus": BUS_EFFECTS, "db": -6.0, "atten": 1.9, "max_dist": 5.0},
	"assembly_done": {"synth": "assembly_complete", "args": [3.4], "bus": BUS_EFFECTS, "db": -3.0, "atten": 1.1, "max_dist": 18.0},
	"ui_hover": {"synth": "ui_blip", "args": ["hover"], "bus": BUS_UI, "db": -16.0},
	"ui_confirm": {"synth": "ui_blip", "args": ["confirm"], "bus": BUS_UI, "db": -12.0},
	"ui_back": {"synth": "ui_blip", "args": ["back"], "bus": BUS_UI, "db": -13.0},
	"ui_error": {"synth": "ui_blip", "args": ["error"], "bus": BUS_UI, "db": -12.0},
	"ui_pick": {"synth": "ui_blip", "args": ["pick"], "bus": BUS_UI, "db": -13.0},
	"hum": {"synth": "electric_hum", "args": [4.0], "bus": BUS_AMBIENCE, "db": -20.0, "atten": 1.2, "max_dist": 14.0},
	"fan": {"synth": "fan_whir", "args": [3.0, 34.0], "bus": BUS_AMBIENCE, "db": -14.0, "atten": 1.6, "max_dist": 10.0},
	"fan_fast": {"synth": "fan_whir", "args": [3.0, 52.0], "bus": BUS_AMBIENCE, "db": -13.0, "atten": 1.6, "max_dist": 10.0},
	"rain": {"synth": "rain_tin", "args": [6.0, 1.0, 555], "bus": BUS_AMBIENCE, "db": -16.0},
	"street": {"synth": "street_bed", "args": [8.0, 1337], "bus": BUS_AMBIENCE, "db": -22.0},
	"shutter": {"synth": "shutter_motor", "args": [2.0], "bus": BUS_EFFECTS, "db": -6.0, "atten": 1.3, "max_dist": 16.0},
	"weld": {"synth": "weld_crackle", "args": [1.6, 404], "bus": BUS_EFFECTS, "db": -12.0, "atten": 1.8, "max_dist": 8.0},
	"core_idle": {"synth": "core_idle", "args": [2.5], "bus": BUS_AMBIENCE, "db": -18.0, "atten": 1.4, "max_dist": 12.0},
	"step_concrete": {"synth": "footstep", "args": [0, 3], "bus": BUS_EFFECTS, "db": -8.0, "atten": 1.8, "max_dist": 4.0},
	"step_earth": {"synth": "footstep", "args": [1, 5], "bus": BUS_EFFECTS, "db": -8.0, "atten": 1.8, "max_dist": 4.0},
	"step_steel": {"synth": "footstep", "args": [2, 8], "bus": BUS_EFFECTS, "db": -9.0, "atten": 1.8, "max_dist": 4.0},
	"step_wood": {"synth": "footstep", "args": [3, 6], "bus": BUS_EFFECTS, "db": -8.0, "atten": 1.8, "max_dist": 4.0},
	"nature": {"synth": "nature_bed", "args": [7.0, 4242], "bus": BUS_AMBIENCE, "db": -24.0},
	"bird": {"synth": "bird_call", "args": [0, 9], "bus": BUS_EFFECTS, "db": -9.0, "atten": 1.5, "max_dist": 14.0},
	"bird2": {"synth": "bird_call", "args": [1, 21], "bus": BUS_EFFECTS, "db": -10.0, "atten": 1.5, "max_dist": 14.0},
}

var _streams: Dictionary = {}
var _pool2d: Array[AudioStreamPlayer] = []
var _pool3d: Array[AudioStreamPlayer3D] = []
var _beds: Dictionary = {}          # name -> AudioStreamPlayer
var _ready_ok: bool = false
var synth_ms: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_apply_volumes()
	_ready_ok = true
	EventBus.ui_panel_opened.connect(_on_panel)
	EventBus.interaction_performed.connect(_on_interaction)


func _setup_buses() -> void:
	var names: Array[String] = [BUS_AMBIENCE, BUS_EFFECTS, BUS_UI]
	for i: int in range(names.size()):
		var target_index: int = i + 1
		if AudioServer.get_bus_index(names[i]) == -1:
			AudioServer.add_bus(target_index)
			AudioServer.set_bus_name(target_index, names[i])
			AudioServer.set_bus_send(target_index, BUS_MASTER)
		var idx: int = AudioServer.get_bus_index(names[i])
		AudioServer.set_bus_mute(idx, false)
	# master gets gentle glue so synthesised transients never poke through
	if AudioServer.get_bus_index(BUS_MASTER) == 0 and AudioServer.get_bus_effect_count(0) == 0:
		var comp := AudioEffectCompressor.new()
		comp.threshold = -14.0
		comp.ratio = 3.0
		comp.attack_us = 8000
		comp.release_ms = 180.0
		comp.mix = 1.0
		AudioServer.add_bus_effect(0, comp)
		var rev := AudioEffectReverb.new()
		rev.room_size = 0.42
		rev.wet = 0.16
		rev.damping = 0.62
		rev.spread = 0.5
		rev.hipass = 120.0
		rev.predelay_msec = 12
		AudioServer.add_bus_effect(0, rev)


func _apply_volumes() -> void:
	var s: Dictionary = GameState.settings
	var master: float = float(s.get("master_volume", 0.8))
	_set_bus_vol(BUS_MASTER, master)
	_set_bus_vol(BUS_AMBIENCE, float(s.get("ambience_volume", 0.75)) * master)
	_set_bus_vol(BUS_EFFECTS, float(s.get("effects_volume", 0.85)) * master)
	_set_bus_vol(BUS_UI, float(s.get("ui_volume", 0.8)) * master)


func _set_bus_vol(bus: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func refresh_settings() -> void:
	_apply_volumes()
	for name: String in _beds:
		var p: AudioStreamPlayer = _beds[name]
		if is_instance_valid(p):
			p.volume_db = float(RECIPES.get(name, {}).get("db", -12.0))


# ===========================================================================
# Streams
# ===========================================================================

func stream(name: String) -> AudioStreamWAV:
	if _streams.has(name):
		return _streams[name]
	var recipe: Dictionary = RECIPES.get(name, {})
	if recipe.is_empty():
		push_warning("AudioBank: unknown sound '%s'" % name)
		return null
	var t0: int = Time.get_ticks_usec()
	var synth_name: String = String(recipe.get("synth", "ui_blip"))
	var args: Array = recipe.get("args", [])
	var result: Variant = _dispatch(synth_name, args)
	_streams[name] = result
	synth_ms += float(Time.get_ticks_usec() - t0) / 1000.0
	return result


## Explicit dispatch instead of reflection: static GDScript functions are not
## reliably callable through Object.call(), and a silent null stream would show
## up as "audio just missing" rather than as an error.
func _dispatch(synth_name: String, args: Array) -> AudioStreamWAV:
	var S := AudioSynthClass
	match synth_name:
		"metal_impact":
			return S.metal_impact(args[0], args[1], args[2], args[3])
		"tool_click":
			return S.tool_click(args[0])
		"servo_sweep":
			return S.servo_sweep(args[0], args[1], args[2], args[3])
		"electric_hum":
			return S.electric_hum(args[0])
		"fan_whir":
			return S.fan_whir(args[0], args[1])
		"rain_tin":
			return S.rain_tin(args[0], args[1], args[2])
		"shutter_motor":
			return S.shutter_motor(args[0])
		"computer_boot":
			return S.computer_boot(args[0])
		"core_charge":
			return S.core_charge(args[0], args[1])
		"core_idle":
			return S.core_idle(args[0])
		"ui_blip":
			return S.ui_blip(args[0])
		"paper_turn":
			return S.paper_turn(args[0])
		"street_bed":
			return S.street_bed(args[0], args[1])
		"weld_crackle":
			return S.weld_crackle(args[0], args[1])
		"assembly_complete":
			return S.assembly_complete(args[0])
		"footstep":
			return S.footstep(args[0], args[1])
		"nature_bed":
			return S.nature_bed(args[0], args[1])
		"bird_call":
			return S.bird_call(args[0], args[1])
	push_warning("AudioBank: no synth for '%s'" % synth_name)
	return null


## Forces synthesis of the whole bank so the first interaction never hitches.
func prewarm(list: Array = []) -> void:
	var names: Array = list if not list.is_empty() else RECIPES.keys()
	for n: String in names:
		stream(n)


func stream_count() -> int:
	return _streams.size()


# ===========================================================================
# Playback
# ===========================================================================

func play(name: String, extra_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _ready_ok:
		return
	var s: AudioStreamWAV = stream(name)
	if s == null:
		return
	var recipe: Dictionary = RECIPES.get(name, {})
	var player: AudioStreamPlayer = _acquire2d()
	player.stream = s
	player.bus = String(recipe.get("bus", BUS_EFFECTS))
	player.volume_db = float(recipe.get("db", -8.0)) + extra_db
	player.pitch_scale = pitch_scale
	player.play()


func play_at(name: String, position: Vector3, extra_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _ready_ok:
		return
	var s: AudioStreamWAV = stream(name)
	if s == null:
		return
	var recipe: Dictionary = RECIPES.get(name, {})
	var player: AudioStreamPlayer3D = _acquire3d()
	player.global_position = position
	player.stream = s
	player.bus = String(recipe.get("bus", BUS_EFFECTS))
	player.volume_db = float(recipe.get("db", -8.0)) + extra_db
	player.pitch_scale = pitch_scale
	player.max_distance = float(recipe.get("max_dist", 10.0))
	player.unit_size = 1.0
	player.play()


func _acquire2d() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool2d:
		if not p.playing:
			return p
	var np := AudioStreamPlayer.new()
	np.bus = BUS_EFFECTS
	add_child(np)
	_pool2d.append(np)
	return np


func _acquire3d() -> AudioStreamPlayer3D:
	for p: AudioStreamPlayer3D in _pool3d:
		if not p.playing:
			return p
	var np := AudioStreamPlayer3D.new()
	np.bus = BUS_EFFECTS
	np.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	np.max_distance = 10.0
	np.unit_size = 1.0
	np.max_db = 6.0
	np.panning_strength = 0.8
	np.attenuation_filter_cutoff_hz = 1400.0
	np.attenuation_filter_db = -4.0
	add_child(np)
	_pool3d.append(np)
	return np


# ===========================================================================
# Beds (looping ambience)
# ===========================================================================

func start_bed(name: String, fade: float = 2.0) -> void:
	if not _ready_ok:
		return
	if _beds.has(name) and is_instance_valid(_beds[name]) and _beds[name].playing:
		return
	var s: AudioStreamWAV = stream(name)
	if s == null:
		return
	var recipe: Dictionary = RECIPES.get(name, {})
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = String(recipe.get("bus", BUS_AMBIENCE))
	p.volume_db = float(recipe.get("db", -18.0))
	p.finished.connect(func() -> void:
		if is_instance_valid(p):
			p.play())
	add_child(p)
	_beds[name] = p
	if fade > 0.0:
		p.volume_db = -80.0
		p.play()
		var tw: Tween = create_tween()
		tw.tween_property(p, "volume_db", float(recipe.get("db", -18.0)), fade)
	else:
		p.play()


func stop_bed(name: String, fade: float = 1.2) -> void:
	if not _beds.has(name) or not is_instance_valid(_beds[name]):
		return
	var p: AudioStreamPlayer = _beds[name]
	var tw: Tween = create_tween()
	tw.tween_property(p, "volume_db", -80.0, fade)
	tw.tween_callback(func() -> void:
		p.stop()
		p.queue_free())
	_beds.erase(name)


func set_bed_playing(name: String, on: bool) -> void:
	if on:
		start_bed(name)
	else:
		stop_bed(name)


func bed_active(name: String) -> bool:
	return _beds.has(name) and is_instance_valid(_beds[name]) and _beds[name].playing


## Called by the power system: the garage's identity changes with the beds.
func apply_power_state(power_on: bool) -> void:
	set_bed_playing("hum", power_on)
	set_bed_playing("street", true)
	set_bed_playing("rain", bool(GameState.settings.get("rain", true)))


func _on_panel(panel_name: String) -> void:
	play("ui_confirm", -4.0)


func _on_interaction(_target: Node3D, action_name: String) -> void:
	match action_name:
		"ui":
			play("ui_confirm")
		_:
			pass


func _exit_tree() -> void:
	for name: String in _beds.keys():
		if is_instance_valid(_beds[name]):
			_beds[name].queue_free()
	_beds.clear()
