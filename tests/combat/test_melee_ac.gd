extends GdUnitTestSuite
## F012 acceptance: kill a training dummy with a sword; guard break works (both directions).

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const DUMMY_SCENE := preload("res://src/world/dev/training_dummy.tscn")
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
	box.size = Vector3(40, 1, 40)
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


## A dummy 1.3 m in front of the player (who faces -Z), facing the player.
func _dummy(setup: Callable = Callable()) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector3(0, 0, -1.3)
	dummy.rotation.y = PI
	if setup.is_valid():
		setup.call(dummy)
	_world.add_child(dummy)
	dummy.set_physics_process(false)
	return dummy


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_step_all(10)


func _step_all(count: int, dummy: TrainingDummy = null) -> void:
	for i in count:
		_player.step(DT)
		if dummy != null:
			dummy.step(DT)


## One full light swing (tap, then run until the weapon is idle again).
func _light_swing(dummy: TrainingDummy) -> void:
	_input.attack_held = true
	_step_all(1, dummy)
	_input.attack_held = false
	for i in 120:
		_step_all(1, dummy)
		if _player.melee.get_state_path() == "Ready/Idle":
			return


func test_kill_training_dummy_with_sword() -> void:
	var dummy := _dummy()
	await _settle()
	assert_str(_player.melee.weapon.id).is_equal("arming_sword")
	var swings := 0
	while not dummy.health.is_dead() and swings < 12:
		_player.stamina.refill()
		_light_swing(dummy)
		swings += 1
	assert_bool(dummy.health.is_dead()).is_true()
	assert_int(swings).is_less_equal(6)


func test_heavies_kill_dummy_in_three() -> void:
	# Overheads come down on the head (weak point ×1.5), so two are usually enough.
	var dummy := _dummy()
	await _settle()
	var heavies := 0
	while not dummy.health.is_dead() and heavies < 6:
		_player.stamina.refill()
		_input.attack_held = true
		_step_all(40, dummy)
		_input.attack_held = false
		_step_all(1, dummy)
		assert_bool(_player.melee.swing.is_heavy()).is_true()
		heavies += 1
		for j in 120:
			_step_all(1, dummy)
			if _player.melee.get_state_path() == "Ready/Idle" or dummy.health.is_dead():
				break
	assert_bool(dummy.health.is_dead()).is_true()
	assert_int(heavies).is_less_equal(3)


func test_lights_guard_break_blocking_dummy() -> void:
	var dummy := _dummy(func(d: TrainingDummy) -> void: d.block_always = true)
	await _settle()
	var broken := [false]
	dummy.health.damaged.connect(
		func(result: DamageResult) -> void: broken[0] = broken[0] or result.guard_broken
	)
	var swings := 0
	while not broken[0] and swings < 20:
		_player.stamina.refill()
		_light_swing(dummy)
		swings += 1
	assert_bool(broken[0]).is_true()
	assert_bool(dummy.guard_broken).is_true()
	assert_bool(dummy.health.block.active).is_false()
	assert_str(dummy.get_node("Label").text).contains("GUARD BROKEN")
	# The block comes back after guard_break_s.
	_step_all(70, dummy)
	assert_bool(dummy.health.block.active).is_true()


func test_heavy_staggers_dummy_and_interrupts_sparring() -> void:
	var dummy := _dummy(func(d: TrainingDummy) -> void: d.spar_enabled = true)
	await _settle()
	# Let the sparring dummy start its telegraph, then heavy it (35 stagger > 30 poise).
	for i in 400:
		dummy.step(DT)
		if dummy.spar_phase == &"windup":
			break
	assert_str(dummy.spar_phase).is_equal("windup")
	dummy.spar_windup_s = 10.0  # keep the telegraph up while we charge
	dummy.step(DT)
	_player.health.invulnerable = true
	_input.attack_held = true
	_step_all(40, dummy)
	_input.attack_held = false
	for j in 60:
		_step_all(1, dummy)
		if dummy.poise.is_staggered():
			break
	assert_bool(dummy.poise.is_staggered()).is_true()
	assert_str(dummy.spar_phase).is_equal("idle")


func test_sparring_dummy_guard_breaks_blocking_player() -> void:
	var dummy := _dummy(func(d: TrainingDummy) -> void: d.spar_enabled = true)
	await _settle()
	_input.block_held = true
	_step_all(2)
	_player.stamina.current = 10.0  # 40 dmg × 0.7 × 0.5 = 14 stamina needed
	var results: Array[DamageResult] = []
	dummy.spar_swung.connect(func(hits: Array[DamageResult]) -> void: results.append_array(hits))
	for i in 400:
		_player.stamina.current = minf(_player.stamina.current, 10.0)
		_step_all(1, dummy)
		if not results.is_empty():
			break
	assert_int(results.size()).is_equal(1)
	assert_bool(results[0].blocked).is_true()
	assert_bool(results[0].guard_broken).is_true()
	assert_str(_player.melee.get_state_path()).is_equal("Staggered")
	assert_float(_player.health.current_health).is_equal_approx(100.0 - 12.0, 0.001)
