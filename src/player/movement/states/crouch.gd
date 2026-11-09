extends MovementState
## Crouched (still or moving) at crouch speed. Standing up needs headroom.
##
## A fresh sprint press cancels a toggled crouch. Sprint already held when the crouch began does
## not, so crouching mid-sprint sticks.

var _sprint_armed: bool = false


func _enter(_data: Dictionary) -> void:
	_sprint_armed = not intent().sprint
	_apply()


func _physics_update(_delta: float) -> void:
	if not intent().sprint:
		_sprint_armed = true
	elif _sprint_armed and intent().crouch and player.has_headroom():
		_sprint_armed = false
		player.input_source.cancel_crouch()
	if follow_ground_leaf():
		return
	_apply()


func _apply() -> void:
	player.set_crouched(true)
	var d := defaults()
	player.set_move_params(d.crouch_speed, d.ground_accel, d.ground_decel)
