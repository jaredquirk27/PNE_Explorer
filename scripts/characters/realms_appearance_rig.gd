extends Node2D

class_name RealmsAppearanceRig

const RealmsAppearanceRecipe = preload("res://scripts/characters/realms_appearance_recipe.gd")
const RealmsAppearanceRegistry = preload("res://scripts/characters/realms_appearance_registry.gd")

var _recipe: Dictionary = RealmsAppearanceRecipe.default_recipe()
var _motion: StringName = &"idle"
var _facing: StringName = &"down"
var _frame_index: int = 0
var _layer_sprites: Dictionary = {}
var _component_ids: Dictionary = {}


func _ready() -> void:
	_rebuild_layers()


func set_appearance_recipe(recipe: Dictionary) -> void:
	_recipe = RealmsAppearanceRecipe.normalize(recipe)
	_component_ids = RealmsAppearanceRegistry.resolve_component_ids(_recipe)
	_rebuild_layers()


func set_motion_state(motion: StringName, facing: StringName, frame_index: int = 0) -> void:
	_motion = motion
	_facing = facing
	_frame_index = frame_index
	_refresh_layers()


func get_recipe() -> Dictionary:
	return _recipe.duplicate(true)


func get_component_ids() -> Dictionary:
	return _component_ids.duplicate(true)


func get_layer_order() -> Array[String]:
	return RealmsAppearanceRegistry.get_layer_order()


func debug_layer_image(layer_name: String) -> Image:
	var sprite: Sprite2D = _layer_sprites.get(layer_name) as Sprite2D
	if sprite is Sprite2D and (sprite as Sprite2D).texture != null:
		return (sprite as Sprite2D).texture.get_image()
	return _build_placeholder_image(layer_name)


func _rebuild_layers() -> void:
	for child in get_children():
		child.queue_free()
	_layer_sprites.clear()
	for layer_name in get_layer_order():
		var sprite := Sprite2D.new()
		sprite.name = StringName(layer_name)
		sprite.centered = false
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2.ONE
		sprite.z_index = _layer_z_index(layer_name)
		add_child(sprite)
		_layer_sprites[layer_name] = sprite
	_refresh_layers()


func _refresh_layers() -> void:
	if _layer_sprites.is_empty():
		return
	for layer_name in get_layer_order():
		var sprite: Sprite2D = _layer_sprites.get(layer_name) as Sprite2D
		if sprite == null:
			continue
		sprite.texture = _build_layer_texture(layer_name)
		sprite.modulate = Color.WHITE
		sprite.self_modulate = Color.WHITE


func _build_layer_texture(layer_name: String) -> Texture2D:
	var component_id: String = _component_id_for_layer(layer_name)
	if component_id.is_empty():
		push_warning("REALMS appearance rig has no registered component for layer '%s'." % layer_name)
		return _build_placeholder_texture(layer_name)
	var texture: Texture2D = RealmsAppearanceRegistry.get_component_texture(component_id)
	if texture == null:
		push_warning("REALMS appearance rig falling back for missing component '%s'." % component_id)
		return _build_placeholder_texture(layer_name)
	return texture


func _component_id_for_layer(layer_name: String) -> String:
	var prototype_ids: Dictionary = RealmsAppearanceRegistry.get_prototype_component_ids()
	return String(_component_ids.get(layer_name, prototype_ids.get(layer_name, "")))


func _layer_z_index(layer_name: String) -> int:
	match layer_name:
		"legs":
			return 0
		"torso":
			return 1
		"head":
			return 2
		"hair":
			return 3
		_:
			return 0


func _build_placeholder_texture(layer_name: String) -> Texture2D:
	var image: Image = _build_placeholder_image(layer_name)
	return ImageTexture.create_from_image(image)


func _build_placeholder_image(layer_name: String) -> Image:
	var image: Image = Image.create(167, 250, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var color := Color("#ff00ff")
	match layer_name:
		"legs":
			_fill_rect(image, Rect2i(48, 140, 72, 92), color)
		"torso":
			_fill_rect(image, Rect2i(42, 64, 84, 88), color)
		"head":
			_fill_rect(image, Rect2i(54, 12, 60, 54), color)
		"hair":
			_fill_rect(image, Rect2i(50, 0, 70, 40), color)
		_:
			_fill_rect(image, Rect2i(0, 0, 24, 24), color)
	return image


func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var x_end: int = int(min(int(rect.position.x + rect.size.x), int(167)))
	var y_end: int = int(min(int(rect.position.y + rect.size.y), int(250)))
	for x in range(max(rect.position.x, 0), x_end):
		for y in range(max(rect.position.y, 0), y_end):
			image.set_pixel(x, y, color)
