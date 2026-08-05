extends "res://scripts/actors/base_actor.gd"

@export var leader_path: NodePath
@export var follow_distance: float = 44.0
@export var stop_distance: float = 8.0
@export var movement_speed: float = 145.0
@export var catch_up_distance: float = 240.0
@export var catch_up_teleport_enabled: bool = true

var _leader: CharacterBody2D
var _following: bool = false
var _last_leader_direction: Vector2 = Vector2.DOWN


func _ready() -> void:
	super()
	_resolve_leader()


func _physics_process(_delta: float) -> void:
	if _leader == null or not is_instance_valid(_leader):
		velocity = Vector2.ZERO
		_resolve_leader()
		return

	if not _leader.velocity.is_zero_approx():
		_last_leader_direction = _leader.velocity.normalized()

	var follow_position := _leader.global_position - _last_leader_direction * follow_distance
	var player_separation := global_position.distance_to(_leader.global_position)
	if catch_up_teleport_enabled and catch_up_distance > 0.0 and player_separation > catch_up_distance:
		global_position = follow_position.round()
		velocity = Vector2.ZERO
		_following = false
		return

	var offset := follow_position - global_position
	var resume_distance := stop_distance + 4.0
	if _following:
		_following = offset.length() > stop_distance
	else:
		_following = offset.length() > resume_distance

	if not _following:
		velocity = Vector2.ZERO
		return

	velocity = offset.normalized() * movement_speed
	if velocity.length() > offset.length() / maxf(get_physics_process_delta_time(), 0.001):
		velocity = offset / maxf(get_physics_process_delta_time(), 0.001)
	move_and_slide()


func set_leader(actor: CharacterBody2D) -> void:
	_leader = actor


func _resolve_leader() -> void:
	if leader_path.is_empty():
		push_warning("CompanionActor has no leader_path; call set_leader() before following.")
		return
	_leader = get_node_or_null(leader_path) as CharacterBody2D
	if _leader == null:
		push_error("CompanionActor could not resolve leader at '%s'." % leader_path)
