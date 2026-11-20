class_name SignageBaker
extends Node
## Turns declarative SignCanvas specs into GPU textures for in-world use.
##
## Two modes:
##   bake()  renders the spec once into an ImageTexture for static props
##           (signboards, notebook pages, calendars, posters, labels).
##   live()  keeps a SubViewport alive and returns it, so animated screens
##           (workstation monitor, diagnostic panels, hologram overlays) can
##           redraw every frame and be sampled straight onto geometry.
##
## Both routes go through the engine's text stack, which is why Bengali conjuncts
## shape correctly in-world. Requires a real rendering device: under --headless the
## bake returns a neutral placeholder instead of failing.

const SignCanvasClass := preload("res://scripts/core/sign_canvas.gd")
const GarageThemeClass := preload("res://scripts/core/garage_theme.gd")

var _shared_theme: Theme
var _live: Dictionary = {}          # id -> { viewport, canvas }
var _bakes: int = 0
var _bake_ms_total: float = 0.0


func _ready() -> void:
	_shared_theme = GarageThemeClass.build()
	get_tree().root.theme = _shared_theme


func theme() -> Theme:
	if _shared_theme == null:
		_shared_theme = GarageThemeClass.build()
	return _shared_theme


func stats() -> Dictionary:
	return {"bakes": _bakes, "avg_ms": (_bake_ms_total / maxf(float(_bakes), 1.0)), "live": _live.size()}


func has_live(id: String) -> bool:
	return _live.has(id)


# ===========================================================================
# Asynchronous bake
# ===========================================================================
## bake() needs two rendered frames, so it is a coroutine. Builders run
## synchronously and cannot await it without becoming coroutines themselves,
## which would infect every call site for no benefit. So the async form hands
## back a placeholder immediately and swaps the real texture in when it lands:
## the signboard is never untextured, and nothing downstream has to know that
## baking takes two frames.

func bake_async(spec: Dictionary, id: String, apply: Callable) -> ImageTexture:
	var size: Vector2i = Vector2i(spec.get("size", Vector2i(512, 256)))
	var placeholder: ImageTexture = bake_placeholder(size, Color(0.05, 0.06, 0.07, 1.0))
	_start_bake(spec, id, apply)
	return placeholder


func _start_bake(spec: Dictionary, id: String, apply: Callable) -> void:
	var tex: ImageTexture = await bake(spec, id)
	if apply.is_valid():
		apply.call(tex)


## Applies a baked texture to a MeshInstance3D, with the emissive and transparency
## settings every sign, plate, page and poster in the garage needs. Returns the
## material so callers can keep a reference for the graphics bench.
func apply_baked(
	target: Node3D,
	spec: Dictionary,
	id: String,
	emissive_energy: float = 0.0,
	roughness: float = 0.5,
	tint: Color = Color.WHITE,
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var size: Vector2i = Vector2i(spec.get("size", Vector2i(512, 256)))
	mat.albedo_texture = bake_placeholder(size, Color(0.05, 0.06, 0.07, 1.0))
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if bool(spec.get("transparent", false)) else BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.resource_name = "baked_" + id
	if emissive_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = Color.WHITE
		mat.emission_energy_multiplier = emissive_energy
		mat.emission_texture = mat.albedo_texture
	if target is MeshInstance3D:
		(target as MeshInstance3D).material_override = mat
	bake_async(spec, id, func(tex: ImageTexture) -> void:
		if tex == null or not is_instance_valid(target):
			return
		mat.albedo_texture = tex
		if mat.emission_enabled:
			mat.emission_texture = tex)
	return mat


# ===========================================================================
# Static bake
# ===========================================================================

func bake(spec: Dictionary, id: String = "") -> ImageTexture:
	var size: Vector2i = Vector2i(spec.get("size", Vector2i(512, 256)))
	var t0: int = Time.get_ticks_usec()
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = bool(spec.get("transparent", true))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	vp.handle_input_locally = false
	vp.msaa_2d = Viewport.MSAA_4X
	vp.disable_3d = true
	vp.name = "bake_" + (id if id != "" else str(_bakes))
	add_child(vp)

	var canvas: Control = SignCanvasClass.new()
	canvas.spec = {}
	canvas.theme = _shared_theme
	vp.add_child(canvas)
	canvas.set_deferred("size", Vector2(size))
	canvas.setup(spec)

	await _frames(2)
	var tex: ImageTexture = _extract(vp, size)
	vp.queue_free()
	_bakes += 1
	_bake_ms_total += float(Time.get_ticks_usec() - t0) / 1000.0
	return tex


func bake_placeholder(size: Vector2i, color: Color) -> ImageTexture:
	## Used when no rendering device is present (headless CI), and as the interim
	## texture for an async bake that has not landed yet, so a prop is never
	## without a material.
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _extract(vp: SubViewport, size: Vector2i) -> ImageTexture:
	var img: Image = vp.get_texture().get_image()
	if img == null or img.is_empty():
		return bake_placeholder(size, Color(0.05, 0.06, 0.07, 1.0))
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != size:
		img.crop(size.x, size.y)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex


func _frames(count: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	for i: int in range(count):
		await tree.process_frame


# ===========================================================================
# Live screens
# ===========================================================================

## Creates (or returns an existing) animated screen. The caller redraws by
## mutating the returned canvas' spec and calling queue_redraw().
func live(id: String, spec: Dictionary) -> Dictionary:
	if _live.has(id):
		var existing: Dictionary = _live[id]
		var ec: Control = existing["canvas"]
		ec.setup(existing["spec"])
		return existing
	var size: Vector2i = Vector2i(spec.get("size", Vector2i(640, 400)))
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = bool(spec.get("transparent", true))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.disable_3d = true
	vp.handle_input_locally = false
	vp.name = "live_" + id
	add_child(vp)
	var canvas: Control = SignCanvasClass.new()
	canvas.theme = _shared_theme
	vp.add_child(canvas)
	canvas.setup(spec)
	var entry: Dictionary = {"viewport": vp, "canvas": canvas, "spec": spec, "texture": vp.get_texture()}
	_live[id] = entry
	return entry


func relive(id: String, spec: Dictionary) -> void:
	if not _live.has(id):
		return
	var entry: Dictionary = _live[id]
	entry["spec"] = spec
	var canvas: Control = entry["canvas"]
	canvas.setup(spec)
	var vp: SubViewport = entry["viewport"]
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


## Pushes only the text layers of a live screen, leaving geometry intact.
func update_texts(id: String, texts: Dictionary) -> void:
	if not _live.has(id):
		return
	var entry: Dictionary = _live[id]
	var canvas: Control = entry["canvas"]
	for child: Node in canvas.get_children():
		if child is Label and texts.has(child.name):
			(child as Label).text = String(texts[child.name])
		elif child is RichTextLabel and texts.has(child.name):
			(child as RichTextLabel).text = String(texts[child.name])
	var vp: SubViewport = entry["viewport"]
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func live_texture(id: String) -> Texture2D:
	if not _live.has(id):
		return null
	return (_live[id]["viewport"] as SubViewport).get_texture()


func free_live(id: String) -> void:
	if _live.has(id):
		var vp: SubViewport = _live[id]["viewport"]
		if is_instance_valid(vp):
			vp.queue_free()
		_live.erase(id)


func _exit_tree() -> void:
	for id: String in _live.keys():
		free_live(id)
