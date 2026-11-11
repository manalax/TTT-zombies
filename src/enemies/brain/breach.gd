extends EnemyState
## Outside a boarded window (F046, docs/adr/0013-barricades.md): walk to its outer point, swipe
## through at a player in reach, tear planks off while holding the window's single tear slot
## (otherwise wait nearby), and climb in once it is open.

## Enemies that cannot tear stop within this distance of the outer point.
const WAIT_RADIUS_M := 2.0
const ARRIVE_M := 0.15

var tear_elapsed: float = 0.0


func _enter(_data: Dictionary) -> void:
	tear_elapsed = 0.0
	enemy.set_pose(&"idle")


func _exit() -> void:
	if enemy.is_breaching():
		var window := enemy.breach
		if window.tearer == enemy:
			window.tearer = null
	enemy.set_pose(&"idle")


func _physics_update(delta: float) -> void:
	if not enemy.is_breaching():
		transition_to(&"Chase")
		return
	if enemy.can_start_attack():
		transition_to(&"Windup")
		return
	var window := enemy.breach
	var outer := window.outer_point()
	var distance := enemy.horizontal_distance_to(outer)
	if window.is_open():
		if window.claim_climb(enemy):
			if enemy.walk_to(outer, delta, ARRIVE_M):
				transition_to(&"Climb")
			return
		_approach_or_wait(outer, distance, delta)
		return
	var tearing := window.claim_tear(enemy)
	if not tearing:
		tear_elapsed = 0.0
		_approach_or_wait(outer, distance, delta)
		return
	if not enemy.walk_to(outer, delta, ARRIVE_M):
		return
	_face_window(delta)
	tear_elapsed += delta
	enemy.set_pose(&"swing", clampf(tear_elapsed / data().barricade_tear_s, 0.0, 1.0))
	if tear_elapsed >= data().barricade_tear_s - HealthComponent.TIMER_EPSILON:
		tear_elapsed = 0.0
		window.tear(enemy)


func _approach_or_wait(outer: Vector3, distance: float, delta: float) -> void:
	enemy.set_pose(&"idle")
	if distance > WAIT_RADIUS_M:
		enemy.walk_to(outer, delta, WAIT_RADIUS_M)
	else:
		enemy.stop()
		_face_window(delta)


func _face_window(delta: float) -> void:
	var window := enemy.breach
	enemy.face(window.inner_point() - enemy.global_position, EnemyBase.CHASE_TURN_DEG_S, delta)
