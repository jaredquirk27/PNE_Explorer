extends Node

const ComfyUIClient = preload("res://scripts/api/comfyui_client.gd")


class FakeTransport:
	extends RefCounted

	var responses: Array = []
	var requests: Array = []

	func request_json(url: String, method: int, headers: PackedStringArray, body: String, _timeout_seconds: float) -> Dictionary:
		requests.append({"url": url, "method": method, "headers": headers, "body": body})
		if responses.is_empty():
			return {"error": "No fake response configured.", "body": {}}
		return responses.pop_front()


func _ready() -> void:
	var failures: Array[String] = []
	await _run_test(failures, "default workflow", _test_default_workflow)
	await _run_test(failures, "prompt injection", _test_prompt_injection)
	await _run_test(failures, "negative injection", _test_negative_injection)
	await _run_test(failures, "bounds", _test_bounds)
	await _run_test(failures, "arbitrary workflow", _test_no_arbitrary_workflow)
	await _run_test(failures, "offline", _test_offline)
	await _run_test(failures, "malformed response", _test_malformed_response)
	await _run_test(failures, "success", _test_success)
	if failures.is_empty():
		print("ComfyUI client tests passed.")
		get_tree().quit(0)
		return
	print("Failures:")
	for failure in failures:
		print(failure)
	get_tree().quit(1)


func _run_test(failures: Array[String], name: String, callable: Callable) -> void:
	var ok := await callable.call()
	if ok != true:
		failures.append(name)


func _test_default_workflow() -> bool:
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors"}, FakeTransport.new())
	var workflow := client.build_workflow("hello", "", 512, 512)
	return workflow["4"]["inputs"]["width"] == 512 and workflow["4"]["inputs"]["height"] == 512 and workflow["4"]["inputs"]["batch_size"] == 1 and workflow["5"]["inputs"]["steps"] == 18 and workflow["5"]["inputs"]["cfg"] == 6.0 and workflow["5"]["inputs"]["sampler_name"] == "euler" and workflow["5"]["inputs"]["scheduler"] == "simple" and workflow["5"]["inputs"]["denoise"] == 1.0


func _test_prompt_injection() -> bool:
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors"}, FakeTransport.new())
	var workflow := client.build_workflow("a red apple", "", 512, 512)
	return workflow["2"]["inputs"]["text"] == "a red apple"


func _test_negative_injection() -> bool:
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors"}, FakeTransport.new())
	var workflow := client.build_workflow("a red apple", "blurry", 512, 512)
	return workflow["3"]["inputs"]["text"] == "blurry"


func _test_bounds() -> bool:
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors"}, FakeTransport.new())
	return client.build_workflow("x", "", 32, 512).is_empty() and client.generate_image("x", "", 32, 512).error != ""


func _test_no_arbitrary_workflow() -> bool:
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors"}, FakeTransport.new())
	return not client.has_method("submit_workflow_json")


func _test_offline() -> bool:
	var transport := FakeTransport.new()
	transport.responses = [{"error": "Connection refused", "body": {}}]
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors"}, transport)
	return (await client.generate_image("test")).error == "Connection refused"


func _test_malformed_response() -> bool:
	var transport := FakeTransport.new()
	transport.responses = [{"error": "", "body": []}]
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors"}, transport)
	return (await client.generate_image("test")).error == "ComfyUI returned an invalid response."


func _test_success() -> bool:
	var transport := FakeTransport.new()
	transport.responses = [
		{"error": "", "body": {"prompt_id": "abc123"}},
		{"error": "", "body": {"abc123": {"outputs": {"7": {"images": [{"filename": "pne_0001.png", "subfolder": "output", "type": "output"}]}}}}},
	]
	var client := ComfyUIClient.new({"base_url": "http://localhost:8188", "checkpoint": "rv6.safetensors", "max_poll_attempts": 1}, transport)
	var result := await client.generate_image("test")
	return result.success and result.filename == "pne_0001.png" and result.image_path == "output/pne_0001.png"
