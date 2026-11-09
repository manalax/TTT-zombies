class_name DamagePipeline
extends RefCounted
## The damage math: a fixed, ordered list of pure stages (docs/adr/0004-damage-pipeline.md).
##
## Order: validate → relation gate → dodge → zone → riposte → match multipliers → relation scale
## → parry → block → armour → clamp. Each stage is a public static function so it can be tested
## alone. resolve() reads the target's state but never changes it; Combat.apply() commits it.


static func resolve(event: DamageEvent, rules: DamageRules) -> DamageResult:
	var reason := validate(event)
	if reason != &"":
		return DamageResult.rejected(event, reason)
	var relation := classify(event)
	reason = gate(relation, event, rules)
	if reason == &"":
		reason = dodge(event)
	if reason != &"":
		var rejected := DamageResult.rejected(event, reason)
		rejected.relation = relation
		return rejected

	var result := DamageResult.new()
	result.event = event
	result.relation = relation
	result.raw_amount = event.amount
	result.stagger = event.stagger
	result.parry_timing_ms = parry_timing_ms(event)
	var amount := apply_zone(event.amount, event)
	result.stages["zone"] = amount
	amount = apply_riposte(amount, event, result)
	result.stages["riposte"] = amount
	amount = apply_match_mults(amount, event, rules)
	result.stages["match"] = amount
	amount = apply_relation_scale(amount, relation, rules)
	result.stages["relation"] = amount
	amount = apply_parry(amount, event, result)
	result.stages["parry"] = amount
	amount = apply_block(amount, event, result)
	result.stages["block"] = amount
	amount = apply_armor(amount, event.target.armor)
	result.stages["armor"] = amount
	apply_clamp(amount, event.target.current_health, result)
	result.accepted = true
	return result


## Stage 1. Returns a rejection reason, or &"" if the event can be processed.
static func validate(event: DamageEvent) -> StringName:
	if event == null or event.target == null:
		return &"no_target"
	if event.target.is_dead():
		return &"target_dead"
	if event.target.invulnerable:
		return &"invulnerable"
	if event.amount <= 0.0:
		return &"no_amount"
	return &""


static func classify(event: DamageEvent) -> CombatTypes.Relation:
	if event.source == null or event.source_faction == CombatTypes.Faction.WORLD:
		return CombatTypes.Relation.WORLD
	if event.source == event.target:
		return CombatTypes.Relation.SELF
	if event.source_faction == event.target.faction:
		return (
			CombatTypes.Relation.FRIENDLY
			if event.source_faction == CombatTypes.Faction.HUNTER
			else CombatTypes.Relation.CULT_ALLY
		)
	return CombatTypes.Relation.HOSTILE


## Stage 2. Returns a rejection reason, or &"" if the relation allows damage.
static func gate(
	relation: CombatTypes.Relation, event: DamageEvent, rules: DamageRules
) -> StringName:
	match relation:
		CombatTypes.Relation.SELF:
			return &"" if rules.self_damage else &"self_damage_off"
		CombatTypes.Relation.FRIENDLY:
			return &"" if rules.friendly_fire else &"friendly_fire_off"
		CombatTypes.Relation.CULT_ALLY:
			return &"" if event.hits_allies else &"cult_ally"
	return &""


## Stage 3: i-frames (dodge) negate attacks, but not falls, hazards or debug damage.
static func dodge(event: DamageEvent) -> StringName:
	if event.target.has_iframes() and CombatTypes.is_dodgeable(event.type):
		return &"dodged"
	return &""


## Stage 4: hurtbox zone multiplier and weak point.
static func apply_zone(amount: float, event: DamageEvent) -> float:
	if event.hurtbox == null:
		return amount
	amount *= event.hurtbox.damage_mult
	if event.hurtbox.is_weakpoint:
		amount *= event.weakpoint_mult
	return amount


## Stage 5: riposte. The parrier's melee hit on the attacker they stunned is multiplied.
static func apply_riposte(amount: float, event: DamageEvent, result: DamageResult) -> float:
	if not is_riposte(event):
		return amount
	result.riposte = true
	return amount * event.riposte_mult


static func is_riposte(event: DamageEvent) -> bool:
	var target := event.target
	return (
		event.type == CombatTypes.DamageType.MELEE
		and event.source != null
		and target.is_stunned()
		and target.riposte_by == event.source
	)


## Stage 6: host multipliers. Enemy damage scales only cult attacks on Hunters.
static func apply_match_mults(amount: float, event: DamageEvent, rules: DamageRules) -> float:
	if (
		event.source_faction == CombatTypes.Faction.CULT
		and event.target.faction == CombatTypes.Faction.HUNTER
	):
		amount *= rules.enemy_damage_mult
	return amount


## Stage 7: friendly-fire scales.
static func apply_relation_scale(
	amount: float, relation: CombatTypes.Relation, rules: DamageRules
) -> float:
	match relation:
		CombatTypes.Relation.FRIENDLY:
			return amount * rules.friendly_fire_scale
		CombatTypes.Relation.CULT_ALLY:
			return amount * rules.cult_friendly_fire_scale
	return amount


## Stage 8: parry. A parryable melee hit inside a fresh block's window is negated entirely
## (no stamina); Combat then stuns the attacker.
static func apply_parry(amount: float, event: DamageEvent, result: DamageResult) -> float:
	if not can_parry(event, result):
		return amount
	result.parried = true
	return 0.0


static func can_parry(event: DamageEvent, result: DamageResult = null) -> bool:
	if result != null and result.riposte:
		return false
	if event.type != CombatTypes.DamageType.MELEE or event.unparryable or event.source == null:
		return false
	var block := event.target.block
	if block == null or not block.active or not block.is_parry_window_open():
		return false
	return _in_block_arc(event, block)


## Seconds-from-window-edge readout for tuning: (time since the block press − window) in ms.
## Negative = inside the window. NAN when the hit did not meet an active block.
static func parry_timing_ms(event: DamageEvent) -> float:
	var block := event.target.block
	if event.type != CombatTypes.DamageType.MELEE or block == null or not block.active:
		return NAN
	if block.since_press == INF:
		return NAN
	return (block.since_press - block.parry_window_s) * 1000.0


## Stage 9: block. Records blocked/absorbed/stamina_spent/guard_broken on [param result].
## A block the blocker cannot pay for still holds, but drains all stamina (guard break).
static func apply_block(amount: float, event: DamageEvent, result: DamageResult) -> float:
	if result.parried or not can_block(event, result):
		return amount
	var block := event.target.block
	var absorbed := amount * block.reduction
	var cost := absorbed * block.stamina_per_damage
	var available := block.stamina.current
	result.blocked = true
	result.absorbed = absorbed
	result.stagger = event.stagger * (1.0 - block.reduction)
	if cost > available:
		result.stamina_spent = available
		result.guard_broken = true
	else:
		result.stamina_spent = cost
	return amount - absorbed


## Unparryable attacks and ripostes also ignore block.
static func can_block(event: DamageEvent, result: DamageResult = null) -> bool:
	if event.unparryable or (result != null and result.riposte):
		return false
	var block := event.target.block
	if block == null or not block.active or block.stamina == null:
		return false
	if not CombatTypes.is_blockable(event.type) or block.stamina.current <= 0.0:
		return false
	return _in_block_arc(event, block)


static func _in_block_arc(event: DamageEvent, block: BlockState) -> bool:
	return is_in_arc(
		event.target.get_world_position(), event.target.forward(), event.origin, block.arc_deg
	)


## True if [param origin] lies within the [param arc_deg] frontal arc (horizontal plane only).
static func is_in_arc(position: Vector3, forward: Vector3, origin: Vector3, arc_deg: float) -> bool:
	var to_origin := Vector2(origin.x - position.x, origin.z - position.z)
	var facing := Vector2(forward.x, forward.z)
	if to_origin.length_squared() < 0.0001:
		return true
	if facing.length_squared() < 0.0001:
		return false
	var angle := rad_to_deg(absf(facing.angle_to(to_origin)))
	return angle <= arc_deg * 0.5 + 0.001


## Stage 10: armour is a flat percentage reduction, always applied in full.
static func apply_armor(amount: float, armor: float) -> float:
	return amount * (1.0 - clampf(armor, 0.0, 1.0))


## Stage 11: clamp to remaining health and record the kill.
static func apply_clamp(amount: float, current_health: float, result: DamageResult) -> void:
	amount = maxf(amount, 0.0)
	result.final_amount = amount
	result.applied = minf(amount, current_health)
	result.overkill = amount - result.applied
	result.killed = amount >= current_health
