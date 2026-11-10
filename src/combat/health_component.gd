class_name HealthComponent
extends Node
## Health of one combatant (player, enemy, dummy). Only Combat.apply() should damage it.
## Its parent (a Node3D) is the combatant's body: position and facing come from there.

signal health_changed(current: float, maximum: float)
signal damaged(result: DamageResult)
## Emitted once per life.
signal died(result: DamageResult)
## Parried: the owner is stunned (no attacking/blocking) and open to the parrier's riposte.
signal stunned(duration_s: float)

const TIMER_EPSILON := 0.000001

@export var faction: CombatTypes.Faction = CombatTypes.Faction.CULT
@export_range(1, 100000, 1) var max_health: float = 100.0
## Flat damage reduction, 0..0.95 (EnemyData.armor). Players have none in F011.
@export_range(0.0, 0.95, 0.01) var armor: float = 0.0
@export var invulnerable: bool = false

## Multiplayer peer id of a player combatant (0 = AI / world object).
var peer_id: int = 0
## Replicated enemy/object id (F023). 0 = none.
var net_id: int = 0
var current_health: float = 100.0
## Null = this combatant cannot block.
var block: BlockState
## Null = this combatant cannot be staggered by hits.
var poise: PoiseComponent
## Who parried this combatant; their next melee hit during the stun is a riposte.
var riposte_by: HealthComponent

var _stun_left: float = 0.0
var _iframes_left: float = 0.0

var _dead: bool = false


func _ready() -> void:
	current_health = max_health


## Sets a new maximum and refills (spawn-time scaling such as player_health_mult).
func setup(p_max_health: float) -> void:
	max_health = p_max_health
	reset()


## Changes the maximum; current health moves by the same amount (clamped to 1..max while
## alive). Used by perks such as Iron Constitution.
func set_max(value: float) -> void:
	var diff := value - max_health
	max_health = maxf(value, 1.0)
	if not _dead:
		current_health = clampf(current_health + diff, 1.0, max_health)
	health_changed.emit(current_health, max_health)


func reset() -> void:
	_dead = false
	_stun_left = 0.0
	_iframes_left = 0.0
	riposte_by = null
	current_health = max_health
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return _dead


## Advances stun and i-frame timers. The owner calls this once per physics step.
func tick(delta: float) -> void:
	if _iframes_left > 0.0:
		_iframes_left = _count_down(_iframes_left, delta)
	if _stun_left > 0.0:
		_stun_left = _count_down(_stun_left, delta)
		if _stun_left == 0.0:
			riposte_by = null


## Snaps float residue to 0 so a 0.2 s timer ends after exactly 12 ticks at 60 Hz.
static func _count_down(value: float, delta: float) -> float:
	value -= delta
	return 0.0 if value < TIMER_EPSILON else value


func stun(duration: float, by: HealthComponent) -> void:
	if _dead or duration <= 0.0:
		return
	_stun_left = duration
	riposte_by = by
	stunned.emit(duration)


func is_stunned() -> bool:
	return _stun_left > 0.0


func get_stun_left() -> float:
	return _stun_left


func clear_riposte() -> void:
	riposte_by = null


## Dodge invulnerability against attacks (CombatTypes.DODGEABLE) for [param seconds].
func grant_iframes(seconds: float) -> void:
	_iframes_left = maxf(_iframes_left, seconds)


func has_iframes() -> bool:
	return _iframes_left > 0.0


func get_iframes_left() -> float:
	return _iframes_left


func get_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	current_health = minf(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)


## Applies an accepted pipeline result. Called by Combat.apply().
func apply_result(result: DamageResult) -> void:
	if _dead or not result.accepted:
		return
	current_health = maxf(0.0, current_health - result.applied)
	health_changed.emit(current_health, max_health)
	damaged.emit(result)
	if result.killed or current_health <= 0.0:
		_dead = true
		died.emit(result)


func get_body() -> Node3D:
	return get_parent() as Node3D


func get_world_position() -> Vector3:
	var body := get_body()
	return body.global_position if body != null and body.is_inside_tree() else Vector3.ZERO


## Horizontal facing of the combatant (-Z of its body).
func forward() -> Vector3:
	var body := get_body()
	if body == null or not body.is_inside_tree():
		return Vector3.FORWARD
	var f := -body.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.0 else Vector3.FORWARD
