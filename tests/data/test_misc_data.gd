extends GdUnitTestSuite
## F003: EnemyData, PerkData, DoorData and WaveModifier validation.

const DataFactory := preload("res://tests/data/data_factory.gd")


func test_enemy_defaults_valid() -> void:
	assert_bool(DataFactory.enemy().validate().is_empty()).is_true()


func test_enemy_errors() -> void:
	var enemy := DataFactory.enemy()
	enemy.max_health = 0.0
	enemy.armor = 1.0
	var report := enemy.validate()
	assert_bool(report.mentions("max_health")).is_true()
	assert_bool(report.mentions("armor")).is_true()


func test_enemy_warnings() -> void:
	var common := DataFactory.enemy()
	common.player_controllable = true
	assert_bool(common.validate().get_warnings()[0].field == "player_controllable").is_true()
	var boss := DataFactory.enemy()
	boss.category = EnemyData.Category.BOSS
	assert_bool(boss.validate().get_warnings()[0].field == "parryable").is_true()


func test_enemy_attack_fields_validated() -> void:
	var enemy := DataFactory.enemy()
	enemy.attack_active_s = 0.0
	enemy.attack_reach_m = 0.0
	enemy.stagger_duration_s = 0.0
	enemy.lunge_distance_m = -1.0
	var report := enemy.validate()
	for field in ["attack_active_s", "attack_reach_m", "stagger_duration_s", "lunge_distance_m"]:
		assert_bool(report.mentions(field)).is_true()


func test_enemy_warns_on_unreachable_attack_range() -> void:
	var enemy := DataFactory.enemy()
	enemy.attack_range_m = 4.0
	enemy.attack_reach_m = 1.5
	enemy.lunge_distance_m = 1.0
	var warnings := enemy.validate().get_warnings()
	(
		assert_bool(warnings.any(func(w: Variant) -> bool: return w.field == "attack_range_m"))
		. is_true()
	)


func test_shipped_acolyte_is_playable() -> void:
	var acolyte := ContentDB.get_item(&"EnemyData", &"acolyte") as EnemyData
	assert_bool(acolyte.validate().is_empty()).is_true()
	assert_object(acolyte.scene).is_not_null()
	var node := acolyte.scene.instantiate()
	assert_bool(node is EnemyBase).is_true()
	node.free()


func test_economy_rules_validation() -> void:
	var rules := EconomyRules.new()
	rules.id = &"test_rules"
	rules.display_name = "Test Rules"
	assert_bool(rules.validate().is_empty()).is_true()
	rules.special_mult = -1.0
	rules.weakpoint_mult = 0.5
	rules.round_to = 0
	var report := rules.validate()
	for field in ["special_mult", "weakpoint_mult", "round_to"]:
		assert_bool(report.mentions(field)).is_true()
	var odd := EconomyRules.new()
	odd.id = &"odd_rules"
	odd.display_name = "Odd Rules"
	odd.riposte_bonus = 55
	assert_str(odd.validate().get_warnings()[0].field).is_equal("riposte_bonus")
	assert_float(odd.category_mult(EnemyData.Category.BOSS)).is_equal(2.0)


func test_perk_rules() -> void:
	var perk := PerkData.new()
	perk.id = &"test_perk"
	perk.display_name = "Test Perk"
	assert_bool(perk.validate().mentions("perk has no effect")).is_true()
	perk.stat_modifiers = {&"mystery_stat": 1.0}
	assert_bool(perk.validate().mentions("unknown stat 'mystery_stat'")).is_true()
	perk.stat_modifiers = {&"reload_speed_mult": 0.0}
	assert_bool(perk.validate().has_errors()).is_true()
	perk.stat_modifiers = {&"max_health_add": 25.0}
	assert_bool(perk.validate().is_empty()).is_true()


func test_door_rules() -> void:
	var door := DoorData.new()
	door.id = &"test_door"
	door.display_name = "Test Door"
	assert_bool(door.validate().mentions("unlocks_zone_id: is required")).is_true()
	door.unlocks_zone_id = &"The Nave"
	assert_bool(door.validate().mentions("snake_case")).is_true()
	door.unlocks_zone_id = &"nave"
	door.cost = -1
	assert_bool(door.validate().mentions("cost")).is_true()


func test_wave_modifier_rules() -> void:
	var modifier := WaveModifier.new()
	modifier.id = &"slow"
	modifier.display_name = "Slow"
	assert_bool(modifier.validate().is_empty()).is_true()
	modifier.enemy_speed_mult = 0.0
	assert_bool(modifier.validate().mentions("enemy_speed_mult")).is_true()
