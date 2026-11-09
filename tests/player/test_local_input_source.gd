extends GdUnitTestSuite
## F010: LocalInputSource look scaling and hold/toggle crouch resolution.

var _saved_sensitivity: float
var _saved_invert: bool
var _saved_mode: int


func before_test() -> void:
	_saved_sensitivity = Settings.mouse_sensitivity
	_saved_invert = Settings.invert_y
	_saved_mode = Settings.crouch_mode


func after_test() -> void:
	Input.action_release(&"crouch")
	Settings.mouse_sensitivity = _saved_sensitivity
	Settings.invert_y = _saved_invert
	Settings.crouch_mode = _saved_mode as Settings.CrouchMode


func _source() -> LocalInputSource:
	var source: LocalInputSource = auto_free(LocalInputSource.new())
	source.capture_on_ready = false
	return source


func test_look_uses_sensitivity() -> void:
	Settings.mouse_sensitivity = 0.2
	Settings.invert_y = false
	var source := _source()
	source.add_mouse_motion(Vector2(10, 5))
	source.add_mouse_motion(Vector2(5, 0))
	assert_vector(source.consume_look()).is_equal_approx(Vector2(3.0, 1.0), Vector2.ONE * 0.0001)
	assert_vector(source.consume_look()).is_equal(Vector2.ZERO)


func test_invert_y() -> void:
	Settings.mouse_sensitivity = 1.0
	Settings.invert_y = true
	var source := _source()
	source.add_mouse_motion(Vector2(2, 4))
	assert_vector(source.consume_look()).is_equal(Vector2(2, -4))


func test_hold_crouch() -> void:
	Settings.crouch_mode = Settings.CrouchMode.HOLD
	var source := _source()
	assert_bool(source.get_intent().crouch).is_false()
	Input.action_press(&"crouch")
	assert_bool(source.get_intent().crouch).is_true()
	await get_tree().process_frame
	assert_bool(source.get_intent().crouch).is_true()
	Input.action_release(&"crouch")
	assert_bool(source.get_intent().crouch).is_false()


func test_toggle_crouch() -> void:
	Settings.crouch_mode = Settings.CrouchMode.TOGGLE
	var source := _source()
	Input.action_press(&"crouch")
	assert_bool(source.get_intent().crouch).is_true()
	await get_tree().process_frame
	Input.action_release(&"crouch")
	await get_tree().process_frame
	# Released, but the toggle stays on.
	assert_bool(source.get_intent().crouch).is_true()
	Input.action_press(&"crouch")
	assert_bool(source.get_intent().crouch).is_false()


func test_cancel_crouch_clears_toggle() -> void:
	Settings.crouch_mode = Settings.CrouchMode.TOGGLE
	var source := _source()
	Input.action_press(&"crouch")
	assert_bool(source.get_intent().crouch).is_true()
	await get_tree().process_frame
	Input.action_release(&"crouch")
	source.cancel_crouch()
	assert_bool(source.get_intent().crouch).is_false()
