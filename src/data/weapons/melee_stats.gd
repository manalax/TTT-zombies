class_name MeleeStats
extends Resource
## Melee behaviour of a weapon (DESIGN §6.3). Embedded in [WeaponData]. Placeholder numbers.

enum Archetype { SWORD, GREATSWORD, MACE, SPEAR, FLAIL }

@export var archetype: Archetype = Archetype.SWORD

@export_group("Damage")
@export_range(0, 500, 1) var light_damage: float = 35.0
@export_range(0, 1000, 1) var heavy_damage: float = 70.0
@export_range(0.1, 5.0, 0.05, "suffix:m") var reach_m: float = 1.8

@export_group("Timing")
@export_range(0.0, 2.0, 0.01, "suffix:s") var light_windup_s: float = 0.15
## Window during which the swing can hit (hit detection's "active frames").
@export_range(0.01, 2.0, 0.01, "suffix:s") var light_active_s: float = 0.12
@export_range(0.0, 2.0, 0.01, "suffix:s") var light_recovery_s: float = 0.3
@export_range(0.0, 3.0, 0.01, "suffix:s") var heavy_charge_s: float = 0.6

@export_group("Stamina & Stagger")
@export_range(0, 100, 1) var light_stamina_cost: float = 15.0
@export_range(0, 100, 1) var heavy_stamina_cost: float = 30.0
@export_range(0, 200, 1) var stagger_light: float = 10.0
@export_range(0, 200, 1) var stagger_heavy: float = 35.0

@export_group("Defence")
## Fraction of incoming damage blocked.
@export_range(0.0, 1.0, 0.01) var block_reduction: float = 0.7
@export_range(0.0, 5.0, 0.05) var block_stamina_per_damage: float = 0.5
@export_range(0.0, 1.0, 0.01, "suffix:s") var parry_window_s: float = 0.2
@export_range(1.0, 10.0, 0.1) var riposte_mult: float = 2.5


func validate_into(report: ValidationReport, source: String) -> void:
	report.check_positive(source, "light_damage", light_damage)
	report.check_positive(source, "heavy_damage", heavy_damage)
	if heavy_damage < light_damage:
		report.warn(source, "heavy_damage", "is lower than light_damage")
	report.check_positive(source, "reach_m", reach_m)
	report.check_min(source, "light_windup_s", light_windup_s, 0.0)
	report.check_positive(source, "light_active_s", light_active_s)
	report.check_min(source, "light_recovery_s", light_recovery_s, 0.0)
	report.check_min(source, "heavy_charge_s", heavy_charge_s, 0.0)
	report.check_min(source, "light_stamina_cost", light_stamina_cost, 0.0)
	report.check_min(source, "heavy_stamina_cost", heavy_stamina_cost, 0.0)
	report.check_min(source, "stagger_light", stagger_light, 0.0)
	report.check_min(source, "stagger_heavy", stagger_heavy, 0.0)
	report.check_range(source, "block_reduction", block_reduction, 0.0, 1.0)
	report.check_min(source, "block_stamina_per_damage", block_stamina_per_damage, 0.0)
	report.check_range(source, "parry_window_s", parry_window_s, 0.0, 1.0)
	report.check_min(source, "riposte_mult", riposte_mult, 1.0)
