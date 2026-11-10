class_name AmmoStation
extends ShopStation
## Refills the held firearm's reserve (DESIGN §6.4) for ammo_price(its ammo_cost), through
## Loadout.grant_ammo(slot, reserve_cap), so ammo_scarcity and the cap apply.


func _setup() -> void:
	label.text = "Ammunition"


func _configure(player: Player) -> void:
	var slot := player.loadout.active_slot
	if not Loadout.is_firearm_slot(slot) or player.loadout.slots[slot] == null:
		set_offer("Refill ammo", -1, "Draw a firearm")
		return
	var gun := player.loadout.slots[slot]
	var ammo := player.loadout.ammo[slot]
	if ammo.reserve >= ammo.reserve_cap:
		set_offer("Refill %s" % gun.display_name, -1, "Ammo full")
	else:
		set_offer("Refill %s" % gun.display_name, price_for(gun))


static func price_for(gun: WeaponData) -> int:
	return PointRules.ammo_price(gun.firearm_stats.ammo_cost)


func _purchase(player: Player) -> void:
	var slot := player.loadout.active_slot
	if not Loadout.is_firearm_slot(slot) or player.loadout.slots[slot] == null:
		return
	var gun := player.loadout.slots[slot]
	var ammo := player.loadout.ammo[slot]
	if ammo.reserve >= ammo.reserve_cap:
		return
	if charge(player, price_for(gun), &"ammo"):
		player.loadout.grant_ammo(slot, gun.firearm_stats.reserve_cap)
