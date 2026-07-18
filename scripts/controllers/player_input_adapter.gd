extends Node

@export var player_controller_path: NodePath

var _player_controller: Node


func _ready() -> void:
	if player_controller_path.is_empty():
		push_error("PlayerInputAdapter requires a player_controller_path.")
		set_physics_process(false)
		return

	var target := get_node_or_null(player_controller_path)
	if target == null:
		push_error("PlayerInputAdapter could not find a controller at '%s'." % player_controller_path)
		set_physics_process(false)
		return

	if not target.has_method(&"set_move_direction"):
		push_error("PlayerInputAdapter target at '%s' must expose set_move_direction(direction: Vector2)." % player_controller_path)
		set_physics_process(false)
		return

	_player_controller = target


func _physics_process(_delta: float) -> void:
	if _player_controller == null:
		return

	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	_player_controller.call(&"set_move_direction", direction)
