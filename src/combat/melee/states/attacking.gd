extends WeaponState
## A swing in progress: Windup, Active, Recovery. Slows the player and locks sprint.


func _physics_update(_delta: float) -> void:
	modifiers(defaults().swing_move_mult, true)


func _handle_event(event: StringName, data: Dictionary) -> bool:
	if event == &"staggered":
		transition_to(&"Staggered", data)
		return true
	return false
