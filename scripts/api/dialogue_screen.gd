extends Control

signal chat_closed
signal local_action_requested(action: StringName, actor_id: StringName)

const PNEBackend = preload("res://scripts/api/pne_backend.gd")
const FALLBACK_UNAVAILABLE := "The conversation service could not be reached. Check the local PNE backend and try again."
const PROFILE_UNAVAILABLE := "Character conversation profile not yet available."
const GENERIC_OPENING := "What's on your mind?"

const GENERIC_SUGGESTIONS: Array[Dictionary] = [
	{"label": "How are things going?", "spoken_line": "How are things going?"},
	{"label": "Tell me about yourself.", "spoken_line": "Tell me about yourself."},
	{"label": "What are you working on?", "spoken_line": "What are you working on?"},
	{"label": "I’ll let you get back to it.", "spoken_line": "I’ll let you get back to it."},
]

const ACCENT_THEMES := {
	"silver": Color(0.80, 0.83, 0.88, 1.0),
	"navy": Color(0.42, 0.58, 0.82, 1.0),
	"cyan": Color(0.34, 0.82, 0.90, 1.0),
	"pink": Color(0.94, 0.48, 0.70, 1.0),
	"monochrome": Color(0.78, 0.78, 0.80, 1.0),
	"red": Color(0.90, 0.34, 0.34, 1.0),
	"blue": Color(0.46, 0.68, 0.90, 1.0),
	"teal": Color(0.36, 0.78, 0.74, 1.0),
	"amber": Color(0.90, 0.66, 0.32, 1.0),
	"green": Color(0.52, 0.78, 0.46, 1.0),
	"gold": Color(0.93, 0.78, 0.36, 1.0),
}

const PLAYER_PROFILE := {
	"display_name": "Rue",
	"accent": Color(0.93, 0.78, 0.36, 1.0),
}

const DEFAULT_ACCENT := Color(0.80, 0.83, 0.88, 1.0)
const DEFAULT_BORDER := Color(0.55, 0.59, 0.66, 1.0)
const RESPONSE_NORMAL_BG := Color(0.08, 0.09, 0.13, 0.98)
const RESPONSE_HOVER_BG := Color(0.12, 0.14, 0.18, 1.0)
const RESPONSE_PRESSED_BG := Color(0.10, 0.11, 0.15, 1.0)
const RESPONSE_DISABLED_BG := Color(0.05, 0.06, 0.08, 0.72)

@export var chat_endpoint: String = ""
@export var default_player_id: String = "player_dxs_ninja"
@export var default_location_id: String = "headquarters_foyer"
@export_range(0.0, 100.0, 1.0) var default_relationship_value: float = 70.0
@export var default_relationship_label: String = "Trusted"
@export var request_timeout: float = 45.0
@export_range(0.1, 3.0, 0.1) var retry_delay: float = 0.75

@onready var dimmer: ColorRect = $WorldDimmer
@onready var main_frame: PanelContainer = $MainFrame
@onready var speaker_name: Label = $MainFrame/FrameMargin/RootVBox/TopIdentityBar/SpeakerName
@onready var speaker_role: Label = $MainFrame/FrameMargin/RootVBox/TopIdentityBar/SpeakerRole
@onready var relationship_status: Label = $MainFrame/FrameMargin/RootVBox/TopIdentityBar/RelationshipStatus
@onready var relationship_meter: ProgressBar = $MainFrame/FrameMargin/RootVBox/TopIdentityBar/RelationshipMeter
@onready var connection_badge: Label = $MainFrame/FrameMargin/RootVBox/TopIdentityBar/ConnectionBadge
@onready var portrait_frame: PanelContainer = $MainFrame/FrameMargin/RootVBox/BodyColumns/PortraitPanel/PortraitMargin/PortraitVBox/PortraitFrame
@onready var metadata_text: RichTextLabel = $MainFrame/FrameMargin/RootVBox/BodyColumns/InfoPanel/InfoMargin/InfoVBox/MetadataText
@onready var portrait_placeholder: Label = $MainFrame/FrameMargin/RootVBox/BodyColumns/PortraitPanel/PortraitMargin/PortraitVBox/PortraitFrame/PortraitStack/PortraitPlaceholder
@onready var actor_portrait: TextureRect = $MainFrame/FrameMargin/RootVBox/BodyColumns/PortraitPanel/PortraitMargin/PortraitVBox/PortraitFrame/PortraitStack/ActorPortrait
@onready var dialogue_scroll: ScrollContainer = $MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/DialogueScroll
@onready var conversation_log: RichTextLabel = $MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/DialogueScroll/ConversationLog
@onready var suggestion_chips: GridContainer = $MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/SuggestionChips
@onready var suggestion_buttons: Array[Button] = [
	$MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/SuggestionChips/Reply1,
	$MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/SuggestionChips/Reply2,
	$MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/SuggestionChips/Reply3,
	$MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/SuggestionChips/Reply4,
]
@onready var composer: HBoxContainer = $MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/Composer
@onready var message_input: LineEdit = $MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/Composer/MessageInput
@onready var send_button: Button = $MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/Composer/SendButton
@onready var close_button: Button = $MainFrame/FrameMargin/RootVBox/BodyColumns/ConversationPanel/ConversationMargin/ConversationVBox/LowerConversation/Composer/CloseButton
@onready var footer_controls: Label = $MainFrame/FrameMargin/RootVBox/FooterControls
@onready var status_line: Label = $MainFrame/FrameMargin/RootVBox/StatusLine

var _http_request: HTTPRequest
var _request_in_flight: bool = false
var _retry_count: int = 0
var _conversation_config: Dictionary = {}
var _current_request: Dictionary = {}
var _current_actor_id: StringName = &""
var _current_display_name: String = "Dialogue"
var _current_portrait_texture: Texture2D
var _current_portrait_expression: String = "neutral"
var _relationship_value: float = 70.0
var _active_message: String = ""
var _pending_input_text: String = ""
var _request_started_msec: int = 0
var _request_started_at: String = ""
var _visible_suggestions: Array = []


func _ready() -> void:
	if chat_endpoint.strip_edges().is_empty():
		chat_endpoint = PNEBackend.chat_url()
	visible = false
	dimmer.color.a = 0.0
	_setup_http()
	_connect_controls()
	_apply_ui_theme()
	_configure_theme_resources()
	_configure_portraits()
	_apply_layout()
	_hide_suggestions()
	_update_composer_state()
	_log_debug_endpoint("ready")


func open_conversation(request: Dictionary) -> void:
	_open_dialogue(request, true, "")
	_append_configured_opening()


func open_npc_conversation(request: Dictionary, initial_text: String, continued_conversation_available: bool, limitation: String = "") -> void:
	_open_dialogue(request, continued_conversation_available, limitation)
	if not initial_text.strip_edges().is_empty():
		_append_npc_line(_display_name_from_request(request), initial_text, true)
	else:
		_append_configured_opening()


func _append_configured_opening() -> void:
	var opening_line: String = String(_conversation_config.get("opening_line", GENERIC_OPENING)).strip_edges()
	if not opening_line.is_empty():
		_append_npc_line(_current_display_name, opening_line, true)


func close_conversation() -> void:
	if _request_in_flight and is_instance_valid(_http_request):
		_http_request.cancel_request()
	_reset_transport_state()
	visible = false
	chat_closed.emit()


func _open_dialogue(request: Dictionary, allow_input: bool, limitation: String) -> void:
	_reset_transport_state()
	_current_request = request.duplicate(true)
	_conversation_config = _resolve_conversation_config(request)
	_current_actor_id = StringName(_conversation_config.get("actor_id", "unknown"))
	_current_display_name = String(_conversation_config.get("display_name", "Unknown Character"))
	_current_portrait_expression = String(_conversation_config.get("default_expression", "neutral"))
	_relationship_value = _resolve_relationship_value(request)
	visible = true
	modulate.a = 1.0
	_apply_ui_theme()
	_apply_runtime_context()
	_set_state_label(String(request.get("conversation_state", "conversation_open")))
	_set_title(_current_display_name)
	_set_speaker_portrait(_current_actor_id, _current_portrait_expression)
	conversation_log.clear()
	if not limitation.strip_edges().is_empty():
		_append_system_line(limitation)
	_configure_suggestions()
	if not allow_input:
		_hide_suggestions()
	_set_composer_enabled(allow_input)
	_fade_world_dimmer(true)
	message_input.grab_focus()
	_update_metadata_panel("", false)


func _connect_controls() -> void:
	close_button.pressed.connect(close_conversation)
	send_button.pressed.connect(_send_message_from_input)
	message_input.text_changed.connect(_on_message_text_changed)
	message_input.text_submitted.connect(_on_text_submitted)
	for index in suggestion_buttons.size():
		suggestion_buttons[index].pressed.connect(_on_suggestion_pressed.bind(index))
		suggestion_buttons[index].disabled = true
	_http_request = HTTPRequest.new()
	_http_request.timeout = request_timeout
	_http_request.request_completed.connect(_on_request_completed)
	add_child(_http_request)


func _setup_http() -> void:
	pass


func _configure_portraits() -> void:
	actor_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	actor_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_portrait.clip_contents = false
	actor_portrait.modulate.a = 1.0
	portrait_placeholder.modulate = Color(0.58, 0.62, 0.70, 1.0)
	actor_portrait.visible = false
	portrait_placeholder.visible = true


func _configure_suggestions() -> void:
	var replies_value: Variant = _current_request.get("suggestions", _conversation_config.get("suggestions", GENERIC_SUGGESTIONS))
	var replies: Array = []
	if replies_value is Array:
		replies = replies_value.duplicate(true)
	if bool(_conversation_config.get("can_follow", false)):
		var is_following: bool = bool(_conversation_config.get("is_following", false))
		replies.push_front({
			"label": "Stop following" if is_following else "Follow me",
			"local_action": "toggle_follow",
		})
	_visible_suggestions.clear()
	for index in mini(replies.size(), suggestion_buttons.size()):
		_visible_suggestions.append(replies[index])
	if _visible_suggestions.is_empty():
		suggestion_chips.visible = false
		for button in suggestion_buttons:
			button.visible = false
			button.disabled = true
		return
	for index in suggestion_buttons.size():
		var button := suggestion_buttons[index]
		if index >= _visible_suggestions.size():
			button.visible = false
			button.disabled = true
			continue
		var reply_value: Variant = _visible_suggestions[index]
		var reply: Dictionary = reply_value if reply_value is Dictionary else {}
		button.visible = true
		button.disabled = _request_in_flight
		button.text = String(reply.get("label", "Suggestion"))
	_update_suggestion_visibility()


func _set_composer_enabled(enabled: bool) -> void:
	message_input.editable = enabled and visible
	send_button.disabled = not enabled or not visible or message_input.text.strip_edges().is_empty()
	for button in suggestion_buttons:
		button.disabled = not enabled or not visible
	_update_suggestion_visibility()


func _update_composer_state() -> void:
	_set_composer_enabled(visible and not _request_in_flight)


func _on_text_submitted(_text: String) -> void:
	_send_message_from_input()


func _send_message_from_input() -> void:
	if _request_in_flight:
		return
	var message := message_input.text.strip_edges()
	if message.is_empty():
		return
	_send_message(message)


func _on_suggestion_pressed(index: int) -> void:
	if index < 0 or index >= _visible_suggestions.size():
		return
	var reply_value: Variant = _visible_suggestions[index]
	var reply: Dictionary = reply_value if reply_value is Dictionary else {}
	var local_action: StringName = StringName(reply.get("local_action", ""))
	if not local_action.is_empty():
		local_action_requested.emit(local_action, _current_actor_id)
		return
	var raw_message: Variant = reply.get("spoken_line", reply.get("message", reply.get("label", "")))
	var message: String = str(raw_message).strip_edges()
	if message.is_empty():
		return
	message_input.text = message
	message_input.caret_column = 0
	_update_send_button_state()
	_update_suggestion_visibility()
	message_input.grab_focus()


func set_follow_action_state(is_following: bool, feedback: String) -> void:
	_conversation_config["is_following"] = is_following
	if not feedback.strip_edges().is_empty():
		_append_system_line(feedback, true)
	_configure_suggestions()


func _send_message(message: String) -> void:
	if _request_in_flight or message.strip_edges().is_empty():
		return
	_request_in_flight = true
	_retry_count = 0
	_active_message = message
	_pending_input_text = message_input.text
	_request_started_msec = Time.get_ticks_msec()
	_request_started_at = Time.get_datetime_string_from_system(true, true)
	_append_player_line(message)
	_set_speaker_portrait(&"player")
	_set_state_label("sending")
	status_line.text = "%s is thinking..." % _current_display_name
	status_line.visible = true
	_set_composer_enabled(false)
	var payload := _build_payload(message)
	_log_dialogue_post()
	var error := _http_request.request(
		chat_endpoint,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_handle_transport_failure(FALLBACK_UNAVAILABLE)
		return
	_log_debug_endpoint("request_started")


func _build_payload(message: String) -> Dictionary:
	var payload := {
		"actor_id": String(_current_actor_id),
		"player_id": String(_current_request.get("player_id", default_player_id)),
		"location_id": String(_current_request.get("location_id", default_location_id)),
		"interaction_action": String(_current_request.get(
			"interaction_action",
			_conversation_config.get("interaction_action", _current_request.get("chronicle_action", "")),
		)),
		"message": message,
		"runtime_context": _build_runtime_context(),
	}
	if _should_include_chronicle_context():
		var chronicle_id := String(_current_request.get("chronicle_id", ""))
		if not chronicle_id.strip_edges().is_empty():
			payload["chronicle_id"] = chronicle_id
		var journey_id := String(_current_request.get("journey_id", ""))
		if not journey_id.strip_edges().is_empty():
			payload["journey_id"] = journey_id
	return payload


func _build_runtime_context() -> Dictionary:
	var runtime_context: Dictionary = {
		"interaction_source": "godot_dialogue_ui",
		"actor_id": String(_current_actor_id),
		"display_name": _current_display_name,
	}
	var extra: Variant = _current_request.get("runtime_context", {})
	if extra is Dictionary:
		for key in extra.keys():
			if _should_filter_runtime_context_key(key):
				continue
			runtime_context[key] = extra[key]
	if _should_include_chronicle_context():
		var scene_id := String(_current_request.get("scene_id", ""))
		if not scene_id.strip_edges().is_empty():
			runtime_context["scene_id"] = scene_id
	return runtime_context


func _should_include_chronicle_context() -> bool:
	return bool(_current_request.get("include_chronicle_context", false))


func _should_filter_runtime_context_key(key: Variant) -> bool:
	if _should_include_chronicle_context():
		return false
	return key == "scene_id" or key == "chronicle_id" or key == "journey_id"


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var body_text := body.get_string_from_utf8()
	_log_request_completion(result, response_code, body_text)
	if result != HTTPRequest.RESULT_SUCCESS:
		if _is_retryable_result(result) and _retry_count < 1 and visible:
			_retry_count += 1
			await get_tree().create_timer(retry_delay).timeout
			if visible and _request_in_flight:
				_retry_chat_request()
			return
		_handle_transport_failure(FALLBACK_UNAVAILABLE)
		return
	if response_code == 404:
		_handle_profile_unavailable()
		return
	var parser := JSON.new()
	if parser.parse(body_text) != OK:
		_handle_transport_failure(FALLBACK_UNAVAILABLE)
		return
	var parsed_value: Variant = parser.data
	if response_code < 200 or response_code >= 300 or not parsed_value is Dictionary:
		_handle_transport_failure(FALLBACK_UNAVAILABLE)
		return
	var parsed: Dictionary = parsed_value
	var response_text: String = _extract_reply(parsed)
	var portrait_expression := String(parsed.get("portrait_expression", "neutral"))
	var accent_theme := String(parsed.get("accent_theme", _conversation_config.get("accent_theme", "silver")))
	var conversation_state: String = str(parsed.get("conversation_state", "conversation_open"))
	var relationship_delta: int = int(parsed.get("relationship_delta", 0))
	var quest_updates_value: Variant = parsed.get("quest_updates", [])
	var quest_updates: Array = quest_updates_value if quest_updates_value is Array else []
	var memory_receipt_value: Variant = parsed.get("memory_receipt", null)
	var memory_available: bool = memory_receipt_value != null or not quest_updates.is_empty()
	_set_state_label(conversation_state)
	_apply_response_theme(accent_theme)
	_set_speaker_portrait(_current_actor_id, portrait_expression)
	_append_npc_line(response_text)
	status_line.text = ""
	status_line.visible = false
	_request_in_flight = false
	_update_composer_state()
	_current_request["conversation_state"] = conversation_state
	_current_request["relationship_delta"] = relationship_delta
	_current_request["quest_updates"] = quest_updates
	_current_request["memory_receipt"] = memory_receipt_value
	_current_request["portrait_expression"] = portrait_expression
	if parsed.has("suggestions"):
		var suggestions_value: Variant = parsed.get("suggestions", [])
		_current_request["suggestions"] = suggestions_value if suggestions_value is Array else []
	_update_metadata_panel(conversation_state, memory_available)
	message_input.clear()
	_pending_input_text = ""
	_configure_suggestions()
	_set_composer_enabled(true)


func _retry_chat_request() -> void:
	if not _request_in_flight:
		return
	_request_started_msec = Time.get_ticks_msec()
	_request_started_at = Time.get_datetime_string_from_system(true, true)
	var payload := _build_payload(_active_message)
	if String(payload.get("message", "")).is_empty():
		_request_in_flight = false
		return
	_log_dialogue_post()
	var error := _http_request.request(
		chat_endpoint,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_handle_transport_failure(FALLBACK_UNAVAILABLE)
		return
	_log_debug_endpoint("request_retry")


func _handle_transport_failure(message: String) -> void:
	_request_in_flight = false
	_set_state_label("connection_unavailable")
	connection_badge.text = "Connection unavailable"
	status_line.text = message
	status_line.visible = true
	_append_connection_failure(message)
	_set_speaker_portrait(_current_actor_id, _current_portrait_expression)
	_update_composer_state()
	_set_composer_enabled(true)
	if not _pending_input_text.is_empty():
		message_input.text = _pending_input_text
		message_input.caret_column = _pending_input_text.length()
	_update_send_button_state()


func _handle_profile_unavailable() -> void:
	_request_in_flight = false
	_set_state_label("unavailable")
	status_line.text = PROFILE_UNAVAILABLE
	status_line.visible = true
	_append_system_line(PROFILE_UNAVAILABLE)
	_set_speaker_portrait(_current_actor_id, _current_portrait_expression)
	_set_composer_enabled(true)
	if not _pending_input_text.is_empty():
		message_input.text = _pending_input_text
		message_input.caret_column = _pending_input_text.length()
	_update_send_button_state()


func _extract_reply(parsed: Dictionary) -> String:
	for key in [&"reply", &"response", &"narrative"]:
		var value := String(parsed.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return FALLBACK_UNAVAILABLE


func _resolve_actor_id(request: Dictionary) -> StringName:
	var config_value: Variant = request.get("conversation_config", {})
	if config_value is Dictionary:
		var configured: String = String(config_value.get("actor_id", "")).strip_edges()
		if not configured.is_empty():
			return StringName(configured)
	var explicit := String(request.get("actor_id", ""))
	if not explicit.is_empty():
		return StringName(explicit)
	var companion := String(request.get("companion_id", ""))
	if not companion.is_empty():
		return StringName(companion)
	return &"unknown"


func _resolve_conversation_config(request: Dictionary) -> Dictionary:
	var config_value: Variant = request.get("conversation_config", {})
	var config: Dictionary = {}
	if config_value is Dictionary:
		config = config_value.duplicate(true)
	var actor_id: String = String(config.get("actor_id", _resolve_actor_id(request))).strip_edges()
	if actor_id.is_empty():
		actor_id = "unknown"
	var display_name: String = String(config.get("display_name", request.get("display_name", ""))).strip_edges()
	if display_name.is_empty():
		display_name = actor_id.replace("_", " ").capitalize()
	var interaction_action: String = String(config.get(
		"interaction_action",
		request.get("interaction_action", request.get("chronicle_action", "")),
	)).strip_edges()
	var suggestions_value: Variant = config.get("suggestions", [])
	var suggestions: Array = suggestions_value if suggestions_value is Array else []
	if suggestions.is_empty():
		suggestions = GENERIC_SUGGESTIONS.duplicate(true)
	config["actor_id"] = actor_id
	config["display_name"] = display_name
	config["role"] = String(config.get("role", "Night Division Member"))
	config["faction"] = String(config.get("faction", "Night Division"))
	config["interaction_action"] = interaction_action
	config["portrait_root"] = String(config.get("portrait_root", ""))
	config["default_expression"] = String(config.get("default_expression", "neutral"))
	config["accent_theme"] = String(config.get("accent_theme", "navy"))
	config["opening_line"] = String(config.get("opening_line", GENERIC_OPENING))
	config["suggestions"] = suggestions
	return config


func _portrait_texture_for_actor(actor_id: StringName, expression: String) -> Texture2D:
	var paths_value: Variant = _conversation_config.get("portrait_paths", {})
	var paths: Dictionary = {}
	if paths_value is Dictionary:
		paths = paths_value
	var requested_path: String = String(paths.get(expression, ""))
	if requested_path.is_empty():
		requested_path = _portrait_path_from_root(actor_id, expression)
	var requested_texture: Texture2D = _load_texture(requested_path)
	if requested_texture != null:
		return requested_texture
	var neutral_path: String = String(paths.get("neutral", ""))
	if neutral_path.is_empty():
		neutral_path = _portrait_path_from_root(actor_id, "neutral")
	var neutral_texture: Texture2D = _load_texture(neutral_path)
	if neutral_texture == null:
		push_warning(
			"Dialogue portrait missing: actor_id=%s expression=neutral path=%s"
			% [String(actor_id), neutral_path if not neutral_path.is_empty() else "<unconfigured>"]
		)
	return neutral_texture


func _portrait_path_from_root(actor_id: StringName, expression: String) -> String:
	var root: String = String(_conversation_config.get("portrait_root", "")).strip_edges()
	if root.is_empty():
		return ""
	if not root.ends_with("/"):
		root += "/"
	return "%s%s_%s.png" % [root, String(actor_id), expression]


func _load_texture(path: String) -> Texture2D:
	if path.strip_edges().is_empty():
		return null
	if not ResourceLoader.exists(path, "Texture2D"):
		return null
	return load(path) as Texture2D


func _apply_ui_theme() -> void:
	var accent: Color = _accent_for_theme(String(_conversation_config.get("accent_theme", "silver")))
	var background := Color(0.05, 0.07, 0.10, 0.97)
	var border := Color(accent.r * 0.7, accent.g * 0.7, accent.b * 0.7, 1.0)
	_apply_panel_style(main_frame, background, border)
	_apply_panel_style(portrait_frame, Color(0.08, 0.1, 0.14, 0.98), border)
	_apply_progress_theme(relationship_meter, border, accent)
	speaker_name.modulate = accent
	speaker_role.modulate = Color(0.72, 0.77, 0.84, 1.0)
	relationship_status.modulate = Color(0.84, 0.87, 0.92, 1.0)
	connection_badge.modulate = Color(0.72, 0.74, 0.8, 1.0)
	metadata_text.modulate = Color(0.84, 0.88, 0.95, 1.0)
	conversation_log.modulate = Color(0.93, 0.95, 0.98, 1.0)
	status_line.modulate = Color(0.82, 0.84, 0.9, 1.0)
	footer_controls.modulate = Color(0.72, 0.74, 0.8, 1.0)
	close_button.modulate = Color(0.95, 0.95, 0.98, 1.0)
	send_button.modulate = PLAYER_PROFILE.get("accent", Color.WHITE)
	for button in suggestion_buttons:
		_style_response_button(button, accent, border)


func _configure_theme_resources() -> void:
	_apply_progress_theme(relationship_meter, DEFAULT_BORDER, DEFAULT_ACCENT)
	for button in suggestion_buttons:
		_style_response_button(button, DEFAULT_ACCENT, DEFAULT_BORDER)


func _apply_response_theme(accent_name: String) -> void:
	var configured_theme: String = String(_conversation_config.get("accent_theme", "silver"))
	var resolved_theme: String = accent_name if ACCENT_THEMES.has(accent_name) else configured_theme
	var accent: Color = _accent_for_theme(resolved_theme)
	speaker_name.modulate = accent
	send_button.modulate = PLAYER_PROFILE.get("accent", Color.WHITE)
	for button in suggestion_buttons:
		_style_response_button(button, accent, DEFAULT_BORDER)


func _accent_for_theme(theme_name: String) -> Color:
	var accent_value: Variant = ACCENT_THEMES.get(theme_name, DEFAULT_ACCENT)
	if accent_value is Color:
		return accent_value
	return DEFAULT_ACCENT


func _apply_panel_style(panel: Control, background: Color, border: Color) -> void:
	if panel == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override(&"panel", style)


func _append_system_line(text: String, force_follow: bool = false) -> void:
	if text.strip_edges().is_empty():
		return
	var should_follow: bool = force_follow or _is_transcript_near_bottom()
	conversation_log.append_text("[color=#93a0b3][i]%s[/i][/color]\n\n" % text)
	if should_follow:
		_queue_scroll_transcript_to_bottom()


func _append_npc_line(speaker_or_text: String, text: String = "", force_follow: bool = false) -> void:
	var message: String = speaker_or_text
	if not text.strip_edges().is_empty():
		message = text
	if message.strip_edges().is_empty():
		return
	var should_follow: bool = force_follow or _is_transcript_near_bottom()
	conversation_log.append_text("[color=#d9e3f1]%s[/color]\n\n" % message)
	if should_follow:
		_queue_scroll_transcript_to_bottom()


func _append_player_line(text: String) -> void:
	conversation_log.append_text("[color=#f0ca6a][b]You:[/b] %s[/color]\n\n" % text)
	_queue_scroll_transcript_to_bottom()


func _is_transcript_near_bottom() -> bool:
	if not is_instance_valid(dialogue_scroll):
		return true
	var scrollbar: VScrollBar = dialogue_scroll.get_v_scroll_bar()
	if scrollbar == null:
		return true
	var bottom_value: float = maxf(scrollbar.min_value, scrollbar.max_value - scrollbar.page)
	return bottom_value - scrollbar.value <= 12.0


func _queue_scroll_transcript_to_bottom() -> void:
	call_deferred("_scroll_transcript_to_bottom")


func _scroll_transcript_to_bottom() -> void:
	await get_tree().process_frame
	if not visible or not is_instance_valid(dialogue_scroll):
		return
	var scrollbar: VScrollBar = dialogue_scroll.get_v_scroll_bar()
	if scrollbar != null:
		scrollbar.value = scrollbar.max_value


func _hide_suggestions() -> void:
	suggestion_chips.visible = false
	for button in suggestion_buttons:
		button.visible = false
		button.disabled = true


func _set_title(text: String) -> void:
	speaker_name.text = text


func _set_state_label(text: String) -> void:
	var normalized: String = text.strip_edges().to_lower()
	if normalized in ["failed", "unavailable", "connection_unavailable"]:
		connection_badge.text = "Connection unavailable"
	else:
		connection_badge.text = ""
	connection_badge.visible = not connection_badge.text.is_empty()
	status_line.visible = not status_line.text.is_empty() or normalized == "connection_unavailable"


func _set_speaker_portrait(speaker: StringName, expression: String = "neutral") -> void:
	if speaker == &"player":
		return
	var texture := _portrait_texture_for_actor(_current_actor_id, expression)
	if texture != null:
		_current_portrait_texture = texture
	else:
		_current_portrait_texture = null
	actor_portrait.texture = _current_portrait_texture
	actor_portrait.visible = _current_portrait_texture != null
	actor_portrait.modulate.a = 1.0
	portrait_placeholder.visible = _current_portrait_texture == null
	portrait_placeholder.text = String(_conversation_config.get("faction", "Dialogue")).to_upper()
	speaker_name.text = _current_display_name
	speaker_role.text = String(_conversation_config.get("role", "Night Division Member"))
	relationship_status.text = _relationship_label()


func _fade_world_dimmer(show: bool) -> void:
	var target_alpha := 0.68 if show else 0.0
	var tween := create_tween()
	tween.tween_property(dimmer, "color:a", target_alpha, 0.25)


func _apply_runtime_context() -> void:
	status_line.text = ""
	_update_metadata_panel(String(_current_request.get("conversation_state", "")), false)


func _reset_transport_state() -> void:
	_request_in_flight = false
	_active_message = ""
	_pending_input_text = ""
	_retry_count = 0
	_visible_suggestions.clear()
	status_line.text = ""
	status_line.visible = false
	message_input.clear()
	_set_composer_enabled(false)
	_hide_suggestions()
	dimmer.color.a = 0.0
	connection_badge.text = ""
	connection_badge.visible = false
	status_line.text = ""
	if is_instance_valid(actor_portrait):
		_current_portrait_texture = null
		_current_portrait_expression = "neutral"
		actor_portrait.texture = null
		actor_portrait.visible = false
		actor_portrait.modulate.a = 1.0
	if is_instance_valid(portrait_placeholder):
		portrait_placeholder.visible = true


func _display_name_from_request(request: Dictionary) -> String:
	var config_value: Variant = request.get("conversation_config", {})
	if config_value is Dictionary:
		var configured: String = String(config_value.get("display_name", "")).strip_edges()
		if not configured.is_empty():
			return configured
	var explicit := String(request.get("display_name", "")).strip_edges()
	if not explicit.is_empty():
		return explicit
	return _current_display_name


func _apply_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		return
	var frame_width: float = viewport_size.x * 0.90
	var frame_height: float = viewport_size.y * 0.90
	main_frame.size = Vector2(frame_width, frame_height)
	main_frame.position = Vector2((viewport_size.x - frame_width) * 0.5, (viewport_size.y - frame_height) * 0.5)
	portrait_frame.custom_minimum_size = Vector2(frame_width * 0.24, 0.0)
	conversation_log.custom_minimum_size = Vector2(frame_width * 0.48, 0.0)
	speaker_name.add_theme_font_size_override(&"font_size", int(maxf(19.0, viewport_size.y * 0.036)))
	speaker_role.add_theme_font_size_override(&"font_size", int(maxf(12.0, viewport_size.y * 0.020)))
	relationship_status.add_theme_font_size_override(&"font_size", int(maxf(10.0, viewport_size.y * 0.016)))
	conversation_log.add_theme_font_size_override(&"normal_font_size", int(maxf(12.0, viewport_size.y * 0.020)))
	footer_controls.add_theme_font_size_override(&"font_size", int(maxf(9.0, viewport_size.y * 0.014)))
	status_line.add_theme_font_size_override(&"font_size", int(maxf(9.0, viewport_size.y * 0.014)))
	for button in suggestion_buttons:
		button.custom_minimum_size = Vector2(0, 18.0)
		button.add_theme_font_size_override(&"font_size", int(maxf(10.0, viewport_size.y * 0.016)))
		button.focus_mode = Control.FOCUS_ALL
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.modulate = _accent_for_theme(String(_conversation_config.get("accent_theme", "silver")))
		_style_response_button(button, button.modulate, DEFAULT_BORDER)
	_update_send_button_state()


func _update_metadata_panel(conversation_state: String, memory_available: bool) -> void:
	if String(conversation_state).strip_edges().is_empty():
		conversation_state = "conversation_open"
	var lines: PackedStringArray = []
	lines.append("[color=#cfd7e6]Location:[/color] The Meridian - Headquarters Foyer")
	lines.append("[color=#cfd7e6]Faction:[/color] %s" % String(_conversation_config.get("faction", "Night Division")))
	lines.append("[color=#cfd7e6]Relationship:[/color] %s (%d%%)" % [_relationship_label(), int(round(_relationship_value))])
	lines.append("[color=#cfd7e6]Conversation:[/color] %s" % conversation_state)
	if memory_available:
		lines.append("[color=#cfd7e6]Memory:[/color] Available")
	metadata_text.text = "\n".join(lines)


func _append_connection_failure(text: String) -> void:
	var should_follow: bool = _is_transcript_near_bottom()
	conversation_log.append_text("[color=#b7a57a][b]Connection unavailable[/b][/color]\n[color=#9aa1ad]%s[/color]\n\n" % text)
	if should_follow:
		_queue_scroll_transcript_to_bottom()


func _log_debug_endpoint(event_name: String) -> void:
	if not OS.is_debug_build():
		return
	print("[DialogueScreen] event=%s endpoint=%s timeout=%.1f request_in_flight=%s" % [
		event_name,
		chat_endpoint,
		request_timeout,
		_request_in_flight,
	])


func _log_request_completion(result: int, response_code: int, body_text: String) -> void:
	if not OS.is_debug_build():
		return
	var elapsed := Time.get_ticks_msec() - _request_started_msec if _request_started_msec > 0 else 0
	print("[DialogueScreen] endpoint=%s result=%d status=%d elapsed_msec=%d body_bytes=%d" % [
		chat_endpoint,
		result,
		response_code,
		elapsed,
		body_text.length(),
	])


func _log_dialogue_post() -> void:
	if not OS.is_debug_build():
		return
	print("REALMS dialogue POST: %s" % chat_endpoint)


func _apply_progress_theme(bar: ProgressBar, border: Color, fill: Color) -> void:
	if bar == null:
		return
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	background.border_color = border
	background.border_width_left = 1
	background.border_width_top = 1
	background.border_width_right = 1
	background.border_width_bottom = 1
	background.corner_radius_top_left = 4
	background.corner_radius_top_right = 4
	background.corner_radius_bottom_left = 4
	background.corner_radius_bottom_right = 4
	var foreground := StyleBoxFlat.new()
	foreground.bg_color = fill
	foreground.corner_radius_top_left = 4
	foreground.corner_radius_top_right = 4
	foreground.corner_radius_bottom_left = 4
	foreground.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override(&"background", background)
	bar.add_theme_stylebox_override(&"fill", foreground)
	bar.max_value = 100.0
	bar.value = _relationship_value
	bar.tooltip_text = "%s (%d%%)" % [_relationship_label(), int(round(_relationship_value))]


func _style_response_button(button: Button, accent: Color, border: Color) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.toggle_mode = false
	button.flat = false
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_constant_override(&"content_margin_left", 8)
	button.add_theme_constant_override(&"content_margin_right", 8)
	button.add_theme_constant_override(&"content_margin_top", 2)
	button.add_theme_constant_override(&"content_margin_bottom", 2)
	var normal := StyleBoxFlat.new()
	normal.bg_color = RESPONSE_NORMAL_BG
	normal.border_color = border
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	var hover := normal.duplicate()
	hover.bg_color = RESPONSE_HOVER_BG
	hover.border_color = accent
	var pressed := normal.duplicate()
	pressed.bg_color = RESPONSE_PRESSED_BG
	pressed.border_color = accent
	var disabled := normal.duplicate()
	disabled.bg_color = RESPONSE_DISABLED_BG
	disabled.border_color = Color(0.35, 0.36, 0.40, 0.85)
	button.add_theme_stylebox_override(&"normal", normal)
	button.add_theme_stylebox_override(&"hover", hover)
	button.add_theme_stylebox_override(&"pressed", pressed)
	button.add_theme_stylebox_override(&"focus", hover)
	button.add_theme_stylebox_override(&"disabled", disabled)


func _on_message_text_changed(_new_text: String) -> void:
	_update_send_button_state()
	_update_suggestion_visibility()


func _update_suggestion_visibility() -> void:
	var has_visible_suggestion: bool = false
	for button in suggestion_buttons:
		if button.visible:
			has_visible_suggestion = true
			break
	suggestion_chips.visible = (
		has_visible_suggestion
		and visible
		and message_input.editable
		and not _request_in_flight
		and message_input.text.strip_edges().is_empty()
	)


func _update_send_button_state() -> void:
	send_button.disabled = _request_in_flight or not visible or message_input.text.strip_edges().is_empty()
	send_button.focus_mode = Control.FOCUS_ALL


func _relationship_label() -> String:
	var label := default_relationship_label.strip_edges()
	if label.is_empty():
		return "Trusted"
	return label


func _resolve_relationship_value(request: Dictionary) -> float:
	var value: float = default_relationship_value
	if request.has("relationship_value"):
		value = float(request.get("relationship_value", value))
	elif request.has("relationship_meter"):
		value = float(request.get("relationship_meter", value))
	return clampf(value, 0.0, 100.0)


func _is_retryable_result(result: int) -> bool:
	return result in [
		HTTPRequest.RESULT_CANT_CONNECT,
		HTTPRequest.RESULT_CANT_RESOLVE,
		HTTPRequest.RESULT_CONNECTION_ERROR,
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
		HTTPRequest.RESULT_NO_RESPONSE,
		HTTPRequest.RESULT_TIMEOUT,
	]
