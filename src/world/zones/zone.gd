class_name Zone
extends Area3D
## A map area unlocked by buying a door into it (DESIGN §11, docs/adr/0010-doors-zones.md).
## Its child EnemySpawnPoints are only active while it is unlocked. The volume (box shapes) is
## used by contains(), e.g. for the F019 director's "zones near players".

## Emitted once, when the zone becomes unlocked.
signal unlocked_changed(is_unlocked: bool)

const GROUP := &"zones"

@export var zone_id: StringName
## The start zone(s) of a map.
@export var starts_unlocked: bool = false

var unlocked: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"debug_info")
	collision_layer = 0
	collision_mask = 0
	monitoring = false
	monitorable = false
	unlocked = starts_unlocked
	if zone_id == &"":
		push_warning("Zone '%s' has no zone_id." % get_path())


## The zone with [param id] in [param tree], or null.
static func find(tree: SceneTree, id: StringName) -> Zone:
	for node in tree.get_nodes_in_group(GROUP):
		var zone := node as Zone
		if zone != null and zone.zone_id == id:
			return zone
	return null


## The innermost Zone ancestor of [param node], or null.
static func of(node: Node) -> Zone:
	var parent := node.get_parent()
	while parent != null:
		if parent is Zone:
			return parent as Zone
		parent = parent.get_parent()
	return null


## Unlocks the zone (authority). Returns true only the first time.
func unlock() -> bool:
	if unlocked or not Net.is_authority():
		return false
	unlocked = true
	unlocked_changed.emit(true)
	Events.zone_unlocked.emit(zone_id)
	return true


## True if [param point] (global) is inside one of this zone's box shapes.
func contains(point: Vector3) -> bool:
	for child in get_children():
		var shape_node := child as CollisionShape3D
		if shape_node == null or not shape_node.shape is BoxShape3D:
			continue
		var box := shape_node.shape as BoxShape3D
		var local := shape_node.global_transform.affine_inverse() * point
		if AABB(-box.size * 0.5, box.size).has_point(local):
			return true
	return false


func spawn_points() -> Array[EnemySpawnPoint]:
	var result: Array[EnemySpawnPoint] = []
	for node in find_children("*", "EnemySpawnPoint", true, false):
		result.append(node as EnemySpawnPoint)
	return result


func get_debug_info() -> Dictionary:
	return {
		"zone":
		(
			"%s: %s (%d spawns)"
			% [zone_id, "unlocked" if unlocked else "locked", spawn_points().size()]
		),
	}
