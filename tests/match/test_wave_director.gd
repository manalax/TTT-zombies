extends GdUnitTestSuite
## F019: WaveDirector pacing, alive budget, delays, weights and clear conditions.

const DT := 1.0 / 60.0

var _director: WaveDirector
var _rng: RandomNumberGenerator
var _next_id: int = 1


func before_test() -> void:
	_director = WaveDirector.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = 11
	_next_id = 1


func _enemy(cost: int = 1) -> EnemyData:
	var data := EnemyData.new()
	data.budget_cost = cost
	return data


func _wave(entries: Array[WaveEntry], budget: int, rate: float = 1.0) -> WaveData:
	var wave := WaveData.new()
	wave.entries = entries
	wave.budget_points = budget
	wave.spawn_rate = rate
	return wave


func _entry(enemy: EnemyData, count: int, weight: float = 1.0, delay: float = 0.0) -> WaveEntry:
	var entry := WaveEntry.new()
	entry.enemy = enemy
	entry.count_min = count
	entry.count_max = count
	entry.weight = weight
	entry.delay_s = delay
	return entry


## Steps [param seconds]; spawns every request. Returns the net ids spawned.
func _run(seconds: float) -> Array[int]:
	var ids: Array[int] = []
	for i in roundi(seconds / DT):
		for enemy in _director.step(DT):
			_director.notify_spawned(_next_id, enemy)
			ids.append(_next_id)
			_next_id += 1
	return ids


func test_spawns_scaled_total_at_rate_within_budget() -> void:
	var entries: Array[WaveEntry] = [_entry(_enemy(), 10)]
	_director.start(_wave(entries, 4, 2.0), MatchSettings.new(), 1, _rng)
	assert_int(_director.total_planned()).is_equal(10)
	var first := _run(0.01)
	assert_int(first.size()).is_equal(1)  # the first spawn is immediate
	_run(5.0)
	assert_int(_director.alive_count()).is_equal(4)  # capped by the alive budget
	assert_int(_director.alive_budget()).is_equal(4)
	_director.notify_died(1)
	_director.notify_died(2)
	var refill := _run(1.0)
	assert_int(refill.size()).is_equal(2)  # 2 per second, as budget frees
	assert_int(_director.spawned).is_equal(6)


func test_rate_limits_spawns() -> void:
	var entries: Array[WaveEntry] = [_entry(_enemy(), 50)]
	_director.start(_wave(entries, 100, 2.0), MatchSettings.new(), 1, _rng)
	var ids := _run(3.0)
	assert_int(ids.size()).is_between(6, 7)


func test_player_scale_applies() -> void:
	var entries: Array[WaveEntry] = [_entry(_enemy(), 10)]
	_director.start(_wave(entries, 100), MatchSettings.new(), 3, _rng)
	assert_int(_director.total_planned()).is_equal(18)


func test_delay_holds_entry_back() -> void:
	var early := _enemy()
	var late := _enemy()
	var entries: Array[WaveEntry] = [_entry(early, 3), _entry(late, 3, 1.0, 2.0)]
	_director.start(_wave(entries, 100, 10.0), MatchSettings.new(), 1, _rng)
	var spawned_late := 0
	for i in roundi(1.5 / DT):
		for enemy in _director.step(DT):
			_director.notify_spawned(_next_id, enemy)
			_next_id += 1
			if enemy == late:
				spawned_late += 1
	assert_int(spawned_late).is_equal(0)
	_run(2.0)
	assert_int(_director.remaining_to_spawn()).is_equal(0)


func test_weights_bias_picks() -> void:
	var common := _enemy()
	var rare := _enemy()
	var entries: Array[WaveEntry] = [_entry(common, 400, 9.0), _entry(rare, 400, 1.0)]
	_director.start(_wave(entries, 10000, 20.0), MatchSettings.new(), 1, _rng)
	var rare_count := 0
	for i in roundi(10.0 / DT):
		for enemy in _director.step(DT):
			_director.notify_spawned(_next_id, enemy)
			_next_id += 1
			if enemy == rare:
				rare_count += 1
	assert_int(_director.spawned).is_equal(200)
	assert_int(rare_count).is_between(8, 35)  # ~10%


func test_tiny_budget_cannot_stall() -> void:
	var entries: Array[WaveEntry] = [_entry(_enemy(5), 2)]
	_director.start(_wave(entries, 1, 5.0), MatchSettings.new(), 1, _rng)
	assert_int(_run(1.0).size()).is_equal(1)  # one at a time, never two
	_director.notify_died(1)
	assert_int(_run(1.0).size()).is_equal(1)


func test_kill_all_clears_only_when_everything_is_dead() -> void:
	var entries: Array[WaveEntry] = [_entry(_enemy(), 3)]
	_director.start(_wave(entries, 10, 10.0), MatchSettings.new(), 1, _rng)
	assert_bool(_director.is_cleared()).is_false()
	var ids := _run(1.0)
	assert_int(ids.size()).is_equal(3)
	_director.notify_died(ids[0])
	_director.notify_died(ids[1])
	assert_bool(_director.is_cleared()).is_false()
	_director.notify_died(ids[2])
	_director.notify_died(9999)  # not ours: ignored
	assert_bool(_director.is_cleared()).is_true()
	assert_int(_director.kills).is_equal(3)


func test_quota_survive_and_timeout() -> void:
	var entries: Array[WaveEntry] = [_entry(_enemy(), 20)]
	var quota := _wave(entries, 50, 10.0)
	quota.clear_condition = WaveData.ClearCondition.KILL_QUOTA
	quota.kill_quota = 2
	_director.start(quota, MatchSettings.new(), 1, _rng)
	var ids := _run(1.0)
	_director.notify_died(ids[0])
	assert_bool(_director.is_cleared()).is_false()
	_director.notify_died(ids[1])
	assert_bool(_director.is_cleared()).is_true()
	var survive := _wave(entries, 50)
	survive.clear_condition = WaveData.ClearCondition.SURVIVE_TIME
	survive.survive_time_s = 3.0
	_director.start(survive, MatchSettings.new(), 1, _rng)
	_run(2.9)
	assert_bool(_director.is_cleared()).is_false()
	_run(0.2)
	assert_bool(_director.is_cleared()).is_true()
	var timed := _wave(entries, 50)
	timed.timeout_s = 1.0
	_director.start(timed, MatchSettings.new(), 1, _rng)
	_run(1.05)
	assert_bool(_director.is_cleared()).is_true()
