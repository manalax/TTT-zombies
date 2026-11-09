# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F011 AC: friendly-fire gating/scaling, block (arc, stamina, guard break), armour math and
## the fixed stage order of DamagePipeline.

const HUNTER := CombatTypes.Faction.HUNTER
const CULT := CombatTypes.Faction.CULT
const MELEE := CombatTypes.DamageType.MELEE
const BULLET := CombatTypes.DamageType.BULLET


## A combatant body in the scene tree at [param pos], facing [param facing] (horizontal).
func _combatant(
	faction: CombatTypes.Faction,
	pos: Vector3 = Vector3.ZERO,
	facing: Vector3 = Vector3.FORWARD,
	max_health: float = 100.0
) -> HealthComponent:
	var body: Node3D = auto_free(Node3D.new())
	var health := HealthComponent.new()
	health.faction = faction
	body.add_child(health)
	add_child(body)
	body.global_position = pos
	if not facing.is_equal_approx(Vector3.FORWARD):
		body.look_at(pos + facing, Vector3.UP)
	health.setup(max_health)
	return health


func _blocker(stamina_amount: float = 100.0, facing: Vector3 = Vector3.FORWARD) -> HealthComponent:
	var target := _combatant(HUNTER, Vector3.ZERO, facing, 1000.0)
	var stamina: StaminaComponent = auto_free(StaminaComponent.new())
	stamina.configure(PlayerDefaults.new())
	stamina.current = stamina_amount
	var block := BlockState.new()
	block.active = true
	block.reduction = 0.7
	block.stamina_per_damage = 0.5
	block.arc_deg = 120.0
	block.stamina = stamina
	target.block = block
	return target


func _event(
	source: HealthComponent, target: HealthComponent, amount: float, type := MELEE
) -> DamageEvent:
	return DamageEvent.from_source(source, target, amount, type)


func _rules() -> DamageRules:
	return DamageRules.new()


func _hurtbox(mult: float, weak: bool) -> Hurtbox:
	var box: Hurtbox = auto_free(Hurtbox.new())
	box.damage_mult = mult
	box.is_weakpoint = weak
	return box


func _resolve(event: DamageEvent, rules: DamageRules = null) -> DamageResult:
	return DamagePipeline.resolve(event, rules if rules != null else _rules())


# --- Relations & friendly fire ---------------------------------------------------------------


func test_classify() -> void:
	var a := _combatant(HUNTER)
	var b := _combatant(HUNTER)
	var c := _combatant(CULT)
	var d := _combatant(CULT)
	assert_int(DamagePipeline.classify(_event(a, a, 1))).is_equal(CombatTypes.Relation.SELF)
	assert_int(DamagePipeline.classify(_event(a, b, 1))).is_equal(CombatTypes.Relation.FRIENDLY)
	assert_int(DamagePipeline.classify(_event(c, d, 1))).is_equal(CombatTypes.Relation.CULT_ALLY)
	assert_int(DamagePipeline.classify(_event(a, c, 1))).is_equal(CombatTypes.Relation.HOSTILE)
	assert_int(DamagePipeline.classify(_event(c, a, 1))).is_equal(CombatTypes.Relation.HOSTILE)
	assert_int(DamagePipeline.classify(DamageEvent.world(a, 1))).is_equal(
		CombatTypes.Relation.WORLD
	)


func test_hostile_damage_is_unscaled() -> void:
	var result := _resolve(_event(_combatant(HUNTER), _combatant(CULT), 40))
	assert_bool(result.accepted).is_true()
	assert_float(result.applied).is_equal(40.0)


func test_friendly_fire_off_rejects() -> void:
	var rules := _rules()
	rules.friendly_fire = false
	var result := _resolve(_event(_combatant(HUNTER), _combatant(HUNTER), 40), rules)
	assert_bool(result.accepted).is_false()
	assert_str(result.reject_reason).is_equal("friendly_fire_off")
	assert_float(result.applied).is_equal(0.0)


func test_friendly_fire_scale_applies_to_melee_and_bullets() -> void:
	var rules := _rules()
	for scale: float in [0.5, 2.0]:
		rules.friendly_fire_scale = scale
		for type: CombatTypes.DamageType in [MELEE, BULLET]:
			var result := _resolve(_event(_combatant(HUNTER), _combatant(HUNTER), 40, type), rules)
			assert_float(result.applied).is_equal_approx(40.0 * scale, 0.0001)


func test_self_damage_gate() -> void:
	var me := _combatant(HUNTER)
	var rules := _rules()
	assert_float(_resolve(_event(me, me, 10), rules).applied).is_equal(10.0)
	rules.self_damage = false
	var result := _resolve(_event(me, me, 10), rules)
	assert_str(result.reject_reason).is_equal("self_damage_off")


func test_self_damage_is_not_friendly_fire_scaled() -> void:
	var me := _combatant(HUNTER)
	var rules := _rules()
	rules.friendly_fire = false
	rules.friendly_fire_scale = 0.5
	assert_float(_resolve(_event(me, me, 10), rules).applied).is_equal(10.0)


func test_cult_allies_only_hurt_by_hits_allies() -> void:
	var bloat := _combatant(CULT)
	var acolyte := _combatant(CULT)
	var swing := _event(bloat, acolyte, 30)
	assert_str(_resolve(swing).reject_reason).is_equal("cult_ally")
	var blast := _event(bloat, acolyte, 30, CombatTypes.DamageType.BLAST)
	blast.hits_allies = true
	var rules := _rules()
	rules.cult_friendly_fire_scale = 0.5
	assert_float(_resolve(blast, rules).applied).is_equal(15.0)


func test_hits_allies_does_not_bypass_hunter_friendly_fire() -> void:
	var rules := _rules()
	rules.friendly_fire = false
	var event := _event(_combatant(HUNTER), _combatant(HUNTER), 30, CombatTypes.DamageType.BLAST)
	event.hits_allies = true
	assert_str(_resolve(event, rules).reject_reason).is_equal("friendly_fire_off")


func test_world_damage_ignores_friendly_fire_rules() -> void:
	var rules := _rules()
	rules.friendly_fire = false
	rules.self_damage = false
	rules.friendly_fire_scale = 0.0
	var result := _resolve(DamageEvent.world(_combatant(HUNTER), 25), rules)
	assert_float(result.applied).is_equal(25.0)


func test_enemy_damage_mult_only_for_cult_on_hunter() -> void:
	var rules := _rules()
	rules.enemy_damage_mult = 2.0
	var hunter := _combatant(HUNTER)
	var cult := _combatant(CULT)
	assert_float(_resolve(_event(cult, hunter, 10), rules).applied).is_equal(20.0)
	assert_float(_resolve(_event(hunter, cult, 10), rules).applied).is_equal(10.0)
	assert_float(_resolve(DamageEvent.world(hunter, 10), rules).applied).is_equal(10.0)


func test_rules_from_settings() -> void:
	var settings := MatchSettings.new()
	settings.friendly_fire = false
	settings.friendly_fire_scale = 0.25
	settings.self_damage = false
	settings.cult_friendly_fire_scale = 1.5
	settings.enemy_damage_mult = 3.0
	var rules := DamageRules.from_settings(settings)
	assert_bool(rules.friendly_fire).is_false()
	assert_float(rules.friendly_fire_scale).is_equal(0.25)
	assert_bool(rules.self_damage).is_false()
	assert_float(rules.cult_friendly_fire_scale).is_equal(1.5)
	assert_float(rules.enemy_damage_mult).is_equal(3.0)
	assert_bool(DamageRules.from_settings(null).friendly_fire).is_true()


# --- Zones & weak points ---------------------------------------------------------------------


func test_zone_and_weakpoint_mults() -> void:
	var hunter := _combatant(HUNTER)
	var cult := _combatant(CULT, Vector3.ZERO, Vector3.FORWARD, 1000)
	var limb := _event(hunter, cult, 40)
	limb.hurtbox = _hurtbox(0.75, false)
	limb.weakpoint_mult = 2.0
	assert_float(_resolve(limb).applied).is_equal(30.0)
	var head := _event(hunter, cult, 40)
	head.hurtbox = _hurtbox(1.0, true)
	head.weakpoint_mult = 2.0
	assert_float(_resolve(head).applied).is_equal(80.0)
	assert_bool(head.is_weakpoint()).is_true()


# --- Block -----------------------------------------------------------------------------------


func test_block_reduces_and_costs_stamina() -> void:
	var target := _blocker()
	var attacker := _combatant(CULT, Vector3(0, 0, -2))
	var result := _resolve(_event(attacker, target, 100))
	assert_bool(result.blocked).is_true()
	assert_float(result.absorbed).is_equal_approx(70.0, 0.0001)
	assert_float(result.applied).is_equal_approx(30.0, 0.0001)
	assert_float(result.stamina_spent).is_equal_approx(35.0, 0.0001)
	assert_bool(result.guard_broken).is_false()
	# resolve() is pure: stamina is only spent when Combat commits the result.
	assert_float(target.block.stamina.current).is_equal(100.0)


func test_block_arc_edges() -> void:
	# 120° arc = 60° either side of forward (-Z).
	for case: Array in [[59.0, true], [-59.0, true], [61.0, false], [-61.0, false], [180.0, false]]:
		var target := _blocker()
		var angle: float = case[0]
		var origin := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(angle)) * 3.0
		var attacker := _combatant(CULT, origin)
		var result := _resolve(_event(attacker, target, 100))
		(
			assert_bool(result.blocked)
			. override_failure_message("attack from %s° blocked?" % angle)
			. is_equal(case[1])
		)


func test_block_arc_follows_facing_and_ignores_height() -> void:
	var target := _blocker(100.0, Vector3.RIGHT)
	var from_right_above := _combatant(CULT, Vector3(3, 5, 0))
	assert_bool(_resolve(_event(from_right_above, target, 50)).blocked).is_true()
	var from_front := _combatant(CULT, Vector3(0, 0, -3))
	assert_bool(_resolve(_event(from_front, target, 50)).blocked).is_false()


func test_block_ignores_non_melee() -> void:
	var target := _blocker()
	var attacker := _combatant(CULT, Vector3(0, 0, -2))
	var result := _resolve(_event(attacker, target, 100, BULLET))
	assert_bool(result.blocked).is_false()
	assert_float(result.applied).is_equal(100.0)


func test_inactive_block_does_nothing() -> void:
	var target := _blocker()
	target.block.active = false
	var result := _resolve(_event(_combatant(CULT, Vector3(0, 0, -2)), target, 100))
	assert_bool(result.blocked).is_false()


func test_guard_break_still_blocks_and_drains_all_stamina() -> void:
	var target := _blocker(20.0)
	var attacker := _combatant(CULT, Vector3(0, 0, -2))
	var result := _resolve(_event(attacker, target, 100))  # cost 35 > 20 stamina
	assert_bool(result.blocked).is_true()
	assert_bool(result.guard_broken).is_true()
	assert_float(result.stamina_spent).is_equal(20.0)
	assert_float(result.applied).is_equal_approx(30.0, 0.0001)


func test_block_with_no_stamina_fails() -> void:
	var target := _blocker(0.0)
	var result := _resolve(_event(_combatant(CULT, Vector3(0, 0, -2)), target, 100))
	assert_bool(result.blocked).is_false()
	assert_float(result.applied).is_equal(100.0)


# --- Armour, order, clamp --------------------------------------------------------------------


func test_armor_reduces_by_percentage() -> void:
	var cult := _combatant(CULT)
	cult.armor = 0.5
	assert_float(_resolve(_event(_combatant(HUNTER), cult, 40)).applied).is_equal(20.0)


func test_armor_also_applies_to_weakpoints() -> void:
	var cult := _combatant(CULT)
	cult.armor = 0.5
	var event := _event(_combatant(HUNTER), cult, 40)
	event.hurtbox = _hurtbox(1.0, true)
	event.weakpoint_mult = 2.0
	assert_float(_resolve(event).applied).is_equal(40.0)


func test_fixed_stage_order() -> void:
	# 100 × weak point 2 × FF 0.5 = 100 → block (70%) = 30 → armour 50% = 15.
	var target := _blocker()
	target.armor = 0.5
	var attacker := _combatant(HUNTER, Vector3(0, 0, -2))
	var event := _event(attacker, target, 100)
	event.hurtbox = _hurtbox(1.0, true)
	event.weakpoint_mult = 2.0
	var rules := _rules()
	rules.friendly_fire_scale = 0.5
	var result := _resolve(event, rules)
	assert_float(result.stages["zone"]).is_equal(200.0)
	assert_float(result.stages["relation"]).is_equal(100.0)
	assert_float(result.stages["block"]).is_equal_approx(30.0, 0.0001)
	assert_float(result.stages["armor"]).is_equal_approx(15.0, 0.0001)
	assert_float(result.applied).is_equal_approx(15.0, 0.0001)
	# Block cost is paid on the damage reaching the block stage, before armour.
	assert_float(result.stamina_spent).is_equal_approx(35.0, 0.0001)


func test_overkill_is_clamped() -> void:
	var cult := _combatant(CULT, Vector3.ZERO, Vector3.FORWARD, 30)
	var result := _resolve(_event(_combatant(HUNTER), cult, 45))
	assert_float(result.final_amount).is_equal(45.0)
	assert_float(result.applied).is_equal(30.0)
	assert_float(result.overkill).is_equal(15.0)
	assert_bool(result.killed).is_true()


func test_invalid_events_are_rejected() -> void:
	var cult := _combatant(CULT)
	assert_str(_resolve(DamageEvent.world(null, 10)).reject_reason).is_equal("no_target")
	assert_str(_resolve(DamageEvent.world(cult, 0)).reject_reason).is_equal("no_amount")
	cult.invulnerable = true
	assert_str(_resolve(DamageEvent.world(cult, 10)).reject_reason).is_equal("invulnerable")
	cult.invulnerable = false
	cult.apply_result(_resolve(DamageEvent.world(cult, 1000)))
	assert_str(_resolve(DamageEvent.world(cult, 10)).reject_reason).is_equal("target_dead")


# --- F013: dodge, parry, riposte -------------------------------------------------------------


func _parrier() -> HealthComponent:
	var target := _blocker()
	target.block.open_parry_window()
	return target


func test_iframes_negate_attacks_only() -> void:
	var target := _combatant(HUNTER)
	target.grant_iframes(0.2)
	var attacker := _combatant(CULT)
	for type: CombatTypes.DamageType in [MELEE, BULLET, CombatTypes.DamageType.BLAST]:
		assert_str(_resolve(_event(attacker, target, 10, type)).reject_reason).is_equal("dodged")
	for type: CombatTypes.DamageType in [
		CombatTypes.DamageType.FALL,
		CombatTypes.DamageType.ENVIRONMENT,
		CombatTypes.DamageType.DEBUG
	]:
		assert_bool(_resolve(DamageEvent.world(target, 10, type)).accepted).is_true()
	target.tick(0.25)
	assert_bool(_resolve(_event(attacker, target, 10)).accepted).is_true()


func test_parry_negates_without_stamina() -> void:
	var target := _parrier()
	var result := _resolve(_event(_combatant(CULT, Vector3(0, 0, -2)), target, 100))
	assert_bool(result.accepted).is_true()
	assert_bool(result.parried).is_true()
	assert_bool(result.blocked).is_false()
	assert_float(result.applied).is_equal(0.0)
	assert_float(result.stamina_spent).is_equal(0.0)
	assert_float(result.parry_timing_ms).is_equal_approx(-200.0, 0.01)


func test_no_parry_after_window_is_a_block() -> void:
	var target := _parrier()
	for i in 13:
		target.block.tick(1.0 / 60.0)
	var result := _resolve(_event(_combatant(CULT, Vector3(0, 0, -2)), target, 100))
	assert_bool(result.parried).is_false()
	assert_bool(result.blocked).is_true()
	assert_float(result.parry_timing_ms).is_greater(0.0)


func test_no_parry_outside_arc_or_for_world_or_bullets() -> void:
	var target := _parrier()
	assert_bool(_resolve(_event(_combatant(CULT, Vector3(0, 0, 2)), target, 50)).parried).is_false()
	assert_bool(_resolve(DamageEvent.world(target, 50, MELEE)).parried).is_false()
	var front := _combatant(CULT, Vector3(0, 0, -2))
	assert_bool(_resolve(_event(front, target, 50, BULLET)).parried).is_false()


func test_unparryable_ignores_parry_and_block() -> void:
	var target := _parrier()
	var event := _event(_combatant(CULT, Vector3(0, 0, -2)), target, 100)
	event.unparryable = true
	var result := _resolve(event)
	assert_bool(result.parried).is_false()
	assert_bool(result.blocked).is_false()
	assert_float(result.applied).is_equal(100.0)


func test_riposte_only_for_the_parrier_while_stunned() -> void:
	var parrier := _combatant(HUNTER)
	var other := _combatant(HUNTER)
	var stunned := _combatant(CULT, Vector3.ZERO, Vector3.FORWARD, 1000)
	stunned.stun(1.2, parrier)
	var riposte := _event(parrier, stunned, 40)
	riposte.riposte_mult = 2.5
	var result := _resolve(riposte)
	assert_bool(result.riposte).is_true()
	assert_float(result.applied).is_equal(100.0)
	var helper := _event(other, stunned, 40)
	helper.riposte_mult = 2.5
	assert_bool(_resolve(helper).riposte).is_false()
	var shot := _event(parrier, stunned, 40, BULLET)
	shot.riposte_mult = 2.5
	assert_bool(_resolve(shot).riposte).is_false()
	stunned.tick(1.3)
	assert_bool(_resolve(riposte).riposte).is_false()


func test_riposte_ignores_block_but_not_armor() -> void:
	var parrier := _combatant(CULT, Vector3(0, 0, -2))
	var target := _blocker()
	target.armor = 0.5
	target.stun(1.0, parrier)
	var event := _event(parrier, target, 40)
	event.riposte_mult = 2.5
	var result := _resolve(event)
	assert_bool(result.riposte).is_true()
	assert_bool(result.blocked).is_false()
	assert_float(result.stages["riposte"]).is_equal(100.0)
	assert_float(result.applied).is_equal(50.0)
