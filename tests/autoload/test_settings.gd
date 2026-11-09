extends GdUnitTestSuite
## F010: local prefs in the Settings autoload (save/load, defaults, clamping).

const PATH := "user://test_settings_f010.cfg"

var _saved: Dictionary = {}


func before_test() -> void:
	_saved = {
		"mouse_sensitivity": Settings.mouse_sensitivity,
		"invert_y": Settings.invert_y,
		"fov": Settings.fov,
		"crouch_mode": Settings.crouch_mode,
	}


func after_test() -> void:
	for key: String in _saved:
		Settings.set(key, _saved[key])
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_round_trip() -> void:
	Settings.mouse_sensitivity = 0.4
	Settings.invert_y = true
	Settings.fov = 100.0
	Settings.crouch_mode = Settings.CrouchMode.TOGGLE
	assert_int(Settings.save_prefs(PATH)).is_equal(OK)
	Settings.reset_prefs()
	assert_bool(Settings.load_prefs(PATH)).is_true()
	assert_float(Settings.mouse_sensitivity).is_equal_approx(0.4, 0.0001)
	assert_bool(Settings.invert_y).is_true()
	assert_float(Settings.fov).is_equal(100.0)
	assert_int(Settings.crouch_mode).is_equal(Settings.CrouchMode.TOGGLE)


func test_missing_file_gives_defaults() -> void:
	Settings.fov = 70.0
	assert_bool(Settings.load_prefs("user://does_not_exist.cfg")).is_true()
	assert_float(Settings.fov).is_equal(90.0)
	assert_float(Settings.mouse_sensitivity).is_equal_approx(0.15, 0.0001)
	assert_bool(Settings.invert_y).is_false()
	assert_int(Settings.crouch_mode).is_equal(Settings.CrouchMode.HOLD)


func test_bad_values_are_clamped_or_ignored() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("controls", "fov", 500)
	cfg.set_value("controls", "mouse_sensitivity", "fast")
	cfg.set_value("controls", "invert_y", 1)
	cfg.set_value("controls", "crouch_mode", "SLIDE")
	cfg.save(PATH)
	Settings.load_prefs(PATH)
	assert_float(Settings.fov).is_equal(120.0)
	assert_float(Settings.mouse_sensitivity).is_equal_approx(0.15, 0.0001)
	assert_bool(Settings.invert_y).is_false()
	assert_int(Settings.crouch_mode).is_equal(Settings.CrouchMode.HOLD)


func test_crouch_mode_saved_by_name() -> void:
	Settings.crouch_mode = Settings.CrouchMode.TOGGLE
	Settings.save_prefs(PATH)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	assert_str(str(cfg.get_value("controls", "crouch_mode"))).is_equal("TOGGLE")
