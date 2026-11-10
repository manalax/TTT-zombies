class_name AITargeting
extends RefCounted
## Who cultist AI may attack, and which one it picks (docs/adr/0008-enemy-ai.md).
## Every AI target decision goes through here so F031 can exclude hidden traitors in one place.

## Group joined by every body AI may consider (players now; decoys later).
const GROUP := &"ai_targets"


## A living Hunter. F031: hidden traitors (and DESIGN Q1: all traitors) return false here.
static func is_valid_target(body: Node3D) -> bool:
	if body == null or not is_instance_valid(body) or not body.is_inside_tree():
		return false
	var health := body.get_node_or_null(^"HealthComponent") as HealthComponent
	if health == null or health.is_dead():
		return false
	return health.faction == CombatTypes.Faction.HUNTER


## The nearest valid candidate to [param from]. The [param current] target is kept unless
## another one is at least [param hysteresis_m] closer, so the choice does not flip-flop.
static func pick(
	from: Vector3, candidates: Array[Node3D], current: Node3D, hysteresis_m: float
) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for candidate in candidates:
		if not is_valid_target(candidate):
			continue
		var dist := from.distance_to(candidate.global_position)
		if dist < best_dist:
			best = candidate
			best_dist = dist
	if best == null or best == current or not is_valid_target(current):
		return best
	var current_dist := from.distance_to(current.global_position)
	return best if best_dist + hysteresis_m <= current_dist else current


## Every body in [constant GROUP] in [param tree].
static func candidates(tree: SceneTree) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in tree.get_nodes_in_group(GROUP):
		if node is Node3D:
			result.append(node as Node3D)
	return result
