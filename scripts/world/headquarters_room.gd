extends Node2D

const HeadquartersRoomRouter = preload("res://scripts/world/headquarters_room_router.gd")
const FollowerManager = preload("res://scripts/actors/follower_manager.gd")
const StaticNPCActorScene: PackedScene = preload("res://scenes/actors/static_npc_actor.tscn")

@export var room_id: StringName
@export var room_display_name: String = "Headquarters Room"
@export var player_path: NodePath
@export var spawn_points_path: NodePath
@export var default_spawn_id: StringName = &"default"
@export_enum("south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east") var default_facing: String = "south"


func _ready() -> void:
	call_deferred("_apply_entry_spawn")


func _apply_entry_spawn() -> void:
	var player: CharacterBody2D = get_node_or_null(player_path) as CharacterBody2D
	var spawn_points: Node2D = get_node_or_null(spawn_points_path) as Node2D
	if player == null or spawn_points == null:
		push_error("%s could not resolve its player or spawn points." % room_display_name)
		return
	var entry: Dictionary = HeadquartersRoomRouter.consume_entry(default_spawn_id, StringName(default_facing))
	var spawn_id: StringName = StringName(entry.get("spawn_id", default_spawn_id))
	var marker: Marker2D = spawn_points.get_node_or_null(NodePath(String(spawn_id))) as Marker2D
	if marker == null:
		push_error("%s has no spawn point named %s." % [room_display_name, spawn_id])
		return
	player.global_position = marker.global_position
	var facing: StringName = StringName(entry.get("facing", default_facing))
	if player.has_method(&"set_staged_facing"):
		player.call(&"set_staged_facing", facing)
	var actors_root: Node2D = player.get_parent() as Node2D
	FollowerManager.restore_followers(actors_root, player, room_id, StaticNPCActorScene)
