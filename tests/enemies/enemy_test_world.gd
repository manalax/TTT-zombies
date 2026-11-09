extends RefCounted
## Builders shared by the F015 enemy suites: a floor with a baked nav region, a player driven by
## scripted input, and acolytes.

const PLAYER_SCENE := preload("res://src/player/player.tscn")
const ACOLYTE_SCENE := preload("res://src/enemies/acolyte/acolyte.tscn")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")


## A Node3D with a floor of [param size] metres and the given extra boxes (Transform3D origin,
## size) under a "Geometry" node, plus a RuntimeNavRegion baked from it. Not yet in the tree.
static func world(size: float, boxes: Array[AABB] = []) -> Node3D:
	var root := Node3D.new()
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	geometry.add_child(_box(AABB(Vector3(-size * 0.5, -1.0, -size * 0.5), Vector3(size, 1, size))))
	for aabb in boxes:
		geometry.add_child(_box(aabb))
	var nav := RuntimeNavRegion.new()
	nav.name = "NavRegion"
	nav.source = ^"../Geometry"
	root.add_child(nav)
	return root


static func _box(aabb: AABB) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = PhysicsLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = aabb.size
	shape.shape = box
	body.position = aabb.get_center()
	body.add_child(shape)
	return body


## A player at [param at] with a scripted input source (returned via the "input" meta).
static func player(parent: Node, at: Vector3) -> Player:
	var p: Player = PLAYER_SCENE.instantiate()
	p.get_node("LocalInputSource").free()
	var input := ScriptedInputSource.new()
	p.add_child(input)
	p.position = at
	p.set_meta(&"input", input)
	parent.add_child(p)
	return p


## An acolyte at [param at] facing [param yaw]. [param data] overrides the shipped acolyte.
static func acolyte(
	parent: Node, at: Vector3, yaw: float = 0.0, data: EnemyData = null
) -> EnemyBase:
	var enemy: EnemyBase = ACOLYTE_SCENE.instantiate()
	if data != null:
		enemy.data = data
	enemy.position = at
	enemy.rotation.y = yaw
	parent.add_child(enemy)
	return enemy


## A copy of the shipped acolyte data, for tests that tune it.
static func acolyte_data() -> EnemyData:
	var shipped := ContentDB.get_item(&"EnemyData", &"acolyte") as EnemyData
	return shipped.duplicate() as EnemyData
