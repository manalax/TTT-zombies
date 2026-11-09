# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F016 acceptance: point rules (damage → points, bonuses, rounding, eligibility, prices).

const HUNTER := CombatTypes.Faction.HUNTER
const CULT := CombatTypes.Faction.CULT
const COMMON := EnemyData.Category.COMMON
const SPECIAL := EnemyData.Category.SPECIAL
const BOSS := EnemyData.Category.BOSS

var _settings: MatchSettings
var _rules: EconomyRules


func before_test() -> void:
	_settings = MatchSettings.new()
	_rules = EconomyRules.new()


func _combatant(faction: CombatTypes.Faction, peer_id: int = 0) -> HealthComponent:
	var health: HealthComponent = auto_free(HealthComponent.new())
	health.faction = faction
	health.peer_id = peer_id
	return health


## An accepted hit by a player (peer 1) on a cultist that removed [param applied] health.
func _hit(
	applied: float,
	weakpoint: bool = false,
	source: HealthComponent = null,
	target: HealthComponent = null
) -> DamageResult:
	source = source if source != null else _combatant(HUNTER, 1)
	target = target if target != null else _combatant(CULT)
	var hurtbox: Hurtbox = null
	if weakpoint:
		hurtbox = auto_free(Hurtbox.new())
		hurtbox.is_weakpoint = true
	var event := DamageEvent.from_source(
		source, target, applied, CombatTypes.DamageType.MELEE, hurtbox
	)
	var result := DamageResult.new()
	result.event = event
	result.accepted = true
	result.applied = applied
	result.final_amount = applied
	result.relation = CombatTypes.Relation.HOSTILE
	return result


func _points(result: DamageResult, category: EnemyData.Category = COMMON) -> int:
	return PointRules.for_hit(result, category, _settings, _rules).total


# --- Formula and rounding -----------------------------------------------------------------


func test_damage_pays_rounded_up_to_ten() -> void:
	assert_int(_points(_hit(40.0))).is_equal(40)
	assert_int(_points(_hit(15.0))).is_equal(20)
	assert_int(_points(_hit(1.0))).is_equal(10)
	assert_int(_points(_hit(52.5))).is_equal(60)
	assert_int(_points(_hit(30.0))).is_equal(30)
	assert_int(_points(_hit(0.01))).is_equal(10)


func test_round_up_helper() -> void:
	assert_int(PointRules.round_up(0.0, 10)).is_equal(0)
	assert_int(PointRules.round_up(-5.0, 10)).is_equal(0)
	assert_int(PointRules.round_up(30.000001, 10)).is_equal(30)
	assert_int(PointRules.round_up(30.1, 10)).is_equal(40)
	assert_int(PointRules.round_up(7.0, 1)).is_equal(7)
	assert_int(PointRules.round_up(7.0, 0)).is_equal(7)


func test_category_multiplier() -> void:
	assert_int(_points(_hit(40.0), SPECIAL)).is_equal(60)
	assert_int(_points(_hit(35.0), BOSS)).is_equal(70)
	assert_int(_points(_hit(35.0), COMMON)).is_equal(40)


func test_points_per_damage_setting() -> void:
	_settings.points_per_damage_mult = 2.0
	assert_int(_points(_hit(15.0))).is_equal(30)
	_settings.points_per_damage_mult = 0.0
	assert_int(_points(_hit(15.0))).is_equal(0)


func test_weakpoint_multiplier() -> void:
	assert_int(_points(_hit(40.0, true))).is_equal(60)
	assert_int(_points(_hit(40.0, true), SPECIAL)).is_equal(90)
	var award := PointRules.for_hit(_hit(40.0, true), COMMON, _settings, _rules)
	assert_bool(award.weakpoint).is_true()
	assert_float(award.damage_points).is_equal_approx(60.0, 0.0001)


func test_riposte_adds_flat_bonus() -> void:
	var result := _hit(87.5)
	result.riposte = true
	var award := PointRules.for_hit(result, COMMON, _settings, _rules)
	assert_int(award.total).is_equal(140)
	assert_int(award.riposte_bonus).is_equal(50)


func test_overkill_never_pays() -> void:
	var result := _hit(10.0)
	result.final_amount = 70.0
	result.overkill = 60.0
	result.killed = true
	assert_int(_points(result)).is_equal(10)


func test_rules_are_tunable() -> void:
	_rules.round_to = 25
	_rules.special_mult = 3.0
	assert_int(_points(_hit(10.0), SPECIAL)).is_equal(50)
	_rules.round_to = 1
	assert_int(_points(_hit(10.4))).is_equal(11)


# --- Eligibility --------------------------------------------------------------------------


func test_rejected_and_zero_damage_pay_nothing() -> void:
	var rejected := _hit(40.0)
	rejected.accepted = false
	assert_int(_points(rejected)).is_equal(0)
	var parried := _hit(0.0)
	parried.parried = true
	assert_int(_points(parried)).is_equal(0)
	assert_int(PointRules.for_hit(null).total).is_equal(0)


func test_friendly_fire_and_self_damage_pay_nothing() -> void:
	var ally := _hit(40.0, false, null, _combatant(HUNTER, 2))
	ally.relation = CombatTypes.Relation.FRIENDLY
	assert_int(_points(ally)).is_equal(0)
	var me := _combatant(HUNTER, 1)
	var own := _hit(40.0, false, me, me)
	own.relation = CombatTypes.Relation.SELF
	assert_int(_points(own)).is_equal(0)


func test_only_players_earn_and_only_from_cult_targets() -> void:
	var by_cult := _hit(40.0, false, _combatant(CULT), _combatant(HUNTER, 1))
	assert_int(_points(by_cult)).is_equal(0)
	var by_ai := _hit(40.0, false, _combatant(HUNTER, 0))
	assert_int(_points(by_ai)).is_equal(0)
	var on_hunter := _hit(40.0, false, null, _combatant(HUNTER, 3))
	assert_int(_points(on_hunter)).is_equal(0)
	var world := _hit(40.0)
	world.event = DamageEvent.world(_combatant(CULT), 40.0, CombatTypes.DamageType.FALL)
	assert_int(_points(world)).is_equal(0)


# --- Prices -------------------------------------------------------------------------------


func test_door_and_shop_prices() -> void:
	assert_int(PointRules.door_price(750, _settings, _rules)).is_equal(750)
	_settings.door_cost_mult = 1.5
	assert_int(PointRules.door_price(750, _settings, _rules)).is_equal(1130)
	_settings.shop_price_mult = 0.5
	assert_int(PointRules.shop_price(1250, _settings, _rules)).is_equal(630)
	_settings.door_cost_mult = 0.0
	assert_int(PointRules.door_price(750, _settings, _rules)).is_equal(0)


func test_ammo_price_follows_scarcity() -> void:
	_settings.ammo_scarcity = 2.0
	assert_int(PointRules.ammo_price(250, _settings, _rules)).is_equal(500)
	_settings.ammo_scarcity = 0.25
	assert_int(PointRules.ammo_price(250, _settings, _rules)).is_equal(70)


func test_defaults_come_from_settings_and_content() -> void:
	var shipped := PointRules.get_rules()
	assert_str(String(shipped.id)).is_equal("economy_rules")
	assert_int(shipped.round_to).is_equal(10)
	var base := Settings.match_settings.door_cost_mult
	assert_int(PointRules.door_price(1000)).is_equal(PointRules.round_up(1000 * base, 10))


func test_award_description() -> void:
	var result := _hit(40.0, true)
	result.riposte = true
	var text := PointRules.for_hit(result, COMMON, _settings, _rules).describe()
	assert_str(text).contains("+110").contains("head").contains("riposte")
	assert_str(PointAward.new().describe()).is_equal("-")
