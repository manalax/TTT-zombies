class_name WaveRules
extends RefCounted
## Pure wave rules (DESIGN §8, docs/adr/0012-wave-director.md): player scaling, the final round,
## and spawn-point choice. No scene access, so they are unit-tested directly.


## The player_scale multiplier for [param living] Hunters (index clamped to the curve).
static func player_scale(living: int, settings: MatchSettings) -> float:
	if settings == null or settings.player_scale.is_empty():
		return 1.0
	var index := clampi(living, 0, settings.player_scale.size() - 1)
	return settings.player_scale[index]


## How many of [param entry] this wave spawns: a roll in [count_min, count_max], scaled by the
## living-player curve and rounded; at least 1 when the roll is > 0 and the scale is > 0.
static func scaled_count(
	entry: WaveEntry, living: int, settings: MatchSettings, rng: RandomNumberGenerator
) -> int:
	var rolled := rng.randi_range(entry.count_min, maxi(entry.count_min, entry.count_max))
	var scale := player_scale(living, settings)
	if rolled <= 0 or scale <= 0.0:
		return 0
	return maxi(1, roundi(rolled * scale))


## The last round of a match: MatchSettings.final_round, capped by the wave set's length.
static func final_round(settings: MatchSettings) -> int:
	if settings == null or settings.wave_set == null:
		return 0
	return mini(settings.final_round, settings.wave_set.waves.size())


## A spawn point at least [param min_distance] (horizontal) from every Hunter position, picked
## at random. If none qualifies, the point farthest from its nearest Hunter. Null if [param
## points] is empty. Callers pass only active points.
static func pick_spawn_point(
	points: Array[EnemySpawnPoint],
	hunters: Array[Vector3],
	min_distance: float,
	rng: RandomNumberGenerator
) -> EnemySpawnPoint:
	if points.is_empty():
		return null
	var far_enough: Array[EnemySpawnPoint] = []
	var best: EnemySpawnPoint = null
	var best_gap := -1.0
	for point in points:
		var gap := nearest_distance(point.global_position, hunters)
		if gap >= min_distance:
			far_enough.append(point)
		if gap > best_gap:
			best_gap = gap
			best = point
	if not far_enough.is_empty():
		return far_enough[rng.randi_range(0, far_enough.size() - 1)]
	return best


## Horizontal distance from [param from] to the closest of [param others] (INF if none).
static func nearest_distance(from: Vector3, others: Array[Vector3]) -> float:
	var best := INF
	for other in others:
		var offset := other - from
		offset.y = 0.0
		best = minf(best, offset.length())
	return best
