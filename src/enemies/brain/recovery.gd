extends EnemyState
## Standing still after the swing: the punish window. Then the attack cooldown starts and it
## goes back to chasing.

var elapsed: float = 0.0


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0
	enemy.stop()


func _physics_update(delta: float) -> void:
	enemy.stop()
	elapsed += delta
	if elapsed >= data().attack_recovery_s - HealthComponent.TIMER_EPSILON:
		enemy.cooldown_left = data().attack_cooldown_s
		transition_to(&"Chase")
