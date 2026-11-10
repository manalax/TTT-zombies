class_name LootEntry
extends Resource
## One weighted outcome in a [LootTable] (DESIGN §10.4).

enum Kind { AMMO, WEAPON, POINTS, CONSUMABLE }

@export var kind: Kind = Kind.AMMO
## Required when kind is WEAPON.
@export var weapon: WeaponData
@export_range(0, 10000, 1) var qty_min: int = 1
@export_range(0, 10000, 1) var qty_max: int = 1
@export_range(0.0, 1000.0, 0.1) var weight: float = 1.0


func validate_into(report: ValidationReport, source: String) -> void:
	report.check_min(source, "weight", weight, 0.0)
	report.check_min(source, "qty_min", qty_min, 0)
	report.check(qty_min <= qty_max, source, "qty_min", "must be <= qty_max (%d)" % qty_max)
	if kind == Kind.WEAPON:
		if weapon == null:
			report.error(source, "weapon", "required for WEAPON entries")
		else:
			GameData.validate_embedded(weapon, report)
	elif weapon != null:
		report.warn(source, "weapon", "is ignored for non-WEAPON entries")
	if kind == Kind.CONSUMABLE:
		report.warn(source, "kind", "CONSUMABLE is reserved until consumables exist (F053)")
