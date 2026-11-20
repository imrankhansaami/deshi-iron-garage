class_name Interactable
extends Node3D
## Base class for every interactive object in the garage.
##
## An interactable is a *description* plus two hooks. It never owns gameplay
## logic beyond reporting whether it is currently usable, so the same prompt,
## highlight and logging path serves the shutter, the switchboard, a spanner on
## the bench and the exosuit core.
##
## The object exposes:
##   id            stable key, used for inspection bookkeeping and saves
##   prompt        the contextual text shown under the crosshair
##   primary       the action E performs ("open", "toggle", "read", "assemble")
##   inspectable   whether F opens a detail panel
##   requires      a predicate on GameState (power on, component held, ...)
##
## Collision is expected to come from a child CollisionShape3D or Area3D; the ray
## in Player walks up to the first ancestor that is an Interactable.

signal hovered(target: Interactable)
signal unhovered(target: Interactable)
signal interacted(target: Interactable, action: String)
signal inspected(target: Interactable)
signal prompt_changed(target: Interactable, text: String)

enum Availability { ALWAYS, NEEDS_POWER, NEEDS_COMPONENT, NEEDS_COMPUTER, LOCKED }

@export var id: String = ""
@export var display_name: String = ""
@export var prompt: String = "Press E to interact"
@export var inspect_prompt: String = "Press F to inspect"
@export var primary_action: String = "use"
@export var inspectable: bool = false
@export var area: StringName = &""
@export var availability: Availability = Availability.ALWAYS
@export var required_component: String = ""
@export var repeatable: bool = true
@export var sfx: String = "tool_place"
@export var sfx_db: float = 0.0
@export var description: String = ""
@export var lore: String = ""
@export var spec_rows: Array = []
@export var max_distance: float = 3.4

var _hovered: bool = false
var _used_once: bool = false


func _ready() -> void:
	if id == "":
		id = name.to_snake_case()
	set_process(false)


## Called by the interaction ray every frame the target is under the crosshair.
func set_hover(state: bool) -> void:
	if state == _hovered:
		return
	_hovered = state
	if state:
		hovered.emit(self)
		EventBus.interactable_hovered.emit(self)
	else:
		unhovered.emit(self)
		EventBus.interactable_unhovered.emit(self)


func is_hovered() -> bool:
	return _hovered


func is_available() -> bool:
	match availability:
		Availability.NEEDS_POWER:
			return GameState.power_on
		Availability.NEEDS_COMPUTER:
			return GameState.computer_on
		Availability.NEEDS_COMPONENT:
			return GameState.has_component(required_component)
		Availability.LOCKED:
			return false
		_:
			return true


func availability_reason() -> String:
	match availability:
		Availability.NEEDS_POWER:
			return "no power"
		Availability.NEEDS_COMPUTER:
			return "workstation offline"
		Availability.NEEDS_COMPONENT:
			return "missing %s" % GameConfig.component_short(required_component)
		Availability.LOCKED:
			return "sealed"
		_:
			return ""


func current_prompt() -> String:
	if not is_available():
		var reason: String = availability_reason()
		return "%s   ·   %s" % [prompt, reason] if reason != "" else prompt
	return prompt


## The E action. Override in subclasses; return true to consume the input.
func interact(player: Node) -> bool:
	if not is_available():
		AudioBank.play("ui_error", -4.0)
		EventBus.notification_requested.emit(
			"%s : %s" % [display_name if display_name != "" else id, availability_reason()],
			"warning",
		)
		return false
	if not repeatable and _used_once:
		return false
	_used_once = true
	if sfx != "":
		AudioBank.play_at(sfx, global_position, sfx_db)
	_primary(player)
	interacted.emit(self, primary_action)
	EventBus.interaction_performed.emit(self, primary_action)
	GameState.mark_inspected(id)
	return true


func _primary(_player: Node) -> void:
	pass


## The F action: opens the inspection panel. Returns the payload the panel shows.
func inspect(player: Node) -> Dictionary:
	if not inspectable:
		return {}
	_inspect(player)
	inspected.emit(self)
	GameState.mark_inspected(id)
	EventBus.interaction_performed.emit(self, "inspect")
	return {
		"id": id,
		"title": display_name if display_name != "" else id,
		"body": description,
		"lore": lore,
		"spec": spec_rows,
		"area": String(area),
	}


func _inspect(_player: Node) -> void:
	pass


func mark_used() -> void:
	_used_once = true


func was_used() -> bool:
	return _used_once


## Bounding box used by the reticle and by the ray's distance test.
func bounds() -> AABB:
	var aabb := AABB(global_position - Vector3.ONE * 0.12, Vector3.ONE * 0.24)
	for child: Node in get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh != null:
				aabb = aabb.merge(mi.global_transform * mi.get_aabb())
		elif child is StaticBody3D or child is Area3D:
			var sub: AABB = _collect_aabb(child)
			if sub.has_volume():
				aabb = aabb.merge(sub)
	return aabb


func _collect_aabb(node: Node) -> AABB:
	var out := AABB()
	for c: Node in node.get_children():
		if c is CollisionShape3D:
			var cs: CollisionShape3D = c as CollisionShape3D
			if cs.shape != null:
				out = out.merge(cs.global_transform * ShapeKit.shape_aabb_local(cs.shape))
		elif c is MeshInstance3D:
			var mi2: MeshInstance3D = c as MeshInstance3D
			if mi2.mesh != null:
				out = out.merge(mi2.global_transform * mi2.get_aabb())
	return out


## Finds the Interactable that owns `node`, walking up the tree.
static func from_node(node: Node) -> Interactable:
	var current: Node = node
	while current != null:
		if current is Interactable:
			return current as Interactable
		current = current.get_parent()
	return null
