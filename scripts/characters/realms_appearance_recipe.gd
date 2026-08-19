extends RefCounted

class_name RealmsAppearanceRecipe

const DEFAULT_RECIPE := {
	"version": 1,
	"body_id": "body_male_base",
	"skin_id": "skin_light",
	"hair_id": "hair_tousled_short",
	"hair_color_id": "hair_brown",
	"top_id": "top_field_jacket",
	"bottom_id": "bottom_cargo_trousers",
	"footwear_id": "footwear_boots_basic",
	"accessory_ids": [],
}

const CATALOG := {
	"body_id": ["body_male_base"],
	"skin_id": ["skin_light", "skin_medium"],
	"hair_id": ["hair_tousled_short", "hair_tied_long"],
	"hair_color_id": ["hair_black", "hair_brown"],
	"top_id": ["top_field_jacket", "top_tshirt"],
	"bottom_id": ["bottom_cargo_trousers", "bottom_tactical_jeans"],
	"footwear_id": ["footwear_boots_basic"],
	"accessory_ids": ["accessory_watch"],
}

const ALIASES := {
	"hair_id": {
		"hair_short": "hair_tousled_short",
		"hair_curly": "hair_tied_long",
		"hair_long": "hair_tied_long",
	},
	"top_id": {
		"top_field_jacket": "top_field_jacket",
		"top_tshirt": "top_tshirt",
	},
	"bottom_id": {
		"bottom_trousers": "bottom_cargo_trousers",
		"bottom_shorts": "bottom_tactical_jeans",
	},
}


static func default_recipe() -> Dictionary:
	return DEFAULT_RECIPE.duplicate(true)


static func normalize(recipe: Dictionary) -> Dictionary:
	var normalized := default_recipe()
	if recipe.is_empty():
		return normalized
	for key in ["body_id", "skin_id", "hair_id", "hair_color_id", "top_id", "bottom_id", "footwear_id"]:
		var value: String = String(recipe.get(key, "")).strip_edges()
		if value.is_empty():
			continue
		value = String(ALIASES.get(key, {}).get(value, value))
		if not _validate_component(key, value):
			return _error("Unsupported %s '%s'." % [key, value])
		normalized[key] = value
	var accessory_ids: Variant = recipe.get("accessory_ids", [])
	if accessory_ids == null:
		accessory_ids = []
	if not (accessory_ids is Array):
		return _error("appearance_recipe.accessory_ids must be an Array.")
	var seen := {}
	normalized["accessory_ids"] = []
	for accessory_id in accessory_ids:
		var value := String(accessory_id).strip_edges()
		if value.is_empty():
			continue
		if not _validate_accessory(value):
			return _error("Unsupported accessory_id '%s'." % value)
		if seen.has(value):
			return _error("appearance_recipe.accessory_ids cannot contain duplicates.")
		seen[value] = true
		normalized["accessory_ids"].append(value)
	var version: int = int(recipe.get("version", normalized["version"]))
	if version < 1:
		return _error("appearance_recipe.version must be at least 1.")
	normalized["version"] = version
	return normalized


static func _validate_component(component_key: String, component_id: String) -> bool:
	if not CATALOG.has(component_key) or not (CATALOG[component_key] as Array).has(component_id):
		push_error("Unsupported %s '%s'." % [component_key, component_id])
		return false
	return true


static func _validate_accessory(component_id: String) -> bool:
	if not (CATALOG["accessory_ids"] as Array).has(component_id):
		push_error("Unsupported accessory_id '%s'." % component_id)
		return false
	return true


static func _error(message: String) -> Dictionary:
	push_error(message)
	return default_recipe()
