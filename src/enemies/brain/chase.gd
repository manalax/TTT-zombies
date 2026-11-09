extends EnemyState
## Follow the navigation path to the target; start a swing once in range and in sight.


func _enter(_data: Dictionary) -> void:
	enemy.set_pose(&"idle")


func _physics_update(delta: float) -> void:
	if not enemy.has_target():
		transition_to(&"Idle")
		return
	if enemy.can_start_attack():
		transition_to(&"Windup")
		return
	enemy.chase(delta)
