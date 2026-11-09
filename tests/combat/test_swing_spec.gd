extends GdUnitTestSuite
## F012: SwingSpec values and the fire-on-release charge rule.


func _stats() -> MeleeStats:
	return MeleeStats.new()


func test_light_from_stats() -> void:
	var stats := _stats()
	var spec := SwingSpec.light(stats, SwingSpec.Sweep.LEFT_TO_RIGHT, &"arming_sword")
	assert_bool(spec.is_heavy()).is_false()
	assert_float(spec.damage).is_equal(stats.light_damage)
	assert_float(spec.stamina_cost).is_equal(stats.light_stamina_cost)
	assert_float(spec.stagger).is_equal(stats.stagger_light)
	assert_float(spec.windup_s).is_equal(stats.light_windup_s)
	assert_float(spec.arc_deg).is_equal(stats.light_arc_deg)
	assert_float(spec.weakpoint_mult).is_equal(stats.weakpoint_mult)
	assert_str(spec.weapon_id).is_equal("arming_sword")


func test_heavy_from_stats() -> void:
	var stats := _stats()
	var spec := SwingSpec.heavy(stats)
	assert_bool(spec.is_heavy()).is_true()
	assert_int(spec.sweep).is_equal(SwingSpec.Sweep.OVERHEAD)
	assert_float(spec.damage).is_equal(stats.heavy_damage)
	assert_float(spec.stamina_cost).is_equal(stats.heavy_stamina_cost)
	assert_float(spec.recovery_s).is_equal(stats.heavy_recovery_s)


func test_release_before_full_charge_is_light() -> void:
	var stats := _stats()
	var side := SwingSpec.Sweep.RIGHT_TO_LEFT
	assert_bool(SwingSpec.for_release(stats, 0.0, side).is_heavy()).is_false()
	(
		assert_bool(SwingSpec.for_release(stats, stats.heavy_charge_s - 0.01, side).is_heavy())
		. is_false()
	)
	assert_int(SwingSpec.for_release(stats, 0.1, side).sweep).is_equal(side)
	assert_bool(SwingSpec.for_release(stats, stats.heavy_charge_s, side).is_heavy()).is_true()
	assert_bool(SwingSpec.for_release(stats, 5.0, side).is_heavy()).is_true()


func test_side_alternates() -> void:
	var l2r := SwingSpec.Sweep.LEFT_TO_RIGHT
	var r2l := SwingSpec.Sweep.RIGHT_TO_LEFT
	assert_int(SwingSpec.next_side(l2r)).is_equal(r2l)
	assert_int(SwingSpec.next_side(r2l)).is_equal(l2r)


func test_directions() -> void:
	var stats := _stats()
	var eps := Vector3.ONE * 0.001
	var l2r := SwingSpec.light(stats, SwingSpec.Sweep.LEFT_TO_RIGHT)
	# Starts 45° to the left (-X), ends 45° to the right, passes straight ahead.
	assert_float(l2r.direction_at(0.0).x).is_less(-0.69)
	assert_float(l2r.direction_at(1.0).x).is_greater(0.69)
	assert_vector(l2r.direction_at(0.5)).is_equal_approx(Vector3.FORWARD, eps)
	var heavy := SwingSpec.heavy(stats)
	# Overhead: from above the horizon down to -35°.
	assert_float(heavy.direction_at(0.0).y).is_greater(0.5)
	assert_float(heavy.direction_at(1.0).y).is_equal_approx(sin(deg_to_rad(-35.0)), 0.001)
	assert_float(heavy.direction_at(1.0).x).is_equal_approx(0.0, 0.001)
