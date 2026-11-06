extends GdUnitTestSuite
## F003: WeaponData composition rules and stat validation.

const DataFactory := preload("res://tests/data/data_factory.gd")


func test_valid_melee_and_firearm() -> void:
	assert_bool(DataFactory.melee_weapon().validate().is_empty()).is_true()
	assert_bool(DataFactory.firearm().validate().is_empty()).is_true()


func test_melee_requires_melee_stats() -> void:
	var weapon := DataFactory.melee_weapon()
	weapon.melee_stats = null
	weapon.firearm_stats = FirearmStats.new()
	var report := weapon.validate()
	assert_bool(report.has_errors()).is_true()
	assert_bool(report.mentions("melee_stats: required")).is_true()


func test_firearm_requires_firearm_stats() -> void:
	var weapon := DataFactory.firearm()
	weapon.firearm_stats = null
	assert_bool(weapon.validate().mentions("firearm_stats: required")).is_true()


func test_hybrid_firearm_with_melee_is_valid() -> void:
	var weapon := DataFactory.firearm()
	weapon.melee_stats = MeleeStats.new()
	assert_bool(weapon.validate().has_errors()).is_false()


func test_sub_stats_are_validated_with_path() -> void:
	var weapon := DataFactory.melee_weapon()
	weapon.melee_stats.reach_m = 0.0
	weapon.firearm_stats = FirearmStats.new()
	weapon.firearm_stats.falloff_start_m = 50.0
	var report := weapon.validate()
	assert_bool(report.mentions("WeaponData:test_blade.melee_stats.reach_m")).is_true()
	assert_bool(report.mentions("firearm_stats.falloff_end_m")).is_true()


func test_tier_range() -> void:
	var weapon := DataFactory.melee_weapon()
	weapon.tier = 6
	assert_bool(weapon.validate().mentions("tier")).is_true()


func test_large_reserve_warns_about_scarcity() -> void:
	var weapon := DataFactory.firearm()
	weapon.firearm_stats.reserve_cap = weapon.firearm_stats.mag_size * 4
	var report := weapon.validate()
	assert_bool(report.has_errors()).is_false()
	assert_bool(report.get_warnings()[0].field == "reserve_cap").is_true()


func test_shipped_weapons_are_valid() -> void:
	for path: String in [
		"res://content/weapons/arming_sword/arming_sword.tres",
		"res://content/weapons/revolver/revolver.tres",
	]:
		var weapon: WeaponData = load(path)
		var report := weapon.validate()
		assert_bool(report.is_empty()).override_failure_message(report.format()).is_true()
