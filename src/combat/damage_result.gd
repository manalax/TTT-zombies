class_name DamageResult
extends RefCounted
## Outcome of DamagePipeline.resolve(). Committed by Combat.apply() when accepted.

var event: DamageEvent
var accepted: bool = false
## Why the event was rejected, e.g. &"friendly_fire_off". Empty when accepted.
var reject_reason: StringName = &""
var relation: CombatTypes.Relation = CombatTypes.Relation.HOSTILE
## The event's amount before any stage.
var raw_amount: float = 0.0
## Amount after all modifiers, before clamping to the target's remaining health.
var final_amount: float = 0.0
## Health actually removed. Points (F016) must use this, never final_amount.
var applied: float = 0.0
var overkill: float = 0.0
var blocked: bool = false
var absorbed: float = 0.0
var stamina_spent: float = 0.0
## The block could not be paid for: stamina is drained to 0 and the blocker is staggered.
var guard_broken: bool = false
## Stagger delivered to the target's poise (reduced by a block like the damage).
var stagger: float = 0.0
var killed: bool = false
## A parry negated this hit; Combat stuns the attacker.
var parried: bool = false
## This hit was a riposte (multiplied, ignored block). F016 may award bonus points.
var riposte: bool = false
## (Time since the target's block press − parry window) in ms; negative = inside. NAN = n/a.
var parry_timing_ms: float = NAN
## Amount after each stage, in order, e.g. {"zone": 60.0, "match": 60.0, ...}.
var stages: Dictionary[String, float] = {}


static func rejected(p_event: DamageEvent, reason: StringName) -> DamageResult:
	var result := DamageResult.new()
	result.event = p_event
	result.reject_reason = reason
	if p_event != null:
		result.raw_amount = p_event.amount
	return result


## Short human-readable summary for debug labels and logs.
func describe() -> String:
	if not accepted:
		return "no damage (%s)" % String(reject_reason).replace("_", " ")
	var notes := PackedStringArray()
	if event.is_weakpoint():
		notes.append("weak point")
	elif event.hurtbox != null and not is_equal_approx(event.hurtbox.damage_mult, 1.0):
		notes.append("%s ×%.2f" % [event.hurtbox.name, event.hurtbox.damage_mult])
	if parried:
		notes.append("PARRIED")
	if riposte:
		notes.append("RIPOSTE ×%.1f" % event.riposte_mult)
	if blocked:
		notes.append("guard broken" if guard_broken else "blocked")
	if event.target.armor > 0.0:
		notes.append("armour %d%%" % roundi(event.target.armor * 100.0))
	if relation == CombatTypes.Relation.FRIENDLY:
		notes.append("friendly fire")
	if killed:
		notes.append("kill")
	var text := "-%.0f" % applied
	if not notes.is_empty():
		text += " (%s)" % ", ".join(notes)
	return text
