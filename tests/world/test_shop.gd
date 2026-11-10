# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F018 acceptance: purchases deduct points and put weapons in the right loadout slots.

const World := preload("res://tests/enemies/enemy_test_world.gd")
const WALL_BUY := preload("res://src/world/shop/wall_buy.tscn")
const AMMO_STATION := preload("res://src/world/shop/ammo_station.tscn")
const PERK_ALTAR := preload("res://src/world/shop/perk_altar.tscn")
const DT := 1.0 / 60.0

var _world: Node3D
var _player: Player
var _settings: MatchSettings
var _saved: MatchSettings
var _purchases: Array[Array] = []


func before_test() -> void:
	_saved = Settings.match_settings
	_settings = _saved.duplicate() as MatchSettings
	Settings.match_settings = _settings
	_purchases.clear()
	Events.item_purchased.connect(_on_purchased)
	_world = auto_free(World.world(20.0))
	add_child(_world)
	_player = World.player(_world, Vector3.ZERO)
	_player.set_physics_process(false)
	_player.loadout.setup([&"revolver", &"arming_sword"])  # FIREARM_A revolver, B empty
	_player.points.reset(10000)


func after_test() -> void:
	Events.item_purchased.disconnect(_on_purchased)
	Settings.match_settings = _saved


func _on_purchased(peer_id: int, kind: StringName, item_id: StringName) -> void:
	_purchases.append([peer_id, kind, item_id])


## Puts [param scene] 1.3 m in front of the player (who faces -Z) and waits for physics.
func _station(scene: PackedScene, setup: Callable = Callable()) -> ShopStation:
	var station: ShopStation = scene.instantiate()
	station.position = Vector3(0, 0, -1.3)
	if setup.is_valid():
		setup.call(station)
	_world.add_child(station)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return station


func _wall_buy(weapon_id: StringName) -> WallBuy:
	return await _station(WALL_BUY, func(s: WallBuy) -> void: s.weapon_id = weapon_id)


func _prompt() -> String:
	var target := _player.get_interact_target()
	return target.get_prompt_text(_player) if target != null else ""


func _steps(count: int) -> void:
	for i in count:
		_player.step(DT)


# --- Firearm wall-buy ---------------------------------------------------------------------


func test_buy_firearm_into_active_slot_and_discard_old() -> void:
	var station := await _wall_buy(&"rifle")
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)
	assert_str(_prompt()).is_equal("E: Buy Hunting Rifle [2000]")
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(8000)
	assert_str(_player.loadout.slots[Loadout.FIREARM_A].id).is_equal("rifle")
	assert_object(_player.loadout.slots[Loadout.FIREARM_B]).is_null()
	var ammo := _player.loadout.ammo[Loadout.FIREARM_A]
	assert_int(ammo.mag).is_equal(station.weapon.firearm_stats.mag_size)
	assert_int(ammo.reserve).is_equal(station.weapon.firearm_stats.reserve_cap)
	assert_array(_purchases).contains_exactly([[_player.health.peer_id, &"weapon", &"rifle"]])


func test_buy_with_melee_out_goes_to_empty_firearm_slot_and_draws_it() -> void:
	await _wall_buy(&"blunderbuss")
	assert_bool(_player.loadout.is_melee_active()).is_true()
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(10000 - 1250)
	assert_str(_player.loadout.slots[Loadout.FIREARM_A].id).is_equal("revolver")
	assert_str(_player.loadout.slots[Loadout.FIREARM_B].id).is_equal("blunderbuss")
	_steps(40)
	assert_int(_player.loadout.active_slot).is_equal(Loadout.FIREARM_B)


func test_shop_price_multiplier_applies() -> void:
	_settings.shop_price_mult = 1.5
	await _wall_buy(&"rifle")
	assert_str(_prompt()).is_equal("E: Buy Hunting Rifle [3000]")
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(7000)


func test_owned_firearm_refills_ammo() -> void:
	var station := await _wall_buy(&"revolver")
	var ammo := _player.loadout.ammo[Loadout.FIREARM_A]
	assert_str(_prompt()).is_equal("Service Revolver ammo — Ammo full")
	assert_bool(_player.try_interact()).is_false()
	assert_int(_player.points.balance).is_equal(10000)
	ammo.reserve = 2
	var price := PointRules.ammo_price(station.weapon.firearm_stats.ammo_cost)
	assert_str(_prompt()).is_equal("E: Service Revolver ammo [%d]" % price)
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(10000 - price)
	assert_int(ammo.reserve).is_equal(ammo.reserve_cap)
	assert_array(_purchases).is_empty()  # ammo is not announced


func test_refill_follows_scarcity() -> void:
	_settings.ammo_scarcity = 2.0
	var station := await _wall_buy(&"revolver")
	var ammo := _player.loadout.ammo[Loadout.FIREARM_A]
	ammo.reserve = 0
	var base := station.weapon.firearm_stats.ammo_cost
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(10000 - PointRules.round_up(base * 2.0, 10))
	assert_int(ammo.reserve).is_equal(AmmoRules.grant(ammo.reserve_cap, _settings))


func test_not_enough_points_changes_nothing() -> void:
	await _wall_buy(&"rifle")
	_player.points.reset(1500)
	var denied: Array[StringName] = []
	_player.interact_denied.connect(func(r: StringName) -> void: denied.append(r))
	assert_bool(_player.try_interact()).is_false()
	assert_array(denied).contains_exactly([&"points"])
	assert_int(_player.points.balance).is_equal(1500)
	assert_str(_player.loadout.slots[Loadout.FIREARM_A].id).is_equal("revolver")
	assert_array(_purchases).is_empty()


# --- Melee wall-buy -----------------------------------------------------------------------


func test_melee_wall_buy_replaces_melee_slot() -> void:
	await _wall_buy(&"greatsword")
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(10000 - 1500)
	assert_str(_player.loadout.slots[Loadout.MELEE].id).is_equal("greatsword")
	assert_str(_player.loadout.slots[Loadout.FIREARM_A].id).is_equal("revolver")
	assert_str(_prompt()).is_equal("Greatsword — Owned")
	assert_bool(_player.try_interact()).is_false()
	assert_int(_player.points.balance).is_equal(8500)


# --- Ammo station -------------------------------------------------------------------------


func test_ammo_station_refills_held_gun_only() -> void:
	await _station(AMMO_STATION)
	assert_str(_prompt()).is_equal("Refill ammo — Draw a firearm")
	assert_bool(_player.try_interact()).is_false()
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)
	assert_str(_prompt()).contains("Ammo full")
	var ammo := _player.loadout.ammo[Loadout.FIREARM_A]
	ammo.reserve = 5
	var price := AmmoStation.price_for(_player.loadout.slots[Loadout.FIREARM_A])
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(10000 - price)
	assert_int(ammo.reserve).is_equal(ammo.reserve_cap)


func test_ammo_station_at_scarcity_two_grants_half() -> void:
	_settings.ammo_scarcity = 2.0
	await _station(AMMO_STATION)
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)
	var ammo := _player.loadout.ammo[Loadout.FIREARM_A]
	ammo.reserve = 0
	assert_bool(_player.try_interact()).is_true()
	assert_int(ammo.reserve).is_equal(ammo.reserve_cap / 2)


# --- Perk altar ---------------------------------------------------------------------------


func test_perk_altar_sells_once_and_applies() -> void:
	await _station(PERK_ALTAR)
	Combat.apply(DamageEvent.world(_player.health, 25.0, CombatTypes.DamageType.DEBUG))
	assert_str(_prompt()).is_equal("E: Take Iron Constitution [2500]")
	assert_bool(_player.try_interact()).is_true()
	assert_int(_player.points.balance).is_equal(7500)
	assert_bool(_player.perks.has(&"iron_constitution")).is_true()
	assert_float(_player.health.max_health).is_equal(125.0)
	assert_float(_player.health.current_health).is_equal(100.0)  # 75 + 25
	assert_str(_prompt()).is_equal("Iron Constitution — Owned")
	assert_bool(_player.try_interact()).is_false()
	assert_int(_player.points.balance).is_equal(7500)
	assert_array(_purchases).contains_exactly(
		[[_player.health.peer_id, &"perk", &"iron_constitution"]]
	)


func test_perk_limit_blocks_purchase() -> void:
	_settings.max_perks = 1
	_player.perks.add(ContentDB.get_item(&"PerkData", &"sure_grip") as PerkData)
	await _station(PERK_ALTAR)
	assert_str(_prompt()).is_equal("Take Iron Constitution — Perk limit")
	assert_bool(_player.try_interact()).is_false()
	assert_int(_player.points.balance).is_equal(10000)
	assert_int(_player.perks.count()).is_equal(1)


# --- Whitelists ---------------------------------------------------------------------------


func test_whitelists_disable_stations() -> void:
	_settings.allowed_weapons = [&"revolver"] as Array[StringName]
	var station := await _wall_buy(&"rifle")
	assert_str(_prompt()).is_equal("Hunting Rifle — Unavailable")
	assert_bool(_player.try_interact()).is_false()
	station.free()
	_settings.allowed_perks = [&"riposte"] as Array[StringName]
	await _station(PERK_ALTAR)
	assert_str(_prompt()).contains("Unavailable")
	assert_bool(_player.try_interact()).is_false()
	assert_int(_player.points.balance).is_equal(10000)
