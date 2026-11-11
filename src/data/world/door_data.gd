class_name DoorData
extends GameData
## A purchasable door that unlocks a map zone (DESIGN §10.2, §11).
## Zones are scene nodes (F017), so the zone id is not resolved here.

@export_range(0, 50000, 50) var cost: int = 750
@export var unlocks_zone_id: StringName
## Interaction prompt, e.g. "Open the Crypt Gate". Empty -> generic prompt.
@export var prompt_text: String = ""


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check_min(source, "cost", cost, 0)
	if unlocks_zone_id == &"":
		report.error(source, "unlocks_zone_id", "is required")
	elif not GameData.is_valid_id(String(unlocks_zone_id)):
		report.error(source, "unlocks_zone_id", "must be snake_case")
