class_name DataSerializer
extends RefCounted
## Converts data resources to/from JSON-safe Dictionaries (docs/adr/0002-content-data-model.md).
##
## Used for lobby replication (MatchSettings, F025) and sharing custom wave sets (F061).
## Rules:
## - Standalone [GameData] (its own .tres) is written as {"ref": "Type:id"} and resolved through
##   the content registry. Embedded resources are written inline as {"type": "Class", ...}.
## - Enums are written by constant name, StringNames as Strings.
## - Asset slots (textures, scenes, ...) are not serialized; peers load them locally.
## - [method from_dict] input may come from the network: only classes in [constant ALLOWED_TYPES]
##   are ever instantiated, and no Variant/object decoding (str_to_var etc.) is used.

const SCHEMA_VERSION := 1
const ALLOWED_TYPES: Array[StringName] = [
	&"MatchSettings",
	&"WaveSet",
	&"WaveData",
	&"WaveEntry",
	&"WaveModifier",
	&"EnemyData",
	&"WeaponData",
	&"MeleeStats",
	&"FirearmStats",
	&"PerkData",
	&"DoorData",
	&"BarricadeData",
	&"LootTable",
	&"LootEntry",
]
const META_KEYS: Array[String] = ["schema", "type"]

## Global class name -> {"path": String, "base": StringName}. Built lazily.
static var _classes: Dictionary = {}


static func to_dict(res: Resource) -> Dictionary:
	var out := _encode_object(res)
	out["schema"] = SCHEMA_VERSION
	return out


## Returns {"resource": Resource or null, "report": ValidationReport}. Decoding problems are
## reported as errors (unknown fields as warnings); fields that fail to decode keep defaults.
## The decoded resource is not validated here; call validate() on it.
static func from_dict(
	data: Dictionary, expected_type: StringName = &"", db: ContentRegistry = null
) -> Dictionary:
	var report := ValidationReport.new()
	var registry := db if db != null else _default_registry()
	var schema: Variant = data.get("schema")
	var res: Resource = null
	if not _is_integral(schema) or int(schema) != SCHEMA_VERSION:
		report.error("root", "schema", "unsupported %s (expected %d)" % [schema, SCHEMA_VERSION])
	else:
		res = _decode_object(data, expected_type, registry, report, "root")
	return {"resource": res, "report": report}


# --- Encoding ---------------------------------------------------------------------------------


static func _encode_object(res: Resource) -> Dictionary:
	var out := {"type": String(_type_of(res))}
	for prop in _storage_props(res):
		var prop_name: String = prop["name"]
		var value: Variant = res.get(prop_name)
		if _is_asset_slot(prop, value):
			continue
		out[prop_name] = _encode_value(res, prop, value)
	return out


static func _encode_value(res: Resource, prop: Dictionary, value: Variant) -> Variant:
	if typeof(value) == TYPE_INT:
		var names := _enum_names(res, prop)
		if not names.is_empty():
			var key: Variant = names.find_key(value)
			return key if key != null else value
	return _encode_element(value)


static func _encode_element(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_OBJECT:
			return _encode_resource_value(value as Resource)
		TYPE_ARRAY:
			var out := []
			for item: Variant in value:
				out.append(_encode_element(item))
			return out
		TYPE_DICTIONARY:
			var out := {}
			var dict: Dictionary = value
			for key: Variant in dict:
				out[str(key)] = _encode_element(dict[key])
			return out
		TYPE_PACKED_FLOAT32_ARRAY:
			return Array(value as PackedFloat32Array)
	return value


static func _encode_resource_value(res: Resource) -> Variant:
	if res == null:
		return null
	if res is GameData and (res as GameData).is_standalone():
		var data := res as GameData
		return {"ref": "%s:%s" % [data.get_type_name(), data.id]}
	if _type_of(res) in ALLOWED_TYPES:
		return _encode_object(res)
	return null


# --- Decoding ---------------------------------------------------------------------------------


static func _decode_object(
	data: Dictionary,
	expected: StringName,
	db: ContentRegistry,
	report: ValidationReport,
	path: String
) -> Resource:
	var type := StringName(str(data.get("type", "")))
	if not type in ALLOWED_TYPES:
		report.error(path, "type", "'%s' is not an allowed data type" % type)
		return null
	if expected != &"" and not _is_a(type, expected):
		report.error(path, "type", "expected %s, got %s" % [expected, type])
		return null
	var script := _script_for(type)
	if script == null:
		report.error(path, "type", "no script for '%s'" % type)
		return null
	var res: Resource = script.new()
	var props := {}
	for prop in _storage_props(res):
		props[prop["name"]] = prop
	for raw_key: Variant in data:
		var key := str(raw_key)
		if key in META_KEYS:
			continue
		if not props.has(key) or _is_asset_slot(props[key], res.get(key)):
			report.warn(path, key, "unknown or non-serializable field, ignored")
			continue
		var result := _decode_value(
			res, props[key], res.get(key), data[raw_key], db, report, "%s.%s" % [path, key]
		)
		if result[0]:
			res.set(key, result[1])
	return res


## Returns [ok: bool, value].
static func _decode_value(
	res: Resource,
	prop: Dictionary,
	current: Variant,
	raw: Variant,
	db: ContentRegistry,
	report: ValidationReport,
	path: String
) -> Array:
	var type: int = prop["type"]
	match type:
		TYPE_BOOL:
			if raw is bool:
				return [true, raw]
		TYPE_INT:
			var names := _enum_names(res, prop)
			if not names.is_empty():
				if raw is String and names.has(raw):
					return [true, names[raw]]
				report.error(path, "", "expected one of %s, got %s" % [names.keys(), raw])
				return [false, null]
			if _is_integral(raw):
				return [true, int(raw)]
		TYPE_FLOAT:
			if raw is int or raw is float:
				return [true, float(raw)]
		TYPE_STRING:
			if raw is String:
				return [true, raw]
		TYPE_STRING_NAME:
			if raw is String or raw is StringName:
				return [true, StringName(str(raw))]
		TYPE_PACKED_FLOAT32_ARRAY:
			if (
				raw is Array
				and (raw as Array).all(func(v: Variant) -> bool: return v is float or v is int)
			):
				return [true, PackedFloat32Array(raw as Array)]
		TYPE_OBJECT:
			return _decode_resource_value(
				StringName(prop.get("class_name", "")), raw, db, report, path
			)
		TYPE_ARRAY:
			if raw is Array and current is Array:
				return _decode_array(current as Array, raw as Array, db, report, path)
		TYPE_DICTIONARY:
			if raw is Dictionary and current is Dictionary:
				return _decode_dictionary(
					current as Dictionary, raw as Dictionary, db, report, path
				)
	report.error(path, "", "expected %s, got %s" % [type_string(type), type_string(typeof(raw))])
	return [false, null]


static func _decode_resource_value(
	expected: StringName, raw: Variant, db: ContentRegistry, report: ValidationReport, path: String
) -> Array:
	if raw == null:
		return [true, null]
	if not raw is Dictionary:
		report.error(path, "", "expected an object or null")
		return [false, null]
	var data: Dictionary = raw
	if not data.has("ref"):
		var obj := _decode_object(data, expected, db, report, path)
		return [obj != null, obj]
	var ref := str(data["ref"])
	var type := StringName(ref.get_slice(":", 0))
	var item_id := StringName(ref.get_slice(":", 1))
	if ref.get_slice_count(":") != 2 or not type in ALLOWED_TYPES or not _is_a(type, expected):
		report.error(path, "ref", "invalid reference '%s' (expected %s)" % [ref, expected])
		return [false, null]
	if db == null:
		report.error(path, "ref", "no content registry to resolve '%s'" % ref)
		return [false, null]
	var item := db.get_item(type, item_id)
	if item == null:
		report.error(path, "ref", "unknown content '%s'" % ref)
		return [false, null]
	return [true, item]


static func _decode_array(
	current: Array, raw: Array, db: ContentRegistry, report: ValidationReport, path: String
) -> Array:
	var out := current.duplicate()
	out.clear()
	var builtin := current.get_typed_builtin()
	if builtin == TYPE_NIL:
		report.error(path, "", "untyped arrays are not serializable")
		return [false, null]
	var element_class := StringName(current.get_typed_class_name())
	var element_script := current.get_typed_script() as Script
	if element_script != null:
		element_class = element_script.get_global_name()
	for i in raw.size():
		var item_path := "%s[%d]" % [path, i]
		var result: Array
		if builtin == TYPE_OBJECT:
			result = _decode_resource_value(element_class, raw[i], db, report, item_path)
			if result[0] and result[1] == null:
				report.error(item_path, "", "null elements are not allowed")
				return [false, null]
		else:
			result = _decode_value(null, {"type": builtin}, null, raw[i], db, report, item_path)
		if not result[0]:
			return [false, null]
		out.append(result[1])
	return [true, out]


static func _decode_dictionary(
	current: Dictionary,
	raw: Dictionary,
	db: ContentRegistry,
	report: ValidationReport,
	path: String
) -> Array:
	var out := current.duplicate()
	out.clear()
	var key_prop := {"type": current.get_typed_key_builtin()}
	var value_prop := {"type": current.get_typed_value_builtin()}
	if key_prop["type"] == TYPE_NIL or value_prop["type"] in [TYPE_NIL, TYPE_OBJECT]:
		report.error(path, "", "only typed dictionaries of plain values are serializable")
		return [false, null]
	for raw_key: Variant in raw:
		var item_path := "%s[%s]" % [path, raw_key]
		var key_result := _decode_value(null, key_prop, null, raw_key, db, report, item_path)
		var value_result := _decode_value(
			null, value_prop, null, raw[raw_key], db, report, item_path
		)
		if not key_result[0] or not value_result[0]:
			return [false, null]
		out[key_result[1]] = value_result[1]
	return [true, out]


# --- Reflection helpers -----------------------------------------------------------------------


static func _storage_props(res: Resource) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for prop in res.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_STORAGE:
			result.append(prop)
	return result


## Object-typed properties whose class is not a data type (textures, scenes, audio...).
static func _is_asset_slot(prop: Dictionary, _value: Variant) -> bool:
	if prop["type"] != TYPE_OBJECT:
		return false
	return not StringName(prop.get("class_name", "")) in ALLOWED_TYPES


## Constant name -> value for an enum-typed int property, or {} if it is a plain int.
static func _enum_names(res: Resource, prop: Dictionary) -> Dictionary:
	if res == null or prop.get("hint", PROPERTY_HINT_NONE) != PROPERTY_HINT_ENUM:
		return {}
	var qualified := str(prop.get("class_name", ""))
	if not qualified.contains("."):
		return {}
	var script := _script_for(StringName(qualified.get_slice(".", 0)))
	if script == null:
		return {}
	var enum_map: Variant = script.get_script_constant_map().get(qualified.get_slice(".", 1))
	return enum_map if enum_map is Dictionary else {}


static func _type_of(res: Resource) -> StringName:
	var script := res.get_script() as Script
	return script.get_global_name() if script != null else StringName(res.get_class())


static func _is_a(type: StringName, base: StringName) -> bool:
	var current := type
	while current != &"":
		if current == base:
			return true
		current = _class_table().get(current, {}).get("base", &"")
	return false


static func _script_for(type: StringName) -> Script:
	var info: Dictionary = _class_table().get(type, {})
	if info.is_empty():
		return null
	return load(str(info["path"])) as Script


static func _class_table() -> Dictionary:
	if _classes.is_empty():
		for entry in ProjectSettings.get_global_class_list():
			_classes[StringName(entry["class"])] = {
				"path": entry["path"], "base": StringName(entry["base"])
			}
	return _classes


static func _is_integral(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_equal_approx(value, roundf(value))


static func _default_registry() -> ContentRegistry:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(^"ContentDB") as ContentRegistry
