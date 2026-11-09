extends GdUnitTestSuite
## F010: PlayerDefaults validation and the shipped defaults.


func _defaults() -> PlayerDefaults:
	var d := PlayerDefaults.new()
	d.id = &"test_defaults"
	d.display_name = "Test Defaults"
	return d


func test_built_in_defaults_valid() -> void:
	var report := _defaults().validate()
	assert_bool(report.is_empty()).override_failure_message(report.format()).is_true()


func test_shipped_defaults_match_design() -> void:
	var d: PlayerDefaults = ContentDB.get_item(&"PlayerDefaults", &"player_defaults")
	assert_object(d).is_not_null()
	assert_float(d.max_health).is_equal(100.0)
	assert_float(d.max_stamina).is_equal(100.0)
	assert_float(d.stamina_regen_per_s).is_equal(20.0)
	assert_float(d.stamina_regen_delay_s).is_equal(1.0)
	assert_float(d.walk_speed).is_equal(4.5)
	assert_float(d.sprint_speed).is_equal(7.0)
	assert_float(d.exhausted_recover_at).is_equal(30.0)


func test_errors() -> void:
	var d := _defaults()
	d.walk_speed = 0.0
	d.crouch_height = 2.0
	d.exhausted_recover_at = 150.0
	d.air_accel = -1.0
	var report := d.validate()
	assert_bool(report.mentions("walk_speed: must be > 0")).is_true()
	assert_bool(report.mentions("crouch_height: must be < stand_height")).is_true()
	assert_bool(report.mentions("exhausted_recover_at")).is_true()
	assert_bool(report.mentions("air_accel")).is_true()


func test_block_arc_range() -> void:
	var d := _defaults()
	d.block_arc_deg = 0.0
	assert_bool(d.validate().mentions("block_arc_deg")).is_true()
	d.block_arc_deg = 360.0
	assert_bool(d.validate().has_errors()).is_false()


func test_capsule_must_fit_crouched() -> void:
	var d := _defaults()
	d.body_radius = 0.6
	assert_bool(d.validate().mentions("body_radius")).is_true()


func test_warnings() -> void:
	var d := _defaults()
	d.sprint_speed = d.walk_speed
	d.crouch_speed = d.walk_speed + 1.0
	var report := d.validate()
	assert_bool(report.has_errors()).is_false()
	assert_int(report.get_warnings().size()).is_equal(2)


func test_eye_height() -> void:
	var d := _defaults()
	assert_float(d.get_eye_height(false)).is_equal_approx(1.65, 0.0001)
	assert_float(d.get_eye_height(true)).is_equal_approx(0.95, 0.0001)
