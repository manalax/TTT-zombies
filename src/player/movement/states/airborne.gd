extends MovementState
## In the air (jumped or fell). Momentum carries; air control is weak; no sprint starts here.
## Coyote-time jumps happen here. Landing reports the fall speed and picks a grounded leaf.

var _carry_speed: float = 0.0


func _enter(_data: Dictionary) -> void:
	_carry_speed = maxf(defaults().walk_speed, PlayerMotor.horizontal_speed(player.velocity))
	_apply()


func _physics_update(_delta: float) -> void:
	if player.jump_assist.try_consume():
		player.jump()
	elif player.is_on_floor() and player.velocity.y <= 0.0:
		player.notify_landed(player.get_last_fall_speed())
		transition_to(choose_ground_leaf())
		return
	_apply()


func _apply() -> void:
	if intent().crouch:
		player.set_crouched(true)
	elif player.has_headroom():
		player.set_crouched(false)
	player.set_move_params(_carry_speed, defaults().air_accel, 0.0)
