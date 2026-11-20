class_name EnumRef
extends RefCounted
## Reads an engine enum ordinal by label from a property's hint string.
##
## Most rendering enums are exposed as class constants and are used directly.
## A few — Environment.TonemapMode being the notable one — are not reachable as
## constants in this engine build, and their ordinals have shifted between minor
## versions. Resolving by label against the live property metadata means the
## project keeps the intended mode across upgrades instead of silently selecting
## a different one, and it degrades to a documented fallback with a warning
## rather than to a wrong-looking render that nobody notices.

static func value(owner: Object, property: String, label: String, fallback: int = 0) -> int:
	if owner == null:
		return fallback
	for p: Dictionary in owner.get_property_list():
		if String(p.get("name", "")) != property:
			continue
		return _ordinal(p, label, fallback)
	push_warning("EnumRef: no property '%s' on %s" % [property, owner.get_class()])
	return fallback


static func _ordinal(p: Dictionary, label: String, fallback: int) -> int:
	var hint_string: String = String(p.get("hint_string", ""))
	if hint_string.is_empty():
		push_warning("EnumRef: '%s' has no hint string, using %d" % [label, fallback])
		return fallback
	var want: String = label.strip_edges().to_lower()
	var parts: PackedStringArray = hint_string.split(",")
	for i: int in range(parts.size()):
		var entry: String = parts[i].strip_edges()
		if entry.to_lower() == want:
			return i
		if entry.contains(":"):
			var kv: PackedStringArray = entry.split(":")
			if String(kv[0]).strip_edges().to_lower() == want:
				return int(kv[1])
	push_warning("EnumRef: '%s' not in [%s], using fallback %d" % [label, hint_string, fallback])
	return fallback


## The only enum the garage genuinely needs this for.
static func tonemap(env: Environment, label: String = "AgX") -> int:
	# 2 == Filmic, the previous stable default, used if AgX is absent.
	return value(env, "tonemap_mode", label, 2)
