# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F019: the match loop (intermission ⇄ waves, victory, defeat, sandbox reset).

const World := preload("res://tests/enemies/enemy_test_world.gd")
const MatchWorld := preload("res://tests/match/match_test_world.gd")
const TestBot := preload("res://tests/match/fixtures/test_bot.gd")
const TEST_SHORT := "res://content/waves/sets/test_short/test_short.tres"
const DT := 1.0 / 60.0

var _world: Node3D
var _manager: MatchManager
var _registry: EnemyRegistry
var _player: Player
var _events: Array[String] = []


func before_test() -> void:
	_events.clear()
	var built := MatchWorld.build(TEST_SHORT)
	_world = auto_free(built["root"])
	_manager = built["manager"]
	_registry = built["registry"]
	add_child(_world)
	_player = World.player(_world, Vector3.ZERO)
	_player.set_physics_process(false)
	_manager.set_physics_process(false)
	Events.intermission_started.connect(_on_intermission)
	Events.round_started.connect(_on_round_started)
	Events.round_cleared.connect(_on_round_cleared)
	Events.match_ended.connect(_on_match_ended)
	await get_tree().physics_frame


func after_test() -> void:
	Events.intermission_started.disconnect(_on_intermission)
	Events.round_started.disconnect(_on_round_started)
	Events.round_cleared.disconnect(_on_round_cleared)
	Events.match_ended.disconnect(_on_match_ended)


func _on_intermission(round_number: int, _duration: float) -> void:
	_events.append("intermission %d" % round_number)


func _on_round_started(round_number: int) -> void:
	_events.append("start %d" % round_number)


func _on_round_cleared(round_number: int) -> void:
	_events.append("clear %d" % round_number)


func _on_match_ended(side: StringName) -> void:
	_events.append("end %s" % side)


func _steps(seconds: float, bot: RefCounted = null) -> void:
	for i in roundi(seconds / DT):
		if bot != null:
			bot.call(&"step", DT)
		_manager.step(DT)


func test_starts_in_lobby_and_only_starts_once() -> void:
	assert_str(String(_manager.phase())).is_equal("Lobby")
	assert_bool(_manager.start_match()).is_true()
	assert_str(String(_manager.phase())).is_equal("Intermission")
	assert_bool(_manager.start_match()).is_false()
	assert_array(_events).contains_exactly(["intermission 1"])
	assert_int(_manager.final_round).is_equal(3)


func test_wave_spawns_far_from_hunters_and_clears() -> void:
	_manager.start_match()
	_steps(0.6)
	assert_str(String(_manager.phase())).is_equal("WaveActive")
	assert_array(_events).contains_exactly(["intermission 1", "start 1"])
	_steps(3.0)
	var enemies := _registry.get_enemies()
	assert_int(enemies.size()).is_greater(0)
	for enemy in enemies:
		var offset := enemy.global_position - _player.global_position
		offset.y = 0.0
		assert_float(offset.length()).is_greater(12.0)  # never the 5 m point (ring jitter ≤ 2 m)
	var bot := TestBot.new(_registry, _player.health)
	bot.kill_delay_s = 0.0
	for enemy in enemies:
		Combat.apply(
			DamageEvent.from_source(
				_player.health, enemy.health, 1000.0, CombatTypes.DamageType.MELEE
			)
		)
	_steps(10.0, bot)
	assert_array(_events).contains(["clear 1", "intermission 2"])
	assert_array(["Intermission", "WaveActive"]).contains([String(_manager.phase())])


func test_victory_then_results_then_lobby() -> void:
	var bot := TestBot.new(_registry, _player.health)
	bot.kill_delay_s = 0.1
	_manager.start_match()
	for i in 6000:
		bot.step(DT)
		_manager.step(DT)
		if _manager.phase() == &"Results":
			break
	assert_str(String(_manager.winner)).is_equal("hunters")
	(
		assert_array(_events)
		. contains_exactly(
			[
				"intermission 1",
				"start 1",
				"clear 1",
				"intermission 2",
				"start 2",
				"clear 2",
				"intermission 3",
				"start 3",
				"clear 3",
				"end hunters",
			]
		)
	)
	_steps(MatchManager.RESULTS_S + 0.1)
	assert_str(String(_manager.phase())).is_equal("Lobby")
	await get_tree().process_frame
	assert_int(_registry.get_enemies().size()).is_equal(0)


func test_defeat_and_sandbox_reset() -> void:
	_player.points.reset(9000)
	_player.loadout.replace_slot(Loadout.MELEE, ContentDB.get_item(&"WeaponData", &"greatsword"))
	_player.global_position = Vector3(3, 0.05, 3)
	_manager.start_match()
	_steps(1.0)
	Combat.apply(DamageEvent.world(_player.health, 1000.0, CombatTypes.DamageType.DEBUG))
	assert_bool(_player.is_dead()).is_true()
	_steps(DT * 2)
	assert_str(String(_manager.winner)).is_equal("cult")
	assert_array(_events).contains(["end cult"])
	assert_str(String(_manager.phase())).is_equal("Results")
	_steps(MatchManager.RESULTS_S + 0.1)
	assert_str(String(_manager.phase())).is_equal("Lobby")
	assert_bool(_player.is_dead()).is_false()
	assert_float(_player.health.current_health).is_equal(_player.health.max_health)
	assert_int(_player.points.balance).is_equal(Settings.match_settings.starting_points)
	assert_str(_player.loadout.slots[Loadout.MELEE].id).is_equal("arming_sword")
	assert_float(_player.global_position.distance_to(Vector3(0, 0.05, 2))).is_less(0.01)
	assert_str(_player.get_movement_state()).is_not_equal("Dead")


func test_no_waves_cannot_start() -> void:
	_manager.settings.wave_set = null
	assert_bool(_manager.start_match()).is_false()
	assert_str(String(_manager.phase())).is_equal("Lobby")
