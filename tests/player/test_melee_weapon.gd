# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F012: the player's melee weapon state machine, driven by scripted input.
## Arming sword defaults: light windup 0.15 / active 0.12 / recovery 0.3, heavy charge 0.6.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const DT := 1.0 / 60.0
const FORWARD := Vector2(0, -1)

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


func _state() -> String:
	return _player.melee.get_state_path()


## Hold attack for [param held_steps] steps, then release (one more step).
func _attack(held_steps: int = 1) -> void:
	_input.attack_held = true
	_steps(held_steps)
	_input.attack_held = false
	_steps(1)


func _steps_until(state: String, limit: int = 200) -> int:
	for i in limit:
		if _state() == state:
			return i
		_player.step(DT)
	return -1


func test_equips_starting_melee() -> void:
	assert_str(_player.melee.weapon.id).is_equal("arming_sword")
	assert_str(_state()).is_equal("Ready/Idle")
	assert_float(_player.health.block.reduction).is_equal(_player.melee.stats.block_reduction)


func test_tap_runs_a_light_swing() -> void:
	_input.attack_held = true
	_steps(1)
	assert_str(_state()).is_equal("Ready/Charging")
	_input.attack_held = false
	_steps(1)
	assert_str(_state()).is_equal("Attacking/Windup")
	assert_bool(_player.melee.swing.is_heavy()).is_false()
	assert_float(_player.stamina.current).is_equal(100.0 - 15.0)
	var to_active := _steps_until("Attacking/Active")
	assert_int(to_active).is_between(8, 10)  # 0.15 s windup
	var to_recovery := _steps_until("Attacking/Recovery")
	assert_int(to_recovery).is_between(6, 9)  # 0.12 s active
	var to_idle := _steps_until("Ready/Idle")
	assert_int(to_idle).is_between(17, 20)  # 0.3 s recovery


func test_full_charge_is_heavy() -> void:
	_attack(40)  # 0.67 s > 0.6 s charge
	assert_bool(_player.melee.swing.is_heavy()).is_true()
	assert_float(_player.stamina.current).is_equal(100.0 - 30.0)


func test_early_release_is_light() -> void:
	_attack(20)  # 0.33 s
	assert_bool(_player.melee.swing.is_heavy()).is_false()
	assert_float(_player.stamina.current).is_equal(85.0)


func test_charging_reports_ratio_and_slows() -> void:
	_input.attack_held = true
	_steps(18)
	assert_float(_player.melee.get_charge_ratio()).is_between(0.4, 0.6)
	assert_float(_player.combat_speed_mult).is_equal(_player.defaults.charge_move_mult)
	assert_bool(_player.sprint_locked).is_true()


func test_no_attack_without_stamina() -> void:
	_player.stamina.drain(100.0)  # also pauses regen
	_attack()
	assert_str(_state()).is_equal("Ready/Idle")


func test_last_stamina_allows_a_swing_and_exhausts() -> void:
	_player.stamina.current = 5.0
	_attack()
	assert_str(_state()).is_equal("Attacking/Windup")
	assert_float(_player.stamina.current).is_equal(0.0)
	assert_bool(_player.stamina.is_exhausted()).is_true()


func test_block_raises_guard_and_slows() -> void:
	_input.block_held = true
	_input.hold(FORWARD)
	_steps(40)
	assert_str(_state()).is_equal("Ready/Blocking")
	assert_bool(_player.health.block.active).is_true()
	var speed := PlayerMotor.horizontal_speed(_player.velocity)
	assert_float(speed).is_equal_approx(4.5 * 0.6, 0.05)
	_input.block_held = false
	_steps(1)
	assert_bool(_player.health.block.active).is_false()


func test_attacking_and_blocking_cancel_sprint() -> void:
	_input.hold(FORWARD, true)
	_steps(30)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Sprint")
	_input.block_held = true
	_steps(2)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Walk")
	_input.block_held = false
	_steps(2)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Sprint")
	_attack()
	_steps(1)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Walk")


func test_feint_cancels_windup_without_refund() -> void:
	_attack()
	assert_str(_state()).is_equal("Attacking/Windup")
	_input.block_held = true
	_steps(1)
	assert_str(_state()).is_equal("Ready/Blocking")
	assert_float(_player.stamina.current).is_equal(85.0)


func test_block_cannot_cancel_recovery() -> void:
	_attack()
	_steps_until("Attacking/Recovery")
	_input.block_held = true
	_steps(3)
	assert_str(_state()).is_equal("Attacking/Recovery")
	_steps_until("Ready/Blocking")
	assert_str(_state()).is_equal("Ready/Blocking")


func test_buffered_light_chains_and_alternates() -> void:
	_attack()
	assert_int(_player.melee.swing.sweep).is_equal(SwingSpec.Sweep.LEFT_TO_RIGHT)
	_steps_until("Attacking/Recovery")
	_steps(10)  # late in the 0.3 s recovery
	_attack()  # press + release while recovering
	var first_swing := _player.melee.swing
	_steps_until("Attacking/Windup")
	assert_object(_player.melee.swing).is_not_same(first_swing)
	assert_int(_player.melee.swing.sweep).is_equal(SwingSpec.Sweep.RIGHT_TO_LEFT)
	assert_float(_player.stamina.current).is_equal(100.0 - 30.0)


func test_stale_buffer_is_dropped() -> void:
	_attack()
	_steps_until("Attacking/Recovery")
	_attack()  # released at the very start of recovery: > 0.2 s before it ends
	_steps_until("Ready/Idle", 40)
	assert_str(_state()).is_equal("Ready/Idle")
	assert_float(_player.stamina.current).is_equal(85.0)


func test_guard_break_staggers() -> void:
	_input.block_held = true
	_steps(20)  # past the 0.2 s parry window: this is a plain block

	_player.stamina.current = 5.0
	var attacker_body: Node3D = auto_free(Node3D.new())
	var attacker := HealthComponent.new()
	attacker.faction = CombatTypes.Faction.CULT
	attacker_body.add_child(attacker)
	_world.add_child(attacker_body)
	attacker_body.global_position = _player.global_position + Vector3(0, 0, -1.5)
	var result := Combat.apply(
		DamageEvent.from_source(attacker, _player.health, 40, CombatTypes.DamageType.MELEE)
	)
	assert_bool(result.guard_broken).is_true()
	assert_str(_state()).is_equal("Staggered")
	assert_bool(_player.health.block.active).is_false()
	_steps(1)
	assert_float(_player.combat_speed_mult).is_equal(_player.defaults.guard_break_move_mult)
	_attack()
	assert_str(_state()).is_equal("Staggered")
	assert_bool(_player.health.block.active).is_false()
	_input.block_held = false
	_steps(60)
	assert_str(_state()).is_equal("Ready/Idle")


func test_equip_swaps_weapon_and_block_stats() -> void:
	var greatsword: WeaponData = ContentDB.get_item(&"WeaponData", &"greatsword")
	_player.melee.equip(greatsword)
	assert_str(_player.melee.weapon.id).is_equal("greatsword")
	assert_float(_player.health.block.reduction).is_equal(0.8)
	_attack()
	assert_float(_player.melee.swing.damage).is_equal(55.0)


func test_dead_player_cannot_attack() -> void:
	Combat.apply(DamageEvent.world(_player.health, 500, CombatTypes.DamageType.DEBUG))
	_attack()
	assert_str(_state()).is_equal("Ready/Idle")
	assert_float(_player.stamina.current).is_equal(100.0)


func test_fresh_block_press_opens_parry_window() -> void:
	_input.block_held = true
	_steps(1)
	assert_bool(_player.health.block.is_parry_window_open()).is_true()
	_steps(13)
	assert_bool(_player.health.block.is_parry_window_open()).is_false()
	assert_bool(_player.health.block.is_locked_out()).is_true()


func test_block_held_through_stagger_does_not_open_window() -> void:
	_input.block_held = true
	_steps(20)
	_player.melee.notify_staggered(0.3)
	_steps(30)  # stagger ends with block still held
	assert_str(_state()).is_equal("Ready/Blocking")
	assert_bool(_player.health.block.is_parry_window_open()).is_false()


func test_stun_staggers_for_stun_duration_and_interrupts_swing() -> void:
	_attack()
	assert_str(_state()).is_equal("Attacking/Windup")
	var other := HealthComponent.new()
	var other_body: Node3D = auto_free(Node3D.new())
	other_body.add_child(other)
	_world.add_child(other_body)
	_player.health.stun(1.2, other)
	assert_str(_state()).is_equal("Staggered")
	_steps(60)
	assert_str(_state()).is_equal("Staggered")
	_steps(15)
	assert_str(_state()).is_equal("Ready/Idle")
