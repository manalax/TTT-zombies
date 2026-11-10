class_name WaveSet
extends GameData
## Ordered waves for a match; index 0 is Round 1 (DESIGN §8.1). Host-customisable (F061).

@export var waves: Array[WaveData] = []


func _validate(report: ValidationReport) -> void:
	var source := source_label()
	report.check(not waves.is_empty(), source, "waves", "needs at least one wave")
	for i in waves.size():
		var wave_source := "%s.waves[%d]" % [source, i]
		if waves[i] == null:
			report.error(wave_source, "", "is null")
		else:
			waves[i].validate_into(report, wave_source)


## Serializable form (shared content referenced by id). See DataSerializer.
func to_dict() -> Dictionary:
	return DataSerializer.to_dict(self)


## Returns {"resource": WaveSet or null, "report": ValidationReport}.
static func from_dict(data: Dictionary) -> Dictionary:
	return DataSerializer.from_dict(data, &"WaveSet")
