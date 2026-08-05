extends CharacterBody2D

const DirectionalVisualHelper = preload("res://scripts/actors/directional_visual_helper.gd")

@export var actor_id: StringName
@export var actor_display_name: String = "Actor"
@export var move_speed: float = 160.0
@export var sprite_frames: SpriteFrames
@export var idle_sheet: Texture2D
@export var walk_sheet: Texture2D
@export_file("*.png") var idle_texture_path: String
@export_file("*.png") var walk_texture_path: String
@export_file("*.png") var south_texture_path: String
@export_file("*.png") var south_west_texture_path: String
@export_file("*.png") var west_texture_path: String
@export_file("*.png") var north_west_texture_path: String
@export_file("*.png") var north_texture_path: String
@export_file("*.png") var north_east_texture_path: String
@export_file("*.png") var east_texture_path: String
@export_file("*.png") var south_east_texture_path: String
@export var sprite_offset: Vector2 = Vector2.ZERO
@export_range(0.35, 8.0, 0.05) var visual_scale: float = 1.0
@export_range(1, 32, 1) var idle_frame_count: int = 2
@export_range(1, 32, 1) var walk_frame_count: int = 9
@export var idle_frames_per_second: float = 2.0
@export var walk_frames_per_second: float = 8.0
@export_enum("south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east") var initial_facing: String = "south"

@onready var visual_root: Node2D = $VisualRoot
@onready var animated_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

var _last_facing: StringName = &"down"
var _lpc_visual_ready: bool = false


func _ready() -> void:
	if actor_id == &"player":
		add_to_group(&"player")
	_last_facing = _canonical_facing(StringName(initial_facing))
	animated_sprite.visible = false
	var directional_frames := _build_directional_frames()
	if directional_frames != null:
		sprite_frames = directional_frames
	else:
		_load_lpc_textures()
		if sprite_frames == null and (idle_sheet != null or walk_sheet != null):
			sprite_frames = _build_sprite_frames()
	if sprite_frames == null:
		push_error("[LPC] %s could not build SpriteFrames; no valid LPC textures were loaded." % actor_display_name)
		set_process(false)
		return

	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.position = sprite_offset
	animated_sprite.visible = true
	animated_sprite.modulate = Color.WHITE
	animated_sprite.self_modulate = Color.WHITE
	animated_sprite.z_index = 10
	visual_root.scale = Vector2.ONE * visual_scale
	_show_idle_frame()
	var startup_animation := _find_animation(&"idle", _last_facing)
	if startup_animation.is_empty() or animated_sprite.sprite_frames.get_frame_count(startup_animation) == 0:
		push_error("[LPC] %s has no valid startup animation idle_%s." % [actor_display_name, _last_facing])
		animated_sprite.visible = false
		set_process(false)
		return
	var startup_texture := animated_sprite.sprite_frames.get_frame_texture(startup_animation, 0)
	if startup_texture == null:
		push_error("[LPC] %s idle_down frame 0 has no texture." % actor_display_name)
		animated_sprite.visible = false
		set_process(false)
		return
	_lpc_visual_ready = true
	_hide_placeholder_debug_visuals()
	print("[LPC] %s playing idle_%s" % [actor_display_name, _last_facing])


func _load_lpc_textures() -> void:
	idle_sheet = _load_lpc_texture(idle_sheet, idle_texture_path, "idle")
	walk_sheet = _load_lpc_texture(walk_sheet, walk_texture_path, "walk")


func _load_lpc_texture(current: Texture2D, resource_path: String, animation_kind: String) -> Texture2D:
	if current != null:
		_validate_lpc_texture(current, current.resource_path, animation_kind)
		return current
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path, "Texture2D"):
		push_error("[LPC] %s failed to load %s texture: %s" % [actor_display_name, animation_kind, resource_path])
		return null
	var loaded := load(resource_path) as Texture2D
	if loaded == null:
		push_error("[LPC] %s failed to load %s texture: %s" % [actor_display_name, animation_kind, resource_path])
		return null
	_validate_lpc_texture(loaded, resource_path, animation_kind)
	return loaded


func _validate_lpc_texture(texture: Texture2D, resource_path: String, animation_kind: String) -> void:
	if texture.get_width() == 832 and texture.get_height() == 256:
		print("[LPC] %s %s texture loaded" % [actor_display_name, animation_kind])
		return
	print("[LPC] %s %s texture loaded as single-frame sprite %dx%d" % [
		actor_display_name, animation_kind, texture.get_width(), texture.get_height()
	])


func _build_sprite_frames() -> SpriteFrames:
	if _uses_full_texture_mode():
		return _build_full_texture_sprite_frames()
	return _build_lpc_sprite_frames()


func _build_directional_frames() -> SpriteFrames:
	var texture_map := {
		&"south": south_texture_path,
		&"south_west": south_west_texture_path,
		&"west": west_texture_path,
		&"north_west": north_west_texture_path,
		&"north": north_texture_path,
		&"north_east": north_east_texture_path,
		&"east": east_texture_path,
		&"south_east": south_east_texture_path,
	}
	var has_any := false
	for value in texture_map.values():
		if String(value).strip_edges() != "":
			has_any = true
			break
	if not has_any:
		return null
	return DirectionalVisualHelper.build_sprite_frames(texture_map, idle_frames_per_second)


func _uses_full_texture_mode() -> bool:
	return (idle_sheet != null and (idle_sheet.get_width() != 832 or idle_sheet.get_height() != 256)) \
		or (walk_sheet != null and (walk_sheet.get_width() != 832 or walk_sheet.get_height() != 256))


func _build_full_texture_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var directions: Array[StringName] = [&"up", &"left", &"down", &"right"]
	var idle_texture := idle_sheet if idle_sheet != null else walk_sheet
	var walk_texture := walk_sheet if walk_sheet != null else idle_sheet
	for facing in directions:
		var idle_animation := StringName("idle_%s" % facing)
		frames.add_animation(idle_animation)
		frames.set_animation_loop(idle_animation, true)
		frames.set_animation_speed(idle_animation, idle_frames_per_second)
		frames.add_frame(idle_animation, idle_texture)

		var walk_animation := StringName("walk_%s" % facing)
		frames.add_animation(walk_animation)
		frames.set_animation_loop(walk_animation, true)
		frames.set_animation_speed(walk_animation, walk_frames_per_second)
		frames.add_frame(walk_animation, walk_texture if walk_texture != null else idle_texture)
	print("[LPC] %s SpriteFrames built in full-texture mode" % actor_display_name)
	return frames


func _build_lpc_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var directions: Array[StringName] = [&"up", &"left", &"down", &"right"]
	for row in directions.size():
		_add_lpc_animation(frames, idle_sheet, StringName("idle_%s" % directions[row]), row, idle_frame_count, idle_frames_per_second)
		_add_lpc_animation(frames, walk_sheet, StringName("walk_%s" % directions[row]), row, walk_frame_count, walk_frames_per_second)
	print("[LPC] %s SpriteFrames built" % actor_display_name)
	return frames


func _hide_placeholder_debug_visuals() -> void:
	for child in find_children("*", "CollisionShape2D", true, false):
		(child as CollisionShape2D).debug_color = Color.TRANSPARENT
	var fallback := get_node_or_null("FallbackVisual") as CanvasItem
	if fallback != null:
		fallback.visible = false


func _add_lpc_animation(
	frames: SpriteFrames,
	sheet: Texture2D,
	animation_name: StringName,
	row: int,
	frame_count: int,
	frames_per_second: float
) -> void:
	if sheet == null:
		return
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, true)
	frames.set_animation_speed(animation_name, frames_per_second)
	for column in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(column * 64, row * 64, 64, 64)
		frames.add_frame(animation_name, frame)


func _process(_delta: float) -> void:
	if velocity.is_zero_approx():
		_show_idle_frame()
		return

	_last_facing = _get_facing_direction(velocity)
	_show_movement_frame()


func _get_facing_direction(direction: Vector2) -> StringName:
	return _canonical_facing(DirectionalVisualHelper.facing_from_vector(direction, _last_facing))


func face_toward(world_position: Vector2) -> void:
	var direction := world_position - global_position
	if direction.is_zero_approx():
		return
	_last_facing = _get_facing_direction(direction)
	velocity = Vector2.ZERO
	_show_idle_frame()


func set_staged_facing(direction: StringName) -> void:
	var canonical := _canonical_facing(direction)
	if canonical.is_empty():
		push_warning("Unknown staged facing '%s' for %s." % [direction, actor_display_name])
		return
	_last_facing = canonical
	velocity = Vector2.ZERO
	_show_idle_frame()


func set_idle_emphasis(enabled: bool) -> void:
	visual_root.position = Vector2(0, -1) if enabled else Vector2.ZERO


func return_to_idle() -> void:
	velocity = Vector2.ZERO
	_last_facing = _canonical_facing(StringName(initial_facing))
	set_idle_emphasis(false)
	_show_idle_frame()


func _show_movement_frame() -> void:
	var walk_animation := _find_animation(&"walk", _last_facing)
	if not walk_animation.is_empty():
		if animated_sprite.animation != walk_animation:
			animated_sprite.animation = walk_animation
		if not animated_sprite.is_playing():
			animated_sprite.play()
		return

	var idle_animation := _find_animation(&"idle", _last_facing)
	if not idle_animation.is_empty():
		animated_sprite.stop()
		animated_sprite.animation = idle_animation
		animated_sprite.frame = 0


func _show_idle_frame() -> void:
	var idle_animation := _find_animation(&"idle", _last_facing)
	if not idle_animation.is_empty():
		if animated_sprite.animation != idle_animation:
			animated_sprite.animation = idle_animation
		if not animated_sprite.is_playing():
			animated_sprite.play()
		return

	animated_sprite.stop()
	var walk_animation := _find_animation(&"walk", _last_facing)
	if not walk_animation.is_empty():
		animated_sprite.animation = walk_animation
		animated_sprite.frame = mini(1, animated_sprite.sprite_frames.get_frame_count(walk_animation) - 1)


func _find_animation(prefix: StringName, facing: StringName) -> StringName:
	for candidate in _animation_candidates_for_facing(facing):
		var animation_name := StringName("%s_%s" % [prefix, candidate])
		if animated_sprite.sprite_frames.has_animation(animation_name):
			return animation_name

	return &""


func _animation_candidates_for_facing(facing: StringName) -> Array[StringName]:
	var canonical := _canonical_facing(facing)
	var candidates: Array[StringName] = [canonical]
	match canonical:
		&"south":
			candidates.append_array([&"down"])
		&"north":
			candidates.append_array([&"up"])
		&"east":
			candidates.append_array([&"right"])
		&"west":
			candidates.append_array([&"left"])
		&"south_east":
			candidates.append_array([&"east", &"south", &"right", &"down"])
		&"south_west":
			candidates.append_array([&"west", &"south", &"left", &"down"])
		&"north_east":
			candidates.append_array([&"east", &"north", &"right", &"up"])
		&"north_west":
			candidates.append_array([&"west", &"north", &"left", &"up"])
	return candidates


func _canonical_facing(facing: StringName) -> StringName:
	match facing:
		&"down", &"south":
			return &"south"
		&"down_left", &"south_west":
			return &"south_west"
		&"left", &"west":
			return &"west"
		&"up_left", &"north_west":
			return &"north_west"
		&"up", &"north":
			return &"north"
		&"up_right", &"north_east":
			return &"north_east"
		&"right", &"east":
			return &"east"
		&"down_right", &"south_east":
			return &"south_east"
		_:
			return &""
