class_name FirearmStats
extends Resource
## Firearm behaviour of a weapon (DESIGN §6.4). Embedded in [WeaponData]. Placeholder numbers.
## Ammo is meant to be scarce: reserves of roughly two magazines.

## Reserve above this many magazines triggers a scarcity warning.
const SCARCITY_MAGS := 3

@export_group("Damage")
@export_range(0, 1000, 1) var damage: float = 40.0
## Projectiles per shot (> 1 for blunderbuss-style spread weapons).
@export_range(1, 32, 1) var pellets: int = 1
@export_range(0, 200, 0.5, "suffix:m") var falloff_start_m: float = 10.0
@export_range(0, 200, 0.5, "suffix:m") var falloff_end_m: float = 30.0
## Damage multiplier at and beyond falloff_end_m.
@export_range(0.0, 1.0, 0.01) var min_damage_mult: float = 0.5
@export_range(1.0, 10.0, 0.1) var weakpoint_mult: float = 2.0

@export_group("Ammo")
@export_range(1, 200, 1) var mag_size: int = 6
@export_range(0, 1000, 1) var reserve_cap: int = 12
@export_range(0.1, 10.0, 0.05, "suffix:s") var reload_s: float = 2.0
## Point cost of a refill at a wall ammo station.
@export_range(0, 10000, 10) var ammo_cost: int = 250

@export_group("Handling")
@export_range(0.01, 5.0, 0.01, "suffix:s") var fire_interval_s: float = 0.35
@export_range(0.0, 45.0, 0.1, "suffix:°") var spread_deg: float = 1.0
@export_range(0.0, 10.0, 0.1) var recoil: float = 1.0
## Number of additional targets a shot passes through.
@export_range(0, 10, 1) var penetration: int = 0


func validate_into(report: ValidationReport, source: String) -> void:
	report.check_positive(source, "damage", damage)
	report.check_min(source, "pellets", pellets, 1)
	report.check_min(source, "falloff_start_m", falloff_start_m, 0.0)
	report.check(
		falloff_start_m <= falloff_end_m,
		source,
		"falloff_end_m",
		"must be >= falloff_start_m (%s)" % falloff_start_m
	)
	report.check_range(source, "min_damage_mult", min_damage_mult, 0.0, 1.0)
	report.check_min(source, "weakpoint_mult", weakpoint_mult, 1.0)
	report.check_min(source, "mag_size", mag_size, 1)
	report.check_min(source, "reserve_cap", reserve_cap, 0)
	if reserve_cap > SCARCITY_MAGS * mag_size:
		report.warn(
			source,
			"reserve_cap",
			"exceeds %d magazines; conflicts with ammo scarcity (DESIGN §6.4)" % SCARCITY_MAGS
		)
	report.check_positive(source, "reload_s", reload_s)
	report.check_min(source, "ammo_cost", ammo_cost, 0)
	report.check_positive(source, "fire_interval_s", fire_interval_s)
	report.check_min(source, "spread_deg", spread_deg, 0.0)
	report.check_min(source, "recoil", recoil, 0.0)
	report.check_min(source, "penetration", penetration, 0)
