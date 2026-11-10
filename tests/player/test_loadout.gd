extends "res://tests/player/firearm_test_base.gd"
## F014: loadout slots, switching, replace_slot and ammo grants (F018: buying via a wall-buy).

const WALL_BUY_SCENE := preload("res://src/world/shop/wall_buy.tscn")


func before_test() -> void:
	await _setup_world([&"arming_sword", &"revolver", &"blunderbuss"])


func test_setup_places_weapons_and_spawns_on_melee() -> void:
	var loadout := _player.loadout
	assert_str(loadout.slots[Loadout.FIREARM_A].id).is_equal("revolver")
	assert_str(loadout.slots[Loadout.FIREARM_B].id).is_equal("blunderbuss")
	assert_str(loadout.slots[Loadout.MELEE].id).is_equal("arming_sword")
	assert_int(loadout.active_slot).is_equal(Loadout.MELEE)
	assert_bool(loadout.is_melee_active()).is_true()


func test_third_firearm_is_rejected() -> void:
	_player.loadout.setup([&"revolver", &"blunderbuss", &"rifle", &"arming_sword"])
	assert_str(_player.loadout.slots[Loadout.FIREARM_A].id).is_equal("revolver")
	assert_str(_player.loadout.slots[Loadout.FIREARM_B].id).is_equal("blunderbuss")


func test_switch_takes_draw_time_and_blocks_attacks() -> void:
	_input.press_slot(Loadout.FIREARM_A)
	_steps(1)
	assert_bool(_player.loadout.is_switching()).is_true()
	_input.attack_held = true
	_steps(10)
	_input.attack_held = false
	_steps(1)
	assert_int(_ammo().mag).is_equal(6)
	_steps(15)  # 0.4 s draw done
	assert_bool(_player.loadout.is_firearm_active()).is_true()
	_click()
	assert_int(_ammo().mag).is_equal(5)


func test_wheel_cycles_and_wraps() -> void:
	_input.cycle_weapon(1)
	_steps(1)
	assert_int(_player.loadout.active_slot).is_equal(Loadout.FIREARM_A)
	_input.cycle_weapon(-1)
	_steps(1)
	assert_int(_player.loadout.active_slot).is_equal(Loadout.MELEE)


func test_empty_slots_are_skipped() -> void:
	_player.loadout.setup([&"arming_sword", &"revolver"])
	_input.press_slot(Loadout.FIREARM_B)
	_steps(1)
	assert_int(_player.loadout.active_slot).is_equal(Loadout.MELEE)
	_input.cycle_weapon(1)
	_steps(30)
	assert_int(_player.loadout.active_slot).is_equal(Loadout.FIREARM_A)
	_input.cycle_weapon(1)
	_steps(30)
	assert_int(_player.loadout.active_slot).is_equal(Loadout.MELEE)


func test_switch_cancels_block() -> void:
	_input.block_held = true
	_steps(3)
	assert_bool(_player.health.block.active).is_true()
	_input.press_slot(Loadout.FIREARM_A)
	_steps(1)
	assert_bool(_player.health.block.active).is_false()


func test_switch_cancels_reload() -> void:
	_player.loadout.set_active_immediate(Loadout.FIREARM_B)
	_ammo(1).mag = 0
	_input.press_reload()
	_steps(60)
	_input.press_slot(Loadout.FIREARM_A)
	_steps(200)
	assert_int(_ammo(1).mag).is_equal(0)


func test_replace_slot_checks_kind_and_refills() -> void:
	var loadout := _player.loadout
	var revolver: WeaponData = ContentDB.get_item(&"WeaponData", &"revolver")
	var rifle: WeaponData = ContentDB.get_item(&"WeaponData", &"rifle")
	assert_object(loadout.replace_slot(Loadout.MELEE, revolver)).is_null()
	assert_str(loadout.slots[Loadout.MELEE].id).is_equal("arming_sword")
	_ammo(0).mag = 1
	var old := loadout.replace_slot(Loadout.FIREARM_A, rifle)
	assert_object(old).is_same(revolver)
	assert_int(_ammo(0).mag).is_equal(5)
	assert_int(_ammo(0).reserve).is_equal(10)


func test_grant_ammo_applies_scarcity_and_cap() -> void:
	var scarce := MatchSettings.new()
	scarce.ammo_scarcity = 2.0
	_ammo(0).reserve = 0
	assert_int(_player.loadout.grant_ammo(Loadout.FIREARM_A, 12, scarce)).is_equal(6)
	assert_int(_player.loadout.grant_ammo(Loadout.FIREARM_A, 100, scarce)).is_equal(6)
	assert_int(_ammo(0).reserve).is_equal(12)


func test_without_override_uses_match_settings() -> void:
	var player := _spawn_player(Vector3(5, 0, 0), [])
	assert_str(player.loadout.slots[Loadout.MELEE].id).is_equal("arming_sword")
	assert_str(player.loadout.slots[Loadout.FIREARM_A].id).is_equal("revolver")
	assert_object(player.loadout.slots[Loadout.FIREARM_B]).is_null()


func test_wall_buy_via_interact_key_draws_new_gun() -> void:
	var station: WallBuy = WALL_BUY_SCENE.instantiate()
	station.weapon_id = &"rifle"
	station.position = Vector3(0, 0, -1.4)
	_world.add_child(station)
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)
	_player.points.reset(5000)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_input.press_interact()
	_steps(1)
	assert_str(_player.loadout.slots[Loadout.FIREARM_A].id).is_equal("rifle")
	_steps(30)
	assert_str(_player.firearm.weapon.id).is_equal("rifle")
