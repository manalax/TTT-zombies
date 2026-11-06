class_name ValidationReport
extends RefCounted
## Collects validation issues for content and settings (docs/adr/0002-content-data-model.md).
##
## Errors mean the data is broken and must be fixed. Warnings are legal but questionable
## (e.g. host settings that make for a poor match) and are shown to the host, never blocking.


class Issue:
	var is_error: bool
	## Where the issue lives, e.g. "WeaponData:arming_sword.melee_stats".
	var source: String
	var field: String
	var message: String

	func _init(p_is_error: bool, p_source: String, p_field: String, p_message: String) -> void:
		is_error = p_is_error
		source = p_source
		field = p_field
		message = p_message

	func format() -> String:
		var where := source if field.is_empty() else "%s.%s" % [source, field]
		return "%s %s: %s" % ["ERROR" if is_error else "WARNING", where, message]


var _issues: Array[Issue] = []


func error(source: String, field: String, message: String) -> void:
	_issues.append(Issue.new(true, source, field, message))


func warn(source: String, field: String, message: String) -> void:
	_issues.append(Issue.new(false, source, field, message))


## Records an error when [param condition] is false.
func check(condition: bool, source: String, field: String, message: String) -> void:
	if not condition:
		error(source, field, message)


func check_positive(source: String, field: String, value: float) -> void:
	check(value > 0.0, source, field, "must be > 0 (got %s)" % value)


func check_min(source: String, field: String, value: float, minimum: float) -> void:
	check(value >= minimum, source, field, "must be >= %s (got %s)" % [minimum, value])


func check_range(source: String, field: String, value: float, lo: float, hi: float) -> void:
	check(
		value >= lo and value <= hi, source, field, "must be in [%s, %s] (got %s)" % [lo, hi, value]
	)


func merge(other: ValidationReport) -> void:
	_issues.append_array(other._issues)


func has_errors() -> bool:
	return _issues.any(func(issue: Issue) -> bool: return issue.is_error)


func is_empty() -> bool:
	return _issues.is_empty()


func get_issues() -> Array[Issue]:
	return _issues.duplicate()


func get_errors() -> Array[Issue]:
	return _select(true)


func get_warnings() -> Array[Issue]:
	return _select(false)


## True if any issue's formatted text contains [param needle]. Handy in tests.
func mentions(needle: String) -> bool:
	return _issues.any(func(issue: Issue) -> bool: return issue.format().contains(needle))


func format() -> String:
	var lines := PackedStringArray()
	for issue in _issues:
		lines.append(issue.format())
	return "\n".join(lines)


func _select(errors: bool) -> Array[Issue]:
	var result: Array[Issue] = []
	for issue in _issues:
		if issue.is_error == errors:
			result.append(issue)
	return result
