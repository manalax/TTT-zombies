extends GdUnitTestSuite
## F019: pure wave rules (player scaling, final round, spawn-point choice).


func _entry(lo: int, hi: int) -> WaveEntry:
	var entry := WaveEntry.new()
	entry.enemy = EnemyData.new()
	entry.count_min = lo
	entry.count_max = hi
	return entry


func _point(at: Vector3) -> EnemySpawnPoint:
	var point: EnemySpawnPoint = auto_free(EnemySpawnPoint.new())
	add_child(point)
	point.global_position = at
	return point


func test_player_scale_curve() -> void:
	var settings := MatchSettings.new()
	assert_float(WaveRules.player_scale(1, settings)).is_equal(1.0)
	assert_float(WaveRules.player_scale(4, settings)).is_equal_approx(2.2, 0.0001)
	assert_float(WaveRules.player_scale(99, settings)).is_equal_approx(3.8, 0.0001)
	assert_float(WaveRules.player_scale(1, null)).is_equal(1.0)


func test_scaled_count() -> void:
	var settings := MatchSettings.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_int(WaveRules.scaled_count(_entry(10, 10), 1, settings, rng)).is_equal(10)
	assert_int(WaveRules.scaled_count(_entry(10, 10), 2, settings, rng)).is_equal(14)
	assert_int(WaveRules.scaled_count(_entry(0, 0), 4, settings, rng)).is_equal(0)
	assert_int(WaveRules.scaled_count(_entry(1, 1), 0, settings, rng)).is_equal(0)
	settings.player_scale[1] = 0.1
	assert_int(WaveRules.scaled_count(_entry(2, 2), 1, settings, rng)).is_equal(1)
	for i in 50:
		var count := WaveRules.scaled_count(_entry(3, 6), 1, MatchSettings.new(), rng)
		assert_int(count).is_between(3, 6)


func test_final_round_is_capped_by_set_length() -> void:
	var settings := MatchSettings.new()
	assert_int(WaveRules.final_round(settings)).is_equal(0)
	settings.wave_set = load("res://content/waves/sets/test_short/test_short.tres")
	assert_int(WaveRules.final_round(settings)).is_equal(3)
	settings.wave_set = load("res://content/waves/sets/dev_twelve/dev_twelve.tres")
	assert_int(WaveRules.final_round(settings)).is_equal(12)
	settings.final_round = 5
	assert_int(WaveRules.final_round(settings)).is_equal(5)


func test_spawn_point_respects_min_distance() -> void:
	var near := _point(Vector3(5, 0, 0))
	var far_a := _point(Vector3(20, 0, 0))
	var far_b := _point(Vector3(0, 0, -25))
	var points: Array[EnemySpawnPoint] = [near, far_a, far_b]
	var hunters: Array[Vector3] = [Vector3.ZERO]
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var seen: Dictionary[EnemySpawnPoint, bool] = {}
	for i in 40:
		var pick := WaveRules.pick_spawn_point(points, hunters, 15.0, rng)
		assert_object(pick).is_not_same(near)
		seen[pick] = true
	assert_int(seen.size()).is_equal(2)


func test_spawn_point_falls_back_to_farthest() -> void:
	var a := _point(Vector3(5, 0, 0))
	var b := _point(Vector3(9, 0, 0))
	var points: Array[EnemySpawnPoint] = [a, b]
	var hunters: Array[Vector3] = [Vector3.ZERO, Vector3(12, 0, 0)]
	var rng := RandomNumberGenerator.new()
	# a: nearest hunter 5 m; b: 3 m. Neither is >= 15 m, so the farthest-from-nearest wins.
	assert_object(WaveRules.pick_spawn_point(points, hunters, 15.0, rng)).is_same(a)
	assert_object(WaveRules.pick_spawn_point([], hunters, 15.0, rng)).is_null()
