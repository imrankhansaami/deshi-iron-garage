extends SceneTree
## Headless parse/compile validator. Loads every .gd in the project and reports
## compile failures, so the build stays honest without needing a GPU.
##
## Usage:  godot --headless --path . -s res://tests/validate_scripts.gd

var _files: PackedStringArray = PackedStringArray()
var _index: int = 0
var _errors: Array[String] = []
var _ok: int = 0


func _initialize() -> void:
	_scan("res://")
	_files.sort()
	print("VALIDATE: %d scripts found" % _files.size())


func _scan(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = path.path_join(name)
		if dir.current_is_dir():
			_scan(full)
		elif name.ends_with(".gd"):
			_files.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _process(_delta: float) -> bool:
	var budget: int = 0
	while _index < _files.size() and budget < 6:
		var f: String = _files[_index]
		_index += 1
		budget += 1
		var script: Script = load(f) as Script
		if script == null:
			_errors.append("%s  -> could not load" % f)
			continue
		if not script.can_instantiate():
			_errors.append("%s  -> compile error" % f)
			continue
		_ok += 1
	if _index >= _files.size():
		_report()
		return true
	return false


func _report() -> void:
	print("VALIDATE: %d ok, %d failed" % [_ok, _errors.size()])
	for e: String in _errors:
		print("  FAIL %s" % e)
	if _errors.is_empty():
		print("VALIDATE: CLEAN")
	else:
		print("VALIDATE: DIRTY")
