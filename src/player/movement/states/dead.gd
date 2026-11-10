extends MovementState
## Dead: movement intent is ignored; the body stops, stays down (crouched shape and eye height)
## and still falls. Look keeps working for spectating. Leaving it (respawn, conversion) is
## F034/F038's job.


func _enter(_data: Dictionary) -> void:
	_apply()


func _physics_update(_delta: float) -> void:
	_apply()


func _apply() -> void:
	player.set_crouched(true)
	player.set_move_params(0.0, defaults().ground_decel, defaults().ground_decel)
