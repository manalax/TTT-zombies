class_name ContentRegistry
extends Node
## Indexes all GameData under res://content by type and id (autoload: ContentDB).
## See docs/adr/0002-content-data-model.md.
##
## Layout rule: res://content/<category...>/<id>/<id>.tres, with a snake_case id equal to the
## file name and its folder name. Ids are unique per type. Violations are reported, not fatal.

const DEFAULT_ROOT := "res://content"
const RESOURCE_EXTENSIONS: Array[String] = ["tres", "res"]

## type (StringName) -> { id (StringName) -> GameData }
var _items: Dictionary = {}
## GameData -> resource path it was loaded from.
var _paths: Dictionary = {}
var _scan_report := ValidationReport.new()


func _ready() -> void:
	scan()
	if OS.is_debug_build():
		for issue in validate_all().get_errors():
			push_error("ContentDB: %s" % issue.format())


## Re-index everything under [param root]. Returns layout problems found while scanning.
func scan(root: String = DEFAULT_ROOT) -> ValidationReport:
	_items.clear()
	_paths.clear()
	_scan_report = ValidationReport.new()
	if DirAccess.dir_exists_absolute(root):
		_scan_dir(root)
	else:
		_scan_report.error(root, "", "content root does not exist")
	return _scan_report


func get_item(type: StringName, item_id: StringName) -> GameData:
	var by_id: Dictionary = _items.get(type, {})
	return by_id.get(item_id) as GameData


func has_item(type: StringName, item_id: StringName) -> bool:
	return get_item(type, item_id) != null


func get_all(type: StringName) -> Array[GameData]:
	var result: Array[GameData] = []
	var by_id: Dictionary = _items.get(type, {})
	for item: GameData in by_id.values():
		result.append(item)
	return result


func get_types() -> Array[StringName]:
	var result: Array[StringName] = []
	for type: StringName in _items:
		result.append(type)
	return result


func get_scan_report() -> ValidationReport:
	return _scan_report


## Layout problems + every item's validate() + cross-references between items.
func validate_all() -> ValidationReport:
	var report := ValidationReport.new()
	report.merge(_scan_report)
	for type: StringName in _items:
		for item: GameData in (_items[type] as Dictionary).values():
			report.merge(item.validate())
	for item in get_all(&"MatchSettings"):
		_validate_match_settings_refs(item as MatchSettings, report)
	return report


func _scan_dir(dir: String) -> void:
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			_scan_dir(dir.path_join(entry.trim_suffix("/")))
		elif entry.get_extension() in RESOURCE_EXTENSIONS:
			_load_item(dir.path_join(entry))


func _load_item(path: String) -> void:
	var res := ResourceLoader.load(path)
	if res == null:
		_scan_report.error(path, "", "failed to load")
		return
	if not res is GameData:
		return  # helper resources (e.g. shared sub-resources) are not indexed
	var data := res as GameData
	var label := data.source_label()
	var stem := path.get_file().get_basename()
	var folder := path.get_base_dir().get_file()
	if String(data.id) != stem:
		_scan_report.error(label, "id", "must equal the file name '%s' (%s)" % [stem, path])
	if folder != stem:
		_scan_report.error(label, "", "must live in a folder named '%s' (%s)" % [stem, path])
	var type := data.get_type_name()
	if not _items.has(type):
		_items[type] = {}
	var by_id: Dictionary = _items[type]
	if by_id.has(data.id):
		var first: String = _paths[by_id[data.id]]
		_scan_report.error(label, "id", "duplicate id; also defined in %s (%s)" % [first, path])
		return
	by_id[data.id] = data
	_paths[data] = path


func _validate_match_settings_refs(settings: MatchSettings, report: ValidationReport) -> void:
	var source := settings.source_label()
	for weapon_id in settings.allowed_weapons:
		report.check(
			has_item(&"WeaponData", weapon_id),
			source,
			"allowed_weapons",
			"unknown weapon '%s'" % weapon_id
		)
	for perk_id in settings.allowed_perks:
		report.check(
			has_item(&"PerkData", perk_id), source, "allowed_perks", "unknown perk '%s'" % perk_id
		)
	var firearms := 0
	var melee := 0
	for weapon_id in settings.starting_loadout:
		var weapon := get_item(&"WeaponData", weapon_id) as WeaponData
		if weapon == null:
			report.error(source, "starting_loadout", "unknown weapon '%s'" % weapon_id)
		elif weapon.slot == WeaponData.Slot.MELEE:
			melee += 1
		else:
			firearms += 1
	report.check(
		firearms <= MatchSettings.MAX_LOADOUT_FIREARMS,
		source,
		"starting_loadout",
		"has %d firearms (max %d)" % [firearms, MatchSettings.MAX_LOADOUT_FIREARMS]
	)
	report.check(
		melee <= MatchSettings.MAX_LOADOUT_MELEE,
		source,
		"starting_loadout",
		"has %d melee weapons (max %d)" % [melee, MatchSettings.MAX_LOADOUT_MELEE]
	)
