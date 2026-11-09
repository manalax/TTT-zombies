class_name Firearm
extends Node
## The player's active firearm (DESIGN §6.4, docs/adr/0007-firearms-loadout.md).
##
## Ticked by Player.step() when a firearm slot is active. Semi-auto: one shot per attack press,
## limited by fire_interval_s. Hitscan pellets inside a spread cone that blooms per shot and
## recovers (no view recoil). RMB aims (tighter spread, slower, FOV zoom, no sprint). The gun is
## lowered while sprinting and cannot fire. Ammo lives in the loadout slot's AmmoState.

signal shot_fired(results: Array[DamageResult], tracers: Array[Vector3])
signal dry_fired
signal reload_started
signal reload_finished

## Damage multiplier per combatant a round has already passed through.
const PENETRATION_DAMAGE_MULT := 0.6
const MAX_RANGE_M := 200.0

var weapon: WeaponData
var stats: FirearmStats
var ammo: AmmoState
## Extra spread from recent shots, in degrees.
var bloom: float = 0.0
var aiming: bool = false
## Seconds until the next shot is allowed.
var cooldown: float = 0.0
var attack_pressed: bool = false
var rng := RandomNumberGenerator.new()

var player: Player:
	get:
		return owner as Player

var _attack_was_held: bool = false
var _stagger_left: float = 0.0

@onready var machine: StateMachine = $FirearmMachine


func equip(data: WeaponData, ammo_state: AmmoState) -> void:
	weapon = data
	stats = data.firearm_stats
	ammo = ammo_state
	bloom = 0.0
	cooldown = 0.0
	aiming = false
	_attack_was_held = player.intent.attack_held if player != null else false
	if machine.is_running():
		machine.stop()
	machine.start()


## Holstered: stops the machine (cancels any reload) and ends aiming.
func holster() -> void:
	if machine.is_running():
		machine.stop()
	aiming = false


func is_active() -> bool:
	return machine.is_running()


func physics_tick(delta: float) -> void:
	if stats == null or not machine.is_running():
		return
	var intent := player.intent
	attack_pressed = intent.attack_held and not _attack_was_held
	_attack_was_held = intent.attack_held
	cooldown = maxf(0.0, cooldown - delta)
	bloom = maxf(0.0, bloom - stats.spread_recovery_deg_s * delta)
	_stagger_left = maxf(0.0, _stagger_left - delta)
	if player.is_dead() or _stagger_left > 0.0:
		aiming = false
		attack_pressed = false
		player.set_combat_modifiers(1.0, false)
		return
	aiming = intent.aim_held and machine.is_in_state(&"Ready")
	machine.physics_tick(delta)


## Parried or guard-broken while holding a gun: no firing or aiming for [param duration].
func notify_staggered(duration: float) -> void:
	_stagger_left = maxf(_stagger_left, duration)


func current_spread() -> float:
	if stats == null:
		return 0.0
	return (stats.spread_deg + bloom) * (stats.ads_spread_mult if aiming else 1.0)


func can_fire() -> bool:
	return cooldown <= 0.0 and ammo != null and ammo.mag > 0


## Fires one round (all pellets). Returns the damage results.
func fire() -> Array[DamageResult]:
	var results: Array[DamageResult] = []
	if not ammo.take_round():
		return results
	cooldown = stats.fire_interval_s
	var eye := player.get_eye_transform()
	var space := player.get_world_3d().direct_space_state
	var exclude := Hitscan.collect_rids(player)
	var spread := current_spread()
	var tracers: Array[Vector3] = []
	for pellet in stats.pellets:
		var dir := spread_direction(eye.basis, spread, rng)
		var through := Hitscan.cast_through(
			space, eye.origin, eye.origin + dir * MAX_RANGE_M, exclude, 1 + stats.penetration
		)
		for index in through.hits.size():
			var hit := through.hits[index]
			var distance := eye.origin.distance_to(hit.position)
			var amount := (
				stats.damage * falloff_mult(stats, distance) * pow(PENETRATION_DAMAGE_MULT, index)
			)
			var event := DamageEvent.from_source(
				player.health,
				hit.hurtbox.health,
				amount,
				CombatTypes.DamageType.BULLET,
				hit.hurtbox
			)
			event.weakpoint_mult = stats.weakpoint_mult
			event.weapon_id = weapon.id
			results.append(Combat.apply(event))
		tracers.append(eye.origin)
		tracers.append(through.end)
	bloom = minf(stats.max_bloom_deg, bloom + stats.spread_bloom_deg)
	shot_fired.emit(results, tracers)
	return results


## Damage multiplier at [param distance]: 1 until falloff_start_m, linear down to
## min_damage_mult at falloff_end_m, constant beyond.
static func falloff_mult(fs: FirearmStats, distance: float) -> float:
	if distance <= fs.falloff_start_m:
		return 1.0
	if distance >= fs.falloff_end_m or fs.falloff_end_m <= fs.falloff_start_m:
		return fs.min_damage_mult
	var t := (distance - fs.falloff_start_m) / (fs.falloff_end_m - fs.falloff_start_m)
	return lerpf(1.0, fs.min_damage_mult, t)


## A random direction within [param spread_deg] of the basis' forward (-Z), uniform over the
## cone's disc.
static func spread_direction(
	basis: Basis, spread_deg: float, random: RandomNumberGenerator
) -> Vector3:
	if spread_deg <= 0.0:
		return (basis * Vector3.FORWARD).normalized()
	var angle := deg_to_rad(spread_deg) * sqrt(random.randf())
	var around := random.randf() * TAU
	var local := Vector3(sin(angle) * cos(around), sin(angle) * sin(around), -cos(angle))
	return (basis * local).normalized()


func get_state_path() -> String:
	return machine.get_active_path() if machine.is_running() else "-"
