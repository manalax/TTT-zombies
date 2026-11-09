extends WeaponState
## Attack button held. Release fires: a full charge is a heavy, anything shorter a light.
## Raising the guard cancels the charge.


func _enter(_data: Dictionary) -> void:
	weapon.charge_s = 0.0


func _physics_update(delta: float) -> void:
	if intent().block_held:
		transition_to(&"Blocking")
		return
	if not intent().attack_held:
		if not weapon.start_swing(weapon.make_release_swing()):
			transition_to(&"Idle")
		return
	weapon.charge_s += delta
	modifiers(defaults().charge_move_mult, true)


func _exit() -> void:
	weapon.charge_s = 0.0
