extends EnemyState
## No valid target: stand still until one appears.


func _enter(_data: Dictionary) -> void:
	enemy.stop()
	enemy.set_pose(&"idle")


func _physics_update(_delta: float) -> void:
	if enemy.has_target():
		transition_to(&"Chase")
	else:
		enemy.stop()
