extends RefCounted

const MAX_ACTIVE_FOLLOWERS: int = 3

static var _active_follower_ids: Array[StringName] = []
static var _follower_snapshots: Dictionary = {}


static func add_follower(actor: Node) -> Dictionary:
	if actor == null or not is_instance_valid(actor):
		return {"ok": false, "message": "That companion is unavailable."}
	var actor_id: StringName = StringName(actor.get(&"actor_id"))
	if actor_id.is_empty() or not bool(actor.get(&"can_follow")):
		return {"ok": false, "message": "This character cannot follow you."}
	if is_following(actor_id):
		return {"ok": true, "slot": formation_slot(actor_id), "message": ""}
	if _active_follower_ids.size() >= MAX_ACTIVE_FOLLOWERS:
		return {"ok": false, "message": "Your group is full."}
	if not actor.has_method(&"get_follower_snapshot"):
		return {"ok": false, "message": "That companion cannot be prepared to follow."}
	var snapshot_value: Variant = actor.call(&"get_follower_snapshot")
	if not snapshot_value is Dictionary:
		return {"ok": false, "message": "That companion cannot be prepared to follow."}
	var snapshot: Dictionary = snapshot_value
	_follower_snapshots[actor_id] = snapshot.duplicate(true)
	_active_follower_ids.append(actor_id)
	return {"ok": true, "slot": _active_follower_ids.size() - 1, "message": ""}


static func remove_follower(actor_id: StringName) -> bool:
	var index: int = _active_follower_ids.find(actor_id)
	if index < 0:
		return false
	_active_follower_ids.remove_at(index)
	_follower_snapshots.erase(actor_id)
	return true


static func is_following(actor_id: StringName) -> bool:
	return _active_follower_ids.has(actor_id)


static func follower_count() -> int:
	return _active_follower_ids.size()


static func active_follower_ids() -> Array[StringName]:
	return _active_follower_ids.duplicate()


static func formation_slot(actor_id: StringName) -> int:
	return _active_follower_ids.find(actor_id)


static func mark_transitioning(tree: SceneTree) -> void:
	for actor in _current_follower_actors(tree):
		if actor.has_method(&"set_follow_transitioning"):
			actor.call(&"set_follow_transitioning", true)


static func cancel_transition(tree: SceneTree) -> void:
	for actor in _current_follower_actors(tree):
		if actor.has_method(&"set_follow_transitioning"):
			actor.call(&"set_follow_transitioning", false)


static func refresh_formation_slots(tree: SceneTree) -> void:
	for actor in _current_follower_actors(tree):
		var actor_id: StringName = StringName(actor.get(&"actor_id"))
		if actor.has_method(&"set_follow_slot"):
			actor.call(&"set_follow_slot", formation_slot(actor_id))


static func restore_followers(
	actors_root: Node2D,
	player: CharacterBody2D,
	room_id: StringName,
	static_npc_scene: PackedScene
) -> void:
	if actors_root == null or player == null or static_npc_scene == null:
		return
	var removed_ids: Array[StringName] = []
	for actor_id in _active_follower_ids:
		var snapshot_value: Variant = _follower_snapshots.get(actor_id, {})
		if not snapshot_value is Dictionary:
			removed_ids.append(actor_id)
			continue
		var snapshot: Dictionary = snapshot_value
		if not _snapshot_allows_room(snapshot, room_id):
			removed_ids.append(actor_id)
			continue
		var actor: CharacterBody2D = _find_actor(actors_root, actor_id)
		if actor == null:
			actor = static_npc_scene.instantiate() as CharacterBody2D
			if actor == null:
				removed_ids.append(actor_id)
				continue
			_apply_snapshot(actor, snapshot)
			actor.set(&"current_room", room_id)
			actors_root.add_child(actor)
		if not actor.has_method(&"start_following"):
			removed_ids.append(actor_id)
			continue
		var started: bool = bool(actor.call(&"start_following", player, formation_slot(actor_id), room_id, true))
		if not started:
			removed_ids.append(actor_id)
	for actor_id in removed_ids:
		remove_follower(actor_id)
	refresh_formation_slots(actors_root.get_tree())


static func _find_actor(actors_root: Node2D, actor_id: StringName) -> CharacterBody2D:
	for child in actors_root.get_children():
		if child is CharacterBody2D and StringName(child.get(&"actor_id")) == actor_id:
			return child as CharacterBody2D
	return null


static func _apply_snapshot(actor: CharacterBody2D, snapshot: Dictionary) -> void:
	for property_name in snapshot.keys():
		if property_name == &"node_name":
			continue
		actor.set(property_name, snapshot[property_name])
	var node_name: String = String(snapshot.get(&"node_name", "Follower"))
	if not node_name.is_empty():
		actor.name = node_name


static func _snapshot_allows_room(snapshot: Dictionary, room_id: StringName) -> bool:
	var rooms_value: Variant = snapshot.get(&"allowed_rooms", PackedStringArray())
	if typeof(rooms_value) == TYPE_PACKED_STRING_ARRAY:
		var packed_rooms: PackedStringArray = rooms_value
		return packed_rooms.has(String(room_id))
	if rooms_value is Array:
		var rooms: Array = rooms_value
		return rooms.has(String(room_id))
	return false


static func _current_follower_actors(tree: SceneTree) -> Array[Node]:
	var actors: Array[Node] = []
	if tree == null:
		return actors
	for node in tree.get_nodes_in_group(&"headquarters_followers"):
		if is_instance_valid(node):
			actors.append(node)
	return actors
