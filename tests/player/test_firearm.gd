# gdlint:disable=max-public-methods
extends "res://tests/player/firearm_test_base.gd"
## F014: firing, ammo, reloads, aiming and sprint rules on the real player scene.
## Revolver: mag 6 / reserve 12, interval 0.35 s, per-round reload 0.45 s.
## Blunderbuss: 8 pellets, mag 2 / reserve 6, whole-mag reload 2.6 s.


func before_test() -> void:
	await _setup_world([&"arming_sword", &"revolver", &"blunderbuss"])
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)


func test_spawns_with_full_ammo() -> void:
	assert_int(_ammo(0).mag).is_equal(6)
	assert_int(_ammo(0).reserve).is_equal(12)
	assert_int(_ammo(1).mag).is_equal(2)
	assert_int(_ammo(1).reserve).is_equal(6)
	assert_str(_gun_state()).is_equal("Ready")


func test_semi_auto_fires_once_per_click() -> void:
	_input.attack_held = true
	_steps(60)
	assert_int(_ammo().mag).is_equal(5)
	_input.attack_held = false
	_steps(1)
	_click()
	assert_int(_ammo().mag).is_equal(4)


func test_fire_interval() -> void:
	_click()
	_click()  # 2 ticks later: still cooling down, the press is dropped
	assert_int(_ammo().mag).is_equal(5)
	_steps(25)
	_click()
	assert_int(_ammo().mag).is_equal(4)


func test_shot_hits_dummy() -> void:
	var dummy := _dummy(Vector3(0, 0, -3))
	await get_tree().physics_frame
	var results: Array[DamageResult] = []
	_player.firearm.shot_fired.connect(
		func(r: Array[DamageResult], _t: Array[Vector3]) -> void: results.append_array(r)
	)
	_click()
	assert_int(results.size()).is_equal(1)
	assert_int(results[0].event.type).is_equal(CombatTypes.DamageType.BULLET)
	assert_float(dummy.health.current_health).is_less(200.0)


func test_empty_click_starts_reload() -> void:
	_ammo().mag = 0
	_click()
	assert_str(_gun_state()).is_equal("Reloading")


func test_dry_fire_with_no_ammo_at_all() -> void:
	_ammo().mag = 0
	_ammo().reserve = 0
	var dry := [0]
	_player.firearm.dry_fired.connect(func() -> void: dry[0] += 1)
	_click()
	assert_int(dry[0]).is_equal(1)
	assert_str(_gun_state()).is_equal("Ready")


func test_whole_mag_reload_tops_up_without_loss() -> void:
	_player.loadout.set_active_immediate(Loadout.FIREARM_B)
	_click()
	assert_int(_ammo(1).mag).is_equal(1)
	_input.press_reload()
	_steps(1)
	assert_str(_gun_state()).is_equal("Reloading")
	_steps(150)  # < 2.6 s: nothing added yet
	assert_int(_ammo(1).mag).is_equal(1)
	_steps(10)
	assert_str(_gun_state()).is_equal("Ready")
	assert_int(_ammo(1).mag).is_equal(2)
	assert_int(_ammo(1).reserve).is_equal(5)


func test_per_round_reload_and_fire_interrupt() -> void:
	_ammo().mag = 0
	_input.press_reload()
	_steps(1)
	_steps(55)  # ~0.93 s: two rounds in
	assert_int(_ammo().mag).is_equal(2)
	assert_int(_ammo().reserve).is_equal(10)
	_click()
	assert_str(_gun_state()).is_equal("Ready")
	assert_int(_ammo().mag).is_equal(1)


func test_sprint_cancels_reload_and_lowers_gun() -> void:
	_player.loadout.set_active_immediate(Loadout.FIREARM_B)
	_ammo(1).mag = 0
	_input.press_reload()
	_steps(30)
	_input.hold(FORWARD, true)
	_steps(30)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Sprint")
	assert_str(_gun_state()).is_equal("Lowered")
	_steps(200)
	assert_int(_ammo(1).mag).is_equal(0)


func test_cannot_fire_while_sprinting() -> void:
	_input.hold(FORWARD, true)
	_steps(30)
	_click()
	assert_int(_ammo().mag).is_equal(6)
	_input.hold(FORWARD)
	_steps(3)
	_click()
	assert_int(_ammo().mag).is_equal(5)


func test_aiming() -> void:
	var hip := _player.firearm.current_spread()
	_input.aim_held = true
	_input.hold(FORWARD)
	_steps(40)
	assert_bool(_player.is_aiming()).is_true()
	assert_float(_player.firearm.current_spread()).is_equal_approx(hip * 0.5, 0.0001)
	assert_float(_player.combat_speed_mult).is_equal(_player.defaults.aim_move_mult)
	assert_float(PlayerMotor.horizontal_speed(_player.velocity)).is_equal_approx(4.5 * 0.6, 0.05)


func test_aim_cancels_sprint() -> void:
	_input.hold(FORWARD, true)
	_steps(30)
	assert_str(_gun_state()).is_equal("Lowered")
	_input.aim_held = true
	_steps(5)
	assert_str(_player.get_movement_state()).is_equal("Grounded/Walk")
	assert_str(_gun_state()).is_equal("Ready")
	assert_bool(_player.is_aiming()).is_true()


func test_bloom_grows_and_recovers() -> void:
	var base := _player.firearm.current_spread()
	_click()
	assert_float(_player.firearm.current_spread()).is_greater(base)
	_steps(60)
	assert_float(_player.firearm.current_spread()).is_equal_approx(base, 0.0001)


func test_blunderbuss_fires_eight_pellets() -> void:
	_player.loadout.set_active_immediate(Loadout.FIREARM_B)
	var tracers: Array[Vector3] = []
	_player.firearm.shot_fired.connect(
		func(_r: Array[DamageResult], t: Array[Vector3]) -> void: tracers.append_array(t)
	)
	_click()
	assert_int(tracers.size()).is_equal(16)


func test_rifle_penetrates_with_reduced_damage() -> void:
	var rifle: WeaponData = ContentDB.get_item(&"WeaponData", &"rifle")
	_player.loadout.replace_slot(Loadout.FIREARM_A, rifle)
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)
	_player.firearm.stats.spread_deg = 0.0
	_player.pitch = deg_to_rad(-5.0)  # through both torsos, below the heads
	var front := _dummy(Vector3(0, 0, -3))
	var back := _dummy(Vector3(0, 0, -5))
	await get_tree().physics_frame
	var results: Array[DamageResult] = []
	_player.firearm.shot_fired.connect(
		func(r: Array[DamageResult], _t: Array[Vector3]) -> void: results.append_array(r)
	)
	_click()
	assert_int(results.size()).is_equal(2)
	assert_object(results[0].event.target).is_same(front.health)
	assert_object(results[1].event.target).is_same(back.health)
	assert_float(results[1].event.amount).is_equal_approx(results[0].event.amount * 0.6, 0.001)


func test_friendly_fire_on_players() -> void:
	var other := _spawn_player(Vector3(0, 0, -3), [&"arming_sword"], PI)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var results: Array[DamageResult] = []
	_player.firearm.shot_fired.connect(
		func(r: Array[DamageResult], _t: Array[Vector3]) -> void: results.append_array(r)
	)
	_click()
	assert_int(results.size()).is_equal(1)
	assert_int(results[0].relation).is_equal(CombatTypes.Relation.FRIENDLY)
	assert_float(other.health.current_health).is_less(100.0)


func test_dead_player_cannot_fire() -> void:
	Combat.apply(DamageEvent.world(_player.health, 500, CombatTypes.DamageType.DEBUG))
	_click()
	assert_int(_ammo().mag).is_equal(6)
