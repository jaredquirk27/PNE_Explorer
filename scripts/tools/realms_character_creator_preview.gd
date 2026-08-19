extends Node2D

const RealmsAppearanceRig = preload("res://scripts/characters/realms_appearance_rig.gd")
const RealmsAppearanceRecipe = preload("res://scripts/characters/realms_appearance_recipe.gd")
const RealmsAppearanceRegistry = preload("res://scripts/characters/realms_appearance_registry.gd")

var _rig: Node2D
var _controls: Dictionary = {}


func _ready() -> void:
	_rig = RealmsAppearanceRig.new()
	_rig.position = Vector2(256, 144)
	add_child(_rig)
	_rig.set_appearance_recipe(RealmsAppearanceRecipe.default_recipe())
	_build_ui()
	_apply_controls()


func _process(_delta: float) -> void:
	var facing: StringName = StringName(_controls["facing"].get_item_text(_controls["facing"].selected).to_lower())
	var motion: StringName = StringName(_controls["motion"].get_item_text(_controls["motion"].selected).to_lower())
	_rig.set_motion_state(motion, facing, int(_controls["frame"].value))


func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(240, 360)
	add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	for label in ["skin", "hair", "hair_color", "top", "bottom"]:
		var option := OptionButton.new()
		option.name = label
		_controls[label] = option
		vbox.add_child(option)
		_populate_option(option, label)
		option.item_selected.connect(_on_recipe_changed)

	var ids := Label.new()
	ids.name = "ComponentIds"
	ids.text = _component_id_text()
	ids.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls["component_ids"] = ids
	vbox.add_child(ids)

	var motion := OptionButton.new()
	motion.name = "motion"
	_controls["motion"] = motion
	vbox.add_child(motion)
	for item in ["idle", "walk"]:
		motion.add_item(item)
	motion.item_selected.connect(_on_recipe_changed)

	var facing := OptionButton.new()
	facing.name = "facing"
	_controls["facing"] = facing
	vbox.add_child(facing)
	for item in ["down", "up", "left", "right"]:
		facing.add_item(item)
	facing.item_selected.connect(_on_recipe_changed)

	var frame := HSlider.new()
	frame.name = "frame"
	frame.min_value = 0
	frame.max_value = 1
	frame.step = 1
	frame.value = 0
	_controls["frame"] = frame
	vbox.add_child(frame)
	frame.value_changed.connect(_on_recipe_changed)

	var hint := Label.new()
	hint.text = "Change selectors to inspect layer order.\nUse motion + facing to verify sync."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)


func _populate_option(option: OptionButton, label: String) -> void:
	var values: Array[String] = []
	match label:
		"skin":
			values = ["skin_light", "skin_medium"]
		"hair":
			values = ["hair_short", "hair_curly", "hair_long"]
		"hair_color":
			values = ["hair_brown", "hair_black"]
		"top":
			values = ["top_field_jacket", "top_tshirt"]
		"bottom":
			values = ["bottom_trousers", "bottom_shorts"]
	for value in values:
		option.add_item(value)


func _on_recipe_changed(_index = null) -> void:
	_apply_controls()


func _apply_controls() -> void:
	var recipe: Dictionary = RealmsAppearanceRecipe.default_recipe()
	recipe["skin_id"] = String(_controls["skin"].get_item_text(_controls["skin"].selected))
	recipe["hair_id"] = String(_controls["hair"].get_item_text(_controls["hair"].selected))
	recipe["hair_color_id"] = String(_controls["hair_color"].get_item_text(_controls["hair_color"].selected))
	recipe["top_id"] = String(_controls["top"].get_item_text(_controls["top"].selected))
	recipe["bottom_id"] = String(_controls["bottom"].get_item_text(_controls["bottom"].selected))
	_rig.set_appearance_recipe(recipe)
	var ids: Label = _controls.get("component_ids") as Label
	if ids != null:
		ids.text = _component_id_text()


func _component_id_text() -> String:
	var component_ids: Dictionary = RealmsAppearanceRegistry.get_prototype_component_ids()
	return "Prototype IDs\nHead: %s\nTorso: %s\nLegs: %s" % [
		component_ids["head"],
		component_ids["torso"],
		component_ids["legs"],
	]
