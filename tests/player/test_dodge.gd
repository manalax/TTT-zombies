extends GdUnitTestSuite
## F013: the dodge movement state (dash, i-frames, cost, cooldown, cancels).

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const DT := 1.0 / 60.0

var _world: Node3D
var _player: Player
var _input: ScriptedInputSource


func before_test() -> void:
	_world = auto_free(Node3D.new())
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.add_child(shape)
	_world.add_child(floor_body)
	add_child(_world)
	_player = PLAYER_SCENE.instantiate()
	_player.get_node("LocalInputSource").free()
	_input = ScriptedInputSource.new()
	_player.add_child(_input)
	_world.add_child(_player)
	_player.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_steps(10)


func _steps(count: int) -> void:
	for i in count:
		_player.step(DT)


func _dodge(move: Vector2 = Vector2.ZERO) -> void:
	_input.hold(move)
	_input.press_dodge()
	_steps(1)


func test_dodge_dashes_in_move_direction() -> void:
	var start := _player.global_position
	_dodge(Vector2.RIGHT)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Dodge")
	_input.hold(Vector2.ZERO)
	_steps(30)
	var moved := _player.global_position - start
	assert_float(moved.x).is_between(2.6, 3.6)
	assert_float(absf(moved.z)).is_less(0.2)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Idle")


func test_no_input_is_a_backstep() -> void:
	var start := _player.global_position
	_dodge()
	_steps(30)
	assert_float(_player.global_position.z - start.z).is_between(2.6, 3.6)


func test_costs_stamina_and_grants_iframes() -> void:
	_dodge(Vector2.LEFT)
	assert_float(_player.stamina.current).is_equal_approx(80.0, 0.5)
	assert_bool(_player.health.has_iframes()).is_true()
	var attacker := HealthComponent.new()
	attacker.faction = CombatTypes.Faction.CULT
	var attacker_body: Node3D = auto_free(Node3D.new())
	attacker_body.add_child(attacker)
	_world.add_child(attacker_body)
	var swing := DamageEvent.from_source(attacker, _player.health, 30, CombatTypes.DamageType.MELEE)
	assert_str(Combat.apply(swing).reject_reason).is_equal("dodged")
	var fall := DamageEvent.world(_player.health, 5, CombatTypes.DamageType.FALL)
	assert_bool(Combat.apply(fall).accepted).is_true()
	_steps(12)  # i-frames last 0.2 s
	assert_bool(_player.health.has_iframes()).is_false()
	swing = DamageEvent.from_source(attacker, _player.health, 30, CombatTypes.DamageType.MELEE)
	assert_bool(Combat.apply(swing).accepted).is_true()


func test_cooldown() -> void:
	_dodge(Vector2.LEFT)
	_steps(18)  # dodge over (0.3 s)
	_dodge(Vector2.RIGHT)
	assert_str(_player.get_movement_state()).is_not_equal("Grounded/Dodge")
	_steps(25)  # cooldown 0.4 s
	_dodge(Vector2.RIGHT)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Dodge")


func test_not_without_stamina_or_in_air() -> void:
	_player.stamina.drain(100.0)
	_dodge(Vector2.LEFT)
	assert_str(_player.get_movement_state()).is_not_equal("Grounded/Dodge")
	_player.stamina.refill()
	_input.press_jump()
	_steps(3)
	_dodge(Vector2.LEFT)
	assert_str(_player.get_movement_state()).is_equal("Airborne")


func test_cancels_blocking() -> void:
	_input.block_held = true
	_steps(3)
	assert_str(_player.melee.get_state_path()).is_equal("Ready/Blocking")
	_dodge(Vector2.LEFT)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Dodge")
	assert_str(_player.melee.get_state_path()).is_equal("Ready/Idle")
	assert_bool(_player.health.block.active).is_false()
	_steps(3)
	# No block or attack starts while dodging, even with block still held.
	assert_str(_player.melee.get_state_path()).is_equal("Ready/Idle")


func test_cancels_recovery_but_not_windup() -> void:
	_input.attack_held = true
	_steps(1)
	_input.attack_held = false
	_steps(1)
	assert_str(_player.melee.get_state_path()).is_equal("Attacking/Windup")
	_dodge(Vector2.LEFT)
	assert_str(_player.get_movement_state()).is_not_equal("Grounded/Dodge")
	for i in 60:
		if _player.melee.get_state_path() == "Attacking/Recovery":
			break
		_steps(1)
	_dodge(Vector2.LEFT)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Dodge")
	assert_str(_player.melee.get_state_path()).is_equal("Ready/Idle")
