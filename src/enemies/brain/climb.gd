extends EnemyState
## Climbing through an open boarded window (F046): move from where it stands to the window's
## inner point over BarricadeData.climb_s, ignoring the window's collider. It can't attack and
## can't be interrupted (staggers and stuns are swallowed). Then the window is behind it.
## If a body (a player standing in the window) stops it short, it drops back to Breach.

var elapsed: float = 0.0
var duration: float = 0.8
var velocity: Vector3 = Vector3.ZERO
var climbed: bool = false


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0
	climbed = false
	var window := enemy.breach
	duration = window.data.climb_s
	enemy.add_collision_exception_with(window)
	var offset := window.inner_point() - enemy.global_position
	offset.y = 0.0
	velocity = offset / duration
	enemy.set_telegraph(false)
	enemy.set_pose(&"raised")


func _physics_update(delta: float) -> void:
	enemy.move_direct(velocity)
	enemy.face(velocity, EnemyBase.CHASE_TURN_DEG_S, delta)
	elapsed += delta
	if elapsed >= duration - HealthComponent.TIMER_EPSILON:
		climbed = enemy.breach.is_inside(enemy.global_position)
		transition_to(&"Chase" if climbed else &"Breach")


func _exit() -> void:
	var window := enemy.breach
	enemy.stop()
	enemy.set_pose(&"idle")
	if window != null and is_instance_valid(window):
		enemy.remove_collision_exception_with(window)
		window.release(enemy)
	if climbed or enemy.is_dead():
		enemy.breach = null


func _handle_event(event: StringName, _event_data: Dictionary) -> bool:
	return event == &"staggered" or event == &"stunned"
