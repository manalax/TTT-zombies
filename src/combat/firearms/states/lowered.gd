extends FirearmState
## Gun lowered while sprinting: no firing. Holding aim locks sprint so the gun comes back up.


func _physics_update(_delta: float) -> void:
	gun.player.set_combat_modifiers(1.0, intent().aim_held)
	if not gun.player.is_sprinting():
		transition_to(&"Ready")
