class_name DamageRules
extends RefCounted
## The MatchSettings values the damage pipeline needs, as a plain value object.

var friendly_fire: bool = true
var friendly_fire_scale: float = 1.0
var self_damage: bool = true
var cult_friendly_fire_scale: float = 1.0
var enemy_damage_mult: float = 1.0


static func from_settings(settings: MatchSettings) -> DamageRules:
	var rules := DamageRules.new()
	if settings == null:
		return rules
	rules.friendly_fire = settings.friendly_fire
	rules.friendly_fire_scale = settings.friendly_fire_scale
	rules.self_damage = settings.self_damage
	rules.cult_friendly_fire_scale = settings.cult_friendly_fire_scale
	rules.enemy_damage_mult = settings.enemy_damage_mult
	return rules
