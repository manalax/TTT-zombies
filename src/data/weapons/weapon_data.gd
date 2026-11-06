class_name WeaponData
extends GameData
## A weapon (DESIGN §6.2). The loadout holds 2 FIREARM-slot weapons and 1 MELEE-slot weapon.
##
## The slot's primary stats are required (MELEE -> melee_stats, FIREARM -> firearm_stats).
## The other stats are an optional hybrid behaviour, e.g. a rifle's bayonet bash.

enum Slot { FIREARM, MELEE }

@export var slot: Slot = Slot.MELEE
@export_range(1, 5, 1) var tier: int = 1
## Point cost at a wall-buy station.
@export_range(0, 20000, 10) var wall_cost: int = 500
@export var melee_stats: MeleeStats
@export var firearm_stats: FirearmStats

@export_group("Assets")
## Viewmodel scene. Null -> placeholder.
@export var scene: PackedScene
@export var icon: Texture2D


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check_range(source, "tier", tier, 1, 5)
	report.check_min(source, "wall_cost", wall_cost, 0)
	if slot == Slot.MELEE:
		report.check(melee_stats != null, source, "melee_stats", "required for MELEE weapons")
	else:
		report.check(firearm_stats != null, source, "firearm_stats", "required for FIREARM weapons")
	if melee_stats != null:
		melee_stats.validate_into(report, source + ".melee_stats")
	if firearm_stats != null:
		firearm_stats.validate_into(report, source + ".firearm_stats")
