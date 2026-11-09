extends MovementState
## Sprinting: grounded, roughly forward, drains stamina. Leaves on release, turning past the
## sprint angle, crouching, or exhaustion (then sprint stays locked until stamina recovers).


func _enter(_data: Dictionary) -> void:
	_apply()


func _physics_update(delta: float) -> void:
	if follow_ground_leaf():
		return
	player.stamina.drain(defaults().sprint_drain_per_s * delta)
	if not player.stamina.can_sprint():
		transition_to(&"Walk")
		return
	_apply()


func _apply() -> void:
	player.set_crouched(false)
	var d := defaults()
	player.set_move_params(d.sprint_speed, d.ground_accel, d.ground_decel)
