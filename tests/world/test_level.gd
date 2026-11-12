extends GdUnitTestSuite
## F057: the placeholder playable level behind "Play" has every level feature: 3 zones behind
## 2 buyable doors, 7 boarded windows with closet spawns, all wall-buys, ammo stations and perk
## altars; its match starts on load and ends back at the main menu.

const LEVEL := preload("res://maps/dev/test_level/test_level.tscn")
const MAIN_SCENE := preload("res://src/main/main.tscn")
const NAV_SYNC_FRAMES := 8

const EXPECTED_STATIONS := {
	&"start": ["weapon:revolver", "ammo", "perk:iron_constitution"],
	&"hall": ["weapon:rifle", "weapon:blunderbuss", "perk:second_wind", "perk:sure_grip"],
	&"vault": ["weapon:greatsword", "weapon:arming_sword", "ammo", "perk:riposte"],
}

var _level: Node3D
var _map: RID


func _build() -> void:
	_level = auto_free(LEVEL.instantiate())
	add_child(_level)
	for i in NAV_SYNC_FRAMES:
		await get_tree().physics_frame
	_map = (_level.get_node("NavRegion") as RuntimeNavRegion).get_navigation_map()


func _zone(id: StringName) -> Zone:
	return Zone.find(get_tree(), id)


func _registry() -> EnemyRegistry:
	return _level.get_node("Enemies") as EnemyRegistry


func _door(node_name: String) -> Door:
	return _level.get_node("Doors/%s" % node_name) as Door


func _reachable(from: Vector3, to: Vector3) -> bool:
	var goal := NavigationServer3D.map_get_closest_point(_map, to)
	if goal.distance_to(to) > 0.75:
		return false
	var path := NavigationServer3D.map_get_path(_map, from, goal, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(goal) < 0.3


func _open(node_name: String) -> void:
	assert_bool(_door(node_name).open(1)).is_true()
	for i in NAV_SYNC_FRAMES:
		await get_tree().physics_frame


func _station_key(station: ShopStation) -> String:
	if station is WallBuy:
		return "weapon:%s" % (station as WallBuy).weapon_id
	if station is PerkAltar:
		return "perk:%s" % (station as PerkAltar).perk_id
	return "ammo"


func test_zones_and_doors() -> void:
	await _build()
	assert_bool(_zone(&"start").unlocked).is_true()
	assert_bool(_zone(&"hall").unlocked).is_false()
	assert_bool(_zone(&"vault").unlocked).is_false()
	assert_int(_door("HallDoor").price()).is_equal(750)
	assert_str(_door("HallDoor").data.unlocks_zone_id).is_equal("hall")
	assert_int(_door("VaultDoor").price()).is_equal(1250)
	assert_str(_door("VaultDoor").data.unlocks_zone_id).is_equal("vault")


func test_every_window_has_one_closet_spawn() -> void:
	await _build()
	var windows := get_tree().get_nodes_in_group(Barricade.GROUP)
	assert_int(windows.size()).is_equal(7)
	var linked: Dictionary[Barricade, int] = {}
	for node in get_tree().get_nodes_in_group(EnemySpawnPoint.GROUP):
		var window := (node as EnemySpawnPoint).get_barricade()
		assert_object(window).is_not_null()
		linked[window] = linked.get(window, 0) + 1
	for window in windows:
		assert_int(linked.get(window, 0)).is_equal(1)


func test_stations_per_zone() -> void:
	await _build()
	var found := {&"start": [], &"hall": [], &"vault": []}
	for child in _level.get_node("Shop").get_children():
		var station := child as ShopStation
		for id: StringName in found:
			if _zone(id).contains(station.global_position + Vector3.UP):
				(found[id] as Array).append(_station_key(station))
	for id: StringName in EXPECTED_STATIONS:
		assert_array(found[id]).contains_exactly_in_any_order(EXPECTED_STATIONS[id])


func test_spawn_points_unlock_with_their_rooms() -> void:
	await _build()
	assert_int(_registry().active_spawn_points().size()).is_equal(3)
	await _open("HallDoor")
	assert_int(_registry().active_spawn_points().size()).is_equal(5)
	await _open("VaultDoor")
	assert_int(_registry().active_spawn_points().size()).is_equal(7)


func test_navigation_through_windows_and_doors() -> void:
	await _build()
	var spawn := (_level.get_node("PlayerSpawn") as Node3D).global_position
	for node in get_tree().get_nodes_in_group(EnemySpawnPoint.GROUP):
		var point := node as EnemySpawnPoint
		var window := point.get_barricade()
		assert_bool(_reachable(point.global_position, window.outer_point())).is_true()
		assert_bool(_reachable(point.global_position, spawn)).is_false()
	var hall := Vector3(24, 0, -4)
	var vault := Vector3(48, 0, -4)
	assert_bool(_reachable(spawn, hall)).is_false()
	await _open("HallDoor")
	assert_bool(_reachable(spawn, hall)).is_true()
	assert_bool(_reachable(spawn, vault)).is_false()
	await _open("VaultDoor")
	assert_bool(_reachable(spawn, vault)).is_true()
	# Every window's inside and every station are reachable once all doors are open.
	for window in get_tree().get_nodes_in_group(Barricade.GROUP):
		assert_bool(_reachable(spawn, (window as Barricade).inner_point())).is_true()
	for child in _level.get_node("Shop").get_children():
		var station := child as Node3D
		var front := station.global_position + station.global_basis.z * 1.0
		var back := station.global_position - station.global_basis.z * 1.0
		assert_bool(_reachable(spawn, front) or _reachable(spawn, back)).is_true()


func test_match_starts_on_load() -> void:
	await _build()
	var manager := _level.get_node("MatchManager") as MatchManager
	assert_bool(manager.auto_start).is_true()
	assert_str(manager.phase()).is_equal("Intermission")
	assert_int(manager.round_number).is_equal(0)


func test_run_ends_at_the_main_menu() -> void:
	var main: Node = auto_free(MAIN_SCENE.instantiate())
	add_child(main)
	await get_tree().process_frame
	Game.load_level(Game.PLAY_LEVEL)
	await get_tree().process_frame
	await get_tree().physics_frame
	var manager := get_tree().get_first_node_in_group(MatchManager.GROUP) as MatchManager
	var player := get_tree().get_first_node_in_group(Player.LOCAL_GROUP) as Player
	manager.set_physics_process(false)
	Combat.apply(DamageEvent.world(player.health, 10000.0, CombatTypes.DamageType.DEBUG))
	manager.step(0.1)
	assert_str(manager.phase()).is_equal("Results")
	manager.step(MatchManager.RESULTS_S + 0.1)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(main.get_node_or_null("MainMenu")).is_instanceof(MainMenu)
	assert_str(Game.current_level_path).is_equal("")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
