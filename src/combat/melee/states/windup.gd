extends WeaponState
## Telegraph before the swing can hit. Block cancels it (feint); stamina is not refunded.

var elapsed: float = 0.0


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0


func _physics_update(delta: float) -> void:
	if intent().block_held:
		transition_to(&"Blocking")
		return
	elapsed += delta
	if elapsed >= weapon.swing.windup_s:
		transition_to(&"Active")
