class_name MeleeSweep
extends RefCounted
## Swept-arc melee hit detection (docs/adr/0005-melee.md). Shared by players and AI/dummies.
##
## Call [method begin] when the active window opens, then [method advance] each physics tick
## with the attacker's eye transform and the new sweep progress (0..1). The arc travelled since
## the last call is sampled every <= MAX_STEP_DEG degrees. Each sample casts the blade (a thin
## capsule from the eye to the tip) against hurtboxes, clipped by a world ray: hitting world
## geometry "clangs" and ends the swing. Every combatant is hit at most once per swing.

const MAX_STEP_DEG := 4.0
const BLADE_RADIUS := 0.1
const MAX_OVERLAPS := 32


class Segment:
	var from: Vector3
	var to: Vector3
	var hit: bool = false
	var clang: bool = false


class Step:
	var hits: Array[DamageResult] = []
	var clanged: bool = false
	var clang_point: Vector3
	var segments: Array[Segment] = []


var spec: SwingSpec
var attacker: HealthComponent
var progress: float = 0.0
var clanged: bool = false

var _exclude: Array[RID] = []
var _hit: Dictionary[int, bool] = {}
var _started: bool = false
var _blade := CapsuleShape3D.new()


func begin(p_spec: SwingSpec, p_attacker: HealthComponent, exclude: Array[RID]) -> void:
	spec = p_spec
	attacker = p_attacker
	_exclude = exclude
	_hit.clear()
	progress = 0.0
	clanged = false
	_started = false
	_blade.radius = BLADE_RADIUS


func hit_count() -> int:
	return _hit.size()


func advance(space: PhysicsDirectSpaceState3D, eye: Transform3D, to_t: float) -> Step:
	var step := Step.new()
	if clanged or spec == null:
		return step
	to_t = clampf(to_t, 0.0, 1.0)
	var from_t := progress
	var samples: Array[float] = []
	if not _started:
		samples.append(from_t)
		_started = true
	var span_deg := (to_t - from_t) * spec.arc_deg
	var count := maxi(0, ceili(span_deg / MAX_STEP_DEG))
	if count == 0 and to_t > from_t:
		count = 1
	for i in range(1, count + 1):
		samples.append(lerpf(from_t, to_t, float(i) / count))
	progress = to_t
	for t in samples:
		_sample(space, eye, t, step)
		if step.clanged:
			clanged = true
			break
	MeleeDebugDraw.submit(step)
	return step


func _sample(space: PhysicsDirectSpaceState3D, eye: Transform3D, t: float, step: Step) -> void:
	var dir := (eye.basis * spec.direction_at(t)).normalized()
	var origin := eye.origin
	var tip := origin + dir * spec.reach_m
	var ray := PhysicsRayQueryParameters3D.create(origin, tip, PhysicsLayers.WORLD, _exclude)
	var wall := space.intersect_ray(ray)
	var segment := Segment.new()
	segment.from = origin
	if not wall.is_empty():
		tip = wall["position"]
		step.clanged = true
		step.clang_point = tip
		segment.clang = true
	segment.to = tip
	step.segments.append(segment)
	for hurtbox in _overlaps(space, origin, tip):
		var health := hurtbox.health
		_hit[health.get_instance_id()] = true
		segment.hit = true
		var event := DamageEvent.from_source(
			attacker, health, spec.damage, CombatTypes.DamageType.MELEE, hurtbox
		)
		event.weakpoint_mult = spec.weakpoint_mult
		event.stagger = spec.stagger
		event.weapon_id = spec.weapon_id
		event.riposte_mult = spec.riposte_mult
		event.unparryable = spec.unparryable
		step.hits.append(Combat.apply(event))


## New combatants touched by the blade from [param from] to [param to]: one hurtbox each,
## preferring a weak point.
func _overlaps(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Array[Hurtbox]:
	var length := from.distance_to(to)
	if length < 0.01:
		return []
	_blade.height = maxf(length, BLADE_RADIUS * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _blade
	var axis := (to - from) / length
	query.transform = Transform3D(Basis(Quaternion(Vector3.UP, axis)), (from + to) * 0.5)
	query.collision_mask = PhysicsLayers.HURTBOXES
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = _exclude
	var best: Dictionary[int, Hurtbox] = {}
	for overlap in space.intersect_shape(query, MAX_OVERLAPS):
		var hurtbox := overlap["collider"] as Hurtbox
		if hurtbox == null or hurtbox.health == null or hurtbox.health == attacker:
			continue
		var key := hurtbox.health.get_instance_id()
		if _hit.has(key):
			continue
		if not best.has(key) or (hurtbox.is_weakpoint and not best[key].is_weakpoint):
			best[key] = hurtbox
	var result: Array[Hurtbox] = []
	result.assign(best.values())
	return result
