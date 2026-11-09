class_name AmmoRules
extends RefCounted
## How MatchSettings.ammo_scarcity applies (docs/adr/0007-firearms-loadout.md).
##
## Higher scarcity = scarcer: every ammo grant (spawn reserve, pickups, drops, station refills)
## is divided by it and every ammo cost multiplied by it. Caps (mag_size, reserve_cap) are never
## scaled; they are always enforced by AmmoState.


static func scarcity(settings: MatchSettings = null) -> float:
	if settings == null:
		settings = Settings.match_settings
	return settings.ammo_scarcity if settings != null else 1.0


## Rounds actually granted for a nominal [param raw] amount.
static func grant(raw: int, settings: MatchSettings = null) -> int:
	if raw <= 0:
		return 0
	return floori(raw / scarcity(settings) + 0.0001)


## Point cost actually charged for a nominal [param raw] ammo cost (wall stations, F018).
static func cost(raw: int, settings: MatchSettings = null) -> int:
	if raw <= 0:
		return 0
	return ceili(raw * scarcity(settings) - 0.0001)
