extends WeaponState
## The swing's hit window: sweep the arc a little further each physics tick. Hitting world
## geometry clangs and ends the swing early (extra recovery).

var elapsed: float = 0.0


func _enter(_data: Dictionary) -> void:
	elapsed = 0.0
	var player := weapon.player
	weapon.sweep.begin(weapon.swing, player.health, Hitscan.collect_rids(player))


func _physics_update(delta: float) -> void:
	elapsed += delta
	var t := elapsed / weapon.swing.active_s
	var space := weapon.player.get_world_3d().direct_space_state
	var step := weapon.sweep.advance(space, weapon.eye_transform(), t)
	if not step.hits.is_empty():
		weapon.swing_hit.emit(step.hits)
	if step.clanged:
		weapon.clanged.emit(step.clang_point)
		transition_to(&"Recovery", {"clang": true})
	elif t >= 1.0:
		transition_to(&"Recovery")
