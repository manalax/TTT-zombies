class_name PointRules
extends RefCounted
## Pure point rules (DESIGN §10.1, docs/adr/0009-points-economy.md).
##
## A player earns points for damage actually removed from a cult target:
##   applied × points_per_damage_mult × category multiplier (× weak-point multiplier),
## rounded UP to a multiple of round_to (any damaging hit pays at least that), plus a flat bonus
## when a riposte lands. No kill bonus. Price helpers apply the MatchSettings multipliers.

const RULES_ID := &"economy_rules"
## Absorbs float noise so 30.000001 does not round up to 40.
const ROUND_EPSILON := 0.0001


## Points for one committed hit. [param category] is the target's EnemyData.category (COMMON
## for targets without EnemyData, such as training dummies).
static func for_hit(
	result: DamageResult,
	category: EnemyData.Category = EnemyData.Category.COMMON,
	settings: MatchSettings = null,
	rules: EconomyRules = null
) -> PointAward:
	var award := PointAward.new()
	if not is_eligible(result):
		return award
	settings = _settings(settings)
	rules = get_rules(rules)
	var per_damage := settings.points_per_damage_mult if settings != null else 1.0
	var points := result.applied * per_damage * rules.category_mult(category)
	award.weakpoint = result.event.is_weakpoint()
	if award.weakpoint:
		points *= rules.weakpoint_mult
	award.damage_points = points
	if points <= 0.0:
		return award
	var total := round_up(points, rules.round_to)
	if result.riposte:
		award.riposte_bonus = rules.riposte_bonus
		total = round_up(total + rules.riposte_bonus, rules.round_to)
	award.total = total
	return award


## Only a player's accepted, damaging, hostile hit on a cult target earns points: not friendly
## fire, self-damage, world damage, parried or fully absorbed hits, or cult attacks.
static func is_eligible(result: DamageResult) -> bool:
	if result == null or not result.accepted or result.applied <= 0.0:
		return false
	var event := result.event
	if event == null or event.target == null or event.source_peer_id <= 0:
		return false
	if result.relation != CombatTypes.Relation.HOSTILE:
		return false
	return event.target.faction == CombatTypes.Faction.CULT


## [param value] rounded up to a multiple of [param step]; any positive value gives >= step.
static func round_up(value: float, step: int) -> int:
	if value <= 0.0:
		return 0
	step = maxi(step, 1)
	return maxi(1, ceili(value / step - ROUND_EPSILON)) * step


static func door_price(
	base: int, settings: MatchSettings = null, rules: EconomyRules = null
) -> int:
	settings = _settings(settings)
	var mult := settings.door_cost_mult if settings != null else 1.0
	return _price(base * mult, rules)


## Wall-buy weapons, perks and other shop items.
static func shop_price(
	base: int, settings: MatchSettings = null, rules: EconomyRules = null
) -> int:
	settings = _settings(settings)
	var mult := settings.shop_price_mult if settings != null else 1.0
	return _price(base * mult, rules)


## Ammo purchases scale with ammo_scarcity (AmmoRules.cost, ADR 0007).
static func ammo_price(
	base: int, settings: MatchSettings = null, rules: EconomyRules = null
) -> int:
	return _price(AmmoRules.cost(base, _settings(settings)), rules)


## Points for one repaired barricade plank (F046): flat, rounded up like every award.
static func repair_points(base: int, rules: EconomyRules = null) -> int:
	return _price(base, rules)


static func _price(value: float, rules: EconomyRules) -> int:
	return round_up(value, get_rules(rules).round_to)


static func _settings(settings: MatchSettings) -> MatchSettings:
	if settings != null:
		return settings
	return Settings.match_settings


static func get_rules(rules: EconomyRules = null) -> EconomyRules:
	if rules != null:
		return rules
	var shipped := ContentDB.get_item(&"EconomyRules", RULES_ID) as EconomyRules
	return shipped if shipped != null else EconomyRules.new()
