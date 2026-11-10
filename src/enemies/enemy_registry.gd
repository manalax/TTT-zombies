class_name EnemyRegistry
extends Node3D
## Container for live enemies in a map, with spawn/clear helpers and AI cost stats (F3 overlay).
## The F019 director will spawn into it.

const GROUP := &"enemy_registry"

var _spawn_counts: Dictionary[int, int] = {}


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(&"debug_info")


func get_enemies() -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	for child in get_children():
		var enemy := child as EnemyBase
		if enemy != null and not enemy.is_queued_for_deletion():
			result.append(enemy)
	return result


func alive_count() -> int:
	var count := 0
	for enemy in get_enemies():
		if not enemy.is_dead():
			count += 1
	return count


## Spawns one [param data] at [param point], spread on the point's rings so repeated spawns do
## not stack (the director's spawn path).
func spawn_one(data: EnemyData, point: EnemySpawnPoint) -> EnemyBase:
	if point == null:
		return null
	var index := _spawn_counts.get(point.get_instance_id(), 0) as int
	_spawn_counts[point.get_instance_id()] = index + 1
	return point.spawn(data, self, index % 13)


## Spawns [param count] of [param data] round-robin over the map's active spawn points
## (points in locked zones are skipped).
func spawn_many(data: EnemyData, count: int) -> Array[EnemyBase]:
	var spawned: Array[EnemyBase] = []
	var points := active_spawn_points()
	if points.is_empty():
		push_warning("EnemyRegistry: no active EnemySpawnPoint in the map.")
		return spawned
	var base := get_child_count()
	for i in count:
		var n := base + i
		var enemy := points[n % points.size()].spawn(data, self, n / points.size())
		if enemy != null:
			spawned.append(enemy)
	return spawned


func active_spawn_points() -> Array[EnemySpawnPoint]:
	var points: Array[EnemySpawnPoint] = []
	for node in get_tree().get_nodes_in_group(EnemySpawnPoint.GROUP):
		var point := node as EnemySpawnPoint
		if point.is_active():
			points.append(point)
	return points


## Removes every enemy immediately. Returns how many were removed.
func clear() -> int:
	var enemies := get_enemies()
	for enemy in enemies:
		enemy.queue_free()
	return enemies.size()


func get_debug_info() -> Dictionary:
	return {
		"alive": "%d (%d bodies)" % [alive_count(), get_enemies().size()],
		"ai ms/tick": "%.2f (peak %.2f)" % [AIStats.smoothed_ms, AIStats.peak_ms],
		"physics ms": "%.2f" % (Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
	}
