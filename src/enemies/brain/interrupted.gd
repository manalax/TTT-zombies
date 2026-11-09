extends EnemyState
## Poise stagger or parry stun: stand still in a flinch for the given duration, then chase.
## A further interruption extends it to the longer remaining time.

var elapsed: float = 0.0
var duration: float = 0.5


func _enter(event_data: Dictionary) -> void:
	elapsed = 0.0
	duration = float(event_data.get("duration", data().stagger_duration_s))
	enemy.stop()
	enemy.set_telegraph(false)
	enemy.set_pose(&"flinch")


func _exit() -> void:
	enemy.set_pose(&"idle")


func _physics_update(delta: float) -> void:
	enemy.stop()
	elapsed += delta
	if elapsed >= duration - HealthComponent.TIMER_EPSILON:
		transition_to(&"Chase")


func _handle_event(event: StringName, event_data: Dictionary) -> bool:
	if event != &"staggered" and event != &"stunned":
		return false
	if event == &"stunned" and name != &"Stunned":
		transition_to(&"Stunned", event_data)
		return true
	duration = maxf(duration - elapsed, float(event_data.get("duration", 0.0)))
	elapsed = 0.0
	return true
