class_name AmmoState
extends RefCounted
## Magazine and reserve of one firearm slot. Caps are hard limits: nothing can push the magazine
## above mag_size or the reserve above reserve_cap.

var mag: int = 0
var reserve: int = 0
var mag_size: int = 1
var reserve_cap: int = 0


static func for_stats(stats: FirearmStats) -> AmmoState:
	var state := AmmoState.new()
	state.mag_size = stats.mag_size
	state.reserve_cap = stats.reserve_cap
	return state


## Spawn/purchase state: a full magazine plus a full reserve granted through AmmoRules
## (so ammo_scarcity applies).
func fill(settings: MatchSettings = null) -> AmmoState:
	mag = mag_size
	reserve = 0
	add_reserve(AmmoRules.grant(reserve_cap, settings))
	return self


## Adds up to [param amount] to the reserve; returns how many were accepted (cap enforced).
func add_reserve(amount: int) -> int:
	var accepted := clampi(amount, 0, reserve_cap - reserve)
	reserve += accepted
	return accepted


func take_round() -> bool:
	if mag <= 0:
		return false
	mag -= 1
	return true


## Rounds a full reload would move from the reserve into the magazine.
func reload_amount() -> int:
	return mini(mag_size - mag, reserve)


func can_reload() -> bool:
	return reload_amount() > 0


## Moves up to [param count] rounds from the reserve into the magazine; returns how many moved.
func move_to_mag(count: int) -> int:
	var moved := clampi(count, 0, reload_amount())
	mag += moved
	reserve -= moved
	return moved


func is_empty() -> bool:
	return mag <= 0
