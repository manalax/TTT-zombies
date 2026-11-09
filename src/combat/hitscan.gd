class_name Hitscan
extends RefCounted
## Instant ray attacks: the first hurtbox along a ray, stopping at world geometry.
## Used by the F7 debug shot now and by firearms (F014).


## Result of a penetrating cast: the combatants hit in order, and where the ray stopped.
class Through:
	var hits: Array[Hit] = []
	var end: Vector3
	## The ray stopped on world geometry (rather than running out of range or penetration).
	var blocked: bool = false


class Hit:
	## Null when the ray hit world geometry (or nothing).
	var hurtbox: Hurtbox
	var collider: Object
	var position: Vector3
	var normal: Vector3


## Returns null if nothing was hit. [param exclude] holds RIDs to ignore (the shooter's own
## body and hurtboxes).
static func cast(
	space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID] = []
) -> Hit:
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.ATTACK_MASK, exclude)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit_data := space.intersect_ray(query)
	if hit_data.is_empty():
		return null
	var hit := Hit.new()
	hit.collider = hit_data["collider"]
	hit.position = hit_data["position"]
	hit.normal = hit_data["normal"]
	hit.hurtbox = hit.collider as Hurtbox
	return hit


## RIDs of [param root]'s hurtboxes and physics bodies, for excluding a shooter from its own ray.
static func collect_rids(root: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if root is CollisionObject3D:
		rids.append((root as CollisionObject3D).get_rid())
	for node in root.find_children("*", "CollisionObject3D", true, false):
		rids.append((node as CollisionObject3D).get_rid())
	return rids


## Like [method cast], but continues through up to [param max_hits] combatants (each hit once,
## by its first hurtbox along the ray). World geometry always stops it.
static func cast_through(
	space: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	exclude: Array[RID] = [],
	max_hits: int = 1
) -> Through:
	var result := Through.new()
	result.end = to
	var skip: Array[RID] = exclude.duplicate()
	while result.hits.size() < max_hits:
		var hit := cast(space, from, to, skip)
		if hit == null:
			result.end = to
			break
		result.end = hit.position
		if hit.hurtbox == null or hit.hurtbox.health == null:
			result.blocked = true
			break
		result.hits.append(hit)
		var body := hit.hurtbox.health.get_body()
		if body != null:
			skip.append_array(collect_rids(body))
		else:
			skip.append(hit.hurtbox.get_rid())
	return result
