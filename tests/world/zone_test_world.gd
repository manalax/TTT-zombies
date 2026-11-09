extends RefCounted
## A two-room world for the F017 suites: room A (z > 0, zone "start", unlocked) and room B
## (z < 0, zone "annex", locked) split by a wall at z = 0 with one doorway holding a Door
## (annex_gate, 750). Room B has one EnemySpawnPoint. Built before entering the tree so the
## nav bake sees the closed door.

const World := preload("res://tests/enemies/enemy_test_world.gd")
const DOOR_SCENE := preload("res://src/world/zones/door.tscn")


static func build(door_id: StringName = &"annex_gate") -> Node3D:
	var walls: Array[AABB] = [
		AABB(Vector3(-15, 0, -0.25), Vector3(13.8, 3, 0.5)),
		AABB(Vector3(1.2, 0, -0.25), Vector3(13.8, 3, 0.5)),
	]
	var root := World.world(30.0, walls)
	root.add_child(zone(&"start", true, Vector3(0, 1.5, 7.5)))
	var annex := zone(&"annex", false, Vector3(0, 1.5, -7.5))
	var point := EnemySpawnPoint.new()
	point.name = "AnnexSpawn"
	point.position = Vector3(0, -1.45, -1.0)  # world (0, 0.05, -8.5)
	annex.add_child(point)
	root.add_child(annex)
	root.add_child(door(door_id, Vector3.ZERO))
	return root


static func zone(id: StringName, unlocked: bool, center: Vector3) -> Zone:
	var area := Zone.new()
	area.name = "Zone_%s" % id
	area.zone_id = id
	area.starts_unlocked = unlocked
	area.position = center
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 3, 15)
	shape.shape = box
	area.add_child(shape)
	return area


static func door(door_id: StringName, at: Vector3) -> Door:
	var node: Door = DOOR_SCENE.instantiate()
	node.name = "Door_%s" % door_id
	node.door_id = door_id
	node.position = at
	return node
