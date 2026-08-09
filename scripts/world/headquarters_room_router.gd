extends RefCounted

static var _pending_spawn_id: StringName = &""
static var _pending_facing: StringName = &""


static func change_room(
	tree: SceneTree,
	scene_path: String,
	spawn_id: StringName,
	facing: StringName
) -> Error:
	if tree == null or not ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("Headquarters room scene is unavailable: %s" % scene_path)
		return ERR_FILE_NOT_FOUND
	_pending_spawn_id = spawn_id
	_pending_facing = facing
	return tree.change_scene_to_file(scene_path)


static func consume_entry(default_spawn_id: StringName, default_facing: StringName) -> Dictionary:
	var entry: Dictionary = {
		"spawn_id": _pending_spawn_id if not _pending_spawn_id.is_empty() else default_spawn_id,
		"facing": _pending_facing if not _pending_facing.is_empty() else default_facing,
	}
	_pending_spawn_id = &""
	_pending_facing = &""
	return entry
