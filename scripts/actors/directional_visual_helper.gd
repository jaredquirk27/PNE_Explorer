extends Object

const DIRECTIONS := [&"south", &"south_west", &"west", &"north_west", &"north", &"north_east", &"east", &"south_east"]

static func facing_from_vector(direction: Vector2, current_facing: StringName = &"south") -> StringName:
	if direction.is_zero_approx():
		return current_facing
	var abs_x := absf(direction.x)
	var abs_y := absf(direction.y)
	if abs_x > abs_y:
		return &"west" if direction.x < 0.0 else &"east"
	if abs_y > abs_x:
		return &"north" if direction.y < 0.0 else &"south"
	if direction.x < 0.0 and direction.y < 0.0:
		return &"north_west"
	if direction.x > 0.0 and direction.y < 0.0:
		return &"north_east"
	if direction.x < 0.0 and direction.y > 0.0:
		return &"south_west"
	if direction.x > 0.0 and direction.y > 0.0:
		return &"south_east"
	return current_facing

static func path_for_facing(path_map: Dictionary, facing: StringName) -> String:
	return String(path_map.get(facing, ""))

static func build_sprite_frames(texture_map: Dictionary, frames_per_second: float = 1.0) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for facing in DIRECTIONS:
		var path := String(texture_map.get(facing, ""))
		if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		var animation := StringName("idle_%s" % facing)
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		frames.set_animation_speed(animation, frames_per_second)
		frames.add_frame(animation, texture)
	return frames
