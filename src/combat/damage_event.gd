class_name DamageEvent
extends RefCounted
## One attempt to damage one target. Built by weapons/AI/hazards and handed to Combat.apply().

## Attacker's health component; null for world damage (falls, hazards, debug).
var source: HealthComponent
var source_faction: CombatTypes.Faction = CombatTypes.Faction.WORLD
## Attacker's peer id (players only; 0 = world / AI).
var source_peer_id: int = 0
var target: HealthComponent
## The hurtbox that was hit, if any (zone multiplier, weak point).
var hurtbox: Hurtbox
var amount: float = 0.0
var type: CombatTypes.DamageType = CombatTypes.DamageType.MELEE
## Weapon multiplier applied on weak-point hurtboxes (e.g. FirearmStats.weakpoint_mult).
var weakpoint_mult: float = 1.0
## Carried for stagger handling (F012/F015); not used by the damage math.
var stagger: float = 0.0
var weapon_id: StringName = &""
## Where the attack came from (attacker position). Used for the block arc.
var origin: Vector3 = Vector3.ZERO
## Area/special attacks that may also hurt the attacker's own (cult) side.
var hits_allies: bool = false
## Cannot be parried or blocked: must be dodged (e.g. Abomination, EnemyData.parryable = false).
var unparryable: bool = false
## Multiplier if this hit is a riposte (MeleeStats.riposte_mult of the attacker's weapon).
var riposte_mult: float = 1.0


## An attack by [param p_source] on [param p_target]. Origin defaults to the source's position.
static func from_source(
	p_source: HealthComponent,
	p_target: HealthComponent,
	p_amount: float,
	p_type: CombatTypes.DamageType,
	p_hurtbox: Hurtbox = null
) -> DamageEvent:
	var event := DamageEvent.new()
	event.source = p_source
	event.source_faction = p_source.faction
	event.source_peer_id = p_source.peer_id
	event.target = p_target
	event.amount = p_amount
	event.type = p_type
	event.hurtbox = p_hurtbox
	event.origin = p_source.get_world_position()
	return event


## Damage from the world (no attacker): falls, hazards, debug.
static func world(
	p_target: HealthComponent,
	p_amount: float,
	p_type: CombatTypes.DamageType = CombatTypes.DamageType.ENVIRONMENT
) -> DamageEvent:
	var event := DamageEvent.new()
	event.target = p_target
	event.amount = p_amount
	event.type = p_type
	if p_target != null:
		event.origin = p_target.get_world_position()
	return event


func is_weakpoint() -> bool:
	return hurtbox != null and hurtbox.is_weakpoint
