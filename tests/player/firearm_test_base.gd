extends GdUnitTestSuite
## Shared setup for F014 player tests: a floor, a player with sword + revolver + blunderbuss.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const DUMMY_SCENE := preload("res://src/world/dev/training_dummy.tscn")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const DT := 1.0 / 60.0
const FORWARD := Vector2(0, -1)

var _world: Node3D
var _player: Player
var _input: ScriptedInputSource


func _setup_world(loadout: Array[StringName]) -> void:
	_world = auto_free(Node3D.new())
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	add_child(_world)
	_player = _spawn_player(Vector3.ZERO, loadout)
	_input = _player.get_node("Input") as ScriptedInputSource
	await get_tree().physics_frame
	await get_tree().physics_frame
	_steps(10)


func _spawn_player(pos: Vector3, loadout: Array[StringName], yaw: float = 0.0) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.get_node("LocalInputSource").free()
	var input := ScriptedInputSource.new()
	input.name = "Input"
	player.add_child(input)
	player.starting_loadout_override = loadout
	player.position = pos
	player.rotation.y = yaw
	_world.add_child(player)
	player.set_physics_process(false)
	return player


func _dummy(pos: Vector3) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = pos
	dummy.rotation.y = PI
	_world.add_child(dummy)
	dummy.set_physics_process(false)
	return dummy


func _steps(count: int) -> void:
	for i in count:
		_player.step(DT)


func _click() -> void:
	_input.attack_held = true
	_steps(1)
	_input.attack_held = false
	_steps(1)


func _gun_state() -> String:
	return _player.firearm.get_state_path()


func _ammo(slot: int = 0) -> AmmoState:
	return _player.loadout.ammo[slot]
