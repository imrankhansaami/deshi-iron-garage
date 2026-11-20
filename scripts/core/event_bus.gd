extends Node
class_name EventBusSingleton
## Global signal hub. Systems communicate through these signals instead of
## hard references, keeping the garage modules independently replaceable
## (see docs/SYSTEM_ARCHITECTURE.md, "Decoupling strategy").

# --- progression -----------------------------------------------------------
signal power_state_changed(is_on: bool)
signal computer_state_changed(is_on: bool)
signal shutter_state_changed(is_open: bool)
signal objective_changed(objective_id: String, text: String)
signal component_collected(component_id: String)
signal assembly_stage_changed(stage: int, stage_name: String)
signal prototype_activated()

# --- interaction -----------------------------------------------------------
signal interactable_hovered(target: Node3D)
signal interactable_unhovered(target: Node3D)
signal interaction_performed(target: Node3D, action_name: String)
signal ui_panel_opened(panel_name: String)
signal ui_panel_closed(panel_name: String)

# --- presentation ----------------------------------------------------------
signal notification_requested(message: String, tone: String)
signal subtitle_requested(speaker: String, text: String, duration: float)
