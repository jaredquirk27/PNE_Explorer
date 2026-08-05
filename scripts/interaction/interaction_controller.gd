extends Node

@export var player_path: NodePath
@export var input_adapter_path: NodePath
@export var prompt_path: NodePath
@export var chat_panel_path: NodePath
@export var chronicle_client_path: NodePath

var _player: CharacterBody2D
var _input_adapter: Node
var _prompt: Label
var _chat_panel: Control
var _chronicle_client: Node
var _current_interactable: Area2D
var _chronicle_pending: bool = false
var _active_interaction_request: Dictionary = {}
var _active_npc: CharacterBody2D
var _completed_story_interactions: Dictionary = {}
var _cached_interaction_narrative: Dictionary = {}
var _pending_transition_title: String = ""
var _available_interactables: Dictionary = {}


func _ready() -> void:
	_player = get_node_or_null(player_path) as CharacterBody2D
	_input_adapter = get_node_or_null(input_adapter_path)
	_prompt = get_node_or_null(prompt_path) as Label
	_chat_panel = get_node_or_null(chat_panel_path) as Control
	_chronicle_client = get_node_or_null(chronicle_client_path)
	if _player == null or _input_adapter == null or _prompt == null or _chat_panel == null or _chronicle_client == null:
		push_error("InteractionController could not resolve its required dependencies.")
		return

	_input_adapter.interact_requested.connect(_on_interact_requested)
	_chat_panel.chat_closed.connect(_on_chat_closed)
	_chronicle_client.action_completed.connect(_on_chronicle_action_completed)
	_chronicle_client.action_failed.connect(_on_chronicle_action_failed)
	call_deferred("_connect_interactables")
	_hide_prompt()


func _connect_interactables() -> void:
	for interactable in get_tree().get_nodes_in_group(&"interactables"):
		interactable.interaction_available.connect(_on_interaction_available)
		interactable.interaction_unavailable.connect(_on_interaction_unavailable)
		interactable.interaction_activated.connect(_on_interaction_activated)
		interactable.interaction_cancelled.connect(_on_interaction_cancelled)


func _on_interaction_available(interactable: Area2D, _request: Dictionary) -> void:
	_available_interactables[interactable.get_instance_id()] = interactable
	if _chat_panel.visible:
		return
	_refresh_current_interactable()


func _on_interaction_unavailable(interactable: Area2D) -> void:
	_available_interactables.erase(interactable.get_instance_id())
	_refresh_current_interactable()


func _on_interact_requested() -> void:
	if _current_interactable != null and not _chat_panel.visible:
		_current_interactable.activate(_player)


func _on_interaction_activated(request: Dictionary) -> void:
	if request.get("interaction_type") == &"advance_chronicle":
		if _chronicle_pending:
			return
		_active_interaction_request = request
		_active_npc = get_node_or_null(NodePath(request.get("actor_path", ""))) as CharacterBody2D
		var actor_id := String(_active_npc.get("actor_id")) if _active_npc != null else "unknown"
		print("[CoglineInteraction] interaction detected actor_id=%s" % actor_id)
		_face_active_npc_to_player()
		var interaction_id := String(request.get("interaction_id", ""))
		if _completed_story_interactions.get(interaction_id, false):
			_open_npc_conversation(String(_cached_interaction_narrative.get(interaction_id, "")))
			return
		_chronicle_pending = true
		_hide_prompt()
		_input_adapter.set_movement_enabled(false)
		var action := String(request.get("chronicle_action", ""))
		print("[CoglineInteraction] campaign action=%s" % action)
		if not _chronicle_client.submit_action(action):
			_on_chronicle_action_failed("Chronicle request was not submitted.")
		return
	if request.get("interaction_type") != &"open_companion_chat":
		push_warning("Unsupported interaction type: %s" % request.get("interaction_type"))
		return
	_hide_prompt()
	_input_adapter.set_movement_enabled(false)
	_chat_panel.open_conversation(request)


func _on_chronicle_action_completed(response: Dictionary) -> void:
	_chronicle_pending = false
	var narrative := String(response.get("narrative", "")).strip_edges()
	var interaction_id := String(_active_interaction_request.get("interaction_id", ""))
	_completed_story_interactions[interaction_id] = true
	_cached_interaction_narrative[interaction_id] = narrative
	if bool(response.get("_scene_transitioned", false)):
		_pending_transition_title = String(response.get("current_scene", response.get("chronicle_scene_title", "")))
	print("[CoglineInteraction] scene_transition=%s" % bool(response.get("_scene_transitioned", false)))
	_open_npc_conversation(narrative)


func _on_chronicle_action_failed(message: String) -> void:
	_chronicle_pending = false
	_input_adapter.set_movement_enabled(true)
	_return_active_npc_to_idle()
	_prompt.text = message
	_prompt.visible = true
	print("[CoglineInteraction] interaction ended with error=%s" % message)


func _on_chat_closed() -> void:
	_input_adapter.set_movement_enabled(true)
	_return_active_npc_to_idle()
	print("[CoglineInteraction] interaction ended")
	if not _pending_transition_title.is_empty():
		_show_transition_toast(_pending_transition_title)
		_pending_transition_title = ""
		return
	if _current_interactable != null:
		var request: Dictionary = _current_interactable.get_interaction_request()
		_prompt.text = "[E] %s" % request.get("prompt_text", "Interact")
		_prompt.visible = true


func _open_npc_conversation(narrative: String) -> void:
	_hide_prompt()
	_input_adapter.set_movement_enabled(false)
	var conversation_available := bool(_active_interaction_request.get("continued_conversation_available", false))
	var limitation := String(_active_interaction_request.get("conversation_unavailable_message", ""))
	if narrative.is_empty():
		limitation = "The campaign response did not contain narrative or NPC dialogue. " + limitation
	_chat_panel.open_npc_conversation(_active_interaction_request, narrative, conversation_available, limitation)
	print("[CoglineInteraction] conversation UI opened dialogue_found=%s" % (not narrative.is_empty()))


func _face_active_npc_to_player() -> void:
	if _active_npc != null and _active_npc.has_method(&"face_toward"):
		_active_npc.call(&"face_toward", _player.global_position)


func _return_active_npc_to_idle() -> void:
	if _active_npc != null and _active_npc.has_method(&"return_to_idle"):
		_active_npc.call(&"return_to_idle")
	_active_npc = null
	_active_interaction_request = {}


func _on_interaction_cancelled(_interaction_id: StringName) -> void:
	_chronicle_pending = false
	_input_adapter.set_movement_enabled(true)
	_return_active_npc_to_idle()
	print("[CoglineInteraction] interaction cancelled")


func _show_transition_toast(scene_title: String) -> void:
	_prompt.text = scene_title
	_prompt.visible = true
	await get_tree().create_timer(2.0).timeout
	if _current_interactable != null and not _chat_panel.visible:
		var request: Dictionary = _current_interactable.get_interaction_request()
		_prompt.text = "[E] %s" % request.get("prompt_text", "Interact")
	else:
		_hide_prompt()


func _hide_prompt() -> void:
	_prompt.visible = false


func _refresh_current_interactable() -> void:
	_current_interactable = null
	var nearest_distance := INF
	for candidate in _available_interactables.values():
		if not is_instance_valid(candidate):
			continue
		var distance := _player.global_position.distance_squared_to((candidate as Area2D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			_current_interactable = candidate as Area2D
	if _current_interactable == null or _chat_panel.visible:
		_hide_prompt()
		return
	var request: Dictionary = _current_interactable.get_interaction_request()
	_prompt.text = "[E] %s" % request.get("prompt_text", "Interact")
	_prompt.visible = true
