extends GdUnitTestSuite
## F013 AC: the parry window is exact to ±1 physics frame; fresh presses only; lockout rules.


func _block(window_s: float = 0.2) -> BlockState:
	var block := BlockState.new()
	block.active = true
	block.parry_window_s = window_s
	block.parry_lockout_s = 0.5
	return block


## Is the window still open [param ticks] physics ticks after the press, at [param hz]?
func _open_after(ticks: int, hz: float) -> bool:
	var block := _block()
	block.open_parry_window()
	for i in ticks:
		block.tick(1.0 / hz)
	return block.is_parry_window_open()


func test_window_exact_to_one_frame_at_60hz() -> void:
	# 0.2 s at 60 Hz = 12 ticks: tick 12 still parries, tick 13 does not.
	assert_bool(_open_after(0, 60.0)).is_true()
	assert_bool(_open_after(11, 60.0)).is_true()
	assert_bool(_open_after(12, 60.0)).is_true()
	assert_bool(_open_after(13, 60.0)).is_false()


func test_window_exact_to_one_frame_at_120hz() -> void:
	assert_bool(_open_after(24, 120.0)).is_true()
	assert_bool(_open_after(25, 120.0)).is_false()


func test_window_needs_a_press() -> void:
	var block := _block()
	assert_bool(block.is_parry_window_open()).is_false()
	block.tick(0.1)
	assert_bool(block.is_parry_window_open()).is_false()


func test_expiry_starts_lockout() -> void:
	var block := _block()
	block.open_parry_window()
	for i in 13:
		block.tick(1.0 / 60.0)
	assert_bool(block.is_locked_out()).is_true()
	assert_bool(block.open_parry_window()).is_false()
	assert_bool(block.is_parry_window_open()).is_false()


func test_early_release_starts_lockout() -> void:
	var block := _block()
	block.open_parry_window()
	block.tick(0.05)
	block.close_parry_window()
	assert_bool(block.is_locked_out()).is_true()
	assert_bool(block.open_parry_window()).is_false()


func test_lockout_expires_after_half_a_second() -> void:
	var block := _block()
	block.open_parry_window()
	block.close_parry_window()
	for i in 29:
		block.tick(1.0 / 60.0)
	assert_bool(block.open_parry_window()).is_false()
	block.tick(1.0 / 60.0 + 0.001)
	assert_bool(block.open_parry_window()).is_true()


func test_no_lockout_after_successful_parry() -> void:
	var block := _block()
	block.open_parry_window()
	block.notify_parried()
	for i in 20:
		block.tick(1.0 / 60.0)
	assert_bool(block.is_locked_out()).is_false()
	assert_bool(block.open_parry_window()).is_true()


func test_configure_from_stats() -> void:
	var stats := MeleeStats.new()
	stats.parry_window_s = 0.25
	stats.parry_stun_s = 1.4
	var block := _block()
	block.configure(stats)
	assert_float(block.parry_window_s).is_equal(0.25)
	assert_float(block.parry_stun_s).is_equal(1.4)
