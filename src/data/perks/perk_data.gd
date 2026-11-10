class_name PerkData
extends GameData
## A purchasable perk ("Sacrament") at a perk altar (DESIGN §10.2).

## Stat keys the player systems understand. Unknown keys warn (new stats arrive with F053).
const KNOWN_STATS: Array[StringName] = [
	&"max_health_add",
	&"stamina_regen_mult",
	&"reload_speed_mult",
	&"parry_window_add",
	&"riposte_mult",
	&"loot_luck_mult",
	&"special_damage_mult",
]

@export_range(0, 50000, 50) var cost: int = 1500
## e.g. {&"max_health_add": 25.0}. "_add" keys are additive, "_mult" keys multiply.
@export var stat_modifiers: Dictionary[StringName, float] = {}
@export var icon: Texture2D


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check_min(source, "cost", cost, 0)
	if stat_modifiers.is_empty():
		report.warn(source, "stat_modifiers", "perk has no effect")
	for stat in stat_modifiers:
		if not stat in KNOWN_STATS:
			report.warn(source, "stat_modifiers", "unknown stat '%s'" % stat)
		if String(stat).ends_with("_mult") and stat_modifiers[stat] <= 0.0:
			report.error(source, "stat_modifiers", "'%s' multiplier must be > 0" % stat)
