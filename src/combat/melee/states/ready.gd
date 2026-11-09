extends WeaponState
## Not attacking: Idle, Charging or Blocking. A guard break or stun sends any of them to Staggered.


func _physics_update(_delta: float) -> void:
	modifiers(1.0, false)


func _handle_event(event: StringName, data: Dictionary) -> bool:
	if event == &"staggered":
		transition_to(&"Staggered", data)
		return true
	return false
