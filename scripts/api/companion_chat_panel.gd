extends Control

signal chat_closed

@export var chat_endpoint: String = "http://127.0.0.1:8000/chat"
@export_range(10.0, 180.0, 1.0) var request_timeout: float = 90.0
@export_range(0.1, 5.0, 0.1) var retry_delay: float = 0.75

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var history: RichTextLabel = $Panel/Margin/VBox/History
@onready var message_input: LineEdit = $Panel/Margin/VBox/Composer/MessageInput
@onready var send_button: Button = $Panel/Margin/VBox/Composer/SendButton
@onready var close_button: Button = $Panel/Margin/VBox/CloseButton
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var health_request: HTTPRequest = $HealthRequest

var _companion_id: StringName
var _display_name: String = "Companion"
var _request_in_flight: bool = false
var _health_check_in_flight: bool = false
var _health_ready: bool = false
var _active_payload: String = ""
var _active_request_started_msec: int = 0
var _active_request_started_at: String = ""
var _retry_count: int = 0
var _request_sequence: int = 0
var _conversation_input_enabled: bool = true


func _ready() -> void:
	visible = false
	http_request.timeout = request_timeout
	health_request.timeout = 5.0
	send_button.pressed.connect(_send_message)
	close_button.pressed.connect(close_conversation)
	message_input.text_submitted.connect(_on_text_submitted)
	http_request.request_completed.connect(_on_request_completed)
	health_request.request_completed.connect(_on_health_completed)


func open_conversation(request: Dictionary) -> void:
	_reset_transport_state()
	_conversation_input_enabled = true
	_companion_id = request.get("companion_id", &"")
	_display_name = String(request.get("display_name", "Companion"))
	if not _companion_id.is_empty():
		_display_name = String(_companion_id).capitalize()
	title_label.text = _display_name
	visible = true
	message_input.grab_focus()
	_start_health_check()


func open_npc_conversation(
	request: Dictionary,
	initial_text: String,
	continued_conversation_available: bool,
	limitation: String = ""
) -> void:
	_reset_transport_state()
	_companion_id = request.get("companion_id", &"")
	_display_name = String(request.get("display_name", "NPC"))
	_conversation_input_enabled = continued_conversation_available
	title_label.text = _display_name
	history.clear()
	visible = true
	if not initial_text.strip_edges().is_empty():
		_append_history(_display_name, initial_text)
	if not continued_conversation_available and not limitation.strip_edges().is_empty():
		history.append_text("[color=gray][i]%s[/i][/color]\n\n" % limitation)
	message_input.placeholder_text = "Conversation unavailable" if not continued_conversation_available else "Message %s..." % _display_name
	if continued_conversation_available:
		message_input.grab_focus()
		_start_health_check()
	else:
		_update_composer_state()


func close_conversation() -> void:
	if _request_in_flight:
		http_request.cancel_request()
	if _health_check_in_flight:
		health_request.cancel_request()
	_reset_transport_state()
	visible = false
	message_input.release_focus()
	chat_closed.emit()


func _start_health_check() -> void:
	_health_check_in_flight = true
	_health_ready = false
	_update_composer_state()
	var health_url := chat_endpoint.trim_suffix("/chat") + "/"
	_log_diagnostic("health_start", {"url": health_url, "already_active": _request_in_flight})
	var error := health_request.request(health_url)
	if error != OK:
		_health_check_in_flight = false
		_append_connection_error("Health check could not start: %s." % error_string(error))
		_log_diagnostic("health_start_error", {"url": health_url, "error": error_string(error)})
		_update_composer_state()


func _on_health_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_health_check_in_flight = false
	_health_ready = result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300
	_log_diagnostic("health_complete", {
		"result": result,
		"result_name": _request_result_name(result),
		"http_status": response_code,
		"body": body.get_string_from_utf8(),
	})
	if not _health_ready:
		_append_connection_error("PNE health check failed: %s (HTTP %d)." % [_request_result_name(result), response_code])
	_update_composer_state()


func _send_message() -> void:
	var message := message_input.text.strip_edges()
	_log_diagnostic("submission_attempt", {
		"url": chat_endpoint,
		"already_active": _request_in_flight,
		"health_ready": _health_ready,
		"companion_id": String(_companion_id),
	})
	if message.is_empty() or _request_in_flight or not _health_ready:
		return
	_append_history("You", message)
	message_input.clear()
	_retry_count = 0
	_active_payload = JSON.stringify({"companion_id": String(_companion_id), "message": message})
	_start_chat_request(false)


func _start_chat_request(is_retry: bool) -> void:
	_request_sequence += 1
	_active_request_started_msec = Time.get_ticks_msec()
	_active_request_started_at = Time.get_datetime_string_from_system(true, true)
	_set_request_pending(true)
	_log_diagnostic("request_start", {
		"request_id": _request_sequence,
		"url": chat_endpoint,
		"start_time_utc": _active_request_started_at,
		"retry": is_retry,
		"retry_count": _retry_count,
		"already_active": false,
		"payload": _active_payload,
	})
	var error := http_request.request(chat_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, _active_payload)
	if error != OK:
		_log_diagnostic("request_start_error", {"request_id": _request_sequence, "error": error_string(error)})
		_append_connection_error("Could not start request: %s." % error_string(error))
		_set_request_pending(false)


func _on_text_submitted(_text: String) -> void:
	_send_message()


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var completed_at := Time.get_datetime_string_from_system(true, true)
	var elapsed_msec := Time.get_ticks_msec() - _active_request_started_msec
	var body_text := body.get_string_from_utf8()
	_log_diagnostic("request_complete", {
		"request_id": _request_sequence,
		"url": chat_endpoint,
		"start_time_utc": _active_request_started_at,
		"completion_time_utc": completed_at,
		"elapsed_msec": elapsed_msec,
		"result": result,
		"result_name": _request_result_name(result),
		"http_status": response_code,
		"response_body": body_text,
	})

	if result != HTTPRequest.RESULT_SUCCESS:
		if _is_retryable_connection_result(result) and _retry_count < 1 and visible:
			_retry_count += 1
			_log_diagnostic("request_retry_scheduled", {"request_id": _request_sequence, "delay_seconds": retry_delay})
			await get_tree().create_timer(retry_delay).timeout
			if visible and _request_in_flight:
				_start_chat_request(true)
			return
		_append_connection_error("PNE request failed: %s (%d)." % [_request_result_name(result), result])
		_set_request_pending(false)
		return

	var parser := JSON.new()
	var parse_error := parser.parse(body_text)
	if parse_error != OK:
		_log_diagnostic("response_parse_error", {
			"request_id": _request_sequence,
			"error": parser.get_error_message(),
			"line": parser.get_error_line(),
			"body": body_text,
		})
		_append_connection_error("PNE returned invalid JSON: %s." % parser.get_error_message())
		_set_request_pending(false)
		return

	var parsed = parser.data
	if response_code < 200 or response_code >= 300:
		var detail := str(parsed.get("detail", "HTTP %d" % response_code)) if parsed is Dictionary else "HTTP %d" % response_code
		_append_connection_error(detail)
		_set_request_pending(false)
		return
	if not parsed is Dictionary or not parsed.has("response"):
		_append_connection_error("PNE returned an invalid chat response.")
		_set_request_pending(false)
		return
	_append_history(_display_name, str(parsed["response"]))
	_set_request_pending(false)


func _append_history(speaker: String, message: String) -> void:
	history.append_text("[b]%s:[/b] %s\n\n" % [speaker, message])
	history.scroll_to_line(history.get_line_count())


func _append_connection_error(message: String) -> void:
	history.append_text("[color=red][b]Connection error:[/b] %s[/color]\n\n" % message)


func _set_request_pending(pending: bool) -> void:
	_request_in_flight = pending
	_update_composer_state()


func _update_composer_state() -> void:
	var composer_ready := visible and _conversation_input_enabled and _health_ready and not _request_in_flight
	send_button.disabled = not composer_ready
	message_input.editable = composer_ready


func _reset_transport_state() -> void:
	_request_in_flight = false
	_health_check_in_flight = false
	_health_ready = false
	_active_payload = ""
	_active_request_started_msec = 0
	_active_request_started_at = ""
	_retry_count = 0
	_update_composer_state()


func _is_retryable_connection_result(result: int) -> bool:
	return result in [
		HTTPRequest.RESULT_CANT_CONNECT,
		HTTPRequest.RESULT_CANT_RESOLVE,
		HTTPRequest.RESULT_CONNECTION_ERROR,
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR,
		HTTPRequest.RESULT_NO_RESPONSE,
		HTTPRequest.RESULT_TIMEOUT,
	]


func _request_result_name(result: int) -> String:
	var names := {
		HTTPRequest.RESULT_SUCCESS: "SUCCESS",
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: "CHUNKED_BODY_SIZE_MISMATCH",
		HTTPRequest.RESULT_CANT_CONNECT: "CANT_CONNECT",
		HTTPRequest.RESULT_CANT_RESOLVE: "CANT_RESOLVE",
		HTTPRequest.RESULT_CONNECTION_ERROR: "CONNECTION_ERROR",
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: "TLS_HANDSHAKE_ERROR",
		HTTPRequest.RESULT_NO_RESPONSE: "NO_RESPONSE",
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: "BODY_SIZE_LIMIT_EXCEEDED",
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: "BODY_DECOMPRESS_FAILED",
		HTTPRequest.RESULT_REQUEST_FAILED: "REQUEST_FAILED",
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: "DOWNLOAD_FILE_CANT_OPEN",
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: "DOWNLOAD_FILE_WRITE_ERROR",
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: "REDIRECT_LIMIT_REACHED",
		HTTPRequest.RESULT_TIMEOUT: "TIMEOUT",
	}
	return names.get(result, "UNKNOWN_RESULT")


func _log_diagnostic(event_name: String, details: Dictionary) -> void:
	var record := details.duplicate()
	record["event"] = event_name
	record["logged_at_utc"] = Time.get_datetime_string_from_system(true, true)
	print("[ExplorerChat] ", JSON.stringify(record))
