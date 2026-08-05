extends Resource
class_name NPCActivityDefinition

@export var activity_id: StringName = &""
@export_file("*.png") var start_idle_texture_path: String
@export_range(0.0, 60.0, 0.1) var start_hold_duration: float = 0.4
@export_range(0.0, 60.0, 0.1) var start_wait_min_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var start_wait_max_seconds: float = 0.0
@export_range(0.1, 60.0, 0.1) var trigger_min_seconds: float = 10.0
@export_range(0.1, 60.0, 0.1) var trigger_max_seconds: float = 25.0
@export_file("*.png") var hold_frame_texture_path: String
@export_range(0.1, 60.0, 0.1) var hold_duration: float = 5.0
@export_range(0.1, 60.0, 0.1) var forward_fps: float = 6.0
@export_range(0.1, 60.0, 0.1) var backward_fps: float = 6.0
@export_file("*.png") var end_idle_texture_path: String
@export_range(0.0, 60.0, 0.1) var end_idle_hold_duration: float = 0.0
@export_range(0.0, 60.0, 0.1) var post_activity_cooldown_min: float = 0.0
@export_range(0.0, 60.0, 0.1) var post_activity_cooldown_max: float = 0.0
@export_range(0.0, 60.0, 0.1) var end_wait_min_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var end_wait_max_seconds: float = 0.0
@export_range(0.0, 1.0, 0.01) var look_toward_player_chance: float = 0.0
@export_range(0.0, 60.0, 0.1) var look_toward_player_min_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var look_toward_player_max_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var mural_wait_min_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var mural_wait_max_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var return_wait_min_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var return_wait_max_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var interaction_restart_min_seconds: float = 0.0
@export_range(0.0, 60.0, 0.1) var interaction_restart_max_seconds: float = 0.0
@export_range(0.1, 60.0, 0.1) var retrigger_min: float = 12.0
@export_range(0.1, 60.0, 0.1) var retrigger_max: float = 25.0
@export_enum("finish", "interrupt") var interrupt_policy: String = "finish"
@export_enum("south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east") var start_facing: String = "south_west"
@export_enum("south", "south_west", "west", "north_west", "north", "north_east", "east", "south_east") var end_facing: String = "south_east"
@export var forward_frames: Array[String] = []
@export var backward_frames: Array[String] = []
