extends GdUnitTestSuite
## F003: GameData base rules (id, display name, standalone detection).

const DataFactory := preload("res://tests/data/data_factory.gd")


func _data(p_id: String, p_name: String = "Name") -> GameData:
	var data := GameData.new()
	data.id = StringName(p_id)
	data.display_name = p_name
	return data


func test_valid_id_passes() -> void:
	assert_bool(_data("arming_sword_2").validate().is_empty()).is_true()


func test_id_rules() -> void:
	for bad: String in ["", "ArmingSword", "2sword", "arming-sword", "_sword", "sword ax"]:
		(
			assert_bool(_data(bad).validate().has_errors())
			. override_failure_message("id '%s' should be rejected" % bad)
			. is_true()
		)


func test_display_name_required() -> void:
	assert_bool(_data("ok", "  ").validate().mentions("display_name")).is_true()


func test_source_label_and_type() -> void:
	var data := DataFactory.enemy("acolyte_x")
	assert_str(String(data.get_type_name())).is_equal("EnemyData")
	assert_str(data.source_label()).is_equal("EnemyData:acolyte_x")


func test_standalone_detection() -> void:
	assert_bool(DataFactory.enemy().is_standalone()).is_false()
	var loaded: GameData = load("res://content/enemies/acolyte/acolyte.tres")
	assert_bool(loaded.is_standalone()).is_true()
