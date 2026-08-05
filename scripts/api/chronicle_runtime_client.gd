extends Node

signal action_completed(response: Dictionary)
signal action_failed(message: String)

@export var campaign_endpoint: String = "http://127.0.0.1:8000/campaign/action"
@export var chronicle_id: String = "chronicle_0001"

var _session: Dictionary = {
	"chronicle_id": "chronicle_0001",
	"active_companion": "rue",
	"companions": ["rue"],
	"relationship_state": {},
}
var _request_in_flight: bool = false
var _http_request: HTTPRequest
var _known_scene_id: String = ""
var _known_scene_title: String = ""


func _ready() -> void:
	_http_request = HTTPRequest.new()
	_http_request.timeout = 90.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)


func submit_action(action: String) -> bool:
	if _request_in_flight or action.strip_edges().is_empty():
		return false
	_request_in_flight = true
	var payload := {
		"campaign": chronicle_id,
		"player_action": action,
		"story_state": "Act I",
		"quest_state": "Witness the summoning.",
		"current_scene": _session.get("currentScene", "Arrival at Hadeshorn"),
		"current_objective": _session.get("currentObjective", "Witness the summoning."),
		"current_location": _session.get("currentLocation", "Hadeshorn"),
		"party": [],
		"recent_events": [],
		"world_flags": {},
		"rpg_dial": 1.0,
		"session": _session,
	}
	if _known_scene_title.is_empty():
		_known_scene_title = String(payload["current_scene"])
	var error := _http_request.request(
		campaign_endpoint,
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_request_in_flight = false
		action_failed.emit("Chronicle request could not start: %s" % error_string(error))
		return false
	print("[CoglineInteraction] submitted campaign action")
	return true


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		print("[CoglineInteraction] response status=%d transport_result=%d" % [response_code, result])
		action_failed.emit("Chronicle request failed (HTTP %d)." % response_code)
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		action_failed.emit("Chronicle returned invalid JSON.")
		return
	var response_keys: Array = parsed.keys()
	response_keys.sort()
	var scene_id := String(parsed.get("chronicle_scene_id", ""))
	var scene_title := String(parsed.get("current_scene", parsed.get("chronicle_scene_title", "")))
	var scene_transitioned := (
		not _known_scene_id.is_empty() and not scene_id.is_empty() and scene_id != _known_scene_id
	) or (
		_known_scene_id.is_empty() and not _known_scene_title.is_empty() and not scene_title.is_empty() and scene_title != _known_scene_title
	)
	parsed["_scene_transitioned"] = scene_transitioned
	parsed["_previous_scene_id"] = _known_scene_id
	parsed["_previous_scene_title"] = _known_scene_title
	if not scene_id.is_empty():
		_known_scene_id = scene_id
	if not scene_title.is_empty():
		_known_scene_title = scene_title
	var dialogue_found := not String(parsed.get("narrative", "")).strip_edges().is_empty()
	print("[CoglineInteraction] response status=%d keys=%s" % [response_code, response_keys])
	print("[CoglineInteraction] dialogue_found=%s scene_transition=%s" % [dialogue_found, scene_transitioned])
	if parsed.get("session") is Dictionary:
		_session = parsed["session"]
	_session["currentScene"] = parsed.get("current_scene", _session.get("currentScene", ""))
	_session["currentObjective"] = parsed.get("current_objective", _session.get("currentObjective", ""))
	_session["currentLocation"] = parsed.get("current_location", _session.get("currentLocation", ""))
	action_completed.emit(parsed)
