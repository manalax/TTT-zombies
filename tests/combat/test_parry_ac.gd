extends GdUnitTestSuite
## F013 acceptance: the parry window is exact to ±1 frame in real play, and riposte applies.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const DUMMY_SCENE := preload("res://src/world/dev/training_dummy.tscn")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const DT := 1.0 / 60.0

var _world: Node3D


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


func _player(pos: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.get_node("LocalInputSource").free()
	var input := ScriptedInputSource.new()
	input.name = "Input"
	player.add_child(input)
	player.position = pos
	player.rotation.y = yaw
	_world.add_child(player)
	player.set_physics_process(false)
	return player


func _src(player: Player) -> ScriptedInputSource:
	return player.get_node("Input") as ScriptedInputSource


func _sparring_dummy(unparryable: bool = false) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector3(0, 0, -1.6)
	dummy.rotation.y = PI
	dummy.spar_enabled = true
	dummy.spar_unparryable = unparryable
	_world.add_child(dummy)
	dummy.set_physics_process(false)
	return dummy


func _settle(players: Array[Player]) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i in 10:
		for p in players:
			p.step(DT)


## Presses block [param ticks_before] ticks before the dummy's swing lands; returns its hit.
func _block_then_swing(ticks_before: int, unparryable: bool = false) -> Array:
	var player := _player()
	var dummy := _sparring_dummy(unparryable)
	await _settle([player])
	var hits: Array[DamageResult] = []
	dummy.spar_swung.connect(func(r: Array[DamageResult]) -> void: hits.append_array(r))
	# Run until the swing would land within ticks_before, then press block.
	dummy.spar_windup_s = 10.0
	for i in 600:
		player.step(DT)
		dummy.step(DT)
		if dummy.spar_phase == &"windup":
			break
	_src(player).block_held = true
	player.step(DT)  # fresh press: window opens with elapsed 0
	for i in ticks_before:
		player.step(DT)
	# Force the swing to land now: end the windup and run the active sweep.
	dummy.trigger_spar_swing()
	for i in 20:
		dummy.step(DT)
		if not hits.is_empty():
			break
	return [player, dummy, hits]


func test_parry_at_last_frame_of_window() -> void:
	var r: Array = await _block_then_swing(12)
	var player: Player = r[0]
	var dummy: TrainingDummy = r[1]
	var hits: Array[DamageResult] = r[2]
	assert_int(hits.size()).is_equal(1)
	assert_bool(hits[0].parried).is_true()
	assert_float(player.health.current_health).is_equal(100.0)
	assert_bool(dummy.health.is_stunned()).is_true()
	assert_str(dummy.get_node("Label").text).contains("STUNNED")


func test_one_frame_late_is_only_a_block() -> void:
	var r: Array = await _block_then_swing(13)
	var hits: Array[DamageResult] = r[2]
	assert_int(hits.size()).is_equal(1)
	assert_bool(hits[0].parried).is_false()
	assert_bool(hits[0].blocked).is_true()
	assert_bool((r[1] as TrainingDummy).health.is_stunned()).is_false()


func test_riposte_bonus_applied_once() -> void:
	var r: Array = await _block_then_swing(5)
	var player: Player = r[0]
	var dummy: TrainingDummy = r[1]
	assert_bool(dummy.health.is_stunned()).is_true()
	var input := _src(player)
	input.block_held = false
	player.step(DT)
	var results: Array[DamageResult] = []
	player.melee.swing_hit.connect(func(h: Array[DamageResult]) -> void: results.append_array(h))
	for swing in 2:
		player.stamina.refill()
		input.attack_held = true
		player.step(DT)
		input.attack_held = false
		for i in 60:
			player.step(DT)
			dummy.step(DT)
			if player.melee.get_state_path() == "Ready/Idle":
				break
	assert_int(results.size()).is_equal(2)
	assert_bool(results[0].riposte).is_true()
	assert_float(results[0].stages["riposte"]).is_equal_approx(
		results[0].stages["zone"] * 2.5, 0.001
	)
	assert_str(dummy.last_hit).is_not_empty()
	assert_bool(results[1].riposte).is_false()


func test_player_parries_player_and_ripostes() -> void:
	# Betrayal preset: friendly fire on. A faces -Z toward B; B faces +Z toward A.
	var a := _player(Vector3(0, 0, 0))
	var b := _player(Vector3(0, 0, -1.4), PI)
	await _settle([a, b])
	var parried := [false]
	b.health.damaged.connect(
		func(res: DamageResult) -> void: parried[0] = parried[0] or res.parried
	)
	# A taps a light (windup 0.15 s = 9 ticks); B presses block 4 ticks later, so the swing
	# lands about 5-12 ticks into B's 12-tick window.
	_src(a).attack_held = true
	_step_both(a, b, 1)
	_src(a).attack_held = false
	_step_both(a, b, 4)
	_src(b).block_held = true
	for i in 30:
		_step_both(a, b, 1)
		if parried[0]:
			break
	assert_bool(parried[0]).is_true()
	assert_float(b.health.current_health).is_equal(100.0)
	assert_str(a.melee.get_state_path()).is_equal("Staggered")
	assert_object(a.health.riposte_by).is_same(b.health)
	var riposte := DamageEvent.from_source(b.health, a.health, 35, CombatTypes.DamageType.MELEE)
	riposte.riposte_mult = 2.5
	assert_float(Combat.apply(riposte).applied).is_equal_approx(87.5, 0.001)


func _step_both(a: Player, b: Player, count: int) -> void:
	for i in count:
		a.step(DT)
		b.step(DT)


func test_unparryable_goes_through_block_and_is_dodged() -> void:
	var r: Array = await _block_then_swing(3, true)
	var player: Player = r[0]
	var hits: Array[DamageResult] = r[2]
	assert_bool(hits[0].parried).is_false()
	assert_bool(hits[0].blocked).is_false()
	assert_float(player.health.current_health).is_equal(60.0)
	# Now dodge the next unparryable swing.
	var dummy: TrainingDummy = r[1]
	var input := _src(player)
	input.block_held = false
	player.step(DT)
	hits.clear()
	dummy.trigger_spar_swing()
	input.press_dodge()
	player.step(DT)
	assert_bool(player.health.has_iframes()).is_true()
	for i in 10:
		dummy.step(DT)
	assert_float(player.health.current_health).is_equal(60.0)
