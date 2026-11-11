extends GdUnitTestSuite
## F014: the placeholder HUD readout and hit markers, against the real sandbox arena.

const ARENA := preload("res://maps/dev/sandbox_arena/sandbox_arena.tscn")

var _arena: Node3D
var _hud: TempHud
var _player: Player


func before_test() -> void:
	_arena = auto_free(ARENA.instantiate())
	add_child(_arena)
	_hud = auto_free(TempHud.new())
	add_child(_hud)
	await get_tree().physics_frame
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group(Player.LOCAL_GROUP) as Player


func after_test() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func test_sandbox_loadout_and_readout() -> void:
	assert_str(_player.loadout.slots[Loadout.FIREARM_B].id).is_equal("blunderbuss")
	assert_str(_hud.readout()).is_equal("ARMING SWORD")
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)
	assert_str(_hud.readout()).is_equal("SERVICE REVOLVER  6 / 12")
	_player.loadout.ammo[Loadout.FIREARM_A].mag = 0
	assert_str(_hud.readout()).contains("RELOAD")
	_player.loadout.request_slot(Loadout.FIREARM_B)
	assert_str(_hud.readout()).contains("SWITCHING")


func test_hit_marker_colours() -> void:
	var dummy: TrainingDummy = _arena.get_node("Dummies/DummyPlain")
	var normal := DamageEvent.world(dummy.health, 10)
	_hud._on_hits([Combat.apply(normal)])
	assert_float(_hud.hit_marker_left).is_greater(0.0)
	assert_object(_hud.hit_marker_color).is_equal(Color.WHITE)
	var lethal := DamageEvent.world(dummy.health, 1000)
	_hud._on_hits([Combat.apply(lethal)])
	assert_object(_hud.hit_marker_color).is_equal(Color(1.0, 0.2, 0.2))


func test_arena_shop_layout() -> void:
	assert_str((_arena.get_node("Shop/RevolverWallBuy") as WallBuy).weapon.id).is_equal("revolver")
	assert_str((_arena.get_node("Shop/RifleWallBuy") as WallBuy).weapon.id).is_equal("rifle")
	assert_int(_arena.get_node("Shop").get_child_count()).is_equal(9)


func test_points_balance_and_popups() -> void:
	await get_tree().process_frame
	assert_str(_hud.points_text()).is_equal("POINTS  %d" % _player.points.balance)
	var dummy: TrainingDummy = _arena.get_node("Dummies/DummyPlain")
	var before := _player.points.balance
	var event := DamageEvent.from_source(
		_player.health, dummy.health, 15.0, CombatTypes.DamageType.MELEE
	)
	Combat.apply(event)
	assert_int(_player.points.balance).is_equal(before + 20)
	assert_int(_hud.popup_count()).is_equal(1)
	assert_str((_hud.get_node("PointPopups").get_child(0) as Label).text).is_equal("+20")
	await get_tree().process_frame
	assert_str(_hud.points_text()).is_equal("POINTS  %d" % (before + 20))
	await get_tree().create_timer(TempHud.POPUP_S + 0.2).timeout
	await get_tree().process_frame
	assert_int(_hud.popup_count()).is_equal(0)


func test_interact_prompt_and_deny_flash() -> void:
	# Stand in front of the annex gate (west wall, z = -6), looking at it (-X).
	_player.global_position = Vector3(-28.4, 0.05, -6)
	_player.yaw = PI * 0.5
	_player.rotation.y = _player.yaw
	_player.points.reset(500)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	assert_str(_hud.prompt_text()).is_equal("E: Open Annex Gate [750]")
	assert_object(_hud.prompt_color()).is_equal(TempHud.DENY_COLOR)
	assert_bool(_player.try_interact()).is_false()
	await get_tree().process_frame
	assert_str(_hud.prompt_text()).contains("Not enough points")
	_player.points.reset(1000)
	assert_bool(_player.try_interact()).is_true()
	assert_array(_hud.feed_lines()).contains(["Player 1 opened the Annex Gate"])


func test_purchase_feed_and_perk_line() -> void:
	Events.item_purchased.emit(1, &"weapon", &"rifle")
	Events.item_purchased.emit(1, &"perk", &"sure_grip")
	assert_array(_hud.feed_lines()).contains(
		["Player 1 bought the Hunting Rifle", "Player 1 took the Sure Grip sacrament"]
	)
	_player.perks.add(ContentDB.get_item(&"PerkData", &"sure_grip") as PerkData)
	assert_str(_hud.points_text()).contains("Sure Grip")


func test_round_counter_timer_and_banners() -> void:
	var manager: MatchManager = _arena.get_node("MatchManager")
	assert_str(_hud.round_text()).is_equal("")
	assert_bool(manager.start_match()).is_true()
	assert_str(_hud.round_text()).is_equal("Next round in 0:30")
	Events.round_started.emit(1)
	assert_str(_hud.banner_text()).is_equal("ROUND 1")
	Events.match_ended.emit(&"cult")
	assert_str(_hud.banner_text()).is_equal("DEFEAT")


func test_health_readout() -> void:
	var health := _player.health
	var full := ceili(health.max_health)
	assert_str(_hud.health_text()).is_equal("HP  %d / %d" % [full, full])
	assert_bool(_hud.health_low()).is_false()
	Combat.apply(DamageEvent.world(health, 25.5, CombatTypes.DamageType.DEBUG))
	assert_str(_hud.health_text()).is_equal("HP  %d / %d" % [ceili(full - 25.5), full])
	Combat.apply(DamageEvent.world(health, health.current_health - 20.0))
	assert_bool(_hud.health_low()).is_true()
	await get_tree().process_frame
	var bar: ProgressBar = _hud.get_node("BottomLeft/Health/Bar")
	assert_float(bar.max_value).is_equal(health.max_health)
	assert_float(bar.value).is_equal(health.current_health)
	health.set_max(health.max_health + 25.0)
	assert_str(_hud.health_text()).ends_with("/ %d" % (full + 25))


func test_charge_ring() -> void:
	var melee := _player.melee
	var heavy := melee.stats.heavy_charge_s
	assert_float(_hud.charge_ring_ratio()).is_equal(-1.0)
	assert_bool(melee.machine.transition_to(&"Charging")).is_true()
	melee.charge_s = TempHud.CHARGE_RING_DELAY_S * 0.5
	assert_float(_hud.charge_ring_ratio()).is_equal(-1.0)  # a tap draws nothing
	melee.charge_s = heavy * 0.5
	assert_float(_hud.charge_ring_ratio()).is_equal_approx(0.5, 0.001)
	assert_object(_hud.charge_ring_color()).is_equal(Color.WHITE)
	melee.charge_s = heavy
	assert_float(_hud.charge_ring_ratio()).is_equal(1.0)
	assert_object(_hud.charge_ring_color()).is_equal(TempHud.WEAKPOINT_COLOR)
	_player.stamina.current = 0.0
	assert_object(_hud.charge_ring_color()).is_equal(TempHud.DENY_COLOR)
	_player.loadout.set_active_immediate(Loadout.FIREARM_A)
	assert_float(_hud.charge_ring_ratio()).is_equal(-1.0)
