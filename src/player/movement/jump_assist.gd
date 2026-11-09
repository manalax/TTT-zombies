class_name JumpAssist
extends RefCounted
## Coyote time and jump buffering as pure timers.
##
## Call [method tick] once per physics step, then [method try_consume] where a jump may start.
## A jump is allowed when the player was on the floor within [member coyote_time_s] and pressed
## jump within [member jump_buffer_s]. Each takeoff can only be consumed once.

var coyote_time_s: float = 0.1
var jump_buffer_s: float = 0.1

var _since_floor: float = INF
var _since_press: float = INF
var _used: bool = false


func _init(p_coyote_time_s: float = 0.1, p_jump_buffer_s: float = 0.1) -> void:
	coyote_time_s = p_coyote_time_s
	jump_buffer_s = p_jump_buffer_s


func tick(delta: float, on_floor: bool, jump_pressed: bool) -> void:
	if on_floor:
		_since_floor = 0.0
		_used = false
	else:
		_since_floor += delta
	if jump_pressed:
		_since_press = 0.0
	else:
		_since_press += delta


func can_jump() -> bool:
	return not _used and _since_floor <= coyote_time_s and _since_press <= jump_buffer_s


## Returns true (and uses up the press and the takeoff) if a jump may start now.
func try_consume() -> bool:
	if not can_jump():
		return false
	_used = true
	_since_press = INF
	return true


func reset() -> void:
	_since_floor = INF
	_since_press = INF
	_used = false
