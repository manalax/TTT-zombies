extends MovementState
## Dodge dash (docs/adr/0006-parry-dodge.md): a quick dash in the move direction (a backstep
## without input) with attack i-frames at the start. Costs stamina, cancels Blocking/Recovery.

var elapsed: float = 0.0
var direction: Vector3 = Vector3.ZERO


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0
	var d := defaults()
	player.set_crouched(false)
	player.stamina.drain(d.dodge_stamina_cost)
	player.health.grant_iframes(d.dodge_iframe_s)
	direction = PlayerMotor.wish_direction(intent().move, player.global_basis)
	if direction == Vector3.ZERO:
		direction = Vector3(player.global_basis.z.x, 0.0, player.global_basis.z.z).normalized()
	player.set_wish_override(direction)
	player.melee.notify_dodged()
	# Lean away from the dash direction (local feedback only).
	player.camera.add_roll(-4.0 * direction.dot(player.global_basis.x))
	_apply()


func _physics_update(delta: float) -> void:
	elapsed += delta
	if elapsed >= defaults().dodge_duration_s:
		follow_ground_leaf()
		return
	_apply()


func _exit() -> void:
	player.set_wish_override(Vector3.ZERO)
	player.start_dodge_cooldown()
	# Shed the dash speed so the dodge covers ~dodge_distance_m instead of sliding on.
	var v := player.velocity
	var horizontal := Vector2(v.x, v.z).limit_length(defaults().walk_speed)
	player.velocity = Vector3(horizontal.x, v.y, horizontal.y)


func _apply() -> void:
	var d := defaults()
	var speed := d.dodge_distance_m / d.dodge_duration_s
	# Near-instant acceleration so the dash is crisp; decel brakes it on exit.
	player.set_move_params(speed, speed * 60.0, d.ground_decel)
