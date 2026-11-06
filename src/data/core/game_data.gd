class_name GameData
extends Resource
## Base class for all top-level content (docs/adr/0002-content-data-model.md).
##
## Shipped content lives in res://content/<category>/<id>/<id>.tres and is indexed by ContentDB.
## Subclasses override [method _validate] to add their own checks.

const ID_PATTERN := "^[a-z][a-z0-9_]*$"

static var _id_regex: RegEx

## Stable snake_case identifier; must equal the file name. Used in saves, net messages and refs.
@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""


static func is_valid_id(value: String) -> bool:
	if _id_regex == null:
		_id_regex = RegEx.create_from_string(ID_PATTERN)
	return _id_regex.search(value) != null


## Runs base checks (id, display name) plus the subclass's [method _validate].
func validate() -> ValidationReport:
	var report := ValidationReport.new()
	var source := source_label()
	if id == &"":
		report.error(source, "id", "is required")
	elif not is_valid_id(String(id)):
		report.error(source, "id", "must be snake_case (%s), got '%s'" % [ID_PATTERN, id])
	report.check(not display_name.strip_edges().is_empty(), source, "display_name", "is required")
	_validate(report)
	return report


## Override to add type-specific checks. Use [method source_label] as the issue source.
func _validate(_report: ValidationReport) -> void:
	pass


## Global class name of this resource's script, e.g. &"WeaponData".
func get_type_name() -> StringName:
	var script := get_script() as Script
	return script.get_global_name() if script != null else &""


## e.g. "WeaponData:arming_sword".
func source_label() -> String:
	return "%s:%s" % [get_type_name(), id]


## True when saved as its own file (shared content), false when embedded in another resource.
## Shared content is referenced by id when serialized; embedded content is serialized inline.
func is_standalone() -> bool:
	return not resource_path.is_empty() and not resource_path.contains("::")


## Validates [param data] only if it is embedded; standalone content is validated by ContentDB.
static func validate_embedded(data: GameData, report: ValidationReport) -> void:
	if data != null and not data.is_standalone():
		report.merge(data.validate())
