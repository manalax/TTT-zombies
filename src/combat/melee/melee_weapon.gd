class_name MeleeWeapon
extends Node
## The player's melee weapon (DESIGN §6.3, docs/adr/0005-melee.md).
##
## Ticked by Player.step() each physics step, before movement. Reads the intent's attack/block
## buttons, runs the weapon state machine, drives the BlockState and sets the player's combat
## movement modifiers. Attacks fire on release: full charge = heavy, otherwise light.

signal swing_started(spec: SwingSpec)
signal swing_hit(results: Array[DamageResult])
signal clanged(point: Vector3)
signal guard_broken
## This weapon's block parried an attack (local feedback).
signal parried

var weapon: WeaponData
var stats: MeleeStats
## The attack in progress (valid from Windup to the end of Recovery).
var swing: SwingSpec
var sweep: MeleeSweep = MeleeSweep.new()
## Side of the next light swing; flips after every light.
var next_side: SwingSpec.Sweep = SwingSpec.Sweep.LEFT_TO_RIGHT
## Seconds the attack button has been held in the current charge.
var charge_s: float = 0.0
## Edges of the attack button for this step.
var attack_pressed: bool = false
var attack_released: bool = false
## Block button went down this step (opens a parry window).
var block_pressed: bool = false
## Seconds since the last attack release (for the combo buffer). INF = none pending.
var since_release: float = INF

var player: Player:
	get:
		return owner as Player

var _attack_was_held: bool = false
var _block_was_held: bool = false

@onready var machine: StateMachine = $WeaponMachine


func equip(data: WeaponData) -> void:
	if data == null or data.melee_stats == null:
		push_error("MeleeWeapon: '%s' has no melee stats." % (data.id if data else &"null"))
		return
	weapon = data
	stats = data.melee_stats
	if player != null and player.health.block != null:
		player.health.block.configure(stats)
		player.health.block.active = false
	swing = null
	charge_s = 0.0
	since_release = INF
	next_side = SwingSpec.Sweep.LEFT_TO_RIGHT
	if machine.is_running():
		machine.stop()
	machine.start()


## Holstered: stops the state machine (exits Blocking/Charging/swings cleanly).
func holster() -> void:
	if machine.is_running():
		machine.stop()
	set_blocking(false)
	swing = null
	charge_s = 0.0
	_attack_was_held = false
	_block_was_held = false


func physics_tick(delta: float) -> void:
	if stats == null or not machine.is_running():
		return
	var intent := player.intent
	if player.is_dead():
		set_blocking(false)
		player.set_combat_modifiers(1.0, false)
		return
	attack_pressed = intent.attack_held and not _attack_was_held
	attack_released = not intent.attack_held and _attack_was_held
	_attack_was_held = intent.attack_held
	block_pressed = intent.block_held and not _block_was_held
	_block_was_held = intent.block_held
	if player.health.block != null:
		player.health.block.tick(delta)
	if attack_released:
		since_release = 0.0
	elif since_release < INF:
		since_release += delta
	machine.physics_tick(delta)


## Starts [param spec] if any stamina is left: pays its cost (may exhaust) and enters Windup.
func start_swing(spec: SwingSpec) -> bool:
	if player.stamina.current <= 0.0:
		return false
	player.stamina.drain(spec.stamina_cost)
	spec.riposte_mult *= player.perks.stat(&"riposte_mult")  # Riposte perk
	swing = spec
	since_release = INF
	if not spec.is_heavy():
		next_side = SwingSpec.next_side(spec.sweep)
	swing_started.emit(spec)
	return machine.transition_to(&"Windup")


func make_release_swing() -> SwingSpec:
	return SwingSpec.for_release(stats, charge_s, next_side, weapon.id)


func make_light_swing() -> SwingSpec:
	return SwingSpec.light(stats, next_side, weapon.id)


func set_blocking(value: bool) -> void:
	var block := player.health.block
	if block != null:
		block.active = value


func is_blocking() -> bool:
	var block := player.health.block
	return block != null and block.active


## Where swings come from: the player's eye, facing the look direction.
func eye_transform() -> Transform3D:
	return player.get_eye_transform()


func notify_guard_broken() -> void:
	set_blocking(false)
	machine.send_event(&"staggered", {"duration": player.defaults.guard_break_stagger_s})
	guard_broken.emit()


## Stunned (parried) or otherwise staggered for [param duration]: interrupts any swing.
func notify_staggered(duration: float) -> void:
	set_blocking(false)
	machine.send_event(&"staggered", {"duration": duration})


## Dodging is allowed unless a swing is about to hit or hitting (Windup/Active).
func allows_dodge() -> bool:
	return not (machine.is_in_state(&"Windup") or machine.is_in_state(&"Active"))


## A dodge cancels Blocking and Recovery.
func notify_dodged() -> void:
	if machine.is_in_state(&"Blocking") or machine.is_in_state(&"Recovery"):
		machine.transition_to(&"Idle")


func get_state_path() -> String:
	return machine.get_active_path()


func get_charge_ratio() -> float:
	if stats == null or stats.heavy_charge_s <= 0.0 or not machine.is_in_state(&"Charging"):
		return 0.0
	return clampf(charge_s / stats.heavy_charge_s, 0.0, 1.0)
