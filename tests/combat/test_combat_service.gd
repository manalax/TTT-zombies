extends GdUnitTestSuite
## F011: the Combat autoload commits pipeline results and announces them.

var _saved_settings: MatchSettings


func before_test() -> void:
	_saved_settings = Settings.match_settings


func after_test() -> void:
	Settings.match_settings = _saved_settings


func _combatant(faction: CombatTypes.Faction, peer_id: int = 0) -> HealthComponent:
	var body: Node3D = auto_free(Node3D.new())
	var health := HealthComponent.new()
	health.faction = faction
	health.peer_id = peer_id
	body.add_child(health)
	add_child(body)
	health.setup(100)
	return health


func test_sandbox_uses_betrayal_preset() -> void:
	assert_object(Settings.match_settings).is_not_null()
	assert_str(Settings.match_settings.id).is_equal("betrayal")


func test_apply_commits_health() -> void:
	var cult := _combatant(CombatTypes.Faction.CULT)
	var result := Combat.apply(DamageEvent.world(cult, 40))
	assert_bool(result.accepted).is_true()
	assert_float(cult.current_health).is_equal(60.0)


func test_apply_commits_block_stamina() -> void:
	var target := _combatant(CombatTypes.Faction.HUNTER)
	var stamina: StaminaComponent = auto_free(StaminaComponent.new())
	stamina.configure(PlayerDefaults.new())
	var block := BlockState.new()
	block.active = true
	block.stamina = stamina
	target.block = block
	var attacker := _combatant(CombatTypes.Faction.CULT)
	(attacker.get_body() as Node3D).global_position = Vector3(0, 0, -2)
	var result := Combat.apply(
		DamageEvent.from_source(attacker, target, 100, CombatTypes.DamageType.MELEE)
	)
	assert_bool(result.blocked).is_true()
	assert_float(stamina.current).is_equal_approx(100.0 - result.stamina_spent, 0.0001)
	assert_float(target.current_health).is_equal_approx(100.0 - result.applied, 0.0001)


func test_player_events_carry_peer_ids() -> void:
	var victim := _combatant(CombatTypes.Faction.HUNTER, 2)
	var shooter := _combatant(CombatTypes.Faction.HUNTER, 3)
	var damaged: Array = []
	var died: Array = []
	var on_damaged := func(peer: int, source: int, amount: float) -> void:
		damaged.append([peer, source, amount])
	var on_died := func(peer: int, killer: int, cause: StringName) -> void:
		died.append([peer, killer, cause])
	Events.player_damaged.connect(on_damaged)
	Events.player_died.connect(on_died)
	Combat.apply(DamageEvent.from_source(shooter, victim, 30, CombatTypes.DamageType.BULLET))
	Combat.apply(DamageEvent.from_source(shooter, victim, 500, CombatTypes.DamageType.BULLET))
	Events.player_damaged.disconnect(on_damaged)
	Events.player_died.disconnect(on_died)
	assert_array(damaged).contains_exactly([[2, 3, 30.0], [2, 3, 70.0]])
	assert_array(died).contains_exactly([[2, 3, &"bullet"]])


func test_damage_applied_not_emitted_for_rejected() -> void:
	var count := [0]
	var on_applied := func(_result: DamageResult) -> void: count[0] += 1
	Combat.damage_applied.connect(on_applied)
	var vigil: MatchSettings = ContentDB.get_item(&"MatchSettings", &"vigil")
	Settings.match_settings = vigil
	var a := _combatant(CombatTypes.Faction.HUNTER, 2)
	var b := _combatant(CombatTypes.Faction.HUNTER, 3)
	var rejected := Combat.apply(DamageEvent.from_source(a, b, 30, CombatTypes.DamageType.MELEE))
	var accepted := Combat.apply(DamageEvent.world(b, 30))
	Combat.damage_applied.disconnect(on_applied)
	assert_str(rejected.reject_reason).is_equal("friendly_fire_off")
	assert_bool(accepted.accepted).is_true()
	assert_int(count[0]).is_equal(1)
	assert_float(b.current_health).is_equal(70.0)


func test_rules_follow_active_settings() -> void:
	var custom := MatchSettings.new()
	custom.friendly_fire_scale = 0.5
	Settings.match_settings = custom
	var a := _combatant(CombatTypes.Faction.HUNTER, 2)
	var b := _combatant(CombatTypes.Faction.HUNTER, 3)
	var result := Combat.apply(DamageEvent.from_source(a, b, 40, CombatTypes.DamageType.MELEE))
	assert_float(result.applied).is_equal(20.0)


func test_parry_stuns_attacker_and_riposte_is_consumed() -> void:
	var parrier := _combatant(CombatTypes.Faction.HUNTER, 2)
	var stamina: StaminaComponent = auto_free(StaminaComponent.new())
	stamina.configure(PlayerDefaults.new())
	var block := BlockState.new()
	block.active = true
	block.stamina = stamina
	block.parry_stun_s = 1.2
	parrier.block = block
	block.open_parry_window()
	var attacker := _combatant(CombatTypes.Faction.CULT)
	(attacker.get_body() as Node3D).global_position = Vector3(0, 0, -2)
	var stuns: Array[float] = []
	attacker.stunned.connect(func(d: float) -> void: stuns.append(d))
	var parried := Combat.apply(
		DamageEvent.from_source(attacker, parrier, 50, CombatTypes.DamageType.MELEE)
	)
	assert_bool(parried.parried).is_true()
	assert_float(parrier.current_health).is_equal(100.0)
	assert_float(stamina.current).is_equal(100.0)
	assert_array(stuns).contains_exactly([1.2])
	assert_object(attacker.riposte_by).is_same(parrier)
	assert_bool(block.is_locked_out()).is_false()
	assert_float(block.last_timing_ms).is_equal_approx(-200.0, 0.01)

	var riposte := DamageEvent.from_source(parrier, attacker, 30, CombatTypes.DamageType.MELEE)
	riposte.riposte_mult = 2.5
	assert_float(Combat.apply(riposte).applied).is_equal(75.0)
	assert_object(attacker.riposte_by).is_null()
	var follow_up := DamageEvent.from_source(parrier, attacker, 10, CombatTypes.DamageType.MELEE)
	follow_up.riposte_mult = 2.5
	assert_float(Combat.apply(follow_up).applied).is_equal(10.0)


func test_stun_expires_with_tick() -> void:
	var a := _combatant(CombatTypes.Faction.CULT)
	var b := _combatant(CombatTypes.Faction.HUNTER)
	a.stun(1.0, b)
	a.tick(0.5)
	assert_bool(a.is_stunned()).is_true()
	a.tick(0.6)
	assert_bool(a.is_stunned()).is_false()
	assert_object(a.riposte_by).is_null()
