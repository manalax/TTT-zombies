class_name WaveData
extends Resource
## One round's composition (DESIGN §8.1). Embedded in a [WaveSet].

enum ClearCondition { KILL_ALL, KILL_QUOTA, SURVIVE_TIME }

## Director budget spent on spawns this wave.
@export_range(0, 10000, 1) var budget_points: int = 20
@export var entries: Array[WaveEntry] = []
## Max concurrent specials (AI + player-controlled).
@export_range(0, 32, 1) var special_cap: int = 0
@export var boss: EnemyData
@export var modifiers: Array[WaveModifier] = []
## Enemies spawned per second.
@export_range(0.05, 20.0, 0.05) var spawn_rate: float = 1.0
## Optional hard time limit; 0 = none.
@export_range(0.0, 3600.0, 1.0, "suffix:s") var timeout_s: float = 0.0
@export var clear_condition: ClearCondition = ClearCondition.KILL_ALL
@export_range(0, 10000, 1) var kill_quota: int = 0
@export_range(0.0, 3600.0, 1.0, "suffix:s") var survive_time_s: float = 0.0


func validate_into(report: ValidationReport, source: String) -> void:
	if entries.is_empty() and boss == null:
		report.error(source, "entries", "wave has no enemies (no entries and no boss)")
	for i in entries.size():
		var entry := entries[i]
		var entry_source := "%s.entries[%d]" % [source, i]
		if entry == null:
			report.error(entry_source, "", "is null")
			continue
		entry.validate_into(report, entry_source)
		if (
			entry.enemy != null
			and entry.enemy.category == EnemyData.Category.SPECIAL
			and special_cap == 0
		):
			report.warn(entry_source, "enemy", "is a special but special_cap is 0")
	if boss != null:
		GameData.validate_embedded(boss, report)
		if boss.category != EnemyData.Category.BOSS:
			report.warn(source, "boss", "'%s' is not a BOSS-category enemy" % boss.id)
	for i in modifiers.size():
		if modifiers[i] == null:
			report.error("%s.modifiers[%d]" % [source, i], "", "is null")
		else:
			GameData.validate_embedded(modifiers[i], report)
	report.check_min(source, "budget_points", budget_points, 0)
	report.check_min(source, "special_cap", special_cap, 0)
	report.check_positive(source, "spawn_rate", spawn_rate)
	report.check_min(source, "timeout_s", timeout_s, 0.0)
	match clear_condition:
		ClearCondition.KILL_QUOTA:
			report.check(kill_quota > 0, source, "kill_quota", "must be > 0 for KILL_QUOTA")
		ClearCondition.SURVIVE_TIME:
			report.check(
				survive_time_s > 0.0, source, "survive_time_s", "must be > 0 for SURVIVE_TIME"
			)
