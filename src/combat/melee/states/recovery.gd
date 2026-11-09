extends WeaponState
## After the swing. Block cannot cancel it. A light released near its end is buffered and
## chains into the next swing (alternating side); a held button starts charging.

var elapsed: float = 0.0
var duration: float = 0.0


func _enter(data: Dictionary) -> void:
	elapsed = 0.0
	duration = weapon.swing.recovery_s
	if data.get("clang", false):
		duration += weapon.stats.clang_recovery_s


func _physics_update(delta: float) -> void:
	elapsed += delta
	if elapsed < duration:
		return
	if weapon.since_release <= weapon.stats.combo_buffer_s:
		if weapon.start_swing(weapon.make_light_swing()):
			return
	if intent().attack_held:
		transition_to(&"Charging")
	else:
		transition_to(&"Idle")
