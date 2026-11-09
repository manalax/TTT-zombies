extends FirearmState
## Gun up. Fires on a press (semi-auto), aims while RMB is held, reloads on R or when firing
## an empty magazine. Lowered while sprinting.


func _physics_update(_delta: float) -> void:
	if gun.player.is_sprinting():
		transition_to(&"Lowered")
		return
	if gun.aiming:
		gun.player.set_combat_modifiers(defaults().aim_move_mult, true)
	else:
		gun.player.set_combat_modifiers(1.0, false)
	if intent().reload_pressed and gun.ammo.can_reload():
		transition_to(&"Reloading")
		return
	if not gun.attack_pressed:
		return
	if gun.can_fire():
		gun.fire()
	elif gun.ammo.is_empty():
		if gun.ammo.can_reload():
			transition_to(&"Reloading")
		else:
			gun.dry_fired.emit()
