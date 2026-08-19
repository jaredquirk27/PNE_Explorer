extends Node

const RealmsAppearanceRecipe = preload("res://scripts/characters/realms_appearance_recipe.gd")
const RealmsAppearanceRig = preload("res://scripts/characters/realms_appearance_rig.gd")
const RealmsAppearanceRegistry = preload("res://scripts/characters/realms_appearance_registry.gd")


func _ready() -> void:
	var failures: Array[String] = []
	_run(failures, "default recipe", _test_default_recipe)
	_run(failures, "validation", _test_validation)
	_run(failures, "registry", _test_registry)
	_run(failures, "asset-backed rig", _test_asset_backed_rig)
	_run(failures, "determinism", _test_determinism)
	if failures.is_empty():
		print("REALMS character creator MVP tests passed.")
		get_tree().quit(0)
		return
	for failure in failures:
		print(failure)
	get_tree().quit(1)


func _run(failures: Array[String], name: String, callable: Callable) -> void:
	if not bool(callable.call()):
		failures.append(name)


func _test_default_recipe() -> bool:
	var recipe := RealmsAppearanceRecipe.default_recipe()
	return recipe["body_id"] == "body_male_base" and recipe["skin_id"] == "skin_light" and recipe["hair_id"] == "hair_tousled_short" and recipe["footwear_id"] == "footwear_boots_basic"


func _test_validation() -> bool:
	var valid := RealmsAppearanceRecipe.normalize({
		"body_id": "body_male_base",
		"skin_id": "skin_medium",
		"hair_id": "hair_curly",
		"hair_color_id": "hair_black",
		"top_id": "top_tshirt",
		"bottom_id": "bottom_tactical_jeans",
		"footwear_id": "footwear_boots_basic",
		"accessory_ids": ["accessory_watch"],
	})
	var invalid := RealmsAppearanceRecipe.normalize({"skin_id": "skin_invalid"})
	return valid["skin_id"] == "skin_medium" and valid["hair_color_id"] == "hair_black" and invalid["skin_id"] == "skin_light"


func _test_registry() -> bool:
	var ids: Dictionary = RealmsAppearanceRegistry.get_prototype_component_ids()
	if ids["head"] != "head_01" or ids["torso"] != "top_field_jacket" or ids["legs"] != "bottom_cargo_trousers":
		return false
	for layer in RealmsAppearanceRegistry.get_layer_order():
		var component_id: String = str(ids[layer])
		var info: Dictionary = RealmsAppearanceRegistry.get_component_info(component_id)
		if info.is_empty():
			return false
		if str(info.get("layer_name", "")) != layer:
			return false
		var texture: Texture2D = RealmsAppearanceRegistry.get_component_texture(component_id)
		if texture == null or texture.get_width() != 167 or texture.get_height() != 250:
			return false
	return true


func _test_asset_backed_rig() -> bool:
	var rig := RealmsAppearanceRig.new()
	add_child(rig)
	rig.set_appearance_recipe(RealmsAppearanceRecipe.default_recipe())
	var ids: Dictionary = rig.get_component_ids()
	var layers: Array[String] = rig.get_layer_order()
	var ok: bool = ids["head"] == "head_01" and ids["torso"] == "top_field_jacket" and ids["legs"] == "bottom_cargo_trousers"
	for layer in layers:
		var image: Image = rig.debug_layer_image(layer)
		ok = ok and image.get_width() == 167 and image.get_height() == 250
	rig.queue_free()
	return ok


func _test_determinism() -> bool:
	var first := RealmsAppearanceRig.new()
	var second := RealmsAppearanceRig.new()
	add_child(first)
	add_child(second)
	var recipe: Dictionary = RealmsAppearanceRecipe.default_recipe()
	recipe["hair_color_id"] = "hair_black"
	first.set_appearance_recipe(recipe)
	second.set_appearance_recipe(recipe)
	first.set_motion_state(&"walk", &"right", 1)
	second.set_motion_state(&"walk", &"right", 1)
	var first_image: Image = first.debug_layer_image("head")
	var second_image: Image = second.debug_layer_image("head")
	var ok: bool = first_image.get_size() == second_image.get_size() and first_image.get_data() == second_image.get_data()
	first.queue_free()
	second.queue_free()
	return ok
