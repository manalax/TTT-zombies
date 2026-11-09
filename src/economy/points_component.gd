class_name PointsComponent
extends Node
## A player's private point wallet (DESIGN §10, docs/adr/0009-points-economy.md).
## Only the authority changes it: damage awards come from the Economy service, purchases from
## doors and stations (F017/F018) through try_spend(). Every change is announced on
## Events.points_changed; F031/F040 replicate the balance to its owner only.

signal changed(total: int, delta: int)
signal awarded(award: PointAward)
signal spent(cost: int, reason: StringName)

var balance: int = 0
## Owner's multiplayer peer id (set by the Player).
var peer_id: int = 0
var last_award: PointAward


## Sets the balance (match start / respawn), e.g. to MatchSettings.starting_points.
func reset(starting: int) -> void:
	if not Net.is_authority():
		return
	var delta := maxi(starting, 0) - balance
	balance = maxi(starting, 0)
	last_award = null
	_announce(delta)


## Credits a computed award (Economy calls this for damage). Ignores empty awards.
func award_points(award: PointAward) -> void:
	if not Net.is_authority() or award == null or award.total <= 0:
		return
	balance += award.total
	last_award = award
	awarded.emit(award)
	_announce(award.total)


## Credits a direct amount (bounty, debug), rounded up like every award. Returns the credit.
func award(amount: int, reason: StringName) -> int:
	var point_award := PointAward.new()
	point_award.reason = reason
	point_award.total = PointRules.round_up(amount, PointRules.get_rules().round_to)
	award_points(point_award)
	return point_award.total if Net.is_authority() else 0


func can_afford(cost: int) -> bool:
	return cost <= balance


## Deducts [param cost] if affordable. Returns false (and changes nothing) otherwise.
func try_spend(cost: int, reason: StringName) -> bool:
	if not Net.is_authority() or cost < 0 or not can_afford(cost):
		return false
	balance -= cost
	spent.emit(cost, reason)
	_announce(-cost)
	return true


func _announce(delta: int) -> void:
	changed.emit(balance, delta)
	Events.points_changed.emit(peer_id, balance, delta)
