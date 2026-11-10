extends GdUnitTestSuite
## F019 acceptance: a bot-assisted run completes 12 waves headless (dev_twelve wave set).
## Time is stepped by hand at 60 Hz; the bot kills each enemy 0.5 s after it spawns.

const World := preload("res://tests/enemies/enemy_test_world.gd")
const MatchWorld := preload("res://tests/match/match_test_world.gd")
const TestBot := preload("res://tests/match/fixtures/test_bot.gd")
const DEV_TWELVE := "res://content/waves/sets/dev_twelve/dev_twelve.tres"
const DT := 1.0 / 60.0
## Generous cap: ~250 enemies and a 45 s survival round is ~5 minutes of game time.
const MAX_STEPS := 60 * 60 * 10
const YIELD_EVERY := 300

var _started: Array[int] = []
var _cleared: Array[int] = []
var _ended: Array[StringName] = []


func _on_started(n: int) -> void:
	_started.append(n)


func _on_cleared(n: int) -> void:
	_cleared.append(n)


func _on_ended(side: StringName) -> void:
	_ended.append(side)


func test_bot_completes_twelve_waves() -> void:
	var built := MatchWorld.build(DEV_TWELVE, 0.2)
	var world: Node3D = auto_free(built["root"])
	var manager: MatchManager = built["manager"]
	var registry: EnemyRegistry = built["registry"]
	add_child(world)
	var player := World.player(world, Vector3.ZERO)
	player.set_physics_process(false)
	player.health.invulnerable = true
	manager.set_physics_process(false)
	await get_tree().physics_frame
	Events.round_started.connect(_on_started)
	Events.round_cleared.connect(_on_cleared)
	Events.match_ended.connect(_on_ended)
	var bot := TestBot.new(registry, player.health)
	var waves: WaveSet = load(DEV_TWELVE)
	var over_budget := 0
	var short_kill_all := 0
	var steps := 0
	assert_bool(manager.start_match()).is_true()
	while steps < MAX_STEPS and _ended.is_empty():
		bot.step(DT)
		var before := _cleared.size()
		manager.step(DT)
		var director := manager.director
		if manager.phase() == &"WaveActive" and director.alive_count() > 1:
			if director.alive_budget() > director.wave.budget_points:
				over_budget += 1
		if _cleared.size() > before:
			var wave := waves.waves[_cleared.back() - 1]
			if wave.clear_condition == WaveData.ClearCondition.KILL_ALL:
				if director.spawned != director.total_planned() or director.spawned == 0:
					short_kill_all += 1
		steps += 1
		if steps % YIELD_EVERY == 0:
			await get_tree().process_frame
	Events.round_started.disconnect(_on_started)
	Events.round_cleared.disconnect(_on_cleared)
	Events.match_ended.disconnect(_on_ended)
	prints("[F019 run] %d steps (%.0f s game time), %d kills" % [steps, steps * DT, bot.kills])
	var expected: Array[int] = []
	expected.assign(range(1, 13))
	assert_array(_started).is_equal(expected)
	assert_array(_cleared).is_equal(expected)
	assert_array(_ended).contains_exactly([&"hunters"])
	assert_str(String(manager.phase())).is_equal("Results")
	assert_int(over_budget).is_equal(0)
	assert_int(short_kill_all).is_equal(0)
	assert_int(steps).is_less(MAX_STEPS)
