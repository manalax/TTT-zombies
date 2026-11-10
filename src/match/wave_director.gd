class_name WaveDirector
extends RefCounted
## Spawn pacing for one wave (DESIGN §8.1, docs/adr/0012-wave-director.md). Pure: it decides
## WHAT to spawn and WHEN; the MatchManager spawns, then reports spawns and deaths back.
##
## Entry counts are the wave's total (rolled, scaled by living Hunters). budget_points caps the
## summed EnemyData.budget_cost of this wave's enemies alive at once, so a big wave trickles in
## at spawn_rate as enemies die. Entries wait for their delay_s; picks are weighted.

var wave: WaveData
var elapsed: float = 0.0
var kills: int = 0
var spawned: int = 0
## Per-entry spawns still to come (parallel to wave.entries).
var remaining: Array[int] = []

var _rng: RandomNumberGenerator
var _accumulator: float = 0.0
## net_id -> budget_cost of this wave's living enemies.
var _alive: Dictionary[int, int] = {}
var _alive_budget: int = 0


func start(
	p_wave: WaveData, settings: MatchSettings, living_hunters: int, rng: RandomNumberGenerator
) -> void:
	wave = p_wave
	_rng = rng
	elapsed = 0.0
	kills = 0
	spawned = 0
	_accumulator = 1.0  # the first spawn is due immediately
	_alive.clear()
	_alive_budget = 0
	remaining.clear()
	for entry in wave.entries:
		remaining.append(WaveRules.scaled_count(entry, living_hunters, settings, rng))


## Advances time; returns the enemies to spawn now (may be empty).
func step(delta: float) -> Array[EnemyData]:
	var requests: Array[EnemyData] = []
	if wave == null:
		return requests
	elapsed += delta
	_accumulator = minf(_accumulator + delta * wave.spawn_rate, 1.0 + wave.spawn_rate)
	while _accumulator >= 1.0:
		var index := _pick_entry(requests)
		if index < 0:
			break
		_accumulator -= 1.0
		remaining[index] -= 1
		requests.append(wave.entries[index].enemy)
	return requests


## Call after the manager actually spawned [param net_id] for a request.
func notify_spawned(net_id: int, enemy: EnemyData) -> void:
	_alive[net_id] = enemy.budget_cost
	_alive_budget += enemy.budget_cost
	spawned += 1


## Call when any enemy dies; ignored if it is not one of this wave's.
func notify_died(net_id: int) -> void:
	if not _alive.has(net_id):
		return
	_alive_budget -= _alive[net_id]
	_alive.erase(net_id)
	kills += 1


func alive_count() -> int:
	return _alive.size()


func alive_budget() -> int:
	return _alive_budget


func remaining_to_spawn() -> int:
	var total := 0
	for count in remaining:
		total += count
	return total


func total_planned() -> int:
	return spawned + remaining_to_spawn()


func is_cleared() -> bool:
	if wave == null:
		return false
	if wave.timeout_s > 0.0 and elapsed >= wave.timeout_s:
		return true
	match wave.clear_condition:
		WaveData.ClearCondition.KILL_QUOTA:
			return kills >= wave.kill_quota
		WaveData.ClearCondition.SURVIVE_TIME:
			return elapsed >= wave.survive_time_s
	return remaining_to_spawn() == 0 and alive_count() == 0


## Weighted pick among entries that are past their delay, have spawns left and fit the alive
## budget (counting [param pending] requests of this step). -1 if none.
func _pick_entry(pending: Array[EnemyData]) -> int:
	var pending_cost := 0
	for enemy in pending:
		pending_cost += enemy.budget_cost
	var eligible: Array[int] = []
	var total_weight := 0.0
	for i in wave.entries.size():
		var entry := wave.entries[i]
		if remaining[i] <= 0 or elapsed < entry.delay_s:
			continue
		var used := _alive_budget + pending_cost
		# Over the cap is only allowed when nothing is alive, so a tiny budget cannot stall.
		if used > 0 and used + entry.enemy.budget_cost > wave.budget_points:
			continue
		eligible.append(i)
		total_weight += entry.weight
	if eligible.is_empty():
		return -1
	var roll := _rng.randf() * total_weight
	for i in eligible:
		roll -= wave.entries[i].weight
		if roll <= 0.0:
			return i
	return eligible.back()
