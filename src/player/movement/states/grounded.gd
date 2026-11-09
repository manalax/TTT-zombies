extends MovementState
## On the floor. Owns leaving the ground (walking off a ledge, jumping) and starting a dodge.


func _physics_update(_delta: float) -> void:
	if not player.is_on_floor():
		transition_to(&"Airborne")
		return
	if player.jump_assist.can_jump() and player.has_headroom():
		player.jump_assist.try_consume()
		player.jump()
		transition_to(&"Airborne")
	elif player.intent.dodge_pressed and player.can_dodge():
		transition_to(&"Dodge")
