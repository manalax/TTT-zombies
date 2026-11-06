extends GdUnitTestSuite
## F003: WaveEntry / WaveData / WaveSet validation.

const DataFactory := preload("res://tests/data/data_factory.gd")


func _report(wave: WaveData) -> ValidationReport:
	var report := ValidationReport.new()
	wave.validate_into(report, "W")
	return report


func test_valid_wave() -> void:
	assert_bool(_report(DataFactory.wave()).is_empty()).is_true()


func test_empty_wave_is_error() -> void:
	var wave := WaveData.new()
	assert_bool(_report(wave).mentions("wave has no enemies")).is_true()


func test_boss_only_wave_is_valid() -> void:
	var wave := WaveData.new()
	wave.boss = DataFactory.enemy("big")
	wave.boss.category = EnemyData.Category.BOSS
	wave.boss.parryable = false
	assert_bool(_report(wave).is_empty()).is_true()


func test_entry_errors() -> void:
	var wave := WaveData.new()
	var no_enemy := WaveEntry.new()
	wave.entries = [no_enemy, DataFactory.entry(null, 5, 2)]
	var report := _report(wave)
	assert_bool(report.mentions("W.entries[0].enemy: is required")).is_true()
	assert_bool(report.mentions("W.entries[1].count_min")).is_true()


func test_clear_condition_requires_value() -> void:
	var wave := DataFactory.wave()
	wave.clear_condition = WaveData.ClearCondition.KILL_QUOTA
	assert_bool(_report(wave).mentions("kill_quota")).is_true()
	wave.clear_condition = WaveData.ClearCondition.SURVIVE_TIME
	assert_bool(_report(wave).mentions("survive_time_s")).is_true()
	wave.survive_time_s = 60.0
	assert_bool(_report(wave).is_empty()).is_true()


func test_warnings() -> void:
	var wave := DataFactory.wave()
	wave.entries[0].enemy.category = EnemyData.Category.SPECIAL
	wave.boss = DataFactory.enemy("not_a_boss")
	var report := _report(wave)
	assert_bool(report.has_errors()).is_false()
	assert_bool(report.mentions("special_cap is 0")).is_true()
	assert_bool(report.mentions("not a BOSS")).is_true()


func test_embedded_enemy_is_validated_standalone_is_not() -> void:
	var wave := DataFactory.wave()
	wave.entries[0].enemy.max_health = 0.0
	assert_bool(_report(wave).mentions("EnemyData:test_enemy.max_health")).is_true()
	var shipped := DataFactory.wave()
	shipped.entries[0].enemy = load("res://content/enemies/acolyte/acolyte.tres")
	assert_bool(_report(shipped).is_empty()).is_true()


func test_wave_set_rules_and_indexed_labels() -> void:
	var empty := DataFactory.wave_set(0)
	assert_bool(empty.validate().mentions("needs at least one wave")).is_true()
	var wave_set := DataFactory.wave_set(3)
	wave_set.waves[1].entries[0].count_max = 0
	(
		assert_bool(
			wave_set.validate().mentions("WaveSet:custom_set.waves[1].entries[0].count_max")
		)
		. is_true()
	)


func test_shipped_wave_set_is_valid() -> void:
	var wave_set: WaveSet = load("res://content/waves/sets/test_short/test_short.tres")
	var report := wave_set.validate()
	assert_bool(report.is_empty()).override_failure_message(report.format()).is_true()
	assert_int(wave_set.waves.size()).is_equal(3)
