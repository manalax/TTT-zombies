extends GdUnitTestSuite
## F018: PerkComponent stat composition and the four working perk effects.

const World := preload("res://tests/enemies/enemy_test_world.gd")
const DT := 1.0 / 60.0

var _player: Player
var _input: Node


func before_test() -> void:
	var world: Node3D = auto_free(World.world(10.0))
	add_child(world)
	_player = World.player(world, Vector3.ZERO)
	_player.set_physics_process(false)
	_input = _player.get_meta(&"input")
	_player.loadout.setup([&"revolver", &"blunderbuss", &"arming_sword"])
	await get_tree().physics_frame
	await get_tree().physics_frame
	_steps(10)


func _perk(id: StringName) -> PerkData:
	return ContentDB.get_item(&"PerkData", id) as PerkData


func _custom(mods: Dictionary[StringName, float]) -> PerkData:
	var perk := PerkData.new()
	perk.id = StringName("custom_%d" % mods.size())
	perk.stat_modifiers = mods
	return perk


func _steps(count: int) -> void:
	for i in count:
		_player.step(DT)


## Ticks from a reload press until the magazine grows.
func _ticks_to_first_round(slot: int) -> int:
	_player.loadout.set_active_immediate(slot)
	_player.loadout.ammo[slot].mag = 0
	_input.press_reload()
	var before := 0
	for i in 400:
		_steps(1)
		if _player.loadout.ammo[slot].mag > before:
			return i + 1
	return -1


func test_stat_composition() -> void:
	var perks := _player.perks
	assert_float(perks.stat(&"max_health_add")).is_equal(0.0)
	assert_float(perks.stat(&"reload_speed_mult")).is_equal(1.0)
	perks.add(_custom({&"max_health_add": 10.0, &"reload_speed_mult": 1.5}))
	perks.add(_custom({&"max_health_add": 5.0, &"reload_speed_mult": 2.0, &"riposte_mult": 1.2}))
	assert_float(perks.stat(&"max_health_add")).is_equal(15.0)
	assert_float(perks.stat(&"reload_speed_mult")).is_equal(3.0)
	assert_float(perks.stat(&"riposte_mult")).is_equal_approx(1.2, 0.0001)


func test_add_rules() -> void:
	var perks := _player.perks
	var iron := _perk(&"iron_constitution")
	assert_bool(perks.add(iron)).is_true()
	assert_bool(perks.add(iron)).is_false()
	assert_str(String(perks.add_block_reason(iron))).is_equal("owned")
	assert_bool(perks.add(null)).is_false()
	assert_array(Array(perks.names())).contains_exactly(["Iron Constitution"])


func test_iron_constitution_raises_max_and_current() -> void:
	Combat.apply(DamageEvent.world(_player.health, 40.0, CombatTypes.DamageType.DEBUG))
	_player.perks.add(_perk(&"iron_constitution"))
	assert_float(_player.health.max_health).is_equal(125.0)
	assert_float(_player.health.current_health).is_equal(85.0)
	_player.perks.clear()
	assert_float(_player.health.max_health).is_equal(100.0)
	assert_float(_player.health.current_health).is_equal(60.0)


func test_second_wind_speeds_stamina_regen() -> void:
	var base := _player.stamina.regen_per_s
	_player.perks.add(_perk(&"second_wind"))
	assert_float(_player.stamina.regen_per_s).is_equal_approx(base * 1.5, 0.0001)


func test_sure_grip_speeds_reloads() -> void:
	var base_round := _ticks_to_first_round(Loadout.FIREARM_A)  # 0.45 s ≈ 27 ticks
	var base_whole := _ticks_to_first_round(Loadout.FIREARM_B)  # 2.6 s ≈ 156 ticks
	assert_int(base_round).is_between(27, 30)
	assert_int(base_whole).is_between(156, 159)
	_player.perks.add(_perk(&"sure_grip"))
	# ×1.4 speed: the time shrinks to 1/1.4 (±1 tick of press/float overhead).
	_assert_scaled(_ticks_to_first_round(Loadout.FIREARM_A), base_round, 1.4)
	_assert_scaled(_ticks_to_first_round(Loadout.FIREARM_B), base_whole, 1.4)


func _assert_scaled(ticks: int, base: int, speed: float) -> void:
	var expected := base / speed
	assert_float(float(ticks)).is_between(expected - 1.5, expected + 1.5)


func test_riposte_perk_multiplies_riposte() -> void:
	_player.perks.add(_perk(&"riposte"))
	var melee := _player.melee
	var spec := melee.make_light_swing()
	var base := spec.riposte_mult
	assert_bool(melee.start_swing(spec)).is_true()
	assert_float(spec.riposte_mult).is_equal_approx(base * 1.3, 0.0001)


func test_deferred_stats_have_no_effect_yet() -> void:
	var before_hp := _player.health.max_health
	var before_regen := _player.stamina.regen_per_s
	_player.perks.add(_custom({&"parry_window_add": 0.1, &"special_damage_mult": 2.0}))
	assert_float(_player.health.max_health).is_equal(before_hp)
	assert_float(_player.stamina.regen_per_s).is_equal(before_regen)
