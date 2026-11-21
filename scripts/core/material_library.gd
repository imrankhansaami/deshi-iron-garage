extends Node
class_name MaterialLibrarySingleton
## Builds and caches every StandardMaterial3D the garage uses, on top of
## TextureFactory. Splitting "synthesise channels" from "configure a PBR model"
## keeps the material definitions readable and lets the benchmark harness swap
## metallic/roughness values without regenerating textures (Experiment 1).

var factory: TextureFactory
var _materials: Dictionary = {}
var _built: bool = false

## Warm-up progress reported to the loading screen, 0..1.
var build_progress: float = 0.0
var build_total: int = 0
var build_done: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func ensure_built() -> void:
	if _built:
		return
	var scale: float = 1.0
	if Engine.has_singleton("GameConfig"):
		scale = GameConfig.tex_scale()
	var size: int = int(TextureFactory.DEFAULT_SIZE * scale)
	factory = TextureFactory.new(size)
	build_total = 34
	build_done = 0
	_built = true


func _tick() -> void:
	build_done = mini(build_done + 1, build_total)
	build_progress = float(build_done) / float(maxi(build_total, 1))


# ===========================================================================
# Surface materials
# ===========================================================================

## Returns a cached StandardMaterial3D for a texture key.
## opts: { uv_scale, uv2_scale, emission, emission_energy, albedo_mix, cull,
##         transparency, metallic_override, rough_override, orm_strength,
##         normal_scale, name }
## opts may carry either a Color or an "#rrggbb" string for the colour fields.
## String() on a Color is a hard error, so both forms are handled explicitly.
static func _color_opt(opts: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = opts.get(key, null)
	if v == null:
		return fallback
	if v is Color:
		return v
	var text: String = str(v)
	if text.is_empty():
		return fallback
	return Color.from_string(text, fallback)


func surface(key: String, opts: Dictionary = {}) -> StandardMaterial3D:
	var mat_key: String = key + "|" + _opts_signature(opts)
	if _materials.has(mat_key):
		return _materials[mat_key]
	ensure_built()
	var s: Dictionary = factory.surface(key)
	var m := StandardMaterial3D.new()
	m.albedo_texture = s["albedo"]
	m.roughness_texture = s["orm"]
	m.roughness_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = s["orm"]
	m.metallic_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_BLUE
	m.ao_enabled = true
	m.ao_texture = s["orm"]
	m.ao_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.35
	m.normal_enabled = true
	m.normal_texture = s["normal"]
	m.normal_scale = float(opts.get("normal_scale", 1.0))
	# --- world-scale texturing --------------------------------------------
	# BoxMesh and PlaneMesh carry 0..1 UVs, so one texture repeat is stretched
	# across whatever the mesh happens to be: a 13 m brick wall got a single brick
	# painted over it, which is why the first rendered garage read as grey
	# camouflage rather than masonry. World triplanar derives UVs from the object's
	# position in metres instead, so uv1_scale becomes "repeats per metre" and every
	# surface tiles at its real physical density regardless of geometry.
	# Sharpness is above the default so the three projections do not smear at the
	# corners, which is the usual giveaway of triplanar use.
	var recipe: Dictionary = TextureFactory.recipes().get(key, {})
	var mpt: float = float(recipe.get("meters_per_tile", 2.0))
	if mpt > 0.05 and not opts.has("no_world_triplanar"):
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = float(opts.get("triplanar_sharpness", 2.4))
		var density: float = 1.0 / mpt
		m.uv1_scale = Vector3(density, density, density)
	if opts.has("uv_scale"):
		m.uv1_scale = _vec3(opts["uv_scale"])
	if opts.has("uv2_scale"):
		m.uv2_scale = _vec3(opts["uv2_scale"])
		m.uv2_triplanar = bool(opts.get("uv2_triplanar", true))
		m.uv2_world_triplanar = true
	m.vertex_color_use_as_albedo = bool(opts.get("vertex_color", false))
	m.albedo_color = _color_opt(opts, "albedo_mix", Color.WHITE)
	if opts.has("metallic_override"):
		m.metallic = float(opts["metallic_override"])
		m.metallic_texture = null
	if opts.has("rough_override"):
		m.roughness = float(opts["rough_override"])
		m.roughness_texture = null
	# --- the gloss pass ------------------------------------------------------
	# `roughness` multiplies the ORM texture's green channel, so one number makes
	# every surface in the room glossier without erasing its per-texel variation.
	# 1.0 was the Godot default; the project now ships shinier — painted steel,
	# sealed concrete, varnished teak — which also feeds the screen-space
	# reflections something to catch.
	if not opts.has("rough_override"):
		m.roughness = float(opts.get("roughness", 0.58))
	var has_emission: bool = opts.has("emission") and str(opts.get("emission", "")) != ""
	if has_emission:
		m.emission_enabled = true
		m.emission = _color_opt(opts, "emission", Color.WHITE)
		m.emission_energy_multiplier = float(opts.get("emission_energy", 1.0))
		if opts.has("emission_texture"):
			m.emission_texture = opts["emission_texture"]
	if bool(opts.get("transparency", false)):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = StandardMaterial3D.CULL_DISABLED if bool(opts.get("double_sided", false)) else StandardMaterial3D.CULL_BACK
	if bool(opts.get("cull_disabled", false)):
		m.cull_mode = StandardMaterial3D.CULL_DISABLED
	# Filtering is a material property in Godot 4, not a texture property, so the
	# anisotropic-mipmap setting lives here rather than in TextureFactory.
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.resource_name = String(opts.get("name", key))
	_materials[mat_key] = m
	_tick()
	return m


func _vec3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	if v is Vector2:
		return Vector3(v.x, v.y, 1.0)
	if v is Array and (v as Array).size() >= 2:
		return Vector3(float(v[0]), float(v[1]), 1.0)
	return Vector3.ONE


func _opts_signature(opts: Dictionary) -> String:
	var keys: Array = opts.keys()
	keys.sort()
	var parts: PackedStringArray = PackedStringArray()
	for k: String in keys:
		var val: Variant = opts[k]
		if val is Texture2D or val is Material:
			parts.append("%s:res" % k)
		else:
			# str() first, then format: "%s" with a raw Variant routes through the
			# String constructor, which rejects Color and Vector3 outright
			var text: String = str(val)
			parts.append("%s:%s" % [k, text])
	return "|".join(parts)


# ===========================================================================
# Named convenience materials (the palette the builders actually use)
# ===========================================================================

func brick() -> StandardMaterial3D:
	return surface("brick_wall", {"uv2_scale": Vector3(1.0, 1.0, 1.0), "uv2_triplanar": true, "normal_scale": 1.4})


func plaster() -> StandardMaterial3D:
	return surface("cement_plaster", {"uv2_scale": Vector3(1.0, 1.0, 1.0), "uv2_triplanar": true})


func floor_worn() -> StandardMaterial3D:
	return surface("worn_concrete", {"uv_scale": Vector3(4.0, 4.0, 4.0), "normal_scale": 0.8})


func roof_tin() -> StandardMaterial3D:
	return surface("corrugated_tin", {"uv_scale": Vector3(6.0, 3.0, 6.0), "cull_disabled": true})


func teak(uv: float = 1.0) -> StandardMaterial3D:
	return surface("teak", {"uv_scale": Vector3(uv, uv, uv)})


func steel(uv: float = 1.0) -> StandardMaterial3D:
	return surface("steel_brushed", {"uv_scale": Vector3(uv, uv, uv)})


func steel_dark(uv: float = 1.0) -> StandardMaterial3D:
	return surface("steel_dark", {"uv_scale": Vector3(uv, uv, uv)})


func cast_iron() -> StandardMaterial3D:
	return surface("cast_iron")


func chrome() -> StandardMaterial3D:
	return surface("chrome")


func brass() -> StandardMaterial3D:
	return surface("brass")


func copper() -> StandardMaterial3D:
	return surface("copper")


func aluminium() -> StandardMaterial3D:
	return surface("aluminium")


func rust() -> StandardMaterial3D:
	return surface("rust_sheet")


func paint_red(uv: float = 1.0) -> StandardMaterial3D:
	return surface("painted_red", {"uv_scale": Vector3(uv, uv, uv)})


func paint_blue(uv: float = 1.0) -> StandardMaterial3D:
	return surface("painted_blue", {"uv_scale": Vector3(uv, uv, uv)})


func paint_green() -> StandardMaterial3D:
	return surface("painted_green")


func paint_yellow() -> StandardMaterial3D:
	return surface("painted_yellow")


func plastic_black() -> StandardMaterial3D:
	return surface("plastic_black")


func plastic_faded() -> StandardMaterial3D:
	return surface("plastic_faded")


func plastic_red() -> StandardMaterial3D:
	return surface("plastic_red")


func rubber() -> StandardMaterial3D:
	return surface("rubber")


func pcb() -> StandardMaterial3D:
	return surface("circuit_board", {"uv_scale": Vector3(1.0, 1.0, 1.0)})


func glass_smoky() -> StandardMaterial3D:
	# The pane this returns is used by both windows, the holo table top and the CRT
	# face. It had transparency enabled but an opaque albedo (alpha 1.0), so every
	# "glass" surface in the project rendered as a solid streaky grey panel — the
	# windows looked like green marble, which is what the captures showed. A smoky
	# pane wants alpha around a quarter and no shadow contribution.
	return surface("glass_smoky", {
		"transparency": true, "double_sided": true,
		"albedo_mix": Color(0.80, 0.85, 0.90, 0.24),
	})


func banner_print(path: String) -> StandardMaterial3D:
	## The one supplied photograph in the project: the workshop banner the author
	## asked to hang in his own garage. Loaded with Image.load_from_file() rather
	## than through the editor's import pipeline, so the image needs no .import side
	## file and a checkout still runs; if the file is missing the material degrades
	## to a plain dark print with a warning rather than breaking the build.
	var key: String = "banner|" + path
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.62
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.resource_name = "banner_print"
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img != null and not img.is_empty():
		m.albedo_texture = ImageTexture.create_from_image(img)
		# a whisper of emission keeps the print readable in the workshop's dim
		# corners without turning it into a light source
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 0.06
		m.emission_texture = m.albedo_texture
	else:
		push_warning("banner_print: could not load %s, using a plain panel" % path)
		m.albedo_color = Color(0.07, 0.09, 0.13)
	_materials[key] = m
	return m


func photo_print(path: String) -> StandardMaterial3D:
	## A supplied photograph as wall art: the author's pictures, loaded with
	## Image.load_from_file() like the street banner, so they need no import side
	## files and a checkout still runs. Cached per path; a missing file degrades to
	## a blank paper print with a warning rather than breaking the build.
	var key: String = "photo|" + path
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.roughness = 0.5
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.resource_name = "photo_print"
	var img: Image = null
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	if img != null and not img.is_empty():
		m.albedo_texture = ImageTexture.create_from_image(img)
		# a touch more emission than the banner: photos hang in dim corners
		m.emission_enabled = true
		m.emission = Color.WHITE
		m.emission_energy_multiplier = 0.08
		m.emission_texture = m.albedo_texture
	else:
		push_warning("photo_print: could not load %s, using a paper blank" % path)
		m.albedo_color = Color(0.86, 0.83, 0.74)
	_materials[key] = m
	return m


func armor_paint(color: Color) -> StandardMaterial3D:
	## Painted plate for the shop's armour builds: saturated colour over metal with
	## a low roughness, so the red and the gold catch the room's lights the way the
	## reference plates do. Colours come from the callers, not from any film.
	var key: String = "armor|" + color.to_html()
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.62
	m.roughness = 0.24
	m.resource_name = "armor_paint"
	_materials[key] = m
	return m


func armor_dark() -> StandardMaterial3D:
	## The armour's underlayer: bare dark alloy between the plates.
	var key: String = "armor_dark"
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("23262b")
	m.metallic = 0.45
	m.roughness = 0.42
	m.resource_name = "armor_dark"
	_materials[key] = m
	return m


func fabric() -> StandardMaterial3D:
	return surface("fabric")


func gamcha() -> StandardMaterial3D:
	return surface("gamcha")


func newspaper() -> StandardMaterial3D:
	return surface("newspaper")


func paper() -> StandardMaterial3D:
	return surface("paper_notebook")


func armour_red() -> StandardMaterial3D:
	return surface("armour_red")


func armour_gold() -> StandardMaterial3D:
	return surface("armour_gold")


# ===========================================================================
# Emissive / utility materials
# ===========================================================================

func unlit_emissive(color: Color, energy: float = 2.0, rough: float = 0.3, metallic: float = 0.0) -> StandardMaterial3D:
	var key: String = "emis|%s|%.2f|%.2f|%.2f" % [color.to_html(), energy, rough, metallic]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color.darkened(0.5)
	m.metallic = metallic
	m.roughness = rough
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.resource_name = "emissive"
	_materials[key] = m
	return m


func led(color: Color, energy: float = 4.0) -> StandardMaterial3D:
	return unlit_emissive(color, energy, 0.25, 0.1)


func screen_material(texture: Texture2D, glow: float = 1.15) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture
	m.albedo_color = Color(0.06, 0.07, 0.08)
	m.emission_enabled = true
	m.emission_texture = texture
	m.emission = Color.WHITE
	m.emission_energy_multiplier = glow
	m.roughness = 0.22
	m.metallic = 0.0
	m.resource_name = "screen"
	return m


func bulb_material(color: Color = Color("fff0cf"), energy: float = 8.0) -> StandardMaterial3D:
	return unlit_emissive(color, energy, 0.1, 0.0)


func shader_material(shader_path: String, params: Dictionary = {}) -> ShaderMaterial:
	var sh: Shader = load(shader_path) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = sh
	for k: String in params:
		mat.set_shader_parameter(k, params[k])
	return mat


func hologram_material(params: Dictionary = {}) -> ShaderMaterial:
	var p: Dictionary = {
		"hologram_color": Color("57e6ff"),
		"fresnel_power": 2.4,
		"scan_speed": 0.55,
		"scan_density": 26.0,
		"scan_band_speed": 0.35,
		"flicker_amount": 0.12,
		"grid_scale": 34.0,
		"opacity": 0.62,
		"glow_strength": 2.1,
		"rim_boost": 1.6,
	}
	for k: String in params:
		p[k] = params[k]
	return shader_material("res://shaders/hologram.gdshader", p)


func energy_core_material(params: Dictionary = {}) -> ShaderMaterial:
	var p: Dictionary = {
		"core_color": Color("7cf3ff"),
		"rim_color": Color("#b8f6ff"),
		"pulse_speed": 1.35,
		"glow_strength": 3.4,
		"ring_count": 3.0,
		"ring_speed": 0.5,
		"noise_scale": 6.0,
		"plasma_amount": 0.55,
		"arc_intensity": 0.7,
	}
	for k: String in params:
		p[k] = params[k]
	return shader_material("res://shaders/energy_core.gdshader", p)


func holo_floor_material() -> ShaderMaterial:
	return shader_material("res://shaders/holo_grid.gdshader", {
		"grid_color": Color("4fd8ff"),
		"cell_size": 0.25,
		"line_width": 0.02,
		"sweep_speed": 0.28,
		"fade_radius": 1.0,
		"pulse": 1.0,
	})


func cable_material(color: Color = Color("#1b1d20")) -> StandardMaterial3D:
	var key: String = "cable|%s" % color.to_html()
	if _materials.has(key):
		return _materials[key]
	var s: Dictionary = factory.surface("rubber")
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.62
	m.metallic = 0.0
	m.normal_enabled = true
	m.normal_texture = s["normal"]
	m.normal_scale = 0.35
	m.resource_name = "cable"
	_materials[key] = m
	return m


func plywood() -> StandardMaterial3D:
	return surface("plywood")


func steel_hardened() -> StandardMaterial3D:
	return surface("steel_brushed", {
		"metallic_override": 1.0, "rough_override": 0.22, "albedo_mix": Color("#aab0b6"),
	})


## A floor stain, as distinct from oil_stain().
##
## Two corrections are baked into this material, both from the overhead capture:
##   1. oil_stain() is near-black at 0.18 roughness, which is right for a small
##      puddle under an engine and catastrophic at floor scale: it absorbs the
##      ceiling lights and the floor reads as a hole.
##   2. A ShapeKit disc_flat is a SOLID cylinder, not a decal, so its top face is
##      fully opaque. Transparency has to come from the albedo alpha; setting
##      `transparency` alone blends nothing, and the stains render as flat black
##      discs, which is exactly what the first overhead shot showed.
func floor_stain() -> StandardMaterial3D:
	return surface("worn_concrete", {
		"albedo_mix": Color(0.29, 0.25, 0.21, 0.42), "rough_override": 0.52, "metallic_override": 0.0,
		"transparency": true, "double_sided": true, "no_shadow": true, "normal_scale": 0.2,
		"uv_scale": Vector3(3.0, 3.0, 3.0),
	})


## The painted walkway from the shutter to the platform. Deliberately narrow and
## desaturated: hazard yellow at full saturation across a 1.5 m lane dominated the
## overhead view and read as decoration rather than as a floor marking.
func walkway_paint() -> StandardMaterial3D:
	return surface("painted_yellow", {
		"albedo_mix": Color(0.72, 0.62, 0.28), "rough_override": 0.68, "metallic_override": 0.0,
		"uv_scale": Vector3(3.0, 3.0, 3.0),
	})


## The anti-static bench mat. Deliberately pattern-free: the rubber surface's
## panel_lines at 0.6 m per tile produced a legible tile grid across the bench,
## which read as floor tiling rather than as a mat. A real ESD mat is a fine
## pebbled sheet, so it carries only the base grain and a satin roughness.
func esd_mat() -> StandardMaterial3D:
	return surface("rubber", {
		"albedo_mix": Color("#2b3038"), "rough_override": 0.56, "metallic_override": 0.0,
		"no_world_triplanar": true, "uv_scale": Vector3(9.0, 9.0, 9.0), "normal_scale": 0.35,
	})


func thread_material() -> StandardMaterial3D:
	return surface("newspaper", {"uv_scale": Vector3(2.0, 2.0, 2.0)})


# ===========================================================================
# Specialty materials the prop catalogue needs. These are all StandardMaterial3D
# parameter sets over the synthesised channel maps — the point of the split is
# that a "used oil stain" and a "heat-blued exhaust" are the same noise field
# with different metallic/roughness, which is exactly the axis Experiment 1
# measures.
# ===========================================================================

func paint_black_or_dark() -> StandardMaterial3D:
	return surface("steel_dark", {"albedo_mix": Color("#2a2c30"), "rough_override": 0.5, "metallic_override": 0.25})


func paint_white_or() -> StandardMaterial3D:
	return surface("cement_plaster", {"albedo_mix": Color("#e6e4dc"), "rough_override": 0.4, "metallic_override": 0.0})


func oil_stain() -> StandardMaterial3D:
	return surface("worn_concrete", {
		"albedo_mix": Color("#1a1512"), "rough_override": 0.18, "metallic_override": 0.0,
		"transparency": true, "double_sided": true, "no_shadow": true, "normal_scale": 0.2,
	})


func steel_heatblued() -> StandardMaterial3D:
	return surface("steel_brushed", {
		"albedo_mix": Color("#5b4a7a"), "metallic_override": 1.0, "rough_override": 0.26,
		"emission": "#160d24", "emission_energy": 0.12,
	})


func weld_bead() -> StandardMaterial3D:
	return surface("cast_iron", {"albedo_mix": Color("#8a7f6a"), "rough_override": 0.62, "metallic_override": 0.85})


func zinc_diecast() -> StandardMaterial3D:
	return surface("aluminium", {"albedo_mix": Color("#9ba1a6"), "rough_override": 0.52, "metallic_override": 0.9})


func ceramic_white() -> StandardMaterial3D:
	return surface("cement_plaster", {"albedo_mix": Color("#efe9df"), "rough_override": 0.22, "metallic_override": 0.0})


func nickel() -> StandardMaterial3D:
	return surface("chrome", {"albedo_mix": Color("#c8ccc4"), "rough_override": 0.22})


func lens_red() -> StandardMaterial3D:
	return surface("plastic_red", {
		"transparency": true, "double_sided": true, "rough_override": 0.12, "metallic_override": 0.0,
		"albedo_mix": Color("#d23a2c"), "emission": "#5a0f0a", "emission_energy": 0.4,
	})


func glass_fluted() -> StandardMaterial3D:
	return surface("glass_smoky", {
		"transparency": true, "double_sided": true, "rough_override": 0.28,
		"albedo_mix": Color("#d8e4ea"), "uv_scale": Vector3(1.0, 8.0, 1.0), "normal_scale": 2.2,
	})


func steel_brushed_disc() -> StandardMaterial3D:
	return surface("steel_brushed", {"metallic_override": 1.0, "rough_override": 0.24, "uv_scale": Vector3(1.0, 1.0, 1.0)})


func steel_laminated() -> StandardMaterial3D:
	return surface("steel_dark", {"uv_scale": Vector3(1.0, 14.0, 1.0), "metallic_override": 0.95, "rough_override": 0.42, "normal_scale": 1.6})


func steel_spring() -> StandardMaterial3D:
	return surface("steel_brushed", {"metallic_override": 1.0, "rough_override": 0.3, "albedo_mix": Color("#8f949a")})


func insulation_tape() -> StandardMaterial3D:
	return surface("plastic_black", {"rough_override": 0.35, "albedo_mix": Color("#7a2a1a")})


func tungsten() -> StandardMaterial3D:
	return unlit_emissive(Color("ffd9a0"), 0.0, 0.4, 0.8)


func tube_glow() -> StandardMaterial3D:
	return unlit_emissive(Color("f4f8ff"), 0.0, 0.15, 0.0)


func diffuser_plastic() -> StandardMaterial3D:
	return surface("plastic_faded", {
		"albedo_mix": Color("#efe6cf"), "rough_override": 0.55, "transparency": true,
		"double_sided": true, "metallic_override": 0.0,
	})


func vinyl_cushion() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#8a2f2a"), "rough_override": 0.45})


func tarpaulin() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#3f5a4a"), "rough_override": 0.7, "double_sided": true, "cull_disabled": true})


func leather_like() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#4a3226"), "rough_override": 0.55, "normal_scale": 1.4})


func hay() -> StandardMaterial3D:
	return surface("gamcha", {"albedo_mix": Color("#c2a860"), "rough_override": 0.9, "uv_scale": Vector3(3.0, 3.0, 3.0)})


func flame_material() -> StandardMaterial3D:
	return unlit_emissive(Color("ffb347"), 2.6, 0.5, 0.0)


func rickshaw_art() -> StandardMaterial3D:
	## The painted floral/decorative panel every cycle-rickshaw carries.
	return surface("teak", {
		"uv_scale": Vector3(1.0, 1.0, 1.0), "rough_override": 0.3, "metallic_override": 0.0,
		"albedo_mix": Color("#e8d08a"), "emission": "#3a1f0a", "emission_energy": 0.05,
	})


func screen_off_material() -> StandardMaterial3D:
	return surface("plastic_black", {"rough_override": 0.12, "metallic_override": 0.0})


func indicator(color: Color, energy: float = 5.0) -> StandardMaterial3D:
	return unlit_emissive(color, energy, 0.2, 0.1)


func hologram_glow(color: Color = Color("57e6ff"), energy: float = 3.0) -> StandardMaterial3D:
	return unlit_emissive(color, energy, 0.1, 0.0)


# --- electronics and plastics ----------------------------------------------

## Sun-yellowed ABS. The `aged` flag picks the harsher variant seen on
## second-hand desktop cases that have spent a decade under a tube light.
func beige_plastic(aged: bool = true) -> StandardMaterial3D:
	var tint: Color = Color("#c9bfa2") if aged else Color("#d8d2c2")
	return surface("plastic_faded", {"albedo_mix": tint, "rough_override": 0.55, "metallic_override": 0.0})


func plastic_white_gloss() -> StandardMaterial3D:
	return surface("cement_plaster", {"albedo_mix": Color("#e2e4e2"), "rough_override": 0.28, "metallic_override": 0.0})


func plastic_translucent() -> StandardMaterial3D:
	return surface("plastic_faded", {
		"albedo_mix": Color("#cfd6da"), "rough_override": 0.3, "transparency": true,
		"double_sided": true, "metallic_override": 0.0,
	})


func plastic_blue_stiff() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#7a6a4a"), "rough_override": 0.4, "metallic_override": 0.0})


func woodgrain_dark() -> StandardMaterial3D:
	return surface("teak", {"albedo_mix": Color("#5a4028"), "uv_scale": Vector3(1.6, 1.6, 1.6), "rough_override": 0.5})


func fabric_grill() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#2a2c2e"), "rough_override": 0.85, "uv_scale": Vector3(4.0, 4.0, 4.0)})


func paper_cone() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#d8cdb4"), "rough_override": 0.75})


func meter_face() -> StandardMaterial3D:
	return surface("paper_notebook", {
		"albedo_mix": Color("#efe7cf"), "rough_override": 0.25, "metallic_override": 0.0,
		"emission": "#2a2416", "emission_energy": 0.05,
	})


func lcd_green() -> StandardMaterial3D:
	return surface("plastic_black", {
		"albedo_mix": Color("#8fae7a"), "rough_override": 0.2, "metallic_override": 0.0,
		"emission": "#9fd88a", "emission_energy": 0.6,
	})


func crt_green() -> StandardMaterial3D:
	return surface("plastic_black", {
		"albedo_mix": Color("#0f1a12"), "rough_override": 0.12, "metallic_override": 0.0,
		"emission": "#3fd87a", "emission_energy": 0.35,
	})


func scope_grid() -> StandardMaterial3D:
	return surface("paper_notebook", {
		"albedo_mix": Color("#1a2a1e"), "rough_override": 0.3, "transparency": true,
		"emission": "#2a5a3a", "emission_energy": 0.2, "double_sided": true,
	})


func seven_segment() -> StandardMaterial3D:
	return surface("plastic_black", {
		"albedo_mix": Color("#1a0d0a"), "rough_override": 0.15,
		"emission": "#ff6a3c", "emission_energy": 0.9,
	})


func ribbon_orange() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#c87a3a"), "rough_override": 0.6, "uv_scale": Vector3(6.0, 1.0, 1.0)})


func gold_finger() -> StandardMaterial3D:
	return surface("brass", {"albedo_mix": Color("#e0c04a"), "metallic_override": 1.0, "rough_override": 0.22})


func silver_solder() -> StandardMaterial3D:
	return surface("chrome", {"albedo_mix": Color("#c6cacd"), "rough_override": 0.3, "metallic_override": 1.0})


func resistor_body() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#c8a878"), "rough_override": 0.45})


func band_color(index: int) -> StandardMaterial3D:
	var palette: Array[Color] = [
		Color("#8a4a2a"), Color("#1b1d20"), Color("#c93a2a"), Color("#e0c04a"),
		Color("#2a5ac9"), Color("#5fd08a"), Color("#e8e4dc"),
	]
	return unlit_emissive(palette[index % palette.size()], 0.05, 0.35, 0.0)


func cap_sleeve() -> StandardMaterial3D:
	return surface("plastic_black", {"albedo_mix": Color("#1a3a6a"), "rough_override": 0.35})


func thermal_paste() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#8a8f94"), "rough_override": 0.6})


func bakelite() -> StandardMaterial3D:
	return surface("plastic_black", {"albedo_mix": Color("#3a2a1e"), "rough_override": 0.28})


func battery_case() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#2a2d31"), "rough_override": 0.62})


func battery_label() -> StandardMaterial3D:
	return surface("paper_notebook", {
		"albedo_mix": Color("#e0d8b8"), "rough_override": 0.5,
		"emission": "#1a1408", "emission_energy": 0.03,
	})


func lead_terminal() -> StandardMaterial3D:
	return surface("lead_grey", {"rough_override": 0.55, "metallic_override": 0.9})


func ferrite() -> StandardMaterial3D:
	return surface("plastic_black", {"albedo_mix": Color("#2a2b2e"), "rough_override": 0.75, "metallic_override": 0.1})


func sponge() -> StandardMaterial3D:
	return surface("gamcha", {"albedo_mix": Color("#4a5a6a"), "rough_override": 0.9})


func meter_case() -> StandardMaterial3D:
	return surface("plastic_black", {"albedo_mix": Color("#e0b83a"), "rough_override": 0.45})


func glass_screen() -> StandardMaterial3D:
	return surface("glass_smoky", {
		"albedo_mix": Color("#a8b0b8"), "rough_override": 0.06, "transparency": true,
		"double_sided": true, "metallic_override": 0.0,
	})


# --- daily-life materials --------------------------------------------------

func stainless() -> StandardMaterial3D:
	return surface("steel_brushed", {"metallic_override": 1.0, "rough_override": 0.18, "albedo_mix": Color("#c4c8cc")})


func tinplate() -> StandardMaterial3D:
	return surface("aluminium", {"metallic_override": 0.95, "rough_override": 0.3, "albedo_mix": Color("#b8bcc0")})


func tin_label() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#d8b048"), "rough_override": 0.45, "metallic_override": 0.1})


func muri() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#efe4c4"), "rough_override": 0.85})


func tea_liquid() -> StandardMaterial3D:
	return surface("glass_smoky", {
		"albedo_mix": Color("#a0642a"), "rough_override": 0.05, "transparency": true,
		"metallic_override": 0.0, "double_sided": true,
	})


func tea_froth() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#d8c0a0"), "rough_override": 0.7})


func tea_stain() -> StandardMaterial3D:
	return surface("paper_notebook", {
		"albedo_mix": Color("#b08a5a"), "rough_override": 0.6, "transparency": true,
		"double_sided": true, "no_shadow": true,
	})


func newsprint_print() -> StandardMaterial3D:
	return surface("newspaper", {"albedo_mix": Color("#3a3a38"), "rough_override": 0.8, "uv_scale": Vector3(1.0, 8.0, 1.0)})


func handwriting_line() -> StandardMaterial3D:
	return surface("paper_notebook", {
		"albedo_mix": Color("#2a3a5a"), "rough_override": 0.7, "uv_scale": Vector3(1.0, 20.0, 1.0),
	})


func gamcha_red() -> StandardMaterial3D:
	return surface("gamcha", {"albedo_mix": Color("#b03a2c"), "uv_scale": Vector3(1.0, 6.0, 1.0)})


func sandal_rubber() -> StandardMaterial3D:
	return surface("rubber", {"albedo_mix": Color("#3a3f45"), "rough_override": 0.85})


func plastic_blue_body() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#3a6aa8"), "rough_override": 0.4})


func water() -> StandardMaterial3D:
	return surface("glass_smoky", {
		"albedo_mix": Color("#6a8aa0"), "rough_override": 0.02, "transparency": true,
		"metallic_override": 0.0, "double_sided": true,
	})


func notebook_cover() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#7a2a1a"), "rough_override": 0.75, "uv_scale": Vector3(2.0, 2.0, 2.0)})


func label_stock() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#f0ead8"), "rough_override": 0.65})


func adhesive_tape() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#c8b890"), "rough_override": 0.3, "transparency": true})


func poster_stock(variant: int) -> StandardMaterial3D:
	var tints: Array[Color] = [
		Color("#c85a3a"), Color("#3a6a8a"), Color("#8a7a3a"), Color("#5a3a6a"), Color("#3a7a5a"),
	]
	return surface("paper_notebook", {
		"albedo_mix": tints[absi(variant) % tints.size()], "rough_override": 0.6,
		"uv_scale": Vector3(1.0, 1.0, 1.0),
	})


func photo_paper() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#8a7a6a"), "rough_override": 0.25})


func cardboard() -> StandardMaterial3D:
	return surface("teak", {"albedo_mix": Color("#a88a5a"), "rough_override": 0.9, "uv_scale": Vector3(2.0, 2.0, 2.0)})


func plastic_bag() -> StandardMaterial3D:
	return surface("plastic_faded", {
		"albedo_mix": Color("#d8e0e8"), "rough_override": 0.15, "transparency": true,
		"double_sided": true, "metallic_override": 0.0, "cull_disabled": true,
	})


func woven_sack() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#c8b888"), "rough_override": 0.85, "uv_scale": Vector3(6.0, 6.0, 6.0)})


func mirror() -> StandardMaterial3D:
	return surface("chrome", {"metallic_override": 1.0, "rough_override": 0.02, "albedo_mix": Color("#e8ecf0")})


func soap() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#d8c8a0"), "rough_override": 0.35})


func bristle() -> StandardMaterial3D:
	return surface("plastic_faded", {"albedo_mix": Color("#e0d8c8"), "rough_override": 0.5})


func chair_fabric() -> StandardMaterial3D:
	return surface("fabric", {"albedo_mix": Color("#3a4048"), "rough_override": 0.8, "uv_scale": Vector3(3.0, 3.0, 3.0)})


func calendar_stock() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#f4ecd8"), "rough_override": 0.55})


func calendar_header() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#b03a2c"), "rough_override": 0.45})


func calendar_cell() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#e8e0cc"), "rough_override": 0.6, "uv_scale": Vector3(1.0, 12.0, 1.0)})


func clock_face() -> StandardMaterial3D:
	return surface("paper_notebook", {"albedo_mix": Color("#f0ece0"), "rough_override": 0.4})


func pen_body() -> StandardMaterial3D:
	return surface("plastic_black", {"albedo_mix": Color("#1a3a6a"), "rough_override": 0.2})


func signboard_back() -> StandardMaterial3D:
	return surface("painted_blue", {"uv_scale": Vector3(1.0, 1.0, 1.0), "rough_override": 0.45})


func signboard_face() -> StandardMaterial3D:
	## Replaced at runtime with a baked SignCanvas texture carrying the Bangla
	## headline; this is the fallback so the board is never blank.
	return surface("paper_notebook", {"albedo_mix": Color("#0d1b2a"), "rough_override": 0.3})


func tread_plate() -> StandardMaterial3D:
	return surface("steel_dark", {
		"metallic_override": 0.95, "rough_override": 0.42, "uv_scale": Vector3(4.0, 4.0, 4.0),
		"normal_scale": 1.8,
	})


func hazard_paint() -> StandardMaterial3D:
	return surface("painted_yellow", {"uv_scale": Vector3(1.0, 8.0, 1.0), "rough_override": 0.55, "normal_scale": 1.2})


func hazard_tape_paint() -> StandardMaterial3D:
	return surface("painted_yellow", {"albedo_mix": Color("#e2453c"), "uv_scale": Vector3(1.0, 10.0, 1.0), "rough_override": 0.5})


func dispose_all() -> void:
	for k: String in _materials.keys():
		var mat: Variant = _materials[k]
		if mat is Resource:
			(mat as Resource).free()
	_materials.clear()
	if factory != null and factory is Object:
		(factory as Object).call("clear_cache")
