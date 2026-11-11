extends GdUnitTestSuite
## F015: RuntimeNavRegion bakes from static colliders at load.

const World := preload("res://tests/enemies/enemy_test_world.gd")
const ARENA := preload("res://maps/dev/sandbox_arena/sandbox_arena.tscn")


func test_bakes_on_ready_around_obstacles() -> void:
	var boxes: Array[AABB] = [AABB(Vector3(-4, 0, -6.5), Vector3(8, 3, 1))]
	var world: Node3D = auto_free(World.world(30.0, boxes))
	add_child(world)
	var nav: RuntimeNavRegion = world.get_node("NavRegion")
	assert_bool(nav.is_baked()).is_false()  # deferred until CSG has built its meshes
	await get_tree().process_frame
	assert_bool(nav.is_baked()).is_true()
	assert_int(nav.polygon_count()).is_greater(0)
	for i in 6:
		await get_tree().physics_frame
	var path := NavigationServer3D.map_get_path(
		nav.get_navigation_map(), Vector3(0, 0, -12), Vector3.ZERO, true
	)
	assert_int(path.size()).is_greater(2)  # goes around the wall, not through it
	var widest := 0.0
	for point in path:
		widest = maxf(widest, absf(point.x))
	assert_float(widest).is_greater_equal(4.0)


func test_tall_box_is_not_walkable() -> void:
	var boxes: Array[AABB] = [AABB(Vector3(4, 0, -1), Vector3(2, 1.3, 2))]
	var world: Node3D = auto_free(World.world(20.0, boxes))
	add_child(world)
	var nav: RuntimeNavRegion = world.get_node("NavRegion")
	await get_tree().process_frame
	for vertex in nav.navigation_mesh.vertices:
		var on_top := absf(vertex.x - 5.0) < 0.5 and absf(vertex.z) < 0.5
		assert_bool(on_top).is_false()


func test_missing_source_does_not_bake() -> void:
	var nav: RuntimeNavRegion = auto_free(RuntimeNavRegion.new())
	nav.source = ^"Nowhere"
	nav.bake_on_ready = false
	add_child(nav)
	nav.bake_now()
	assert_bool(nav.is_baked()).is_false()
	assert_int(nav.polygon_count()).is_equal(0)


## The sandbox arena (CSG greybox): what acolytes can and cannot reach from the player spawn.
func test_arena_walkability() -> void:
	var arena: Node3D = auto_free(ARENA.instantiate())
	add_child(arena)
	for i in 8:
		await get_tree().physics_frame
	var map := (arena.get_node("NavRegion") as RuntimeNavRegion).get_navigation_map()
	var spawn := Vector3(0, 0, 8)
	assert_bool(_reachable(map, spawn, Vector3(-18, 2.0, -12.5))).is_true()  # 20° ramp top
	assert_bool(_reachable(map, spawn, Vector3(-14, 2.0, -10))).is_true()  # 40° ramp top
	assert_bool(_reachable(map, spawn, Vector3(-4, 2.0, -9.5))).is_true()  # stair landing
	assert_bool(_reachable(map, spawn, Vector3(-10, 2.0, -9.5))).is_false()  # 50°: too steep
	assert_bool(_reachable(map, spawn, Vector3(3, 0.5, -8))).is_false()  # 0.5 m box: jump only
	assert_bool(_reachable(map, spawn, Vector3(9, 1.3, -8))).is_false()  # 1.3 m box
	# Spawn closets (F046) are islands behind their boarded windows: enemies reach the window's
	# outer point, then the brain climbs them through.
	for point in get_tree().get_nodes_in_group(EnemySpawnPoint.GROUP):
		var spawn_point := point as EnemySpawnPoint
		var from := spawn_point.global_position
		assert_bool(_reachable(map, from, spawn)).is_false()
		var window := spawn_point.get_barricade()
		assert_bool(_reachable(map, from, window.outer_point())).is_true()
		assert_bool(_reachable(map, window.inner_point(), spawn)).is_equal(
			spawn_point.zone.zone_id != &"annex"
		)
	# The annex is a separate island until a door into it opens (via the door's link).
	var annex := Vector3(-40, 0, 0)
	assert_bool(_reachable(map, spawn, annex)).is_false()
	(arena.get_node("Doors/AnnexGate") as Door).open(1)
	for i in 8:
		await get_tree().physics_frame
	assert_bool(_reachable(map, spawn, annex)).is_true()


func _reachable(map: RID, from: Vector3, to: Vector3) -> bool:
	var goal := NavigationServer3D.map_get_closest_point(map, to)
	if goal.distance_to(to) > 0.6:
		return false
	var path := NavigationServer3D.map_get_path(map, from, goal, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(goal) < 0.3
