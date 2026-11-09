class_name EconomyRules
extends GameData
## How damage turns into points (DESIGN §10.1, docs/adr/0009-points-economy.md).
## Shipped as content/economy/economy_rules/. MatchSettings.points_per_damage_mult applies on top.
## There is no kill bonus: points come from damage dealt (plus the bonuses below).

@export_group("Damage")
## Points per point of damage, by the target's EnemyData.category.
@export_range(0.0, 10.0, 0.05) var common_mult: float = 1.0
@export_range(0.0, 10.0, 0.05) var special_mult: float = 1.5
@export_range(0.0, 10.0, 0.05) var boss_mult: float = 2.0

@export_group("Bonuses")
## Multiplier on a weak-point hit's damage points.
@export_range(1.0, 10.0, 0.05) var weakpoint_mult: float = 1.5
## Flat bonus when a riposte lands.
@export_range(0, 1000, 10) var riposte_bonus: int = 50

@export_group("Rounding")
## Every award is rounded up to a multiple of this, so any damaging hit pays at least this much.
@export_range(1, 100, 1) var round_to: int = 10


func category_mult(category: EnemyData.Category) -> float:
	match category:
		EnemyData.Category.SPECIAL:
			return special_mult
		EnemyData.Category.BOSS:
			return boss_mult
	return common_mult


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	for field: String in ["common_mult", "special_mult", "boss_mult"]:
		report.check_min(source, field, float(get(field)), 0.0)
	report.check_min(source, "weakpoint_mult", weakpoint_mult, 1.0)
	report.check_min(source, "riposte_bonus", riposte_bonus, 0)
	report.check_min(source, "round_to", round_to, 1)
	if riposte_bonus % maxi(round_to, 1) != 0:
		report.warn(source, "riposte_bonus", "is not a multiple of round_to (totals get rounded)")
