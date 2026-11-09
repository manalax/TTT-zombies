extends GdUnitTestSuite
## F014: falloff, spread cone and bloom/aim spread on the Firearm.


func _stats() -> FirearmStats:
	var stats := FirearmStats.new()
	stats.falloff_start_m = 10.0
	stats.falloff_end_m = 30.0
	stats.min_damage_mult = 0.5
	return stats


func test_falloff() -> void:
	var stats := _stats()
	assert_float(Firearm.falloff_mult(stats, 0.0)).is_equal(1.0)
	assert_float(Firearm.falloff_mult(stats, 10.0)).is_equal(1.0)
	assert_float(Firearm.falloff_mult(stats, 20.0)).is_equal_approx(0.75, 0.0001)
	assert_float(Firearm.falloff_mult(stats, 30.0)).is_equal(0.5)
	assert_float(Firearm.falloff_mult(stats, 100.0)).is_equal(0.5)


func test_penetration_chain() -> void:
	assert_float(pow(Firearm.PENETRATION_DAMAGE_MULT, 0)).is_equal(1.0)
	assert_float(pow(Firearm.PENETRATION_DAMAGE_MULT, 1)).is_equal_approx(0.6, 0.0001)
	assert_float(pow(Firearm.PENETRATION_DAMAGE_MULT, 2)).is_equal_approx(0.36, 0.0001)


func test_spread_cone_stays_within_angle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 500:
		var dir := Firearm.spread_direction(Basis.IDENTITY, 5.0, rng)
		var angle := rad_to_deg(dir.angle_to(Vector3.FORWARD))
		assert_float(angle).is_less_equal(5.0001)
	assert_vector(Firearm.spread_direction(Basis.IDENTITY, 0.0, rng)).is_equal_approx(
		Vector3.FORWARD, Vector3.ONE * 0.0001
	)


func test_spread_follows_basis() -> void:
	var rng := RandomNumberGenerator.new()
	var basis := Basis(Vector3.UP, deg_to_rad(90))
	assert_vector(Firearm.spread_direction(basis, 0.0, rng)).is_equal_approx(
		Vector3.LEFT, Vector3.ONE * 0.0001
	)


func test_bloom_and_aim_spread() -> void:
	var gun: Firearm = auto_free(Firearm.new())
	gun.stats = FirearmStats.new()
	gun.stats.spread_deg = 2.0
	gun.stats.ads_spread_mult = 0.5
	assert_float(gun.current_spread()).is_equal(2.0)
	gun.bloom = 3.0
	assert_float(gun.current_spread()).is_equal(5.0)
	gun.aiming = true
	assert_float(gun.current_spread()).is_equal(2.5)
