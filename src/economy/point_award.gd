class_name PointAward
extends RefCounted
## Points earned by one hit (or a direct award), with the breakdown for the debug overlay.

## What the wallet receives (a multiple of EconomyRules.round_to). 0 = nothing earned.
var total: int = 0
## Damage points before rounding (applied × multipliers, including the weak-point factor).
var damage_points: float = 0.0
var weakpoint: bool = false
var riposte_bonus: int = 0
## &"damage", &"debug", or a later source such as &"bounty".
var reason: StringName = &"damage"


func describe() -> String:
	if total <= 0:
		return "-"
	if reason != &"damage":
		return "+%d %s" % [total, reason]
	var text := "+%d (dmg %.1f" % [total, damage_points]
	if weakpoint:
		text += " head"
	if riposte_bonus > 0:
		text += " +%d riposte" % riposte_bonus
	return text + ")"
