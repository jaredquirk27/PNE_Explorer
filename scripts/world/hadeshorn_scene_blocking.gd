extends Node

@export var cogline_path: NodePath
@export var walker_path: NodePath
@export var par_path: NodePath
@export var coll_path: NodePath
@export var morgan_path: NodePath
@export var wren_path: NodePath
@export var garth_path: NodePath

var _cogline: CharacterBody2D
var _walker: CharacterBody2D
var _par: CharacterBody2D
var _coll: CharacterBody2D
var _morgan: CharacterBody2D
var _wren: CharacterBody2D
var _garth: CharacterBody2D


func _ready() -> void:
	_cogline = get_node_or_null(cogline_path) as CharacterBody2D
	_walker = get_node_or_null(walker_path) as CharacterBody2D
	_par = get_node_or_null(par_path) as CharacterBody2D
	_coll = get_node_or_null(coll_path) as CharacterBody2D
	_morgan = get_node_or_null(morgan_path) as CharacterBody2D
	_wren = get_node_or_null(wren_path) as CharacterBody2D
	_garth = get_node_or_null(garth_path) as CharacterBody2D
	if [_cogline, _walker, _par, _coll, _morgan, _wren, _garth].has(null):
		push_error("HadeshornSceneBlocking could not resolve every staged actor.")
		return

	_apply_opening_facings()
	_run_brothers_conversation()
	_run_wren_garth_signing()
	_run_walker_observation()


func _apply_opening_facings() -> void:
	_cogline.call(&"set_staged_facing", &"up")
	_walker.call(&"set_staged_facing", &"up")
	_par.call(&"set_staged_facing", &"right")
	_coll.call(&"set_staged_facing", &"left")
	_morgan.face_toward((_par.global_position + _coll.global_position) * 0.5)
	_wren.call(&"set_staged_facing", &"right")
	_garth.call(&"set_staged_facing", &"left")


func _run_brothers_conversation() -> void:
	while is_inside_tree():
		_par.call(&"set_idle_emphasis", true)
		await get_tree().create_timer(1.1).timeout
		_par.call(&"set_idle_emphasis", false)
		await get_tree().create_timer(0.7).timeout
		_coll.call(&"set_idle_emphasis", true)
		await get_tree().create_timer(1.0).timeout
		_coll.call(&"set_idle_emphasis", false)
		await get_tree().create_timer(2.4).timeout


func _run_wren_garth_signing() -> void:
	while is_inside_tree():
		# Idle A: Wren signs while Garth watches.
		_wren.call(&"set_staged_facing", &"right")
		_garth.call(&"set_staged_facing", &"left")
		_wren.call(&"set_idle_emphasis", true)
		await get_tree().create_timer(1.2).timeout
		_wren.call(&"set_idle_emphasis", false)

		# Idle B: Garth answers in sign.
		_garth.call(&"set_idle_emphasis", true)
		await get_tree().create_timer(1.2).timeout
		_garth.call(&"set_idle_emphasis", false)

		# Idle C: both briefly check the lake.
		_wren.call(&"set_staged_facing", &"up")
		_garth.call(&"set_staged_facing", &"up")
		await get_tree().create_timer(1.0).timeout

		# Idle D: their signed conversation resumes.
		_wren.call(&"set_staged_facing", &"right")
		_garth.call(&"set_staged_facing", &"left")
		await get_tree().create_timer(2.4).timeout


func _run_walker_observation() -> void:
	while is_inside_tree():
		await get_tree().create_timer(7.5).timeout
		_walker.face_toward(_cogline.global_position)
		await get_tree().create_timer(0.8).timeout
		_walker.call(&"set_staged_facing", &"up")
