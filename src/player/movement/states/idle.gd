extends MovementState
## Standing still: decelerate to a stop.


func _enter(_data: Dictionary) -> void:
	_apply()


func _physics_update(_delta: float) -> void:
	if follow_ground_leaf():
		return
	_apply()


func _apply() -> void:
	player.set_crouched(false)
	player.set_move_params(0.0, defaults().ground_accel, defaults().ground_decel)
