extends Node2D

const VALID_WATER_STATES: PackedStringArray = ["idle", "ritual_01", "ritual_02", "ritual_03"]
const EXPECTED_BACKGROUND_PATH := "res://GameAssets/Scenes/Hadeshorn/dragons_teeth_mountain.png"
const FALLBACK_BACKGROUND_PATH := "res://GameAssets/Scenes/Hadeshorn/Terrain/foreground_cliffs.png"
const STAGING_PLACEHOLDER_TEXTURE := preload("res://GameAssets/Characters/Player/Male_Base/standard/idle.png")

@export_enum("idle", "ritual_01", "ritual_02", "ritual_03") var initial_water_state: String = "idle"
@export var show_staging_debug: bool = false

@onready var _water_layers: Dictionary = {
	"idle": $Water/Idle,
	"ritual_01": $Water/Ritual01,
	"ritual_02": $Water/Ritual02,
	"ritual_03": $Water/Ritual03,
}

var current_water_state: String = ""

const STAGING_MARKERS: PackedStringArray = [
	"WalkerPosition",
	"ParPosition",
	"CollPosition",
	"MorganPosition",
	"WrenPosition",
	"GarthPosition",
	"RumorPosition",
]


func _ready() -> void:
	_validate_environment_textures()
	set_water_state(initial_water_state)
	print("[Hadeshorn] environment loaded path=%s global_position=%s scale=%s rotation=%s visible=%s" % [
		get_path(), global_position, global_scale, global_rotation, visible
	])
	call_deferred("_report_runtime_view")
	queue_redraw()


func _draw() -> void:
	if not show_staging_debug:
		return
	var font := ThemeDB.fallback_font
	for index in STAGING_MARKERS.size():
		var marker_name := STAGING_MARKERS[index]
		var marker := get_node_or_null("ActorMarkers/%s" % marker_name) as Marker2D
		if marker == null:
			continue
		var color := Color.from_hsv(float(index) / float(STAGING_MARKERS.size()), 0.75, 1.0)
		var destination := Rect2(marker.position - Vector2(32, 64), Vector2(64, 64))
		var source := Rect2(0, 128, 64, 64)
		draw_texture_rect_region(STAGING_PLACEHOLDER_TEXTURE, destination, source, color)
		draw_string(font, marker.position + Vector2(-30, 14), marker_name.trim_suffix("Position"), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color.WHITE)


func set_water_state(state_name: String) -> void:
	if not VALID_WATER_STATES.has(state_name):
		push_warning("[Hadeshorn] invalid lake state request: '%s'" % state_name)
		return

	for water_state in _water_layers:
		(_water_layers[water_state] as CanvasItem).visible = water_state == state_name
	current_water_state = state_name
	print("[Hadeshorn] lake state=%s" % current_water_state)


func _validate_environment_textures() -> void:
	if not ResourceLoader.exists(EXPECTED_BACKGROUND_PATH, "Texture2D"):
		print("[Hadeshorn] dedicated Dragon's Teeth texture unavailable; using painted fallback: %s" % FALLBACK_BACKGROUND_PATH)

	for sprite_path in [
		NodePath("Background/DragonsTeeth"),
		NodePath("Background/ForegroundCliffs"),
		NodePath("ExtendedTerrain/ShaleBeyond"),
		NodePath("Terrain/WalkableShale"),
		NodePath("Water/Idle"),
		NodePath("Water/Ritual01"),
		NodePath("Water/Ritual02"),
		NodePath("Water/Ritual03"),
	]:
		var sprite := get_node_or_null(sprite_path) as Sprite2D
		if sprite == null or sprite.texture == null:
			push_error("[Hadeshorn] missing texture on node: %s" % sprite_path)
			continue
		print("[Hadeshorn] texture loaded node=%s path=%s visible=%s alpha=%.1f z_index=%d global_position=%s scale=%s rotation=%s" % [
			sprite_path,
			sprite.texture.resource_path,
			sprite.visible,
			sprite.modulate.a * sprite.self_modulate.a,
			sprite.z_index,
			sprite.global_position,
			sprite.global_scale,
			sprite.global_rotation,
		])


func _report_runtime_view() -> void:
	var current_scene := get_tree().current_scene
	var environment_bounds := Rect2(global_position, Vector2(576, 512) * global_scale)
	print("[Hadeshorn] active_root=%s environment_bounds=%s" % [
		current_scene.get_path() if current_scene != null else NodePath(),
		environment_bounds,
	])
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		print("[Hadeshorn] active_camera=none")
		return
	var viewport_size := get_viewport_rect().size / camera.zoom
	var camera_rect := Rect2(camera.get_screen_center_position() - viewport_size * 0.5, viewport_size)
	print("[Hadeshorn] active_camera=%s global_position=%s screen_center=%s visible_rect=%s" % [
		camera.get_path(), camera.global_position, camera.get_screen_center_position(), camera_rect
	])
	for marker_name in STAGING_MARKERS:
		var marker := get_node_or_null("ActorMarkers/%s" % marker_name) as Marker2D
		if marker != null:
			print("[Hadeshorn] staging_marker=%s global_position=%s visible_to_camera=%s" % [
				marker_name.trim_suffix("Position"), marker.global_position, camera_rect.has_point(marker.global_position)
			])
