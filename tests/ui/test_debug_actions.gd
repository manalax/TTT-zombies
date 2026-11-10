extends GdUnitTestSuite
## F011: debug damage keys against the real sandbox arena.

const ARENA := preload("res://maps/dev/sandbox_arena/sandbox_arena.tscn")

var _arena: Node3D
var _actions: DebugActions


func before_test() -> void:
	_arena = auto_free(ARENA.instantiate())
	add_child(_arena)
	_actions = auto_free(DebugActions.new())
	add_child(_actions)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_arena_has_local_player_and_dummies() -> void:
	assert_object(_actions.get_local_player()).is_not_null()
	assert_int(_arena.get_node("Dummies").get_child_count()).is_equal(5)


func test_hurt_self() -> void:
	var result := _actions.hurt_self()
	assert_bool(result.accepted).is_true()
	assert_float(_actions.get_local_player().health.current_health).is_equal(75.0)


func test_test_shot_hits_armoured_dummy_head() -> void:
	# The player spawns facing -Z straight at the armoured dummy; eye height lines up with its head.
	var dummy: TrainingDummy = _arena.get_node("Dummies/DummyArmoured")
	var result := _actions.test_shot()
	assert_object(result).is_not_null()
	assert_bool(result.accepted).is_true()
	assert_bool(result.event.is_weakpoint()).is_true()
	# 30 × weak point 2 × armour 0.5.
	assert_float(result.applied).is_equal_approx(30.0, 0.0001)
	assert_float(dummy.health.current_health).is_equal_approx(170.0, 0.0001)
	assert_str(dummy.last_hit).contains("armour 50%")


func test_spawn_and_clear_enemies() -> void:
	var registry: EnemyRegistry = _arena.get_node("Enemies")
	assert_int(_actions.spawn_enemies(1)).is_equal(1)
	assert_int(_actions.spawn_enemies(5)).is_equal(5)
	assert_int(registry.alive_count()).is_equal(6)
	# Spread over the four spawn points, never stacked.
	var enemies := registry.get_enemies()
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			var gap := enemies[i].global_position.distance_to(enemies[j].global_position)
			assert_float(gap).is_greater(0.5)
	assert_int(_actions.clear_enemies()).is_equal(6)
	await get_tree().process_frame
	assert_int(registry.get_enemies().size()).is_equal(0)


func test_arena_navmesh_baked_and_overlay_info() -> void:
	var nav: RuntimeNavRegion = _arena.get_node("NavRegion")
	assert_bool(nav.is_baked()).is_true()
	assert_int(get_tree().get_nodes_in_group(EnemySpawnPoint.GROUP).size()).is_equal(5)
	var registry: EnemyRegistry = _arena.get_node("Enemies")
	assert_int(registry.active_spawn_points().size()).is_equal(4)  # annex locked
	var info: Dictionary = (_arena.get_node("Enemies") as EnemyRegistry).get_debug_info()
	assert_bool(info.has("ai ms/tick")).is_true()


func test_grant_points() -> void:
	var player := _actions.get_local_player()
	var before := player.points.balance
	assert_int(_actions.grant_points(1000)).is_equal(before + 1000)


func test_opening_the_annex_adds_its_spawn_point() -> void:
	var registry: EnemyRegistry = _arena.get_node("Enemies")
	var annex: Zone = _arena.get_node("ZoneAnnex")
	assert_bool((_arena.get_node("Doors/AnnexPostern") as Door).open(1)).is_true()
	assert_bool(annex.unlocked).is_true()
	assert_int(registry.active_spawn_points().size()).is_equal(5)
	_actions.spawn_enemies(5)
	var in_annex := 0
	for enemy in registry.get_enemies():
		if annex.contains(enemy.global_position + Vector3.UP):
			in_annex += 1
	assert_int(in_annex).is_equal(1)


func test_start_match_key() -> void:
	var manager: MatchManager = _arena.get_node("MatchManager")
	assert_bool(_actions.start_match()).is_true()
	assert_str(String(manager.phase())).is_equal("Intermission")
	assert_int(manager.final_round).is_equal(12)
	assert_bool(_actions.start_match()).is_false()
