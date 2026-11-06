extends GdUnitTestSuite
## F003: DataSerializer round-trips and untrusted-input handling.

const DataFactory := preload("res://tests/data/data_factory.gd")

const TEST_SHORT := "res://content/waves/sets/test_short/test_short.tres"


func _json_roundtrip(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


func _customised_settings() -> MatchSettings:
	var settings := DataFactory.settings()
	settings.wave_set = load(TEST_SHORT)
	settings.mode = MatchSettings.Mode.VIGIL
	settings.max_players = 4
	settings.friendly_fire_scale = 0.5
	settings.regen_mode = MatchSettings.RegenMode.ALWAYS
	settings.starting_loadout = [&"arming_sword", &"revolver"]
	settings.player_scale = PackedFloat32Array([0, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5])
	settings.match_seed = 4242
	return settings


func test_match_settings_round_trip_through_json() -> void:
	var original := _customised_settings()
	var encoded := original.to_dict()
	var result := MatchSettings.from_dict(_json_roundtrip(encoded))
	var report: ValidationReport = result["report"]
	assert_bool(report.is_empty()).override_failure_message(report.format()).is_true()
	var decoded: MatchSettings = result["resource"]
	assert_dict(decoded.to_dict()).is_equal(encoded)
	assert_object(decoded.wave_set).is_same(load(TEST_SHORT))
	assert_int(decoded.starting_loadout.get_typed_builtin()).is_equal(TYPE_STRING_NAME)
	assert_int(decoded.regen_mode).is_equal(MatchSettings.RegenMode.ALWAYS)


func test_enums_and_refs_are_readable() -> void:
	var encoded := _customised_settings().to_dict()
	assert_str(str(encoded["mode"])).is_equal("VIGIL")
	assert_dict(encoded["wave_set"]).is_equal({"ref": "WaveSet:test_short"})
	assert_int(int(encoded["schema"])).is_equal(DataSerializer.SCHEMA_VERSION)
	assert_str(str(encoded["type"])).is_equal("MatchSettings")


func test_custom_wave_set_is_embedded_and_round_trips() -> void:
	var settings := DataFactory.settings()
	settings.wave_set.waves[0].entries[0].enemy = load("res://content/enemies/acolyte/acolyte.tres")
	settings.wave_set.waves[1].clear_condition = WaveData.ClearCondition.KILL_QUOTA
	settings.wave_set.waves[1].kill_quota = 40
	var encoded := settings.to_dict()
	var embedded: Dictionary = encoded["wave_set"]
	assert_str(str(embedded["type"])).is_equal("WaveSet")
	var first_entry: Dictionary = embedded["waves"][0]["entries"][0]
	assert_dict(first_entry["enemy"]).is_equal({"ref": "EnemyData:acolyte"})
	var result := MatchSettings.from_dict(_json_roundtrip(encoded))
	var decoded: MatchSettings = result["resource"]
	assert_bool((result["report"] as ValidationReport).is_empty()).is_true()
	assert_int(decoded.wave_set.waves.size()).is_equal(12)
	assert_int(decoded.wave_set.waves[1].kill_quota).is_equal(40)
	assert_dict(decoded.to_dict()).is_equal(encoded)


func test_wave_set_round_trip() -> void:
	var wave_set: WaveSet = load(TEST_SHORT)
	var encoded := wave_set.to_dict()
	var result := WaveSet.from_dict(_json_roundtrip(encoded))
	var decoded: WaveSet = result["resource"]
	assert_dict(decoded.to_dict()).is_equal(encoded)
	assert_bool(decoded.validate().is_empty()).is_true()


func test_perk_dictionary_round_trip() -> void:
	var perk: PerkData = load("res://content/perks/iron_constitution/iron_constitution.tres")
	var result := DataSerializer.from_dict(_json_roundtrip(DataSerializer.to_dict(perk)))
	var decoded: PerkData = result["resource"]
	assert_float(decoded.stat_modifiers[&"max_health_add"]).is_equal(25.0)
	assert_int(decoded.stat_modifiers.get_typed_key_builtin()).is_equal(TYPE_STRING_NAME)


func test_unknown_field_warns_and_is_ignored() -> void:
	var encoded := DataFactory.settings().to_dict()
	encoded["future_field"] = 1
	var result := MatchSettings.from_dict(encoded)
	var report: ValidationReport = result["report"]
	assert_bool(report.has_errors()).is_false()
	assert_bool(report.mentions("future_field")).is_true()
	assert_object(result["resource"]).is_not_null()


func test_type_mismatch_keeps_default() -> void:
	var encoded := DataFactory.settings().to_dict()
	encoded["max_players"] = "six"
	encoded["mode"] = "DEATHMATCH"
	var result := MatchSettings.from_dict(encoded)
	var report: ValidationReport = result["report"]
	assert_bool(report.mentions("root.max_players")).is_true()
	assert_bool(report.mentions("root.mode")).is_true()
	var decoded: MatchSettings = result["resource"]
	assert_int(decoded.max_players).is_equal(6)
	assert_int(decoded.mode).is_equal(MatchSettings.Mode.BETRAYAL)


func test_disallowed_types_are_never_instantiated() -> void:
	var top := DataSerializer.from_dict({"schema": 1, "type": "Node"})
	assert_object(top["resource"]).is_null()
	assert_bool((top["report"] as ValidationReport).has_errors()).is_true()
	var encoded := DataFactory.settings().to_dict()
	encoded["wave_set"] = {"type": "GDScript", "source_code": "extends Node"}
	var nested := MatchSettings.from_dict(encoded)
	(
		assert_bool((nested["report"] as ValidationReport).mentions("not an allowed data type"))
		. is_true()
	)
	assert_object((nested["resource"] as MatchSettings).wave_set).is_null()  # default kept


func test_bad_refs_and_expected_type() -> void:
	var encoded := DataFactory.settings().to_dict()
	encoded["wave_set"] = {"ref": "WaveSet:does_not_exist"}
	var report: ValidationReport = MatchSettings.from_dict(encoded)["report"]
	assert_bool(report.mentions("unknown content 'WaveSet:does_not_exist'")).is_true()
	encoded["wave_set"] = {"ref": "EnemyData:acolyte"}
	report = MatchSettings.from_dict(encoded)["report"]
	assert_bool(report.mentions("invalid reference")).is_true()
	var wrong_root := MatchSettings.from_dict(DataFactory.wave_set().to_dict())
	assert_object(wrong_root["resource"]).is_null()


func test_schema_mismatch_is_rejected() -> void:
	var encoded := DataFactory.settings().to_dict()
	encoded["schema"] = 99
	var result := MatchSettings.from_dict(encoded)
	assert_object(result["resource"]).is_null()
	assert_bool((result["report"] as ValidationReport).mentions("schema")).is_true()
