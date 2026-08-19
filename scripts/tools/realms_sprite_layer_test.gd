extends Node2D

const HEAD_TEXTURE := preload("res://assets/actors/player/prototype/test/head.png")
const TORSO_TEXTURE := preload("res://assets/actors/player/prototype/test/torso.png")
const LEGS_TEXTURE := preload("res://assets/actors/player/prototype/test/legs.png")

@onready var stacked: Node2D = $Stacked
@onready var separated: Node2D = $Separated


func _ready() -> void:
	queue_redraw()
	_set_sprite_textures(stacked, 0.0)
	_set_sprite_textures(separated, 14.0)


func _draw() -> void:
	var grid_color := Color(0.22, 0.22, 0.24, 0.55)
	for x in range(0, 1024, 16):
		draw_line(Vector2(x, 0), Vector2(x, 768), grid_color, 1.0)
	for y in range(0, 768, 16):
		draw_line(Vector2(0, y), Vector2(1024, y), grid_color, 1.0)
	draw_rect(Rect2(Vector2.ZERO, Vector2(1024, 768)), Color(0.08, 0.09, 0.10, 1.0), true)


func _set_sprite_textures(root: Node2D, x_offset: float) -> void:
	var legs := root.get_node_or_null("Legs") as Sprite2D
	var torso := root.get_node_or_null("Torso") as Sprite2D
	var head := root.get_node_or_null("Head") as Sprite2D
	if legs != null:
		legs.texture = LEGS_TEXTURE
		legs.centered = false
		legs.position = Vector2(x_offset, 0)
		legs.scale = Vector2.ONE
	if torso != null:
		torso.texture = TORSO_TEXTURE
		torso.centered = false
		torso.position = Vector2(x_offset, 0)
		torso.scale = Vector2.ONE
	if head != null:
		head.texture = HEAD_TEXTURE
		head.centered = false
		head.position = Vector2(x_offset, 0)
		head.scale = Vector2.ONE
