extends WeaponState
## Guard broken or stunned (parried): no attacking or blocking for the given duration
## (guard_break_stagger_s or the parrier's parry_stun_s), and slowed.

var elapsed: float = 0.0
var duration: float = 1.0


func _enter(data: Dictionary) -> void:
	elapsed = 0.0
	duration = float(data.get("duration", defaults().guard_break_stagger_s))
	weapon.set_blocking(false)


func _physics_update(delta: float) -> void:
	modifiers(defaults().guard_break_move_mult, true)
	elapsed += delta
	if elapsed >= duration:
		transition_to(&"Idle")


## Further staggers while staggered extend it to the longer remaining duration.
func _handle_event(event: StringName, data: Dictionary) -> bool:
	if event != &"staggered":
		return false
	duration = maxf(duration - elapsed, float(data.get("duration", 0.0)))
	elapsed = 0.0
	return true
