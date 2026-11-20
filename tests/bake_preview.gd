extends SceneTree
## Renders the lab-wall plate specs to PNGs, so the Bangla on the scientists'
## plaques and the inventions board can be proof-read at full resolution without
## launching the whole garage. Needs a rendering device: run WITHOUT --headless.
##
## Usage:  godot --path . -s res://tests/bake_preview.gd
## Output: user://captures/preview_*.png

func _initialize() -> void:
	_run()


func _run() -> void:
	## Load the game scripts dynamically, inside the running tree: a `-s` script
	## compiles before the project's autoloads are registered, so naming
	## GarageDressing (which mentions GameConfig) statically fails to compile.
	## By the time this runs, the tree exists and the singletons resolve.
	await process_frame
	var dressing_script: Script = load("res://scripts/garage/garage_dressing.gd")
	var baker_script: Script = load("res://scripts/core/signage_baker.gd")
	var dressing: Node = dressing_script.new()
	var baker: Node = baker_script.new()
	root.add_child(baker)
	await process_frame

	var scientists: Array = _read_array("res://data/scientists.json")
	var inventions: Array = _read_array("res://data/inventions.json")
	var jobs: Array = []
	for i: int in range(scientists.size()):
		jobs.append({
			"id": "scientist_%d" % i,
			"spec": dressing.call("_scientist_spec", scientists[i]),
		})
	jobs.append({"id": "sci_header", "spec": dressing.call("_corner_header_spec")})
	jobs.append({"id": "inventions", "spec": dressing.call("_inventions_spec", inventions)})
	jobs.append({"id": "flag", "spec": dressing.call("_flag_spec")})
	jobs.append({"id": "coin_front", "spec": dressing.call("_coin_face_spec", true)})
	jobs.append({"id": "coin_back", "spec": dressing.call("_coin_face_spec", false)})
	jobs.append({"id": "map_bangladesh", "spec": dressing.call("_bangladesh_map_spec")})
	jobs.append({"id": "map_sylhet", "spec": dressing.call("_sylhet_map_spec")})
	# a wrap probe: the same long sentence at three settings, and the labels'
	# actual sizes printed afterwards — the fastest way to see what this engine
	# build does with a width on a plain Label
	var wrap_spec: Dictionary = {
		"size": Vector2i(384, 486), "transparent": false, "bg": "#101a2c",
		"layers": [
			{"type": "text", "name": "A", "pos": Vector2(22, 20), "size": 20, "width": 340, "align": "center", "color": "#ffffff",
				"text": "A plain Label with a width set should wrap this sentence into several lines if autowrap works at all."},
			{"type": "text", "name": "B", "pos": Vector2(22, 200), "size": 20, "color": "#d4af37", "height": 90, "width": 340, "align": "center",
				"text": "The same sentence again, this time with a height also given, which should not change the wrapping at all."},
			{"type": "text", "name": "C", "pos": Vector2(22, 360), "size": 20, "width": 340, "align": "center", "color": "#4fd8ff",
				"text": "বিক্রমপুরে জন্ম। বেতার তরঙ্গ নিয়ে প্রথম পরীক্ষাগুলোর একজন, আর উদ্ভিদের প্রাণ ও সাড়া নিয়ে গবেষণার জনক।"},
		],
	}
	jobs.append({"id": "wraptest", "spec": wrap_spec})
	_inspect_wrap(wrap_spec)

	for job: Dictionary in jobs:
		var tex: ImageTexture = await baker.bake(job["spec"], job["id"])
		if tex == null:
			print("PREVIEW: %s FAILED" % job["id"])
			continue
		var path: String = "user://captures/preview_%s.png" % job["id"]
		var err: Error = tex.get_image().save_png(path)
		print("PREVIEW: %s -> %s (%s)" % [job["id"], path, error_string(err)])
	dressing.free()
	quit()


func _inspect_wrap(spec: Dictionary) -> void:
	## Builds the spec into a live SignCanvas and prints each label's size against
	## its minimum size, which is what decides whether wrapping works.
	var canvas_script: Script = load("res://scripts/core/sign_canvas.gd")
	var canvas: Control = canvas_script.new()
	root.add_child(canvas)
	canvas.setup(spec)
	await process_frame
	for child: Node in canvas.get_children():
		if child is Label:
			var l: Label = child
			print("WRAP: %-4s size=%s min=%s lines=%d" % [
				String(l.name), str(l.size), str(l.get_combined_minimum_size()),
				l.get_line_count()])
	canvas.queue_free()


func _read_array(path: String) -> Array:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("bake_preview: cannot read %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if typeof(parsed) == TYPE_ARRAY else []
