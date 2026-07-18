extends CharacterBody2D

@export var actor_id: StringName
@export var move_speed: float = 160.0
@export var sprite_frames: SpriteFrames
@export var sprite_offset: Vector2 = Vector2.ZERO
@export_range(1, 8, 1) var visual_scale: int = 1

@onready var visual_root: Node2D = $VisualRoot
@onready var animated_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D

var _last_facing: StringName = &"down"


func _ready() -> void:
	if sprite_frames == null:
		push_error("BaseActor requires a SpriteFrames resource.")
		set_process(false)
		return

	animated_sprite.sprite_frames = sprite_frames
	animated_sprite.position = sprite_offset
	visual_root.scale = Vector2.ONE * visual_scale
	_show_idle_frame()


func _process(_delta: float) -> void:
	if velocity.is_zero_approx():
		_show_idle_frame()
		return

	_last_facing = _get_facing_direction(velocity)
	_show_movement_frame()


func _get_facing_direction(direction: Vector2) -> StringName:
	if absf(direction.x) > absf(direction.y):
		return &"left" if direction.x < 0.0 else &"right"

	return &"up" if direction.y < 0.0 else &"down"


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
	animated_sprite.stop()

	var idle_animation := _find_animation(&"idle", _last_facing)
	if not idle_animation.is_empty():
		animated_sprite.animation = idle_animation
		animated_sprite.frame = 0
		return

	var walk_animation := _find_animation(&"walk", _last_facing)
	if not walk_animation.is_empty():
		animated_sprite.animation = walk_animation
		animated_sprite.frame = mini(1, animated_sprite.sprite_frames.get_frame_count(walk_animation) - 1)


func _find_animation(prefix: StringName, facing: StringName) -> StringName:
	var animation_name := StringName("%s_%s" % [prefix, facing])
	if animated_sprite.sprite_frames.has_animation(animation_name):
		return animation_name

	return &""
