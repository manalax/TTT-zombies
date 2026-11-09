extends WeaponState
## Weapon at rest. Block wins over attack.


func _physics_update(_delta: float) -> void:
	if weapon.player.is_dodging():
		return
	if intent().block_held:
		transition_to(&"Blocking")
	elif weapon.attack_pressed or intent().attack_held:
		transition_to(&"Charging")
