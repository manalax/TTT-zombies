class_name LootTable
extends GameData
## Weighted loot for a zone or container (DESIGN §10.4). Deeper zones get better tables.

@export var entries: Array[LootEntry] = []
## Number of picks per loot event.
@export_range(1, 20, 1) var rolls: int = 1


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check(not entries.is_empty(), source, "entries", "needs at least one entry")
	for i in entries.size():
		var entry_source := "%s.entries[%d]" % [source, i]
		if entries[i] == null:
			report.error(entry_source, "", "is null")
		else:
			entries[i].validate_into(report, entry_source)
	if not entries.is_empty():
		report.check(total_weight() > 0.0, source, "entries", "total weight must be > 0")
	report.check_min(source, "rolls", rolls, 1)


func total_weight() -> float:
	var total := 0.0
	for entry in entries:
		if entry != null:
			total += maxf(entry.weight, 0.0)
	return total


## Weighted random pick. Deterministic for a seeded [param rng]. Null if nothing can be picked.
func pick(rng: RandomNumberGenerator) -> LootEntry:
	var total := total_weight()
	if total <= 0.0:
		push_error("%s: cannot pick from a table with zero total weight" % source_label())
		return null
	var roll := rng.randf() * total
	var last: LootEntry = null
	for entry in entries:
		if entry == null or entry.weight <= 0.0:
			continue
		last = entry
		roll -= entry.weight
		if roll < 0.0:
			return entry
	return last
