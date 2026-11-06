class_name WaveEntry
extends Resource
## One enemy type in a wave and how many of it to spawn (DESIGN §8.1).

enum SpawnGroup { ANY, ZONE_ONLY, ELITE_ROOM }

@export var enemy: EnemyData
@export_range(0, 500, 1) var count_min: int = 5
@export_range(0, 500, 1) var count_max: int = 5
## Relative spawn priority when the director picks what to spawn next.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
## Seconds after wave start before this entry starts spawning.
@export_range(0.0, 600.0, 0.5, "suffix:s") var delay_s: float = 0.0
@export var spawn_group: SpawnGroup = SpawnGroup.ANY


func validate_into(report: ValidationReport, source: String) -> void:
	if enemy == null:
		report.error(source, "enemy", "is required")
	else:
		GameData.validate_embedded(enemy, report)
	report.check_min(source, "count_min", count_min, 0)
	report.check_positive(source, "count_max", count_max)
	report.check(
		count_min <= count_max, source, "count_min", "must be <= count_max (%d)" % count_max
	)
	report.check_positive(source, "weight", weight)
	report.check_min(source, "delay_s", delay_s, 0.0)
