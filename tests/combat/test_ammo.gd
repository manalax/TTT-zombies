extends GdUnitTestSuite
## F014 AC: ammo caps are enforced and the scarcity multiplier is applied.


func _settings(scarcity: float) -> MatchSettings:
	var settings := MatchSettings.new()
	settings.ammo_scarcity = scarcity
	return settings


func _state(mag_size: int = 6, reserve_cap: int = 12) -> AmmoState:
	var state := AmmoState.new()
	state.mag_size = mag_size
	state.reserve_cap = reserve_cap
	return state


func test_reserve_cap_is_enforced() -> void:
	var state := _state()
	assert_int(state.add_reserve(10)).is_equal(10)
	assert_int(state.add_reserve(10)).is_equal(2)
	assert_int(state.reserve).is_equal(12)
	assert_int(state.add_reserve(5)).is_equal(0)
	assert_int(state.reserve).is_equal(12)
	assert_int(state.add_reserve(-3)).is_equal(0)


func test_reload_never_overfills_and_only_moves_reserve() -> void:
	var state := _state()
	state.mag = 4
	state.reserve = 12
	assert_int(state.reload_amount()).is_equal(2)
	assert_int(state.move_to_mag(99)).is_equal(2)
	assert_int(state.mag).is_equal(6)
	assert_int(state.reserve).is_equal(10)
	state.mag = 0
	state.reserve = 3
	assert_int(state.move_to_mag(6)).is_equal(3)
	assert_int(state.mag).is_equal(3)
	assert_int(state.reserve).is_equal(0)
	assert_bool(state.can_reload()).is_false()


func test_empty_mag_cannot_fire() -> void:
	var state := _state()
	state.mag = 1
	assert_bool(state.take_round()).is_true()
	assert_bool(state.take_round()).is_false()
	assert_int(state.mag).is_equal(0)
	assert_bool(state.is_empty()).is_true()


func test_scarcity_scales_grants() -> void:
	assert_int(AmmoRules.grant(12, _settings(1.0))).is_equal(12)
	assert_int(AmmoRules.grant(12, _settings(2.0))).is_equal(6)
	assert_int(AmmoRules.grant(12, _settings(3.0))).is_equal(4)
	assert_int(AmmoRules.grant(12, _settings(0.5))).is_equal(24)
	assert_int(AmmoRules.grant(0, _settings(0.5))).is_equal(0)


func test_scarcity_scales_costs() -> void:
	assert_int(AmmoRules.cost(250, _settings(1.0))).is_equal(250)
	assert_int(AmmoRules.cost(250, _settings(2.0))).is_equal(500)
	assert_int(AmmoRules.cost(250, _settings(0.25))).is_equal(63)


func test_generous_grant_is_still_capped() -> void:
	var state := _state()
	assert_int(state.add_reserve(AmmoRules.grant(12, _settings(0.5)))).is_equal(12)
	assert_int(state.reserve).is_equal(12)


func test_fill_applies_scarcity_to_reserve_only() -> void:
	var stats := FirearmStats.new()
	stats.mag_size = 6
	stats.reserve_cap = 12
	var scarce := AmmoState.for_stats(stats).fill(_settings(3.0))
	assert_int(scarce.mag).is_equal(6)
	assert_int(scarce.reserve).is_equal(4)
	var generous := AmmoState.for_stats(stats).fill(_settings(0.25))
	assert_int(generous.reserve).is_equal(12)


func test_default_scarcity_comes_from_active_settings() -> void:
	var saved := Settings.match_settings
	Settings.match_settings = _settings(2.0)
	var granted := AmmoRules.grant(10)
	Settings.match_settings = saved
	assert_int(granted).is_equal(5)
