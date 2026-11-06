extends GdUnitTestSuite
## F003: MatchSettings validation (§9) and traitor counts (§4.2).

const DataFactory := preload("res://tests/data/data_factory.gd")


func test_defaults_with_full_wave_set_are_clean() -> void:
	var report := DataFactory.settings().validate()
	assert_bool(report.is_empty()).override_failure_message(report.format()).is_true()


func test_impossible_values_are_errors() -> void:
	var settings := DataFactory.settings()
	settings.max_players = 9
	settings.ammo_scarcity = 5.0
	settings.player_scale = PackedFloat32Array([1.0])
	settings.wave_set = null
	var report := settings.validate()
	for field: String in ["max_players", "ammo_scarcity", "player_scale", "wave_set"]:
		(
			assert_bool(report.mentions("." + field))
			. override_failure_message("expected an error for %s:\n%s" % [field, report.format()])
			. is_true()
		)


func test_questionable_betrayal_settings_warn_not_error() -> void:
	var settings := DataFactory.settings()
	settings.max_players = 3
	settings.friendly_fire = false
	var report := settings.validate()
	assert_bool(report.has_errors()).is_false()
	assert_bool(report.mentions("plays poorly below 4")).is_true()
	assert_bool(report.mentions("traitors cannot attack")).is_true()


func test_too_many_traitors_warns() -> void:
	var settings := DataFactory.settings()
	settings.traitor_count_mode = MatchSettings.TraitorCountMode.EXACT
	settings.exact_traitor_count = 3
	assert_bool(settings.validate().mentions("half the lobby")).is_true()


func test_vigil_ignores_traitors_and_conversion() -> void:
	var settings := DataFactory.settings()
	settings.mode = MatchSettings.Mode.VIGIL
	var report := settings.validate()
	assert_bool(report.mentions("traitors_enabled: is ignored")).is_true()
	assert_bool(report.mentions("conversion_enabled: is ignored")).is_true()


func test_short_wave_set_warns() -> void:
	var settings := DataFactory.settings()
	settings.wave_set = DataFactory.wave_set(3)
	assert_bool(settings.validate().mentions("has 3 waves but final_round is 12")).is_true()


func test_embedded_wave_set_is_validated() -> void:
	var settings := DataFactory.settings()
	settings.wave_set.waves[0].entries[0].count_max = 0
	assert_bool(settings.validate().has_errors()).is_true()


func test_traitor_count_ratio() -> void:
	var settings := DataFactory.settings()
	var expected := {2: 1, 4: 1, 5: 1, 8: 1}
	for players: int in expected:
		assert_int(settings.traitor_count_for(players)).is_equal(expected[players])
	settings.hunters_per_traitor = 2
	expected = {2: 1, 3: 1, 4: 2, 8: 4}
	for players: int in expected:
		assert_int(settings.traitor_count_for(players)).is_equal(expected[players])


func test_traitor_count_exact_and_disabled() -> void:
	var settings := DataFactory.settings()
	settings.traitor_count_mode = MatchSettings.TraitorCountMode.EXACT
	settings.exact_traitor_count = 3
	assert_int(settings.traitor_count_for(8)).is_equal(3)
	assert_int(settings.traitor_count_for(2)).is_equal(1)  # always leaves a Hunter
	settings.traitors_enabled = false
	assert_int(settings.traitor_count_for(8)).is_equal(0)
	settings.traitors_enabled = true
	settings.mode = MatchSettings.Mode.VIGIL
	assert_int(settings.traitor_count_for(8)).is_equal(0)


func test_presets_have_no_errors() -> void:
	for preset: String in ["betrayal", "vigil"]:
		var settings: MatchSettings = load(
			"res://content/match_presets/%s/%s.tres" % [preset, preset]
		)
		var report := settings.validate()
		assert_bool(report.has_errors()).override_failure_message(report.format()).is_false()
	var vigil: MatchSettings = load("res://content/match_presets/vigil/vigil.tres")
	assert_int(vigil.traitor_count_for(8)).is_equal(0)
	assert_bool(vigil.friendly_fire).is_false()
