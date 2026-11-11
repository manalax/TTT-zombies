extends GdUnitTestSuite
## F046 acceptance: enemies breach boarded windows plank by plank (swiping through at players in
## reach, then climbing in); players hold interact on the inside to repair them for points.
## World: a wall at z = 0 with a 2.4 m window at x = 0 holding a Barricade; outside (z < 0) is
## the closet with a linked spawn point, inside (z > 0) the player. Brains are stepped by hand.

const World := preload("res://tests/enemies/enemy_test_world.gd")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const BARRICADE_SCENE := preload("res://src/world/barricade/barricade.tscn")
const DT := 1.0 / 60.0
const NAV_SYNC_FRAMES := 8

var _world: Node3D
var _window: Barricade
var _point: EnemySpawnPoint
var _player: Player
var _input: ScriptedInputSource
var _enemies: Array[EnemyBase] = []
var _changes: Array[int] = []


func before_test() -> void:
	_enemies.clear()
	_changes.clear()
	Events.barricade_changed.connect(_on_changed)
	var walls: Array[AABB] = [
		AABB(Vector3(-15, 0, -0.25), Vector3(13.8, 3, 0.5)),
		AABB(Vector3(1.2, 0, -0.25), Vector3(13.8, 3, 0.5)),
	]
	_world = auto_free(World.world(30.0, walls))
	_window = BARRICADE_SCENE.instantiate()
	_window.name = "Window"
	_window.barricade_id = &"test_window"
	_world.add_child(_window)
	_point = EnemySpawnPoint.new()
	_point.name = "ClosetSpawn"
	_point.position = Vector3(0, 0.05, -6)
	_point.barricade = ^"../Window"
	_world.add_child(_point)
	add_child(_world)
	_player = World.player(_world, Vector3(0, 0, 10))
	_player.set_physics_process(false)
	_input = _player.get_meta(&"input")
	for i in NAV_SYNC_FRAMES:
		await get_tree().physics_frame


func after_test() -> void:
	Events.barricade_changed.disconnect(_on_changed)


func _on_changed(barricade_id: StringName, planks: int) -> void:
	assert_str(barricade_id).is_equal("test_window")
	_changes.append(planks)


func _spawn(data: EnemyData = null) -> EnemyBase:
	if data == null:
		data = World.acolyte_data()
	var enemy := _point.spawn(data, _world, _enemies.size() * 2)
	enemy.set_physics_process(false)
	enemy.agent.avoidance_enabled = false
	enemy.update_target()
	_enemies.append(enemy)
	return enemy


func _steps(count: int) -> void:
	for i in count:
		_player.step(DT)
		for enemy in _enemies:
			if is_instance_valid(enemy):
				enemy.step(DT)


func _until(condition: Callable, limit: int) -> int:
	for i in limit:
		if condition.call():
			return i
		_steps(1)
	return -1


func _fast_tearer() -> EnemyData:
	var data := World.acolyte_data()
	data.barricade_tear_s = 0.1
	return data


# --- Rules --------------------------------------------------------------------------------


func test_tear_and_repair_rules() -> void:
	var enemy := _spawn()
	var other := _spawn()
	assert_int(_window.planks).is_equal(6)
	assert_bool(_window.tear(enemy)).is_false()  # must hold the tear slot
	assert_bool(_window.claim_tear(enemy)).is_true()
	assert_bool(_window.claim_tear(other)).is_false()
	for i in 6:
		assert_bool(_window.tear(enemy)).is_true()
	assert_bool(_window.tear(enemy)).is_false()
	assert_bool(_window.is_open()).is_true()
	assert_array(_changes).contains_exactly([5, 4, 3, 2, 1, 0])
	assert_bool(_window.claim_climb(other)).is_true()
	assert_bool(_window.claim_climb(enemy)).is_false()
	assert_bool(_window.can_repair(_player)).is_false()  # blocked while someone climbs
	_window.release(other)
	var before := _player.points.balance
	assert_bool(_window.repair(_player)).is_true()
	assert_int(_player.points.balance).is_equal(before + 10)
	_window.planks = 6
	assert_bool(_window.can_repair(_player)).is_false()  # intact
	assert_bool(_window.repair(_player)).is_false()


func test_hold_interact_repairs_one_plank_per_interval() -> void:
	_player.global_position = Vector3(0, 0, 1.3)
	await get_tree().physics_frame
	_window.planks = 3
	var target := _player.get_interact_target()
	assert_object(target).is_same(_window.interactable)
	assert_str(target.get_prompt_text(_player)).is_equal("Hold E: Repair barricade")
	var before := _player.points.balance
	_input.interact_held = true
	_steps(44)
	assert_int(_window.planks).is_equal(3)
	assert_float(_player.get_interact_hold_ratio()).is_greater(0.9)
	_steps(1)  # 45 ticks = 0.75 s
	assert_int(_window.planks).is_equal(4)
	_steps(30)
	_input.interact_held = false
	_steps(1)
	assert_float(_player.get_interact_hold_ratio()).is_equal(0.0)  # releasing resets
	_input.interact_held = true
	_steps(44)
	assert_int(_window.planks).is_equal(4)
	_steps(1)
	assert_int(_window.planks).is_equal(5)
	assert_int(_player.points.balance).is_equal(before + 20)
	_steps(45)
	assert_int(_window.planks).is_equal(6)
	assert_str(target.get_prompt_text(_player)).is_equal("Repair barricade — Intact")
	_steps(90)
	assert_int(_player.points.balance).is_equal(before + 30)


func test_window_blocks_players_but_not_attacks() -> void:
	_player.global_position = Vector3(0, 0, 1.5)
	var enemy := _spawn()
	enemy.global_position = Vector3(0, 0.05, -1.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var from := Vector3(0, 1.2, 1.0)
	var query := PhysicsRayQueryParameters3D.create(
		from, Vector3(0, 1.2, -3.0), PhysicsLayers.ATTACK_MASK
	)
	query.collide_with_areas = true
	var hit := _world.get_world_3d().direct_space_state.intersect_ray(query)
	assert_bool(hit.is_empty()).is_false()
	assert_bool(hit["collider"] is Hurtbox).is_true()
	_input.hold(Vector2(0, -1))  # walk forward (-Z) into the window
	_steps(120)
	assert_float(_player.global_position.z).is_greater(0.3)


# --- AI -----------------------------------------------------------------------------------


func test_acolyte_tears_every_plank_then_climbs_in() -> void:
	var enemy := _spawn(_fast_tearer())
	assert_object(enemy.breach).is_same(_window)
	var reached := _until(func() -> bool: return enemy.get_state_path() == "Alive/Climb", 900)
	assert_int(reached).is_greater_equal(0)
	assert_array(_changes).contains_exactly([5, 4, 3, 2, 1, 0])
	assert_float(enemy.global_position.z).is_less(0.0)
	assert_bool(_window.can_repair(_player)).is_false()  # someone is climbing
	enemy.brain.send_event(&"staggered", {"duration": 1.0})
	assert_str(enemy.get_state_path()).is_equal("Alive/Climb")  # climbing can't be interrupted
	var inside := _until(func() -> bool: return enemy.breach == null, 120)
	assert_int(inside).is_between(40, 60)  # 0.8 s
	assert_float(enemy.global_position.z).is_greater(0.5)
	assert_object(_window.climber).is_null()
	_steps(5)
	assert_str(enemy.get_state_path()).is_equal("Alive/Chase")


func test_one_tearer_at_a_time() -> void:
	var first := _spawn(_fast_tearer())
	var second := _spawn(_fast_tearer())
	var tearing := _until(func() -> bool: return _window.planks < 6, 600)
	assert_int(tearing).is_greater_equal(0)
	var tearer := _window.tearer
	assert_bool(tearer == first or tearer == second).is_true()
	var waiter := second if tearer == first else first
	assert_str(waiter.get_state_path()).is_equal("Alive/Breach")
	assert_float(waiter.horizontal_distance_to(_window.outer_point())).is_greater(0.35)
	# Planks fall at one tearer's rate: 5 more in about 0.5 s, not twice as fast.
	_steps(15)
	assert_int(_window.planks).is_greater_equal(3)


func test_swipes_through_window_without_lunging() -> void:
	_player.global_position = Vector3(0, 0, 0.55)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var enemy := _spawn()
	var health_before := _player.health.current_health
	var hit := _until(func() -> bool: return _player.health.current_health < health_before, 900)
	assert_int(hit).is_greater_equal(0)
	assert_float(enemy.global_position.z).is_less(-0.3)  # still outside, no lunge
	assert_bool(enemy.is_breaching()).is_true()
	assert_int(_window.planks).is_equal(6)  # it swiped instead of tearing
	_steps(120)
	assert_float(enemy.global_position.z).is_less(-0.3)


func test_closet_is_unreachable_from_inside() -> void:
	var map := _world.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(0, 0, 8), Vector3(0, 0, -8), true)
	assert_bool(path.is_empty()).is_false()
	assert_float(path[path.size() - 1].z).is_greater(0.0)


func test_spawn_spread_is_clamped_in_closets() -> void:
	_point.max_spread_index = 2
	var enemy := _point.spawn(World.acolyte_data(), _world, 9)
	enemy.set_physics_process(false)
	var offset := enemy.global_position - _point.global_position
	assert_float(Vector2(offset.x, offset.z).length()).is_less_equal(
		EnemySpawnPoint.RING_SPACING_M + 0.01
	)
