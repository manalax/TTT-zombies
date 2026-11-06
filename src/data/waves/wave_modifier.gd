class_name WaveModifier
extends GameData
## A named modifier applied to a wave, e.g. "frenzied" or "fog" (DESIGN §8.1).

@export_range(0.1, 10.0, 0.05) var enemy_health_mult: float = 1.0
@export_range(0.1, 10.0, 0.05) var enemy_damage_mult: float = 1.0
@export_range(0.1, 5.0, 0.05) var enemy_speed_mult: float = 1.0
@export_range(0.1, 10.0, 0.05) var spawn_rate_mult: float = 1.0
@export var hide_hud_markers: bool = false
@export var fog: bool = false


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check_positive(source, "enemy_health_mult", enemy_health_mult)
	report.check_positive(source, "enemy_damage_mult", enemy_damage_mult)
	report.check_positive(source, "enemy_speed_mult", enemy_speed_mult)
	report.check_positive(source, "spawn_rate_mult", spawn_rate_mult)
