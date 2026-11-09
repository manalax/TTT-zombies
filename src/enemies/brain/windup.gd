extends EnemyState
## The telegraph (the parry read): stand still, glow and raise the arm for attack_windup_s while
## slowly turning to track the target. At the end the swing direction locks.

var elapsed: float = 0.0


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0
	enemy.stop()
	enemy.set_telegraph(true)
	enemy.set_pose(&"raised")


func _physics_update(delta: float) -> void:
	enemy.stop()
	if enemy.has_target():
		enemy.face(
			enemy.target.global_position - enemy.global_position, EnemyBase.WINDUP_TURN_DEG_S, delta
		)
	elapsed += delta
	if elapsed >= data().attack_windup_s - HealthComponent.TIMER_EPSILON:
		transition_to(&"Lunge")
