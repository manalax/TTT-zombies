extends GdUnitTestSuite
## F010 integration: the real player scene on a test floor, driven by scripted intents.
## Steps are run manually (Player.step) so timing is deterministic.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const DT := 1.0 / 60.0
const FORWARD := Vector2(0, -1)

var _world: Node3D
var _player: Player
var _input: ScriptedInputSource


func before_test() -> void:
	_world = auto_free(Node3D.new())
	_add_box(_world, Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	_player = PLAYER_SCENE.instantiate()
	_player.get_node("LocalInputSource").free()
	_input = ScriptedInputSource.new()
	_input.name = "ScriptedInputSource"
	_player.add_child(_input)
	_player.defaults = _defaults()
	_world.add_child(_player)
	add_child(_world)
	_player.set_physics_process(false)
	# Let the physics server register the bodies, then settle onto the floor.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_steps(10)


func _defaults() -> PlayerDefaults:
	var d := PlayerDefaults.new()
	d.id = &"test_defaults"
	d.display_name = "Test"
	return d


func _add_box(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.position = pos
	body.add_child(shape)
	parent.add_child(body)


func _steps(count: int) -> void:
	for i in count:
		_player.step(DT)


func _state() -> String:
	return _player.get_movement_state()


func _speed() -> float:
	return PlayerMotor.horizontal_speed(_player.velocity)


func test_starts_idle_on_floor() -> void:
	assert_str(_state()).is_equal("Grounded/Idle")
	assert_bool(_player.is_on_floor()).is_true()


func test_walk_then_sprint() -> void:
	_input.hold(FORWARD)
	_steps(30)
	assert_str(_state()).is_equal("Grounded/Walk")
	assert_float(_speed()).is_equal_approx(4.5, 0.05)
	_input.hold(FORWARD, true)
	_steps(30)
	assert_str(_state()).is_equal("Grounded/Sprint")
	assert_float(_speed()).is_equal_approx(7.0, 0.05)
	assert_float(_player.stamina.current).is_less(100.0)
	_input.hold(Vector2.ZERO)
	_steps(30)
	assert_str(_state()).is_equal("Grounded/Idle")
	assert_float(_speed()).is_less(0.01)


func test_strafe_does_not_sprint() -> void:
	_input.hold(Vector2.RIGHT, true)
	_steps(20)
	assert_str(_state()).is_equal("Grounded/Walk")
	_input.hold(Vector2(0, 1), true)
	_steps(5)
	assert_str(_state()).is_equal("Grounded/Walk")


func test_exhaustion_locks_sprint_until_recovered() -> void:
	_player.defaults.sprint_drain_per_s = 600.0  # empties 100 stamina in 10 steps
	_player.defaults.stamina_regen_delay_s = 0.0
	_player.stamina.regen_per_s = 60.0  # 1 stamina per step
	_player.stamina.regen_delay_s = 0.0
	_input.hold(FORWARD, true)
	_steps(15)
	assert_bool(_player.stamina.is_exhausted()).is_true()
	assert_str(_state()).is_equal("Grounded/Walk")
	_steps(20)  # ~20 stamina: still locked out while holding sprint
	assert_float(_player.stamina.current).is_less(30.0)
	assert_str(_state()).is_equal("Grounded/Walk")
	_player.defaults.sprint_drain_per_s = 0.0  # so the resumed sprint is not re-exhausted
	_steps(15)  # past 30: sprint resumes
	assert_float(_player.stamina.current).is_greater_equal(30.0)
	assert_str(_state()).is_equal("Grounded/Sprint")


func test_jump_and_land() -> void:
	_input.press_jump()
	_steps(1)
	assert_str(_state()).is_equal("Airborne")
	assert_float(_player.velocity.y).is_greater(0.0)
	var landings: Array[float] = []
	_player.landed.connect(func(speed: float) -> void: landings.append(speed))
	_steps(90)
	assert_str(_state()).is_equal("Grounded/Idle")
	assert_int(landings.size()).is_equal(1)
	assert_float(landings[0]).is_greater(3.0)


func test_no_sprint_start_in_air() -> void:
	_input.hold(FORWARD)
	_steps(30)
	_input.press_jump()
	_steps(1)
	_input.hold(FORWARD, true)
	var max_air_speed := 0.0
	for i in 20:
		_steps(1)
		assert_str(_state()).is_equal("Airborne")
		max_air_speed = maxf(max_air_speed, _speed())
	assert_float(max_air_speed).is_less_equal(4.5 + 0.01)
	_steps(60)
	assert_str(_state()).is_equal("Grounded/Sprint")


func test_sprint_momentum_carries_into_jump() -> void:
	_input.hold(FORWARD, true)
	_steps(40)
	_input.press_jump()
	_steps(10)
	assert_str(_state()).is_equal("Airborne")
	assert_float(_speed()).is_equal_approx(7.0, 0.05)


func test_crouch_and_stand() -> void:
	_input.hold(FORWARD, false, true)
	_steps(30)
	assert_str(_state()).is_equal("Grounded/Crouch")
	assert_bool(_player.is_crouched()).is_true()
	assert_float(_speed()).is_equal_approx(2.25, 0.05)
	_input.hold(FORWARD)
	_steps(2)
	assert_str(_state()).is_equal("Grounded/Walk")
	assert_bool(_player.is_crouched()).is_false()


func test_stays_crouched_under_ceiling() -> void:
	# Ceiling bottom at 1.4 m over z in [-6, -2]: crouched (1.1 m) fits, standing (1.8 m) does not.
	_add_box(_world, Vector3(6, 0.5, 4), Vector3(0, 1.65, -4))
	await get_tree().physics_frame
	_input.hold(FORWARD, false, true)
	_steps(110)  # ~4 m at crouch speed
	assert_float(_player.position.z).is_between(-5.5, -2.5)
	_input.hold(FORWARD)  # crouch released under the ceiling
	_steps(5)
	assert_str(_state()).is_equal("Grounded/Crouch")
	assert_bool(_player.is_crouched()).is_true()
	assert_bool(_player.has_headroom()).is_false()
	_steps(80)  # walk out the far side
	assert_str(_state()).is_equal("Grounded/Walk")
	assert_bool(_player.is_crouched()).is_false()


func test_crouch_cancels_sprint() -> void:
	_input.hold(FORWARD, true)
	_steps(20)
	_input.hold(FORWARD, true, true)
	_steps(2)
	assert_str(_state()).is_equal("Grounded/Crouch")
	# Sprint was already held when the crouch began, so it does not cancel the crouch.
	assert_bool(_input.crouch_cancelled).is_false()
	_input.hold(FORWARD, false, true)
	_steps(1)
	_input.hold(FORWARD, true, true)
	_steps(1)
	assert_bool(_input.crouch_cancelled).is_true()


func test_eye_height_lerps() -> void:
	var standing := _player.head.position.y
	_input.hold(Vector2.ZERO, false, true)
	_steps(1)
	assert_float(_player.head.position.y).is_between(
		_player.defaults.get_eye_height(true) + 0.01, standing - 0.01
	)
	_steps(20)
	assert_float(_player.head.position.y).is_equal_approx(
		_player.defaults.get_eye_height(true), 0.001
	)


func test_look_turns_body_and_clamps_pitch() -> void:
	_input.look = Vector2(90, 500)
	_player._process(DT)
	assert_float(_player.yaw).is_equal_approx(deg_to_rad(-90), 0.0001)
	assert_float(_player.pitch).is_equal_approx(deg_to_rad(-89), 0.0001)
	_input.hold(FORWARD)
	_steps(30)
	# Yawed 90° right: forward input moves toward +x.
	assert_float(_player.velocity.x).is_greater(4.0)
