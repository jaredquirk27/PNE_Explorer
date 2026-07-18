extends Node

@export var controlled_actor_path: NodePath

var _controlled_actor: CharacterBody2D
var _move_direction: Vector2 = Vector2.ZERO


func _ready() -> void:
	if controlled_actor_path.is_empty():
		push_error("PlayerController requires a controlled_actor_path.")
		set_physics_process(false)
		return

	var target := get_node_or_null(controlled_actor_path)
	if target == null:
		push_error("PlayerController could not find an actor at '%s'." % controlled_actor_path)
		set_physics_process(false)
		return

	if not target is CharacterBody2D:
		push_error("PlayerController target at '%s' must be a CharacterBody2D." % controlled_actor_path)
		set_physics_process(false)
		return

	if not _has_property(target, &"move_speed"):
		push_error("PlayerController target at '%s' must define a move_speed property." % controlled_actor_path)
		set_physics_process(false)
		return

	_controlled_actor = target as CharacterBody2D


func set_move_direction(direction: Vector2) -> void:
	_move_direction = direction


func _physics_process(_delta: float) -> void:
	if _controlled_actor == null:
		return

	var movement_direction := _move_direction.limit_length(1.0)
	var move_speed := float(_controlled_actor.get(&"move_speed"))
	_controlled_actor.velocity = movement_direction * move_speed
	_controlled_actor.move_and_slide()


func _has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if property.name == property_name:
			return true

	return false
