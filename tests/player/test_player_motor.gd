extends GdUnitTestSuite
## F010: pure movement math (PlayerMotor) and coyote/buffer timers (JumpAssist).

const DT := 1.0 / 60.0


func test_accelerate_reaches_target_in_expected_time() -> void:
	var v := Vector3.ZERO
	var steps := 0
	while v.length() < 4.5 - 0.0001 and steps < 1000:
		v = PlayerMotor.accelerate(v, Vector3.FORWARD, 4.5, 30.0, 35.0, DT)
		steps += 1
	# 4.5 m/s at 30 m/s² = 0.15 s = 9 steps.
	assert_int(steps).is_equal(9)
	assert_vector(v).is_equal_approx(Vector3(0, 0, -4.5), Vector3.ONE * 0.0001)


func test_accelerate_never_overshoots() -> void:
	var v := Vector3(0, 0, -4.4)
	v = PlayerMotor.accelerate(v, Vector3.FORWARD, 4.5, 30.0, 35.0, DT)
	assert_float(v.length()).is_equal_approx(4.5, 0.0001)


func test_decelerate_to_stop() -> void:
	var v := Vector3(3.5, 2.0, 0)
	for i in 6:
		v = PlayerMotor.accelerate(v, Vector3.ZERO, 0.0, 30.0, 35.0, DT)
	# 3.5 m/s at 35 m/s² stops in exactly 0.1 s; vertical speed is untouched.
	assert_vector(v).is_equal_approx(Vector3(0, 2.0, 0), Vector3.ONE * 0.0001)


func test_air_accel_is_slower() -> void:
	var ground := PlayerMotor.accelerate(Vector3.ZERO, Vector3.RIGHT, 4.5, 30.0, 35.0, DT)
	var air := PlayerMotor.accelerate(Vector3.ZERO, Vector3.RIGHT, 4.5, 4.0, 0.0, DT)
	assert_float(air.length()).is_less(ground.length())


func test_no_decel_keeps_momentum() -> void:
	var v := PlayerMotor.accelerate(Vector3(5, 0, 0), Vector3.ZERO, 5.0, 4.0, 0.0, DT)
	assert_vector(v).is_equal(Vector3(5, 0, 0))


func test_gravity() -> void:
	var v := PlayerMotor.apply_gravity(Vector3(1, 0, 0), 9.8, 0.5)
	assert_vector(v).is_equal_approx(Vector3(1, -4.9, 0), Vector3.ONE * 0.0001)


func test_sprint_direction_boundary() -> void:
	var limit := 45.0
	assert_bool(PlayerMotor.is_sprint_direction(Vector2.UP, limit)).is_true()
	(
		assert_bool(PlayerMotor.is_sprint_direction(Vector2.UP.rotated(deg_to_rad(44)), limit))
		. is_true()
	)
	(
		assert_bool(PlayerMotor.is_sprint_direction(Vector2.UP.rotated(deg_to_rad(-44)), limit))
		. is_true()
	)
	(
		assert_bool(PlayerMotor.is_sprint_direction(Vector2.UP.rotated(deg_to_rad(46)), limit))
		. is_false()
	)
	# Diagonal keyboard input (W+D) is exactly 45°.
	assert_bool(PlayerMotor.is_sprint_direction(Vector2(1, -1).normalized(), limit)).is_true()
	assert_bool(PlayerMotor.is_sprint_direction(Vector2.RIGHT, limit)).is_false()
	assert_bool(PlayerMotor.is_sprint_direction(Vector2.DOWN, limit)).is_false()
	assert_bool(PlayerMotor.is_sprint_direction(Vector2.ZERO, limit)).is_false()


func test_wish_direction_follows_yaw() -> void:
	assert_vector(PlayerMotor.wish_direction(Vector2.UP, Basis.IDENTITY)).is_equal_approx(
		Vector3.FORWARD, Vector3.ONE * 0.0001
	)
	# Turned 90° left: "forward" input moves toward -x.
	var basis := Basis(Vector3.UP, deg_to_rad(90))
	assert_vector(PlayerMotor.wish_direction(Vector2.UP, basis)).is_equal_approx(
		Vector3.LEFT, Vector3.ONE * 0.0001
	)
	assert_vector(PlayerMotor.wish_direction(Vector2(0.05, 0), basis)).is_equal(Vector3.ZERO)
	(
		assert_float(PlayerMotor.wish_direction(Vector2(1, -1), Basis.IDENTITY).length())
		. is_equal_approx(1.0, 0.0001)
	)


func test_jump_on_floor() -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(DT, true, false)
	assert_bool(assist.can_jump()).is_false()
	assist.tick(DT, true, true)
	assert_bool(assist.try_consume()).is_true()
	assert_bool(assist.try_consume()).is_false()


func test_coyote_window() -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(DT, true, false)
	for i in 4:
		assist.tick(DT, false, false)
	assist.tick(DT, false, true)  # pressed ~0.083 s after leaving the ledge
	assert_bool(assist.try_consume()).is_true()


func test_coyote_expires() -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(DT, true, false)
	for i in 7:
		assist.tick(DT, false, false)
	assist.tick(DT, false, true)
	assert_bool(assist.try_consume()).is_false()


func test_no_double_jump_in_air() -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(DT, true, true)
	assert_bool(assist.try_consume()).is_true()
	assist.tick(DT, false, true)
	assert_bool(assist.try_consume()).is_false()


func test_buffered_jump_triggers_on_landing() -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(DT, false, true)  # pressed in the air
	assist.tick(DT, false, false)
	assist.tick(DT, true, false)  # lands ~0.033 s later
	assert_bool(assist.try_consume()).is_true()


func test_buffer_expires() -> void:
	var assist := JumpAssist.new(0.1, 0.1)
	assist.tick(DT, false, true)
	for i in 7:
		assist.tick(DT, false, false)
	assist.tick(DT, true, false)
	assert_bool(assist.try_consume()).is_false()
