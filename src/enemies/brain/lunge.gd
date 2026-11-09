extends EnemyState
## The swing's hit window: dash lunge_distance_m along the locked facing while sweeping the arc.
## Walls and bodies stop the dash (move_and_slide); hitting a wall with the blade clangs.

var elapsed: float = 0.0
var direction: Vector3 = Vector3.FORWARD


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0
	enemy.set_telegraph(false)
	enemy.lock_swing()
	direction = enemy.forward()
	direction.y = 0.0
	direction = direction.normalized()
	enemy.begin_sweep()
	enemy.set_pose(&"swing", 0.0)


func _physics_update(delta: float) -> void:
	var active := data().attack_active_s
	enemy.move_direct(direction * data().lunge_distance_m / active)
	elapsed += delta
	var t := minf(elapsed / active, 1.0)
	enemy.set_pose(&"swing", t)
	var clanged := enemy.advance_sweep(t)
	if clanged or t >= 1.0 - HealthComponent.TIMER_EPSILON:
		transition_to(&"Recovery", {"clang": clanged})
