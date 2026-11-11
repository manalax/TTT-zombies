class_name BarricadeData
extends GameData
## A boarded-window type (F046, docs/adr/0013-barricades.md): how many planks it holds and how
## repairing and climbing through it work. Enemies' tear speed is EnemyData.barricade_tear_s.

@export_range(1, 20, 1) var plank_count: int = 6
## Seconds of holding interact per plank nailed back.
@export_range(0.05, 10.0, 0.05, "suffix:s") var repair_interval_s: float = 0.75
## Points per plank repaired (rounded up like every award).
@export_range(0, 1000, 10) var repair_points: int = 10
## Seconds an enemy takes to climb through the open window.
@export_range(0.05, 10.0, 0.05, "suffix:s") var climb_s: float = 0.8


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check_min(source, "plank_count", plank_count, 1)
	report.check_positive(source, "repair_interval_s", repair_interval_s)
	report.check_min(source, "repair_points", repair_points, 0)
	report.check_positive(source, "climb_s", climb_s)
