# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F017 acceptance: buying a door opens it, unlocks its zone and that zone's spawn points, and
## lets cultists path through. Locked zones are separate nav islands.

const ZoneWorld := preload("res://tests/world/zone_test_world.gd")
const World := preload("res://tests/enemies/enemy_test_world.gd")
const NAV_SYNC_FRAMES := 8

var _world: Node3D
var _door: Door
var _start: Zone
var _annex: Zone
var _point: EnemySpawnPoint
var _player: Player
var _opened: Array[Array] = []
var _unlocked: Array[StringName] = []


func before_test() -> void:
	_opened.clear()
	_unlocked.clear()
	Events.door_opened.connect(_on_door_opened)
	Events.zone_unlocked.connect(_on_zone_unlocked)
	_world = auto_free(ZoneWorld.build())
	add_child(_world)
	_door = _world.get_node("Door_annex_gate")
	_start = _world.get_node("Zone_start")
	_annex = _world.get_node("Zone_annex")
	_point = _annex.get_node("AnnexSpawn")
	# Player in room A, 1.6 m from the door, looking at it (-Z).
	_player = World.player(_world, Vector3(0, 0, 1.6))
	_player.set_physics_process(false)
	for i in NAV_SYNC_FRAMES:
		await get_tree().physics_frame


func after_test() -> void:
	Events.door_opened.disconnect(_on_door_opened)
	Events.zone_unlocked.disconnect(_on_zone_unlocked)


func _on_door_opened(door_id: StringName, peer_id: int) -> void:
	_opened.append([door_id, peer_id])


func _on_zone_unlocked(zone_id: StringName) -> void:
	_unlocked.append(zone_id)


func _map() -> RID:
	return (_world.get_node("NavRegion") as RuntimeNavRegion).get_navigation_map()


## True if a nav path from room A reaches deep into room B.
func _path_into_annex() -> bool:
	var path := NavigationServer3D.map_get_path(_map(), Vector3(0, 0, 6), Vector3(0, 0, -6), true)
	return not path.is_empty() and path[path.size() - 1].z < -5.0


func test_starts_locked_with_inactive_spawns_and_no_path() -> void:
	assert_bool(_start.unlocked).is_true()
	assert_bool(_annex.unlocked).is_false()
	assert_bool(_point.is_active()).is_false()
	assert_bool(_door.is_open).is_false()
	assert_bool(_door.link.enabled).is_false()
	assert_bool(_path_into_annex()).is_false()


func test_buying_the_door_unlocks_zone_and_spawns() -> void:
	_player.points.reset(1000)
	assert_object(_player.get_interact_target()).is_same(_door.interactable)
	assert_str(_door.interactable.get_prompt_text()).is_equal("E: Open Annex Gate [750]")
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(250)
	assert_bool(_door.is_open).is_true()
	assert_bool(_door.link.enabled).is_true()
	assert_bool(_annex.unlocked).is_true()
	assert_bool(_point.is_active()).is_true()
	assert_array(_opened).contains_exactly([[&"annex_gate", _player.health.peer_id]])
	assert_array(_unlocked).contains_exactly([&"annex"])
	await get_tree().physics_frame
	assert_int(_door.collision_layer).is_equal(0)
	assert_object(_player.get_interact_target()).is_null()


func test_door_cost_multiplier_applies() -> void:
	var settings := Settings.match_settings
	var saved := settings.door_cost_mult
	settings.door_cost_mult = 1.5
	_door.refresh()
	assert_int(_door.price()).is_equal(1130)
	_player.points.reset(1200)
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(70)
	settings.door_cost_mult = saved


func test_not_enough_points_changes_nothing() -> void:
	_player.points.reset(500)
	var denied: Array[StringName] = []
	_player.interact_denied.connect(func(reason: StringName) -> void: denied.append(reason))
	assert_bool(_door.interactable.can_use(_player)).is_false()
	assert_bool(_player.try_interact()).is_false()
	assert_array(denied).contains_exactly([&"points"])
	assert_int(_player.points.balance).is_equal(500)
	assert_bool(_door.is_open).is_false()
	assert_bool(_annex.unlocked).is_false()
	assert_array(_opened).is_empty()


func test_opening_is_idempotent() -> void:
	_player.points.reset(2000)
	assert_bool(_player.try_interact()).is_true()
	assert_bool(_door.open(1)).is_false()
	assert_bool(_door.interactable.enabled).is_false()
	_door._on_used(_player)  # a stale use after opening
	assert_int(_player.points.balance).is_equal(1250)
	assert_int(_opened.size()).is_equal(1)
	assert_int(_unlocked.size()).is_equal(1)


func test_open_door_connects_nav_and_cultists_come_through() -> void:
	_player.health.invulnerable = true
	assert_bool(_door.open(1)).is_true()
	for i in NAV_SYNC_FRAMES:
		await get_tree().physics_frame
	assert_bool(_path_into_annex()).is_true()
	var acolyte := World.acolyte(_world, Vector3(0, 0.05, -8.5))
	var crossed := false
	for i in 420:
		await get_tree().physics_frame
		if acolyte.global_position.z > 0.5:
			crossed = true
			break
	assert_bool(crossed).is_true()


func test_second_door_into_unlocked_zone_stays_closed() -> void:
	var postern: Door = ZoneWorld.door(&"annex_postern", Vector3(10, 0, 10))
	_world.add_child(postern)
	assert_bool(_door.open(1)).is_true()
	assert_bool(_annex.unlocked).is_true()
	assert_bool(postern.is_open).is_false()
	assert_bool(postern.interactable.enabled).is_true()
	assert_int(postern.interactable.cost).is_equal(250)
	assert_bool(postern.open(1)).is_true()
	assert_array(_unlocked).contains_exactly([&"annex"])  # unlocked only once


func test_zone_helpers() -> void:
	assert_object(Zone.find(get_tree(), &"annex")).is_same(_annex)
	assert_object(Zone.find(get_tree(), &"nowhere")).is_null()
	assert_object(Zone.of(_point)).is_same(_annex)
	assert_bool(_annex.contains(Vector3(0, 1, -7))).is_true()
	assert_bool(_annex.contains(Vector3(0, 1, 7))).is_false()
	assert_bool(_start.contains(Vector3(3, 0.5, 7))).is_true()
	assert_int(_annex.spawn_points().size()).is_equal(1)
	assert_bool(_annex.unlock()).is_true()
	assert_bool(_annex.unlock()).is_false()


func test_registry_spawns_only_at_active_points() -> void:
	var registry := EnemyRegistry.new()
	_world.add_child(registry)
	var data := World.acolyte_data()
	assert_int(registry.spawn_many(data, 2).size()).is_equal(0)
	_annex.unlock()
	var spawned := registry.spawn_many(data, 2)
	assert_int(spawned.size()).is_equal(2)
	for enemy in spawned:
		assert_bool(_annex.contains(enemy.global_position + Vector3.UP)).is_true()
