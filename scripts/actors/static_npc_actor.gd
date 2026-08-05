extends CharacterBody2D

const DirectionalVisualHelper = preload("res://scripts/actors/directional_visual_helper.gd")
const NPCActivityDefinition = preload("res://scripts/actors/npc_activity_definition.gd")

@export var actor_id: StringName
@export var actor_display_name: String = "NPC"
@export_file("*.png") var sprite_texture_path: String
@export_file("*.png") var south_texture_path: String
@export_file("*.png") var south_west_texture_path: String
@export_file("*.png") var west_texture_path: String
@export_file("*.png") var north_west_texture_path: String
@export_file("*.png") var north_texture_path: String
@export_file("*.png") var north_east_texture_path: String
@export_file("*.png") var east_texture_path: String
@export_file("*.png") var south_east_texture_path: String
@export_range(0.1, 8.0, 0.05) var visual_scale: float = 0.4
@export var sprite_offset: Vector2 = Vector2.ZERO
@export var interaction_prompt: String = "Talk"
@export var interaction_action: String = ""
@export var interaction_enabled: bool = true
@export var ambient_motion_enabled: bool = true
@export_range(8.0, 128.0, 1.0) var roam_radius: float = 20.0
@export_range(0.1, 8.0, 0.05) var ambient_move_speed: float = 18.0
@export_range(0.2, 6.0, 0.05) var ambient_pause_min: float = 0.8
@export_range(0.2, 6.0, 0.05) var ambient_pause_max: float = 2.2
@export var activity_definitions: Array[NPCActivityDefinition] = []
@export var activity_debug_enabled: bool = false

@onready var visual_root: Node2D = $VisualRoot
@onready var animated_sprite: AnimatedSprite2D = $VisualRoot/AnimatedSprite2D
@onready var interaction_area: Area2D = $InteractionArea

var _home_position: Vector2
var _ambient_target: Vector2
var _ambient_timer: float = 0.0
var _ambient_state: StringName = &"pause"
var _ambient_rng := RandomNumberGenerator.new()
var _current_facing: StringName = &"south"
var _base_sprite_frames: SpriteFrames
var _active_activity: NPCActivityDefinition
var _activity_phase: StringName = &"idle"
var _activity_frame_index: int = 0
var _activity_timer: float = 0.0
var _activity_wait_timer: float = 0.0
var _activity_cooldown_timer: float = 0.0
var _activity_resume_ambient_motion: bool = true
var _activity_sprite_frames: SpriteFrames
var _activity_restart_pending: bool = false
var _activity_restart_facing: StringName = &"south"
var _activity_player_look_pending: bool = false
var _activity_player_look_facing: StringName = &"south"
var _activity_should_glance_player: bool = false
var _activity_paused_for_interaction: bool = false


func _ready() -> void:
	_home_position = global_position
	_ambient_rng.seed = int(abs(actor_id.hash())) ^ int(_home_position.x * 1000.0) ^ int(_home_position.y * 1000.0)
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.visible = false
	_apply_visuals()
	_base_sprite_frames = animated_sprite.sprite_frames
	visual_root.scale = Vector2.ONE * visual_scale
	animated_sprite.position = sprite_offset
	if interaction_area != null and interaction_area.has_method(&"set_interaction_enabled"):
		interaction_area.call(&"set_interaction_enabled", interaction_enabled)
	if interaction_area != null:
		interaction_area.set(&"display_name", actor_display_name)
		interaction_area.set(&"prompt_text", interaction_prompt)
		interaction_area.set(&"chronicle_action", interaction_action)
		interaction_area.set(&"interaction_id", actor_id)
	_pick_new_ambient_target(true)
	_select_activity_timer(true)
	_refresh_idle_animation()


func _physics_process(delta: float) -> void:
	_update_activity(delta)
	if not ambient_motion_enabled:
		return
	_update_ambient_motion(delta)


func _apply_visuals() -> void:
	var directional_frames := _build_directional_frames()
	if directional_frames != null:
		animated_sprite.sprite_frames = directional_frames
		animated_sprite.visible = true
		return
	if not sprite_texture_path.is_empty() and ResourceLoader.exists(sprite_texture_path, "Texture2D"):
		var texture := load(sprite_texture_path) as Texture2D
		if texture != null:
			var frames := SpriteFrames.new()
			frames.remove_animation(&"default")
			for facing in [&"south", &"south_west", &"west", &"north_west", &"north", &"north_east", &"east", &"south_east"]:
				var idle_animation := StringName("idle_%s" % facing)
				frames.add_animation(idle_animation)
				frames.set_animation_loop(idle_animation, true)
				frames.set_animation_speed(idle_animation, 1.0)
				frames.add_frame(idle_animation, texture)
			animated_sprite.sprite_frames = frames
			animated_sprite.visible = true
			return
	push_error("[StaticNPC] %s missing sprite texture(s)." % actor_display_name)


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
	return DirectionalVisualHelper.build_sprite_frames(texture_map, 1.0)


func _update_ambient_motion(delta: float) -> void:
	if _ambient_state == &"pause":
		_ambient_timer -= delta
		if _ambient_timer <= 0.0:
			_pick_new_ambient_target(false)
		return
	if _ambient_state == &"move":
		var to_target := _ambient_target - global_position
		if to_target.length() <= 2.0:
			global_position = _ambient_target
			velocity = Vector2.ZERO
			_ambient_state = &"pause"
			_ambient_timer = _ambient_rng.randf_range(ambient_pause_min, ambient_pause_max)
			_refresh_idle_animation()
			return
		velocity = to_target.normalized() * ambient_move_speed
		move_and_slide()
		_update_facing_from_velocity(velocity)
		_refresh_movement_animation()


func _pick_new_ambient_target(force_idle: bool) -> void:
	if _active_activity != null and _activity_phase != &"idle":
		return
	if force_idle:
		velocity = Vector2.ZERO
		_ambient_target = _home_position
		_ambient_timer = _ambient_rng.randf_range(ambient_pause_min, ambient_pause_max)
		_ambient_state = &"pause"
		_refresh_idle_animation()
		return
	var roam_offset := Vector2(
		_ambient_rng.randf_range(-roam_radius, roam_radius),
		_ambient_rng.randf_range(-roam_radius, roam_radius)
	)
	_ambient_target = _home_position + roam_offset
	_ambient_state = &"move"
	_update_facing_toward(_ambient_target)


func _update_facing_from_velocity(current_velocity: Vector2) -> void:
	if current_velocity.is_zero_approx():
		return
	_current_facing = _canonical_facing(DirectionalVisualHelper.facing_from_vector(current_velocity, _current_facing))


func _update_facing_toward(target: Vector2) -> void:
	var direction := target - global_position
	if direction.is_zero_approx():
		return
	_current_facing = _canonical_facing(DirectionalVisualHelper.facing_from_vector(direction, _current_facing))


func _refresh_movement_animation() -> void:
	var animation_name := _find_animation(&"walk", _current_facing)
	if animation_name.is_empty():
		animation_name = _find_animation(&"idle", _current_facing)
	if animation_name.is_empty():
		return
	if animated_sprite.animation != animation_name:
		animated_sprite.animation = animation_name
	animated_sprite.play()


func _refresh_idle_animation() -> void:
	var animation_name := _find_animation(&"idle", _current_facing)
	if animation_name.is_empty():
		return
	animated_sprite.stop()
	animated_sprite.animation = animation_name
	animated_sprite.frame = 0


func face_toward(world_position: Vector2) -> void:
	if _active_activity != null:
		_activity_paused_for_interaction = true
		_activity_restart_pending = true
		_activity_restart_facing = _canonical_facing(StringName(_active_activity.start_facing))
	var direction := world_position - global_position
	if direction.is_zero_approx():
		return
	_current_facing = _canonical_facing(DirectionalVisualHelper.facing_from_vector(direction, _current_facing))
	velocity = Vector2.ZERO
	_ambient_state = &"pause"
	_ambient_timer = _ambient_rng.randf_range(ambient_pause_min, ambient_pause_max)
	if _active_activity != null:
		_activity_phase = &"player_look"
		_activity_timer = 0.0
		animated_sprite.sprite_frames = _activity_sprite_frames
		_refresh_activity_frame()
	else:
		_refresh_idle_animation()


func return_to_idle() -> void:
	if _activity_paused_for_interaction and _active_activity != null:
		_current_facing = _canonical_facing(StringName(_active_activity.end_facing))
		_activity_phase = &"idle"
		_activity_frame_index = 0
		_activity_timer = 0.0
		_activity_cooldown_timer = _activity_wait_range(_active_activity.post_activity_cooldown_min, _active_activity.post_activity_cooldown_max, _active_activity.retrigger_min, _active_activity.retrigger_max)
		_active_activity = null
		_activity_paused_for_interaction = false
		_activity_restart_pending = false
		ambient_motion_enabled = _activity_resume_ambient_motion
		animated_sprite.sprite_frames = _base_sprite_frames
		_refresh_idle_animation()
		return
	_cancel_activity(false)
	if _activity_restart_pending:
		_current_facing = _activity_restart_facing
		_activity_restart_pending = false
	velocity = Vector2.ZERO
	_ambient_state = &"pause"
	_ambient_timer = _ambient_rng.randf_range(ambient_pause_min, ambient_pause_max)
	_refresh_idle_animation()


func set_staged_facing(direction: StringName) -> void:
	_cancel_activity(true)
	var canonical := _canonical_facing(direction)
	if canonical.is_empty():
		push_warning("Unknown staged facing '%s' for %s." % [direction, actor_display_name])
		return
	_current_facing = canonical
	_refresh_idle_animation()


func set_idle_emphasis(enabled: bool) -> void:
	visual_root.position = Vector2(0, -1) if enabled else Vector2.ZERO


func _update_activity(delta: float) -> void:
	if _active_activity == null:
		if _activity_cooldown_timer > 0.0:
			_activity_cooldown_timer -= delta
			if _activity_cooldown_timer <= 0.0:
				_activity_cooldown_timer = 0.0
				_select_activity_timer(true)
		return
	if _active_activity == null:
		return
	if _activity_paused_for_interaction:
		return
	if not velocity.is_zero_approx():
		return
	if _activity_phase == &"idle":
		_activity_wait_timer -= delta
		if _activity_wait_timer <= 0.0:
			_start_activity(_active_activity)
		return
	if activity_debug_enabled:
		print("[NPCActivity] id=%s phase=%s frame=%d timer=%.3f" % [
			_active_activity.activity_id, _activity_phase, _activity_frame_index, _activity_timer
		])
	_run_activity(delta)


func _select_activity_timer(use_initial_trigger: bool = false) -> void:
	_active_activity = null
	_activity_phase = &"idle"
	_activity_wait_timer = 0.0
	if activity_definitions.is_empty():
		return
	var valid: Array[NPCActivityDefinition] = []
	for definition in activity_definitions:
		if definition == null:
			continue
		if String(definition.activity_id).strip_edges().is_empty():
			continue
		valid.append(definition)
	if valid.is_empty():
		return
	_active_activity = valid[0]
	if use_initial_trigger:
		_activity_wait_timer = _activity_wait_range(_active_activity.trigger_min_seconds, _active_activity.trigger_max_seconds, _active_activity.retrigger_min, _active_activity.retrigger_max)
	else:
		_activity_wait_timer = _activity_wait_range(_active_activity.start_wait_min_seconds, _active_activity.start_wait_max_seconds, _active_activity.retrigger_min, _active_activity.retrigger_max)


func _start_activity(definition: NPCActivityDefinition) -> void:
	if definition == null:
		return
	_active_activity = definition
	_current_facing = _canonical_facing(StringName(definition.start_facing))
	_activity_restart_pending = false
	_activity_restart_facing = _canonical_facing(StringName(definition.start_facing))
	_activity_paused_for_interaction = false
	_activity_cooldown_timer = 0.0
	_activity_phase = &"start_idle"
	_activity_frame_index = 0
	_activity_timer = 0.0
	_activity_sprite_frames = _build_activity_sprite_frames(definition)
	if _activity_sprite_frames == null:
		_cancel_activity(true)
		return
	_activity_resume_ambient_motion = ambient_motion_enabled
	ambient_motion_enabled = false
	velocity = Vector2.ZERO
	animated_sprite.sprite_frames = _activity_sprite_frames
	_refresh_activity_frame()


func _run_activity(delta: float) -> void:
	if _active_activity == null:
		return
	match _activity_phase:
		&"start_idle":
			if _active_activity.start_hold_duration > 0.0:
				_activity_timer += delta
				if _activity_timer >= _active_activity.start_hold_duration:
					_activity_phase = &"forward"
					_activity_frame_index = 0
					_activity_timer = 0.0
					_refresh_activity_frame()
			else:
				_activity_phase = &"forward"
				_activity_frame_index = 0
				_activity_timer = 0.0
				_refresh_activity_frame()
		&"forward":
			_activity_timer += delta
			if _activity_timer >= _frame_duration(_active_activity.forward_fps):
				_activity_timer = 0.0
				_activity_frame_index += 1
				if _activity_frame_index >= _active_activity.forward_frames.size():
					_activity_phase = &"hold"
					_activity_timer = 0.0
					_refresh_activity_frame()
					return
				_refresh_activity_frame()
		&"hold":
			_activity_timer += delta
			if _activity_timer >= _active_activity.hold_duration:
				_activity_phase = &"backward"
				_activity_frame_index = 0
				_activity_timer = 0.0
				_refresh_activity_frame()
		&"backward":
			_activity_timer += delta
			if _activity_timer >= _frame_duration(_active_activity.backward_fps):
				_activity_timer = 0.0
				_activity_frame_index += 1
				if _activity_frame_index >= _active_activity.backward_frames.size():
					_activity_phase = &"end_idle_hold"
					_activity_timer = 0.0
					_current_facing = _canonical_facing(StringName(_active_activity.end_facing))
					_refresh_activity_frame()
					return
				_refresh_activity_frame()
		&"end_idle_hold":
			_activity_timer += delta
			if _activity_timer >= _active_activity.end_idle_hold_duration:
				_activity_phase = &"cooldown"
				_activity_timer = 0.0
				_activity_wait_timer = _activity_wait_range(_active_activity.post_activity_cooldown_min, _active_activity.post_activity_cooldown_max, _active_activity.retrigger_min, _active_activity.retrigger_max)
				_refresh_activity_frame()
			return
		&"cooldown":
			_activity_timer += delta
			if _activity_timer >= _activity_wait_timer:
				_finish_activity()
			return


func _refresh_activity_frame() -> void:
	if _active_activity == null:
		return
	var path := ""
	var frame_index := 0
	match _activity_phase:
		&"start_idle":
			path = _active_activity.start_idle_texture_path
		&"forward":
			path = _activity_frame_path(_active_activity.forward_frames, _activity_frame_index)
			frame_index = _activity_frame_index
		&"hold":
			path = _active_activity.hold_frame_texture_path if not _active_activity.hold_frame_texture_path.is_empty() else _activity_frame_path(_active_activity.forward_frames, maxi(0, _active_activity.forward_frames.size() - 1))
			frame_index = 0
		&"backward":
			path = _activity_frame_path(_active_activity.backward_frames, _activity_frame_index)
			frame_index = _activity_frame_index
		&"end_idle_hold", &"cooldown", &"end_idle":
			path = _active_activity.end_idle_texture_path
	if path.is_empty():
		return
	var animation := StringName("%s_%s" % [_activity_phase, _active_activity.activity_id])
	if animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation(animation):
		return
	if animated_sprite.animation != animation:
		animated_sprite.animation = animation
	animated_sprite.frame = frame_index
	if _activity_phase in [&"forward", &"backward"]:
		if not animated_sprite.is_playing():
			animated_sprite.play()
	else:
		animated_sprite.stop()


func _finish_activity() -> void:
	if _active_activity == null:
		return
	_current_facing = _canonical_facing(StringName(_active_activity.end_facing))
	_activity_phase = &"idle"
	_activity_frame_index = 0
	_activity_timer = 0.0
	_activity_cooldown_timer = _activity_wait_range(_active_activity.post_activity_cooldown_min, _active_activity.post_activity_cooldown_max, _active_activity.retrigger_min, _active_activity.retrigger_max)
	_active_activity = null
	ambient_motion_enabled = _activity_resume_ambient_motion
	_activity_restart_pending = false
	_activity_player_look_pending = false
	_activity_should_glance_player = false
	_activity_paused_for_interaction = false
	animated_sprite.sprite_frames = _base_sprite_frames
	_activity_wait_timer = 0.0
	_refresh_idle_animation()


func _cancel_activity(return_to_idle_pose: bool) -> void:
	if _active_activity == null:
		return
	_active_activity = null
	_activity_phase = &"idle"
	_activity_frame_index = 0
	_activity_timer = 0.0
	_activity_cooldown_timer = _activity_wait_range(_active_activity.post_activity_cooldown_min, _active_activity.post_activity_cooldown_max, _active_activity.retrigger_min, _active_activity.retrigger_max)
	ambient_motion_enabled = _activity_resume_ambient_motion
	_activity_restart_pending = false
	_activity_player_look_pending = false
	_activity_should_glance_player = false
	_activity_paused_for_interaction = false
	animated_sprite.sprite_frames = _base_sprite_frames
	_select_activity_timer(false)
	if return_to_idle_pose:
		_refresh_idle_animation()


func _frame_duration(fps: float) -> float:
	return 1.0 / maxf(fps, 0.1)


func _activity_frame_path(paths: Array[String], index: int) -> String:
	if index < 0 or index >= paths.size():
		return ""
	return String(paths[index])


func _build_activity_sprite_frames(definition: NPCActivityDefinition) -> SpriteFrames:
	if definition == null:
		return null
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	_add_activity_texture_animation(frames, StringName("start_idle_%s" % definition.activity_id), definition.start_idle_texture_path, false, 1.0)
	_add_activity_animation(frames, StringName("forward_%s" % definition.activity_id), definition.forward_frames, definition.forward_fps, false)
	_add_activity_texture_animation(frames, StringName("hold_%s" % definition.activity_id), definition.hold_frame_texture_path, true, 1.0)
	_add_activity_animation(frames, StringName("backward_%s" % definition.activity_id), definition.backward_frames, definition.backward_fps, false)
	_add_activity_texture_animation(frames, StringName("end_idle_hold_%s" % definition.activity_id), definition.end_idle_texture_path, false, 1.0)
	_add_activity_texture_animation(frames, StringName("cooldown_%s" % definition.activity_id), definition.end_idle_texture_path, false, 1.0)
	_add_activity_texture_animation(frames, StringName("end_idle_%s" % definition.activity_id), definition.end_idle_texture_path, false, 1.0)
	return frames


func _add_activity_animation(frames: SpriteFrames, animation_name: StringName, paths: Array[String], fps: float, loop: bool) -> void:
	if paths.is_empty():
		return
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for path in paths:
		if path.is_empty():
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			frames.add_frame(animation_name, texture)


func _add_activity_texture_animation(frames: SpriteFrames, animation_name: StringName, path: String, loop: bool, fps: float) -> void:
	if path.is_empty():
		return
	var texture := load(path) as Texture2D
	if texture == null:
		return
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	frames.add_frame(animation_name, texture)


func _activity_wait_range(min_seconds: float, max_seconds: float, fallback_min: float, fallback_max: float) -> float:
	if max_seconds > min_seconds:
		return _ambient_rng.randf_range(min_seconds, max_seconds)
	if fallback_max > fallback_min:
		return _ambient_rng.randf_range(fallback_min, fallback_max)
	return maxf(fallback_min, fallback_max)


func _find_animation(prefix: StringName, facing: StringName) -> StringName:
	for candidate in _animation_candidates_for_facing(facing):
		var animation_name := StringName("%s_%s" % [prefix, candidate])
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(animation_name):
			return animation_name
	return &""


func _animation_candidates_for_facing(facing: StringName) -> Array[StringName]:
	var canonical := _canonical_facing(facing)
	var candidates: Array[StringName] = [canonical]
	match canonical:
		&"south":
			candidates.append(&"down")
		&"north":
			candidates.append(&"up")
		&"east":
			candidates.append(&"right")
		&"west":
			candidates.append(&"left")
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
			return &"south"
