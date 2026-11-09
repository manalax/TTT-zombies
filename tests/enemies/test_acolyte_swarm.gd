extends GdUnitTestSuite
## F015 acceptance: a swarm chases a player without frame drops. Raised from 30 to the
## DESIGN §12.5 target of 60. Rendering FPS is a manual check (Shift+F10 in the sandbox).

const World := preload("res://tests/enemies/enemy_test_world.gd")
const COUNT := 60
const FRAMES := 360
## Per-tick budget for all 60 AI steps (frame is 16.7 ms). Deliberately loose for slow CI.
const AI_BUDGET_MS := 4.0

var _world: Node3D
var _player: Player


func before_test() -> void:
	var pillars: Array[AABB] = [
		AABB(Vector3(-5, 0, -6), Vector3(1.2, 3, 1.2)),
		AABB(Vector3(4, 0, 5), Vector3(1.2, 3, 1.2)),
		AABB(Vector3(-7, 0, 6), Vector3(3, 3, 1)),
	]
	_world = auto_free(World.world(50.0, pillars))
	add_child(_world)
	_player = World.player(_world, Vector3.ZERO)
	_player.health.invulnerable = true
	await get_tree().physics_frame


func test_sixty_acolytes_chase_within_budget() -> void:
	var enemies: Array[EnemyBase] = []
	var start_dist: Array[float] = []
	for i in COUNT:
		var angle := TAU * i / COUNT
		var radius := 14.0 + (i % 4) * 2.0
		var at := Vector3(cos(angle) * radius, 0.05, sin(angle) * radius)
		var enemy := World.acolyte(_world, at)
		enemies.append(enemy)
		start_dist.append(enemy.horizontal_distance_to(_player.global_position))
	await get_tree().physics_frame
	AIStats.reset()
	for f in FRAMES:
		await get_tree().physics_frame
	var near := 0
	var closed := 0
	var min_spacing := INF
	var nearest_sum := 0.0
	for i in COUNT:
		var enemy := enemies[i]
		var dist := enemy.horizontal_distance_to(_player.global_position)
		if dist < start_dist[i] - 3.0:
			closed += 1
		if dist < 5.0:
			near += 1
		var nearest := INF
		for j in COUNT:
			if j != i:
				nearest = minf(nearest, enemy.horizontal_distance_to(enemies[j].global_position))
		nearest_sum += nearest
		min_spacing = minf(min_spacing, nearest)
	var mean_nearest := nearest_sum / COUNT
	var mean := AIStats.mean_ms()
	prints(
		(
			(
				"[F015 swarm] %d acolytes, %d ticks: AI mean %.2f ms, peak %.2f ms; "
				+ "closed %d, within 5 m %d, nearest neighbour mean %.2f m / min %.2f m"
			)
			% [
				COUNT,
				AIStats.tick_count(),
				mean,
				AIStats.peak_ms,
				closed,
				near,
				mean_nearest,
				min_spacing
			]
		)
	)
	assert_int(closed).is_equal(COUNT)
	assert_int(near).is_greater_equal(int(COUNT * 0.9))
	# Avoidance spreads the crowd (agent diameter 0.9 m). Lunges converge on the player and
	# acolytes do not collide with each other, so a pair may briefly overlap, but never stack.
	assert_float(mean_nearest).is_greater(0.7)
	assert_float(min_spacing).is_greater(0.15)
	assert_float(mean).is_less(AI_BUDGET_MS)
