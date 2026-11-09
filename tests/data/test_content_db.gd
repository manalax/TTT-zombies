extends GdUnitTestSuite
## F003: ContentDB indexing, layout rules and the shipped-content guard.

const FIXTURES := "res://tests/data/fixtures/content"


func _fixture_db() -> ContentRegistry:
	var db: ContentRegistry = auto_free(ContentRegistry.new())
	db.scan(FIXTURES)
	return db


## The guard every content change must pass.
func test_all_shipped_content_validates() -> void:
	var report := ContentDB.validate_all()
	assert_bool(report.has_errors()).override_failure_message(report.format()).is_false()


func test_shipped_content_is_indexed() -> void:
	assert_object(ContentDB.get_item(&"WeaponData", &"arming_sword")).is_not_null()
	assert_object(ContentDB.get_item(&"EnemyData", &"acolyte")).is_not_null()
	assert_bool(ContentDB.has_item(&"WeaponData", &"nope")).is_false()
	assert_int(ContentDB.get_all(&"MatchSettings").size()).is_equal(2)
	for type: StringName in [
		&"WeaponData",
		&"EnemyData",
		&"WaveModifier",
		&"WaveSet",
		&"PerkData",
		&"DoorData",
		&"LootTable",
		&"MatchSettings",
		&"PlayerDefaults",
		&"EconomyRules",
	]:
		(
			assert_bool(type in ContentDB.get_types())
			. override_failure_message("no sample content of type %s" % type)
			. is_true()
		)


func test_layout_problems_are_reported() -> void:
	var report := _fixture_db().get_scan_report()
	assert_bool(report.mentions("duplicate id")).is_true()
	assert_bool(report.mentions("must equal the file name 'good_enemy_copy'")).is_true()
	assert_bool(report.mentions("must live in a folder named 'wrong_folder'")).is_true()


func test_duplicate_keeps_first_definition() -> void:
	var db := _fixture_db()
	var enemy := db.get_item(&"EnemyData", &"good_enemy")
	assert_str(enemy.display_name).is_equal("Good Enemy")


func test_validate_all_includes_items_and_cross_refs() -> void:
	var report := _fixture_db().validate_all()
	assert_bool(report.mentions("WaveSet:broken_set.waves[0].entries[0].count_min")).is_true()
	assert_bool(report.mentions("unknown weapon 'nope'")).is_true()


func test_loadout_slot_limits() -> void:
	var settings: MatchSettings = ContentDB.get_item(&"MatchSettings", &"betrayal")
	var original := settings.starting_loadout.duplicate()
	settings.starting_loadout = [&"arming_sword", &"arming_sword", &"revolver"]
	var report := ContentDB.validate_all()
	settings.starting_loadout = original
	assert_bool(report.mentions("has 2 melee weapons (max 1)")).is_true()


func test_missing_root_is_reported() -> void:
	var db: ContentRegistry = auto_free(ContentRegistry.new())
	assert_bool(db.scan("res://does/not/exist").has_errors()).is_true()
