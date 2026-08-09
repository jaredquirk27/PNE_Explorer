extends RefCounted

class_name ComfyUIClient

const PNEBackend = preload("res://scripts/api/pne_backend.gd")

const DEFAULT_BASE_URL := "http://127.0.0.1:8188"
const DEFAULT_CHECKPOINT := "Realistic Vision 6.0.safetensors"
const DEFAULT_WIDTH := 512
const DEFAULT_HEIGHT := 512
const DEFAULT_BATCH_SIZE := 1
const DEFAULT_STEPS := 18
const DEFAULT_CFG := 6.0
const DEFAULT_SAMPLER := "euler"
const DEFAULT_SCHEDULER := "simple"
const DEFAULT_DENOISE := 1.0
const MIN_DIMENSION := 64
const MAX_DIMENSION := 2048

var base_url: String = ""
var checkpoint: String = ""
var request_timeout: float = 60.0
var poll_interval: float = 0.5
var max_poll_attempts: int = 120
var http_client: Object


func _init(config: Dictionary = {}, transport: Object = null) -> void:
	base_url = _configured_base_url(config)
	checkpoint = _configured_checkpoint(config)
	request_timeout = float(config.get("request_timeout", request_timeout))
	poll_interval = float(config.get("poll_interval", poll_interval))
	max_poll_attempts = int(config.get("max_poll_attempts", max_poll_attempts))
	http_client = transport if transport != null else _create_default_transport()


func generate_image(prompt: String, negative_prompt: String = "", width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT) -> ImageGenerationResult:
	var result := ImageGenerationResult.new()
	var sanitized_prompt := String(prompt).strip_edges()
	if sanitized_prompt.is_empty():
		result.error = "Prompt cannot be empty."
		return result
	var safe_width := _clamp_dimension(width)
	var safe_height := _clamp_dimension(height)
	if safe_width <= 0 or safe_height <= 0:
		result.error = "Requested image size is outside supported bounds."
		return result

	var workflow := _build_workflow(sanitized_prompt, negative_prompt.strip_edges(), safe_width, safe_height)
	var submitted := _post_json("%s/prompt" % base_url, {"prompt": workflow})
	if submitted.error != "":
		result.error = submitted.error
		return result
	var prompt_id := String(submitted.body.get("prompt_id", ""))
	if prompt_id.is_empty():
		result.error = "ComfyUI returned no prompt_id."
		return result
	result.prompt_id = prompt_id

	var history := _wait_for_history(prompt_id)
	if history.error != "":
		result.error = history.error
		return result
	var image_meta := _extract_image_metadata(history.body, prompt_id)
	if image_meta.is_empty():
		result.error = "ComfyUI completed without producing an image."
		return result

	result.success = true
	result.filename = String(image_meta.get("filename", ""))
	result.subfolder = String(image_meta.get("subfolder", ""))
	result.output_type = String(image_meta.get("type", "output"))
	result.image_path = _image_path(result.subfolder, result.filename)
	return result


func build_workflow(prompt: String, negative_prompt: String = "", width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT) -> Dictionary:
	var safe_width := _clamp_dimension(width)
	var safe_height := _clamp_dimension(height)
	if safe_width <= 0 or safe_height <= 0 or String(prompt).strip_edges().is_empty():
		return {}
	return _build_workflow(String(prompt).strip_edges(), String(negative_prompt).strip_edges(), safe_width, safe_height)


func _build_workflow(prompt: String, negative_prompt: String, width: int, height: int) -> Dictionary:
	return {
		"1": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": checkpoint}},
		"2": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": prompt}},
		"3": {"class_type": "CLIPTextEncode", "inputs": {"clip": ["1", 1], "text": negative_prompt}},
		"4": {"class_type": "EmptyLatentImage", "inputs": {"batch_size": DEFAULT_BATCH_SIZE, "height": height, "width": width}},
		"5": {"class_type": "KSampler", "inputs": {
			"cfg": DEFAULT_CFG,
			"denoise": DEFAULT_DENOISE,
			"latent_image": ["4", 0],
			"model": ["1", 0],
			"negative": ["3", 0],
			"noise_seed": 0,
			"sampler_name": DEFAULT_SAMPLER,
			"scheduler": DEFAULT_SCHEDULER,
			"positive": ["2", 0],
			"steps": DEFAULT_STEPS,
		}},
		"6": {"class_type": "VAEDecode", "inputs": {"samples": ["5", 0], "vae": ["1", 2]}},
		"7": {"class_type": "SaveImage", "inputs": {"filename_prefix": "pne", "images": ["6", 0]}},
	}


func _wait_for_history(prompt_id: String) -> Dictionary:
	var attempt := 0
	while attempt < max_poll_attempts:
		var response := _get_json("%s/history/%s" % [base_url, prompt_id])
		if response.error != "":
			return response
		if response.body is Dictionary and response.body.has(prompt_id):
			return {"error": "", "body": response.body[prompt_id]}
		await _sleep(poll_interval)
		attempt += 1
	return {"error": "Timed out waiting for ComfyUI result.", "body": {}}


func _extract_image_metadata(history_payload: Variant, prompt_id: String) -> Dictionary:
	if not (history_payload is Dictionary):
		return {}
	var outputs: Variant = history_payload.get("outputs", {})
	if not (outputs is Dictionary):
		return {}
	for node_id in outputs.keys():
		var node_output: Variant = outputs[node_id]
		if not (node_output is Dictionary):
			continue
		var images: Variant = node_output.get("images", [])
		if not (images is Array):
			continue
		for image in images:
			if image is Dictionary and String(image.get("type", "output")) != "":
				return image
	return {}


func _post_json(url: String, payload: Dictionary) -> Dictionary:
	return _request_json(url, HTTPClient.METHOD_POST, payload)


func _get_json(url: String) -> Dictionary:
	return _request_json(url, HTTPClient.METHOD_GET, null)


func _request_json(url: String, method: int, payload: Variant) -> Dictionary:
	var body := ""
	var headers := PackedStringArray()
	if payload != null:
		headers = PackedStringArray(["Content-Type: application/json"])
		body = JSON.stringify(payload)
	var response := await http_client.request_json(url, method, headers, body, request_timeout)
	if response.error != "":
		return response
	if not (response.body is Dictionary):
		return {"error": "ComfyUI returned an invalid response.", "body": {}}
	return response


func _clamp_dimension(value: int) -> int:
	if value < MIN_DIMENSION or value > MAX_DIMENSION:
		return -1
	return value


func _image_path(subfolder: String, filename: String) -> String:
	if subfolder.strip_edges().is_empty():
		return filename
	return "%s/%s" % [subfolder, filename]


func _configured_base_url(config: Dictionary) -> String:
	var configured := String(config.get("base_url", "")).strip_edges()
	if configured.is_empty():
		configured = String(ProjectSettings.get_setting("application/config/comfyui_base_url", "")).strip_edges()
	if configured.is_empty():
		configured = OS.get_environment("COMFYUI_BASE_URL").strip_edges()
	if configured.is_empty():
		configured = DEFAULT_BASE_URL
	return configured.trim_suffix("/")


func _configured_checkpoint(config: Dictionary) -> String:
	var configured := String(config.get("checkpoint", "")).strip_edges()
	if configured.is_empty():
		configured = String(ProjectSettings.get_setting("application/config/comfyui_checkpoint", "")).strip_edges()
	if configured.is_empty():
		configured = OS.get_environment("COMFYUI_CHECKPOINT").strip_edges()
	if configured.is_empty():
		configured = DEFAULT_CHECKPOINT
	return configured


func _create_default_transport() -> Object:
	return ComfyUIHTTPTransport.new()


func _sleep(seconds: float) -> void:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		await tree.create_timer(seconds).timeout
		return


class ComfyUIHTTPTransport:
	extends RefCounted

	func request_json(url: String, method: int, headers: PackedStringArray, body: String, timeout_seconds: float) -> Dictionary:
		var request := HTTPRequest.new()
		request.timeout = timeout_seconds
		var tree := Engine.get_main_loop()
		if not (tree is SceneTree):
			return {"error": "ComfyUI transport requires an active SceneTree.", "body": {}}
		tree.root.add_child(request)
		var err := OK
		if body.is_empty():
			err = request.request(url, headers, method)
		else:
			err = request.request(url, headers, method, body)
		if err != OK:
			request.queue_free()
			return {"error": error_string(err), "body": {}}
		var response := await request.request_completed
		request.queue_free()
		var result_code: int = response[0]
		var response_code: int = response[1]
		var response_body: PackedByteArray = response[3]
		if result_code != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
			return {"error": "HTTP %d" % response_code, "body": {}}
		var parser := JSON.new()
		var parse_err := parser.parse(response_body.get_string_from_utf8())
		if parse_err != OK:
			return {"error": parser.get_error_message(), "body": {}}
		return {"error": "", "body": parser.get_data()}
