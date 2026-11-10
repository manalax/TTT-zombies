class_name PerkComponent
extends Node
## A player's perks ("Sacraments", DESIGN §10.2, docs/adr/0011-shops-perks.md).
## Each perk is owned at most once, up to MatchSettings.max_perks. Systems read the combined
## effect with [method stat]: "_add" keys sum (base 0), "_mult" keys multiply (base 1).
## Adding a perk calls Player.apply_perks() for stats derived at spawn (health, stamina regen).

signal changed

var owned: Array[PerkData] = []


func has(perk_id: StringName) -> bool:
	for perk in owned:
		if perk.id == perk_id:
			return true
	return false


func count() -> int:
	return owned.size()


static func max_perks(settings: MatchSettings = null) -> int:
	if settings == null:
		settings = Settings.match_settings
	return settings.max_perks if settings != null else 4


## Why [param perk] cannot be added: &"" if it can, else &"owned" / &"limit" / &"invalid".
func add_block_reason(perk: PerkData, settings: MatchSettings = null) -> StringName:
	if perk == null:
		return &"invalid"
	if has(perk.id):
		return &"owned"
	if count() >= max_perks(settings):
		return &"limit"
	return &""


## Adds [param perk] (authority). Returns false if owned, over the limit or invalid.
func add(perk: PerkData) -> bool:
	if not Net.is_authority() or add_block_reason(perk) != &"":
		return false
	owned.append(perk)
	_apply()
	changed.emit()
	return true


func clear() -> void:
	if not Net.is_authority():
		return
	owned.clear()
	_apply()
	changed.emit()


## Combined value of [param key] over all owned perks.
func stat(key: StringName) -> float:
	var additive := String(key).ends_with("_add")
	var value := 0.0 if additive else 1.0
	for perk in owned:
		if not perk.stat_modifiers.has(key):
			continue
		if additive:
			value += perk.stat_modifiers[key]
		else:
			value *= perk.stat_modifiers[key]
	return value


func names() -> PackedStringArray:
	var result := PackedStringArray()
	for perk in owned:
		result.append(perk.display_name)
	return result


func _apply() -> void:
	var player := get_parent() as Player
	if player != null:
		player.apply_perks()
