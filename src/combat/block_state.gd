class_name BlockState
extends RefCounted
## A combatant's block and parry window, read by the damage pipeline.
## F012 toggles [member active] from input and copies the stats from the weapon's MeleeStats.
##
## Parry timing (docs/adr/0006-parry-dodge.md): a fresh block press opens a window of
## [member parry_window_s]. Timers advance only through [method tick] (once per physics step), so
## a hit N ticks after the press sees exactly N × delta. A window that ends without a parry
## starts a [member parry_lockout_s] lockout during which presses only block.

var active: bool = false
## Fraction of blockable damage absorbed (MeleeStats.block_reduction).
var reduction: float = 0.7
## Stamina paid per point of absorbed damage (MeleeStats.block_stamina_per_damage).
var stamina_per_damage: float = 0.5
## Total frontal arc covered by the block, in degrees.
var arc_deg: float = 120.0
var stamina: StaminaComponent

var parry_window_s: float = 0.2
var parry_lockout_s: float = 0.5
## How long a parried attacker is stunned (and open to a riposte).
var parry_stun_s: float = 1.2
## Seconds since the last fresh press that opened a window (INF = none).
var since_press: float = INF
## Last parry timing readout in ms (see DamageResult.parry_timing_ms). NAN = none yet.
var last_timing_ms: float = NAN

var _window_open: bool = false
var _parried_this_window: bool = false
var _lockout_left: float = 0.0


func configure(stats: MeleeStats) -> void:
	reduction = stats.block_reduction
	stamina_per_damage = stats.block_stamina_per_damage
	parry_window_s = stats.parry_window_s
	parry_stun_s = stats.parry_stun_s


## Called on a fresh block press. Returns false (block only) while locked out.
func open_parry_window() -> bool:
	if _lockout_left > 0.0:
		return false
	_window_open = true
	_parried_this_window = false
	since_press = 0.0
	return true


func close_parry_window() -> void:
	if not _window_open:
		return
	_window_open = false
	if not _parried_this_window:
		_lockout_left = parry_lockout_s


func is_parry_window_open() -> bool:
	return _window_open and since_press <= parry_window_s + 0.0001


func notify_parried() -> void:
	_parried_this_window = true


func is_locked_out() -> bool:
	return _lockout_left > 0.0


func get_lockout_left() -> float:
	return _lockout_left


func tick(delta: float) -> void:
	if since_press < INF:
		since_press += delta
	if _lockout_left > 0.0:
		_lockout_left = maxf(0.0, _lockout_left - delta)
	if _window_open and since_press > parry_window_s + 0.0001:
		close_parry_window()
