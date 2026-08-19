extends Control

const RealmsAppearanceRig = preload("res://scripts/characters/realms_appearance_rig.gd")
const RealmsAppearanceRecipe = preload("res://scripts/characters/realms_appearance_recipe.gd")
const RealmsAppearanceRegistry = preload("res://scripts/characters/realms_appearance_registry.gd")
const PNEBackend = preload("res://scripts/api/pne_backend.gd")

const PRONOUN_OPTIONS := [
	{"id": "he_him", "label": "he/him"},
	{"id": "she_her", "label": "she/her"},
	{"id": "they_them", "label": "they/them"},
]

const VARIANCY_OPTIONS := [
	{"id": "telekinetic", "label": "Telekinetic\nKinetic Psychic"},
	{"id": "pyrokinetic", "label": "Pyrokinetic\nFire"},
	{"id": "electrokinetic", "label": "Electrokinetic\nLightning"},
	{"id": "spatiokinetic", "label": "Spatiokinetic\nTeleport"},
	{"id": "magnetokinetic", "label": "Magnetokinetic\nMagnetism"},
	{"id": "cryokinetic", "label": "Cryokinetic\nIce"},
]

const ORIGIN_OPTIONS := [
	{"id": "freed_from_novagen", "label": "Freed from Novagen"},
	{"id": "public_manifestation", "label": "Public Manifestation"},
	{"id": "independent_reference", "label": "Independent Reference"},
	{"id": "liara_finds_you", "label": "Liara Finds You"},
]

const APPEARANCE_OPTIONS := {
	"hair_id": [
		{"id": "hair_tousled_short", "label": "Hair 1"},
		{"id": "hair_tied_long", "label": "Hair 2"},
	],
	"top_id": [
		{"id": "top_field_jacket", "label": "Torso 1"},
		{"id": "top_tshirt", "label": "Torso 2"},
	],
	"bottom_id": [
		{"id": "bottom_cargo_trousers", "label": "Legs 1"},
		{"id": "bottom_tactical_jeans", "label": "Legs 2"},
	],
}

const VARIANCY_PROFILE_MAP := {
	"telekinetic": {
		"variancy_class": "Kinetic",
		"ability_class": "Kinetic",
		"core_ability": "telekinesis",
		"ability_theme": "Telekinetic",
		"ability_description": "Kinetic Psychic",
	},
	"pyrokinetic": {
		"variancy_class": "Energetic",
		"ability_class": "Energetic",
		"core_ability": "energy_projection",
		"ability_theme": "Pyrokinetic",
		"ability_description": "Fire",
	},
	"electrokinetic": {
		"variancy_class": "Energetic",
		"ability_class": "Energetic",
		"core_ability": "energy_projection",
		"ability_theme": "Electrokinetic",
		"ability_description": "Lightning",
	},
	"spatiokinetic": {
		"variancy_class": "Spatial",
		"ability_class": "Spatial",
		"core_ability": "reflex_teleport",
		"ability_theme": "Spatiokinetic",
		"ability_description": "Teleport",
	},
	"magnetokinetic": {
		"variancy_class": "Kinetic",
		"ability_class": "Kinetic",
		"core_ability": "telekinesis",
		"ability_theme": "Magnetokinetic",
		"ability_description": "Magnetism",
	},
	"cryokinetic": {
		"variancy_class": "Biological",
		"ability_class": "Biological",
		"core_ability": "regeneration",
		"ability_theme": "Cryokinetic",
		"ability_description": "Ice",
	},
}

const ORIGIN_PROFILE_MAP := {
	"freed_from_novagen": "novagen_survivor",
	"public_manifestation": "public_manifestation",
	"independent_reference": "independent_network",
	"liara_finds_you": "cheng_identified",
}

var _rig: RealmsAppearanceRig
var _load_request: HTTPRequest
var _save_request: HTTPRequest
var _tabs: TabContainer
var _controls: Dictionary = {}
var _status_label: Label
var _summary_label: RichTextLabel
var _confirm_button: Button
var _back_button: Button
var _profile: Dictionary = {}
var _save_in_flight: bool = false


func _ready() -> void:
	_build_ui()
	_rig = RealmsAppearanceRig.new()
	_rig.position = Vector2(820, 170)
	add_child(_rig)
	_rig.set_appearance_recipe(RealmsAppearanceRecipe.default_recipe())

	_load_request = HTTPRequest.new()
	add_child(_load_request)
	_load_request.request_completed.connect(_on_load_completed)

	_save_request = HTTPRequest.new()
	add_child(_save_request)
	_save_request.request_completed.connect(_on_save_completed)

	_update_preview()
	_refresh_summary()
	_load_profile()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#14151b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "REALMS Character Creator MVP"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	var tabs := TabContainer.new()
	tabs.position = Vector2(20, 56)
	tabs.custom_minimum_size = Vector2(720, 540)
	tabs.size = Vector2(720, 540)
	add_child(tabs)
	_tabs = tabs

	_add_identity_tab(tabs)
	_add_appearance_tab(tabs)
	_add_origin_tab(tabs)
	_add_variancy_tab(tabs)
	_add_confirm_tab(tabs)

	_status_label = Label.new()
	_status_label.position = Vector2(20, 610)
	_status_label.size = Vector2(780, 28)
	_status_label.text = "Load the active REALMS onboarding state or confirm a new character."
	add_child(_status_label)


func _add_identity_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Identity"
	page.custom_minimum_size = Vector2(680, 500)
	tabs.add_child(page)

	_add_section_label(page, "Identity")
	_add_labeled_line_edit(page, "Name", "display_name", "Jared Quirk")
	_add_labeled_option(page, "Pronouns", "pronouns", PRONOUN_OPTIONS, "they_them")


func _add_appearance_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Appearance"
	page.custom_minimum_size = Vector2(680, 500)
	tabs.add_child(page)

	_add_section_label(page, "Appearance")
	_add_labeled_option(page, "Hair", "hair_id", APPEARANCE_OPTIONS["hair_id"], "hair_tousled_short")
	_add_labeled_option(page, "Torso", "top_id", APPEARANCE_OPTIONS["top_id"], "top_field_jacket")
	_add_labeled_option(page, "Legs", "bottom_id", APPEARANCE_OPTIONS["bottom_id"], "bottom_cargo_trousers")

	var head_label := Label.new()
	head_label.text = "Head is fixed for this MVP."
	page.add_child(head_label)

	var combo_label := Label.new()
	combo_label.name = "ComboLabel"
	combo_label.text = "8 combinations: 2 hair × 2 torsos × 2 legs"
	page.add_child(combo_label)


func _add_origin_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Origin"
	page.custom_minimum_size = Vector2(680, 500)
	tabs.add_child(page)

	_add_section_label(page, "Origin")
	_add_labeled_option(page, "Origin choice", "origin_type", ORIGIN_OPTIONS, "public_manifestation")


func _add_variancy_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Variancy"
	page.custom_minimum_size = Vector2(680, 500)
	tabs.add_child(page)

	_add_section_label(page, "Variancy")
	_add_labeled_option(page, "Variancy type", "variancy_class", VARIANCY_OPTIONS, "telekinetic")


func _add_confirm_tab(tabs: TabContainer) -> void:
	var page := VBoxContainer.new()
	page.name = "Confirm"
	page.custom_minimum_size = Vector2(680, 500)
	tabs.add_child(page)

	_add_section_label(page, "Review")
	_summary_label = RichTextLabel.new()
	_summary_label.fit_content = true
	_summary_label.bbcode_enabled = true
	_summary_label.custom_minimum_size = Vector2(640, 240)
	page.add_child(_summary_label)

	var preview_title := Label.new()
	preview_title.text = "Appearance Preview"
	page.add_child(preview_title)

	var preview_hint := Label.new()
	preview_hint.text = "The live preview appears beside the summary."
	preview_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(preview_hint)

	var button_row := HBoxContainer.new()
	page.add_child(button_row)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.pressed.connect(_on_confirm_back_pressed)
	button_row.add_child(_back_button)

	_confirm_button = Button.new()
	_confirm_button.text = "Create Character"
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(_on_create_character_pressed)
	button_row.add_child(_confirm_button)

	var reset_button := Button.new()
	reset_button.text = "Reload Active Profile"
	reset_button.pressed.connect(_load_profile)
	button_row.add_child(reset_button)

	var note := Label.new()
	note.text = "Confirmation persists the selected player profile through the live onboarding turn endpoint."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	parent.add_child(label)


func _add_labeled_line_edit(parent: VBoxContainer, label_text: String, key: String, default_value: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var edit := LineEdit.new()
	edit.text = default_value
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.text_changed.connect(_on_profile_changed)
	row.add_child(edit)
	_controls[key] = edit


func _add_labeled_option(parent: VBoxContainer, label_text: String, key: String, options: Array, default_id: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in options:
		var item_id: String = str(entry.get("id", ""))
		var item_label: String = str(entry.get("label", item_id))
		option.add_item(item_label)
		option.set_item_metadata(option.item_count - 1, item_id)
		if item_id == default_id:
			option.selected = option.item_count - 1
	option.item_selected.connect(_on_profile_changed)
	row.add_child(option)
	_controls[key] = option


func _on_profile_changed(_value = null) -> void:
	_update_preview()
	_refresh_summary()


func _selected_option_id(key: String, fallback: String) -> String:
	var option: OptionButton = _controls.get(key) as OptionButton
	if option == null or option.item_count == 0:
		return fallback
	var metadata: Variant = option.get_item_metadata(option.selected)
	var text: String = str(metadata).strip_edges()
	return text if not text.is_empty() else fallback


func _selected_option_label(key: String, fallback: String) -> String:
	var option: OptionButton = _controls.get(key) as OptionButton
	if option == null or option.item_count == 0:
		return fallback
	var metadata: Variant = option.get_item_metadata(option.selected)
	var id_value: String = str(metadata).strip_edges()
	if id_value.is_empty():
		return fallback
	var label: String = option.get_item_text(option.selected)
	return label if not label.strip_edges().is_empty() else fallback


func _line_edit_text(key: String, fallback: String) -> String:
	var edit: LineEdit = _controls.get(key) as LineEdit
	if edit == null:
		return fallback
	var text: String = edit.text.strip_edges()
	return text if not text.is_empty() else fallback


func _current_profile_updates() -> Dictionary:
	var appearance_recipe: Dictionary = RealmsAppearanceRecipe.default_recipe()
	appearance_recipe["hair_id"] = _selected_option_id("hair_id", "hair_tousled_short")
	appearance_recipe["top_id"] = _selected_option_id("top_id", "top_field_jacket")
	appearance_recipe["bottom_id"] = _selected_option_id("bottom_id", "bottom_cargo_trousers")
	var variancy_id: String = _selected_option_id("variancy_class", "telekinetic")
	var variancy_profile: Dictionary = VARIANCY_PROFILE_MAP.get(variancy_id, VARIANCY_PROFILE_MAP["telekinetic"])
	var origin_id: String = _selected_option_id("origin_type", "public_manifestation")
	return {
		"display_name": _line_edit_text("display_name", "Jared Quirk"),
		"pronouns": _selected_option_id("pronouns", "they_them"),
		"origin": origin_id,
		"origin_type": origin_id,
		"origin_display_name": _origin_label_for_id(origin_id),
		"origin_selection_mode": "exact_origin",
		"variancy_class": variancy_profile.get("variancy_class", "Kinetic"),
		"ability_class": variancy_profile.get("ability_class", "Kinetic"),
		"core_ability": variancy_profile.get("core_ability", "telekinesis"),
		"ability_theme": variancy_profile.get("ability_theme", "Telekinetic"),
		"ability_description": variancy_profile.get("ability_description", "Kinetic Psychic"),
		"ability_selection_mode": "exact_ability",
		"appearance_recipe": appearance_recipe,
	}


func _origin_label_for_id(origin_id: String) -> String:
	for entry in ORIGIN_OPTIONS:
		if str(entry.get("id", "")) == origin_id:
			return str(entry.get("label", origin_id))
	return origin_id


func _update_preview() -> void:
	if _rig == null:
		return
	var updates: Dictionary = _current_profile_updates()
	var recipe_value: Variant = updates.get("appearance_recipe", RealmsAppearanceRecipe.default_recipe())
	var recipe: Dictionary = recipe_value if recipe_value is Dictionary else RealmsAppearanceRecipe.default_recipe()
	_rig.set_appearance_recipe(recipe)
	_rig.set_motion_state(&"idle", &"down", 0)


func _refresh_summary() -> void:
	if _summary_label == null:
		return
	var updates: Dictionary = _current_profile_updates()
	_summary_label.text = "[b]Name:[/b] %s\n[b]Pronouns:[/b] %s\n[b]Origin:[/b] %s\n[b]Variancy:[/b] %s\n[b]Variancy label:[/b] %s\n[b]Hair:[/b] %s\n[b]Torso:[/b] %s\n[b]Legs:[/b] %s" % [
		updates["display_name"],
		updates["pronouns"],
		updates["origin_display_name"],
		updates["variancy_class"],
		_selected_option_label("variancy_class", "Telekinetic"),
		str(updates["appearance_recipe"]["hair_id"]),
		str(updates["appearance_recipe"]["top_id"]),
		str(updates["appearance_recipe"]["bottom_id"]),
	]


func _load_profile() -> void:
	_status_label.text = "Loading active REALMS onboarding profile..."
	var error: Error = _load_request.request(PNEBackend.realms_onboarding_url())
	if error != OK:
		_status_label.text = "Unable to start profile load: %s" % error_string(error)


func _on_load_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_status_label.text = "Profile load failed: HTTP %d. Using local defaults." % response_code
		_apply_profile({})
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_status_label.text = "Profile load returned invalid JSON. Using local defaults."
		_apply_profile({})
		return
	var payload: Dictionary = parsed
	var player_profile_value: Variant = payload.get("player_profile", {})
	var player_profile: Dictionary = player_profile_value if player_profile_value is Dictionary else {}
	_apply_profile(player_profile)
	_status_label.text = "Loaded active REALMS profile."


func _apply_profile(profile: Dictionary) -> void:
	_profile = profile.duplicate(true)
	var name_edit: LineEdit = _controls.get("display_name") as LineEdit
	if name_edit != null:
		name_edit.text = str(profile.get("display_name", "Jared Quirk"))
	var pronoun_id: String = str(profile.get("pronouns", "they_them"))
	var origin_id: String = _origin_id_from_profile(profile)
	var variancy_id: String = _variancy_id_from_profile(profile)
	_set_selected_option("pronouns", pronoun_id)
	_set_selected_option("origin_type", origin_id)
	_set_selected_option("variancy_class", variancy_id)
	var recipe_value: Variant = profile.get("appearance_recipe", RealmsAppearanceRecipe.default_recipe())
	var recipe: Dictionary = recipe_value if recipe_value is Dictionary else RealmsAppearanceRecipe.default_recipe()
	_set_selected_option("hair_id", _appearance_id_from_recipe("hair_id", str(recipe.get("hair_id", "hair_tousled_short"))))
	_set_selected_option("top_id", _appearance_id_from_recipe("top_id", str(recipe.get("top_id", "top_field_jacket"))))
	_set_selected_option("bottom_id", _appearance_id_from_recipe("bottom_id", str(recipe.get("bottom_id", "bottom_cargo_trousers"))))
	_update_preview()
	_refresh_summary()
	_update_confirm_button_state()


func _set_selected_option(key: String, id_value: String) -> void:
	var option: OptionButton = _controls.get(key) as OptionButton
	if option == null:
		return
	for index in range(option.item_count):
		var metadata: String = str(option.get_item_metadata(index))
		if metadata == id_value:
			option.selected = index
			return
		if key == "origin_type" and ORIGIN_PROFILE_MAP.get(metadata, metadata) == id_value:
			option.selected = index
			return
		if key == "hair_id" and _appearance_alias("hair_id", metadata) == id_value:
			option.selected = index
			return
		if key == "top_id" and _appearance_alias("top_id", metadata) == id_value:
			option.selected = index
			return
		if key == "bottom_id" and _appearance_alias("bottom_id", metadata) == id_value:
			option.selected = index
			return


func _origin_id_from_profile(profile: Dictionary) -> String:
	var origin_raw: Variant = profile.get("origin_type")
	if origin_raw == null or str(origin_raw).strip_edges().is_empty():
		origin_raw = profile.get("origin")
	var origin_value: String = str(origin_raw).strip_edges()
	if origin_value.is_empty():
		origin_value = "public_manifestation"
	for key in ORIGIN_PROFILE_MAP.keys():
		if ORIGIN_PROFILE_MAP[key] == origin_value:
			return key
	if origin_value in ORIGIN_PROFILE_MAP.keys():
		return origin_value
	return "public_manifestation"


func _appearance_id_from_recipe(key: String, stored_id: String) -> String:
	return _appearance_alias(key, stored_id)


func _appearance_alias(key: String, stored_id: String) -> String:
	match key:
		"hair_id":
			if stored_id == "hair_short":
				return "hair_tousled_short"
			if stored_id == "hair_curly" or stored_id == "hair_long":
				return "hair_tied_long"
		"top_id":
			if stored_id == "top_tshirt":
				return "top_tshirt"
			if stored_id == "top_field_jacket":
				return "top_field_jacket"
		"bottom_id":
			if stored_id == "bottom_trousers":
				return "bottom_cargo_trousers"
			if stored_id == "bottom_shorts":
				return "bottom_tactical_jeans"
	return stored_id


func _variancy_id_from_profile(profile: Dictionary) -> String:
	var theme_raw: Variant = profile.get("ability_theme")
	if theme_raw == null or str(theme_raw).strip_edges().is_empty():
		theme_raw = profile.get("ability_display_name")
	var theme: String = str(theme_raw).strip_edges()
	var core_ability: String = str(profile.get("core_ability", "")).strip_edges()
	var family_raw: Variant = profile.get("variancy_class")
	if family_raw == null or str(family_raw).strip_edges().is_empty():
		family_raw = profile.get("ability_class")
	var family: String = str(family_raw).strip_edges()
	if theme == "Telekinetic" or core_ability == "telekinesis" or family == "Kinetic":
		return "telekinetic"
	if theme == "Pyrokinetic" or theme == "Electrokinetic" or core_ability == "energy_projection":
		return "pyrokinetic" if theme == "Pyrokinetic" else "electrokinetic"
	if theme == "Spatiokinetic" or core_ability == "reflex_teleport" or family == "Spatial":
		return "spatiokinetic"
	if theme == "Magnetokinetic":
		return "magnetokinetic"
	if theme == "Cryokinetic":
		return "cryokinetic"
	return "telekinetic"


func _on_save_pressed() -> void:
	_on_create_character_pressed()


func _on_confirm_back_pressed() -> void:
	if _tabs != null:
		_tabs.current_tab = 3


func _on_create_character_pressed() -> void:
	if _save_in_flight:
		return
	var validation_error: String = _validate_character_profile()
	if not validation_error.is_empty():
		_status_label.text = validation_error
		return
	_save_in_flight = true
	_update_confirm_button_state()
	var updates: Dictionary = _current_profile_updates()
	var body: Dictionary = {
		"request_id": "creator-%s" % Time.get_unix_time_from_system(),
		"action_mode": "choose",
		"selected_choice_id": _selected_option_id("origin_type", "public_manifestation"),
		"input_text": "I choose %s." % _origin_label_for_id(_selected_option_id("origin_type", "public_manifestation")),
		"player_profile_updates": updates,
		"source": "player",
	}
	_status_label.text = "Saving character to PNE..."
	var error: Error = _save_request.request(
		PNEBackend.realms_onboarding_turn_url(),
		["Content-Type: application/json"],
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if error != OK:
		_save_in_flight = false
		_update_confirm_button_state()
		_status_label.text = "Save request failed to start: %s" % error_string(error)


func _on_save_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_save_in_flight = false
	_update_confirm_button_state()
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_status_label.text = "Save failed: HTTP %d" % response_code
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		var saved_profile_value: Variant = (parsed as Dictionary).get("player_profile", _profile)
		if saved_profile_value is Dictionary:
			_profile = saved_profile_value
	_status_label.text = "Character created."


func _update_confirm_button_state() -> void:
	if _confirm_button != null:
		_confirm_button.disabled = _save_in_flight
		_confirm_button.text = "Creating..." if _save_in_flight else "Create Character"
	if _back_button != null:
		_back_button.disabled = _save_in_flight


func _validate_character_profile() -> String:
	var display_name: String = _line_edit_text("display_name", "")
	if display_name.is_empty():
		return "Display name is required."
	if _selected_option_id("pronouns", "").is_empty():
		return "Pronouns are required."
	var origin_id: String = _selected_option_id("origin_type", "")
	if origin_id.is_empty() or not _origin_is_valid(origin_id):
		return "Please choose a valid origin."
	var variancy_id: String = _selected_option_id("variancy_class", "")
	if variancy_id.is_empty() or not VARIANCY_PROFILE_MAP.has(variancy_id):
		return "Please choose a valid Variancy."
	var recipe: Dictionary = RealmsAppearanceRecipe.default_recipe()
	var hair_id: String = _selected_option_id("hair_id", "")
	var top_id: String = _selected_option_id("top_id", "")
	var bottom_id: String = _selected_option_id("bottom_id", "")
	if hair_id.is_empty() or top_id.is_empty() or bottom_id.is_empty():
		return "Please complete the appearance selections."
	recipe["hair_id"] = hair_id
	recipe["top_id"] = top_id
	recipe["bottom_id"] = bottom_id
	var normalized_recipe: Dictionary = RealmsAppearanceRecipe.normalize(recipe)
	if normalized_recipe.is_empty():
		return "Please choose a valid appearance recipe."
	return ""


func _origin_is_valid(origin_id: String) -> bool:
	for entry in ORIGIN_OPTIONS:
		if str(entry.get("id", "")) == origin_id:
			return true
	return false
