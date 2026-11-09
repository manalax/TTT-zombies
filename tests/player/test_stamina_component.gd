extends GdUnitTestSuite
## F010: StaminaComponent drain, regen delay, exhaustion lockout and signals.

## Exactly representable, so accumulated time hits the 1.0 s regen delay exactly.
const DT := 0.25


func _stamina() -> StaminaComponent:
	var s: StaminaComponent = auto_free(StaminaComponent.new())
	var d := PlayerDefaults.new()
	s.configure(d)
	return s


func _tick(s: StaminaComponent, seconds: float) -> void:
	for i in roundi(seconds / DT):
		s.tick(DT)


func test_starts_full() -> void:
	var s := _stamina()
	assert_float(s.current).is_equal(100.0)
	assert_bool(s.can_sprint()).is_true()


func test_drain_clamps_at_zero_and_exhausts() -> void:
	var s := _stamina()
	s.drain(250.0)
	assert_float(s.current).is_equal(0.0)
	assert_bool(s.is_exhausted()).is_true()
	assert_bool(s.can_sprint()).is_false()


func test_regen_waits_for_delay() -> void:
	var s := _stamina()
	s.drain(50.0)
	_tick(s, 0.75)
	assert_float(s.current).is_equal(50.0)
	_tick(s, 0.5)
	# Regen starts once 1.0 s has passed: the ticks at 1.0 and 1.25 s each regen 20/s * 0.25 s.
	assert_float(s.current).is_equal_approx(60.0, 0.001)


func test_regen_caps_at_max() -> void:
	var s := _stamina()
	s.drain(10.0)
	_tick(s, 5.0)
	assert_float(s.current).is_equal(100.0)


func test_exhaustion_lockout_until_recover_threshold() -> void:
	var s := _stamina()
	s.drain(100.0)
	_tick(s, 2.0)  # 1 s delay, then 5 regen ticks = 25 stamina
	assert_float(s.current).is_equal_approx(25.0, 0.001)
	assert_bool(s.can_sprint()).is_false()
	_tick(s, 0.6)
	assert_float(s.current).is_greater_equal(30.0)
	assert_bool(s.is_exhausted()).is_false()
	assert_bool(s.can_sprint()).is_true()


func test_partial_drain_does_not_exhaust() -> void:
	var s := _stamina()
	s.drain(99.0)
	assert_bool(s.is_exhausted()).is_false()
	assert_bool(s.can_sprint()).is_true()


func test_try_spend() -> void:
	var s := _stamina()
	assert_bool(s.try_spend(60.0)).is_true()
	assert_float(s.current).is_equal(40.0)
	assert_bool(s.try_spend(60.0)).is_false()
	assert_float(s.current).is_equal(40.0)


func test_spending_resets_regen_delay() -> void:
	var s := _stamina()
	s.drain(20.0)
	_tick(s, 0.75)
	s.drain(10.0)
	_tick(s, 0.75)
	assert_float(s.current).is_equal(70.0)


func test_signals() -> void:
	var s := _stamina()
	var changes: Array[float] = []
	var exhausted: Array[bool] = []
	s.stamina_changed.connect(func(current: float, _max: float) -> void: changes.append(current))
	s.exhausted_changed.connect(func(value: bool) -> void: exhausted.append(value))
	s.drain(100.0)
	s.refill()
	assert_array(changes).contains_exactly([0.0, 100.0])
	assert_array(exhausted).contains_exactly([true, false])
