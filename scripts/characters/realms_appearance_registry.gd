extends RefCounted

class_name RealmsAppearanceRegistry

const COMPONENTS := {
	"bottom_cargo_trousers": {
		"category": "legs",
		"texture_path": "res://assets/actors/player/prototype/test/legs1.png",
		"expected_size": Vector2i(167, 250),
		"layer_name": "legs",
	},
	"bottom_tactical_jeans": {
		"category": "legs",
		"texture_path": "res://assets/actors/player/prototype/test/legs2.png",
		"expected_size": Vector2i(167, 250),
		"layer_name": "legs",
	},
	"top_field_jacket": {
		"category": "torso",
		"texture_path": "res://assets/actors/player/prototype/test/torso2.png",
		"expected_size": Vector2i(167, 250),
		"layer_name": "torso",
	},
	"top_tshirt": {
		"category": "torso",
		"texture_path": "res://assets/actors/player/prototype/test/torso1.png",
		"expected_size": Vector2i(167, 250),
		"layer_name": "torso",
	},
	"hair_tousled_short": {
		"category": "hair",
		"texture_path": "res://assets/actors/player/prototype/test/hair1.png",
		"expected_size": Vector2i(167, 250),
		"layer_name": "hair",
	},
	"hair_tied_long": {
		"category": "hair",
		"texture_path": "res://assets/actors/player/prototype/test/hair2.png",
		"expected_size": Vector2i(167, 250),
		"layer_name": "hair",
	},
	"head_01": {
		"category": "head",
		"texture_path": "res://assets/actors/player/prototype/test/head.png",
		"expected_size": Vector2i(167, 250),
		"layer_name": "head",
	},
}

const PROTOTYPE_COMPONENT_IDS := {
	"legs": "bottom_cargo_trousers",
	"torso": "top_field_jacket",
	"hair": "hair_tousled_short",
	"head": "head_01",
}

const ALIASES := {
	"bottom_trousers": "bottom_cargo_trousers",
	"bottom_shorts": "bottom_tactical_jeans",
	"hair_short": "hair_tousled_short",
	"hair_curly": "hair_tied_long",
	"hair_long": "hair_tied_long",
}

static var _texture_cache: Dictionary = {}


static func get_layer_order() -> Array[String]:
	return ["legs", "torso", "head", "hair"]


static func get_prototype_component_ids() -> Dictionary:
	return PROTOTYPE_COMPONENT_IDS.duplicate(true)


static func resolve_component_ids(_recipe: Dictionary) -> Dictionary:
	return {
		"legs": String(_recipe.get("bottom_id", PROTOTYPE_COMPONENT_IDS["legs"])),
		"torso": String(_recipe.get("top_id", PROTOTYPE_COMPONENT_IDS["torso"])),
		"hair": String(_recipe.get("hair_id", PROTOTYPE_COMPONENT_IDS["hair"])),
		"head": String(PROTOTYPE_COMPONENT_IDS["head"]),
	}


static func get_component_info(component_id: String) -> Dictionary:
	var normalized_id: String = String(ALIASES.get(component_id, component_id))
	if not COMPONENTS.has(normalized_id):
		push_error("REALMS appearance registry does not contain component_id '%s'." % component_id)
		return {}
	return (COMPONENTS[normalized_id] as Dictionary).duplicate(true)


static func get_component_texture(component_id: String) -> Texture2D:
	if _texture_cache.has(component_id):
		return _texture_cache[component_id]
	var info: Dictionary = get_component_info(component_id)
	if info.is_empty():
		return null
	var resource_path: String = String(info.get("texture_path", "")).strip_edges()
	if resource_path.is_empty():
		push_error("REALMS appearance registry failed to load texture for '%s': %s" % [component_id, resource_path])
		return null
	var texture: Texture2D = null
	if ResourceLoader.exists(resource_path, "Texture2D"):
		texture = load(resource_path) as Texture2D
	if texture == null:
		var absolute_path: String = ProjectSettings.globalize_path(resource_path)
		var image: Image = Image.load_from_file(absolute_path)
		if image == null or image.is_empty():
			push_error("REALMS appearance registry failed to load texture for '%s': %s" % [component_id, resource_path])
			return null
		texture = ImageTexture.create_from_image(image)
	_validate_texture(component_id, texture, info)
	_texture_cache[component_id] = texture
	return texture


static func _validate_texture(component_id: String, texture: Texture2D, info: Dictionary) -> void:
	var expected_size_value: Variant = info.get("expected_size", Vector2i.ZERO)
	var expected_size: Vector2i = expected_size_value if expected_size_value is Vector2i else Vector2i.ZERO
	if texture.get_width() != expected_size.x or texture.get_height() != expected_size.y:
		push_error("REALMS appearance component '%s' must be %dx%d, got %dx%d." % [
			component_id,
			expected_size.x,
			expected_size.y,
			texture.get_width(),
			texture.get_height(),
		])
