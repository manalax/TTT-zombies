# gdlint:disable=max-public-methods
class_name EnemyBase
extends CharacterBody3D
## AI-controlled cultist body (DESIGN §7.1, docs/adr/0008-enemy-ai.md). Common types are an
## EnemyData plus this scene; specials will extend it.
##
## Each physics step ([method step]): tick health and poise, re-pick the target and repath on
## staggered timers, tick the brain (which sets the move mode), then move. The brain and damage
## only run on the authority. Movement and attack timing tick every step, so parry windows stay
## exact; only targeting and path queries are throttled.

signal attack_hit(results: Array[DamageResult])
signal telegraph_changed(on: bool)

enum MoveMode { STOP, CHASE, WALK, DIRECT }

## Group of all live enemies (debug tools, director).
const GROUP := &"enemies"
const TARGET_INTERVAL_S := 1.0
const REPATH_INTERVAL_S := 0.3
## A new target must be this much closer than the current one to switch.
const TARGET_HYSTERESIS_M := 2.0
const CHASE_TURN_DEG_S := 540.0
## Turn rate while telegraphing: tracks a walking target but a late sidestep beats it.
const WINDUP_TURN_DEG_S := 120.0
const EYE_HEIGHT_M := 1.4
## Where the swing aims on the target, above its feet.
const TARGET_AIM_HEIGHT_M := 0.9
const MAX_SWING_PITCH_DEG := 40.0
## Widest swing arc while swiping through a boarded window (F046).
const WINDOW_ARC_DEG := 40.0
## Swipes through a window start this far past the blade reach (the target's body radius).
const WINDOW_REACH_SLACK_M := 0.3
## walk_to covers the last metres straight, past the end of the eroded navmesh.
const WALK_DIRECT_M := 1.5
const TELEGRAPH_COLOR := Color(1.0, 0.1, 0.05)
const UNPARRYABLE_COLOR := Color(0.6, 0.1, 1.0)

static var _next_net_id: int = 1

## ContentDB id used when [member data] was not set before entering the tree.
@export var enemy_id: StringName = &"acolyte"

var data: EnemyData
var net_id: int = 0
var target: Node3D
## The boarded window this enemy must get through first (spawned in its closet, F046);
## null once inside (or for enemies spawned inside).
var breach: Barricade
## Seconds until a new swing may start.
var cooldown_left: float = 0.0
## Basis of the current swing, locked at windup end.
var swing_basis: Basis = Basis.IDENTITY
var sweep: MeleeSweep = MeleeSweep.new()

var _aggro_target: Node3D
var _aggro_left: float = 0.0
var _target_timer: float = 0.0
var _repath_timer: float = 0.0
var _move_mode: MoveMode = MoveMode.STOP
var _direct_velocity: Vector3 = Vector3.ZERO
var _safe_velocity: Vector3 = Vector3.ZERO
var _corpse_left: float = -1.0
var _gravity: float = 9.8
var _self_rids: Array[RID] = []
var _head_material: StandardMaterial3D

@onready var health: HealthComponent = $HealthComponent
@onready var poise: PoiseComponent = $PoiseComponent
@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var brain: StateMachine = $Brain
@onready var visual: Node3D = $Visual
@onready var _head_mesh: MeshInstance3D = $Visual/Head
@onready var _arm: Node3D = $Visual/Arm


func _ready() -> void:
	if data == null:
		data = ContentDB.get_item(&"EnemyData", enemy_id) as EnemyData
	if data == null:
		push_error("EnemyBase: EnemyData '%s' not found; using defaults." % enemy_id)
		data = EnemyData.new()
	add_to_group(GROUP)
	net_id = _next_net_id
	_next_net_id += 1
	collision_layer = PhysicsLayers.ENEMIES
	collision_mask = PhysicsLayers.WORLD | PhysicsLayers.PLAYERS | PhysicsLayers.BARRIER
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	health.faction = CombatTypes.Faction.CULT
	health.armor = data.armor
	health.net_id = net_id
	health.setup(data.max_health)
	poise.stagger_resist = data.stagger_resist
	poise.stagger_duration_s = data.stagger_duration_s
	health.poise = poise
	agent.max_speed = data.move_speed
	agent.velocity_computed.connect(_on_velocity_computed)
	# Spread the throttled work over frames so a burst of spawns does not replan together.
	_target_timer = fmod(net_id * 0.137, TARGET_INTERVAL_S)
	_repath_timer = fmod(net_id * 0.071, REPATH_INTERVAL_S)
	_self_rids = Hitscan.collect_rids(self)
	_head_material = (_head_mesh.get_active_material(0) as StandardMaterial3D).duplicate()
	_head_mesh.material_override = _head_material
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.stunned.connect(_on_stunned)
	poise.staggered.connect(_on_staggered)
	brain.start()
	Events.enemy_spawned.emit(net_id, data.id)


func _physics_process(delta: float) -> void:
	step(delta)


## One simulation step. Public so tests can drive it deterministically.
func step(delta: float) -> void:
	if not Net.is_authority():
		return
	var started := Time.get_ticks_usec()
	health.tick(delta)
	poise.tick(delta)
	if health.is_dead():
		_corpse_left -= delta
		if _corpse_left <= 0.0:
			queue_free()
		AIStats.record(Time.get_ticks_usec() - started)
		return
	cooldown_left = maxf(0.0, cooldown_left - delta)
	_aggro_left = maxf(0.0, _aggro_left - delta)
	_target_timer -= delta
	if _target_timer <= 0.0:
		_target_timer += TARGET_INTERVAL_S
		update_target()
	_repath_timer -= delta
	if _repath_timer <= 0.0:
		_repath_timer += REPATH_INTERVAL_S
		if target != null and _move_mode == MoveMode.CHASE:
			agent.target_position = target.global_position
	brain.physics_tick(delta)
	_integrate(delta)
	AIStats.record(Time.get_ticks_usec() - started)


## Re-picks the target now: recent aggro first, else the nearest valid player.
func update_target() -> void:
	if _aggro_left > 0.0 and AITargeting.is_valid_target(_aggro_target):
		target = _aggro_target
		return
	var previous := target
	target = AITargeting.pick(
		global_position,
		AITargeting.candidates(get_tree()),
		target if AITargeting.is_valid_target(target) else null,
		TARGET_HYSTERESIS_M
	)
	if target != null and target != previous:
		agent.target_position = target.global_position


func has_target() -> bool:
	return AITargeting.is_valid_target(target)


# --- Movement (called by brain states every step) -------------------------------------------


## Walk the navigation path toward the target (with avoidance).
func chase(delta: float) -> void:
	if not has_target():
		stop()
		return
	if _move_mode != MoveMode.CHASE:
		_move_mode = MoveMode.CHASE
		agent.target_position = target.global_position
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		# No path yet (map syncing) or already there: head straight for the target.
		dir = target.global_position - global_position
		dir.y = 0.0
	var desired := dir.normalized() * data.move_speed if dir.length_squared() > 0.0 else Vector3()
	face(dir, CHASE_TURN_DEG_S, delta)
	if agent.avoidance_enabled:
		agent.velocity = desired
	else:
		_safe_velocity = desired


## Walk the navigation path to a fixed [param point] (with avoidance), e.g. a window's outer
## point. The last stretch (where the eroded navmesh ends) is walked straight, without
## avoidance. Returns true once within [param arrive_m] of it (horizontally); then it stops.
func walk_to(point: Vector3, delta: float, arrive_m: float = 0.3) -> bool:
	var offset := point - global_position
	offset.y = 0.0
	if offset.length() <= arrive_m:
		stop()
		return true
	if agent.target_position.distance_squared_to(point) > 0.01:
		agent.target_position = point
	if offset.length() <= WALK_DIRECT_M or agent.is_navigation_finished():
		face(offset, CHASE_TURN_DEG_S, delta)
		move_direct(offset.normalized() * minf(data.move_speed, offset.length() / delta))
		return false
	_move_mode = MoveMode.WALK
	var dir := agent.get_next_path_position() - global_position
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = offset
	var desired := dir.normalized() * data.move_speed
	face(dir, CHASE_TURN_DEG_S, delta)
	if agent.avoidance_enabled:
		agent.velocity = desired
	else:
		_safe_velocity = desired
	return false


func stop() -> void:
	_move_mode = MoveMode.STOP
	_direct_velocity = Vector3.ZERO


## Move with an exact horizontal velocity, ignoring avoidance (lunge).
func move_direct(horizontal_velocity: Vector3) -> void:
	_move_mode = MoveMode.DIRECT
	_direct_velocity = Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.z)


## Turns toward [param direction] (horizontal) by at most [param turn_deg_s] per second.
func face(direction: Vector3, turn_deg_s: float, delta: float) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		return
	var wanted := atan2(-direction.x, -direction.z)
	var diff := wrapf(wanted - rotation.y, -PI, PI)
	var max_step := deg_to_rad(turn_deg_s) * delta
	rotation.y = wrapf(rotation.y + clampf(diff, -max_step, max_step), -PI, PI)


func forward() -> Vector3:
	return -global_basis.z


func horizontal_distance_to(point: Vector3) -> float:
	var offset := point - global_position
	offset.y = 0.0
	return offset.length()


# --- Attack -----------------------------------------------------------------------------


## True while this enemy still has to get through its boarded window.
func is_breaching() -> bool:
	return breach != null and is_instance_valid(breach)


## Lunges are cancelled while swiping through a window (the dash would hit the boards).
func lunge_scale() -> float:
	return 0.0 if is_breaching() else 1.0


## True if a new swing may start now: target valid and in range, in sight, cooldown over.
## Through a window there is no lunge: the range is the blade's reach plus a body's width.
func can_start_attack() -> bool:
	if not has_target() or cooldown_left > 0.0 or not is_on_floor():
		return false
	var attack_range := data.attack_range_m
	if is_breaching():
		attack_range = data.attack_reach_m + WINDOW_REACH_SLACK_M
	if horizontal_distance_to(target.global_position) > attack_range:
		return false
	return _has_line_of_sight(target)


func _has_line_of_sight(body: Node3D) -> bool:
	var from := global_position + Vector3.UP * EYE_HEIGHT_M
	var to := body.global_position + Vector3.UP * TARGET_AIM_HEIGHT_M
	var query := PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD, _self_rids)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Locks the swing: facing (yaw from the body) and pitch toward the target's centre.
func lock_swing() -> void:
	var pitch := 0.0
	if has_target():
		var eye := global_position + Vector3.UP * EYE_HEIGHT_M
		var aim := target.global_position + Vector3.UP * TARGET_AIM_HEIGHT_M
		var flat := horizontal_distance_to(aim)
		var limit := deg_to_rad(MAX_SWING_PITCH_DEG)
		pitch = clampf(atan2(aim.y - eye.y, flat), -limit, limit)
	swing_basis = Basis.from_euler(Vector3(pitch, rotation.y, 0.0))


func eye_transform() -> Transform3D:
	return Transform3D(swing_basis, global_position + Vector3.UP * EYE_HEIGHT_M)


func build_swing() -> SwingSpec:
	var spec := SwingSpec.new()
	spec.kind = SwingSpec.Kind.LIGHT
	spec.sweep = SwingSpec.Sweep.RIGHT_TO_LEFT
	spec.damage = data.attack_damage
	spec.stagger = data.attack_stagger
	# Through a window frame the arc narrows so the swing doesn't clang off the jambs.
	spec.arc_deg = (
		minf(data.attack_arc_deg, WINDOW_ARC_DEG) if is_breaching() else data.attack_arc_deg
	)
	spec.reach_m = data.attack_reach_m
	spec.windup_s = data.attack_windup_s
	spec.active_s = data.attack_active_s
	spec.recovery_s = data.attack_recovery_s
	spec.weapon_id = data.id
	spec.unparryable = not data.parryable
	return spec


func begin_sweep() -> void:
	sweep.begin(build_swing(), health, _self_rids)


## Advances the active swing to progress [param t]. Returns true if it clanged on the world.
func advance_sweep(t: float) -> bool:
	var result := sweep.advance(get_world_3d().direct_space_state, eye_transform(), t)
	if not result.hits.is_empty():
		attack_hit.emit(result.hits)
	return result.clanged


func set_telegraph(on: bool) -> void:
	_head_material.emission_enabled = on
	_head_material.emission = TELEGRAPH_COLOR if data.parryable else UNPARRYABLE_COLOR
	_head_material.emission_energy_multiplier = 2.5
	telegraph_changed.emit(on)


func is_telegraphing() -> bool:
	return _head_material.emission_enabled


## Greybox poses: "idle", "raised" (telegraph), "swing" (0..1 progress), "flinch".
func set_pose(pose: StringName, t: float = 0.0) -> void:
	match pose:
		&"raised":
			_arm.rotation_degrees = Vector3(150.0, 0.0, 0.0)
			visual.rotation_degrees.x = 0.0
		&"swing":
			_arm.rotation_degrees = Vector3(90.0, lerpf(60.0, -60.0, t), 0.0)
			visual.rotation_degrees.x = -8.0
		&"flinch":
			_arm.rotation_degrees = Vector3(20.0, 0.0, 0.0)
			visual.rotation_degrees.x = 12.0
		_:
			_arm.rotation_degrees = Vector3.ZERO
			visual.rotation_degrees.x = 0.0


func get_state_path() -> String:
	return brain.get_active_path()


func is_dead() -> bool:
	return health.is_dead()


# --- Internals --------------------------------------------------------------------------


func _integrate(delta: float) -> void:
	var horizontal := Vector3.ZERO
	match _move_mode:
		MoveMode.CHASE, MoveMode.WALK:
			horizontal = _safe_velocity
		MoveMode.DIRECT:
			horizontal = _direct_velocity
	if _move_mode != MoveMode.CHASE and _move_mode != MoveMode.WALK and agent.avoidance_enabled:
		# Report the real velocity so neighbours do not predict a stopped agent still walking.
		agent.velocity = horizontal
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
	else:
		velocity.y -= _gravity * delta
	move_and_slide()


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	_safe_velocity = Vector3(safe_velocity.x, 0.0, safe_velocity.z)


func _on_damaged(result: DamageResult) -> void:
	var source := result.event.source
	if source == null or health.is_dead():
		return
	var body := source.get_body()
	if AITargeting.is_valid_target(body):
		_aggro_target = body
		_aggro_left = data.aggro_memory_s
		if body != target:
			target = body
			agent.target_position = body.global_position


func _on_staggered(duration: float) -> void:
	if not health.is_dead():
		brain.send_event(&"staggered", {"duration": duration})


func _on_stunned(duration: float) -> void:
	if not health.is_dead():
		brain.send_event(&"stunned", {"duration": duration})


func _on_died(result: DamageResult) -> void:
	_corpse_left = data.corpse_s
	if is_breaching():
		breach.release(self)
	stop()
	velocity = Vector3.ZERO
	agent.avoidance_enabled = false
	# Deferred: death can happen inside a physics query (a sweep or hitscan).
	set_deferred(&"collision_layer", 0)
	for hurtbox in find_children("*", "Hurtbox", true, false):
		hurtbox.set_deferred(&"collision_layer", 0)
	set_telegraph(false)
	brain.transition_to(&"Dead")
	Events.enemy_killed.emit(net_id, result.event.source_peer_id)
	if is_inside_tree():
		var tween := create_tween()
		tween.tween_property(visual, ^"rotation_degrees:x", -90.0, 0.35)
		tween.parallel().tween_property(visual, ^"position:y", 0.25, 0.35)
