class_name PerkAltar
extends ShopStation
## Sells one perk ("Sacrament", DESIGN §10.2) for shop_price(cost). Each perk once per player, up
## to MatchSettings.max_perks; disabled if the host's allowed_perks excludes it.

@export var perk_id: StringName = &"iron_constitution"

var perk: PerkData


func _setup() -> void:
	perk = ContentDB.get_item(&"PerkData", perk_id) as PerkData
	if perk == null:
		push_error("PerkAltar '%s': PerkData '%s' not found." % [name, perk_id])
	label.text = perk.display_name if perk != null else "?"


func price() -> int:
	return PointRules.shop_price(perk.cost)


func _configure(player: Player) -> void:
	if perk == null:
		set_offer("Nothing", -1, "Unavailable")
		return
	var title := "Take %s" % perk.display_name
	if not is_allowed(perk.id, _whitelist()):
		set_offer(title, -1, "Unavailable")
		return
	match player.perks.add_block_reason(perk):
		&"owned":
			set_offer(perk.display_name, -1, "Owned")
		&"limit":
			set_offer(title, -1, "Perk limit")
		_:
			set_offer(title, price())


func _purchase(player: Player) -> void:
	if player.perks.add_block_reason(perk) != &"":
		return
	if charge(player, price(), &"perk"):
		player.perks.add(perk)
		announce(player, &"perk", perk.id)


static func _whitelist() -> Array[StringName]:
	var settings := Settings.match_settings
	return settings.allowed_perks if settings != null else ([] as Array[StringName])
