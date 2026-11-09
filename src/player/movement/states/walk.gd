extends MovementState
## Walking at walk speed in any direction.


func _enter(_data: Dictionary) -> void:
	_apply()


func _physics_update(_delta: float) -> void:
	if follow_ground_leaf():
		return
	_apply()


func _apply() -> void:
	player.set_crouched(false)
	var d := defaults()
	player.set_move_params(d.walk_speed, d.ground_accel, d.ground_decel)
