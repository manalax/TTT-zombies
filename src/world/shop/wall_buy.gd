class_name WallBuy
extends ShopStation
## Sells one weapon (DESIGN §10.2). Firearm: if you don't own it, buy it for
## shop_price(wall_cost) into Loadout.firearm_slot_for_pickup() (the old gun is discarded; the new
## one comes with fresh ammo); if you own it, refill its reserve for ammo_price(ammo_cost).
## Melee: replaces the melee slot; disabled while you own it.

@export var weapon_id: StringName = &"revolver"

var weapon: WeaponData


func _setup() -> void:
	weapon = ContentDB.get_item(&"WeaponData", weapon_id) as WeaponData
	if weapon == null:
		push_error("WallBuy '%s': WeaponData '%s' not found." % [name, weapon_id])
	label.text = weapon.display_name if weapon != null else "?"


## The slot holding this weapon for [param player], or Loadout.NONE.
func owned_slot(player: Player) -> int:
	for slot in Loadout.SLOT_COUNT:
		if player.loadout.slots[slot] == weapon:
			return slot
	return Loadout.NONE


func buy_price() -> int:
	return PointRules.shop_price(weapon.wall_cost)


func refill_price() -> int:
	return PointRules.ammo_price(weapon.firearm_stats.ammo_cost)


func _configure(player: Player) -> void:
	if weapon == null:
		set_offer("Nothing", -1, "Unavailable")
		return
	var title := weapon.display_name
	if not is_allowed(weapon.id, _whitelist()):
		set_offer(title, -1, "Unavailable")
		return
	var slot := owned_slot(player)
	if slot == Loadout.NONE:
		set_offer("Buy %s" % title, buy_price())
	elif weapon.slot == WeaponData.Slot.MELEE:
		set_offer(title, -1, "Owned")
	elif _reserve_full(player, slot):
		set_offer("%s ammo" % title, -1, "Ammo full")
	else:
		set_offer("%s ammo" % title, refill_price())


func _purchase(player: Player) -> void:
	var slot := owned_slot(player)
	if slot == Loadout.NONE:
		var target := (
			Loadout.MELEE
			if weapon.slot == WeaponData.Slot.MELEE
			else player.loadout.firearm_slot_for_pickup()
		)
		if not charge(player, buy_price(), &"wall_buy"):
			return
		player.loadout.replace_slot(target, weapon)
		if player.loadout.active_slot != target:
			player.loadout.request_slot(target)
		announce(player, &"weapon", weapon.id)
	elif weapon.slot == WeaponData.Slot.FIREARM and not _reserve_full(player, slot):
		if charge(player, refill_price(), &"ammo"):
			player.loadout.grant_ammo(slot, weapon.firearm_stats.reserve_cap)


static func _reserve_full(player: Player, slot: int) -> bool:
	var ammo := player.loadout.ammo[slot]
	return ammo == null or ammo.reserve >= ammo.reserve_cap


static func _whitelist() -> Array[StringName]:
	var settings := Settings.match_settings
	return settings.allowed_weapons if settings != null else ([] as Array[StringName])
