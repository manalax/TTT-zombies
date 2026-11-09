extends FirearmState
## Topping up the magazine from the reserve (no rounds are lost). Whole-magazine reloads add
## everything at the end; per-round reloads add one round every reload_round_s and a fire press
## (with a round loaded) stops the reload and fires. Sprinting or switching weapons cancels it.

var elapsed: float = 0.0


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0
	gun.reload_started.emit()


func _physics_update(delta: float) -> void:
	gun.player.set_combat_modifiers(1.0, false)
	if gun.player.is_sprinting():
		transition_to(&"Lowered")
		return
	var fs := gun.stats
	if fs.reload_per_round and gun.attack_pressed and gun.ammo.mag > 0:
		transition_to(&"Ready")
		if gun.can_fire():
			gun.fire()
		return
	elapsed += delta
	if fs.reload_per_round:
		if elapsed >= fs.reload_round_s:
			elapsed -= fs.reload_round_s
			gun.ammo.move_to_mag(1)
			if not gun.ammo.can_reload():
				_finish()
	elif elapsed >= fs.reload_s:
		gun.ammo.move_to_mag(gun.ammo.reload_amount())
		_finish()


func _finish() -> void:
	gun.reload_finished.emit()
	transition_to(&"Ready")
