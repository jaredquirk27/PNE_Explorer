extends Area2D

signal interaction_available(interactable: Area2D, request: Dictionary)
signal interaction_unavailable(interactable: Area2D)
signal interaction_activated(request: Dictionary)
signal interaction_cancelled(interaction_id: StringName)

@export var interaction_id: StringName
@export var interaction_type: StringName
@export var display_name: String = "Interactable"
@export var prompt_text: String = "Interact"
@export var companion_id: StringName
@export_multiline var chronicle_action: String = ""
@export var continued_conversation_available: bool = true
@export_multiline var conversation_unavailable_message: String = ""
@export var conversation_config: Dictionary = {}
@export_file("*.tscn") var destination_scene_path: String = ""
@export var destination_spawn_id: StringName = &"default"
@export_enum("south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east") var destination_facing: String = "south"
@export var enabled: bool = true

var _actor_in_range: CharacterBody2D


func _ready() -> void:
	add_to_group(&"interactables")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func activate(actor: CharacterBody2D) -> void:
	if not enabled or actor == null or actor != _actor_in_range:
		return
	interaction_activated.emit(get_interaction_request())


func cancel() -> void:
	interaction_cancelled.emit(interaction_id)


func get_interaction_request() -> Dictionary:
	var request: Dictionary = {
		"actor_path": get_parent().get_path(),
		"interaction_id": interaction_id,
		"interaction_type": interaction_type,
		"display_name": display_name,
		"prompt_text": prompt_text,
		"companion_id": companion_id,
		"chronicle_action": chronicle_action,
		"continued_conversation_available": continued_conversation_available,
		"conversation_unavailable_message": conversation_unavailable_message,
		"destination_scene_path": destination_scene_path,
		"destination_spawn_id": destination_spawn_id,
		"destination_facing": destination_facing,
	}
	if not conversation_config.is_empty():
		request["conversation_config"] = conversation_config.duplicate(true)
		request["actor_id"] = StringName(conversation_config.get("actor_id", companion_id))
		request["interaction_action"] = String(conversation_config.get("interaction_action", chronicle_action))
		request["location_id"] = String(conversation_config.get("location_id", ""))
	return request


func set_interaction_enabled(value: bool) -> void:
	enabled = value
	if not enabled and _actor_in_range != null:
		interaction_unavailable.emit(self)


func _on_body_entered(body: Node2D) -> void:
	if not enabled or not body is CharacterBody2D:
		return
	if body.get(&"actor_id") != &"player":
		return
	_actor_in_range = body as CharacterBody2D
	interaction_available.emit(self, get_interaction_request())


func _on_body_exited(body: Node2D) -> void:
	if body != _actor_in_range:
		return
	_actor_in_range = null
	interaction_unavailable.emit(self)
