class_name PlayerMotor
extends RefCounted
## Pure movement math shared by the movement states (docs/adr/0003-player-controller.md).
##
## Static and side-effect free so it is unit-testable and reusable for server-side simulation.

## Below this input length the stick/keys count as released.
const INPUT_DEADZONE := 0.1


## Moves the horizontal part of [param velocity] toward [param wish_dir] * [param target_speed].
## With no wish direction it slows down at [param decel]. The vertical part is untouched.
static func accelerate(
	velocity: Vector3,
	wish_dir: Vector3,
	target_speed: float,
	accel: float,
	decel: float,
	delta: float
) -> Vector3:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if wish_dir.length_squared() > 0.0:
		horizontal = horizontal.move_toward(wish_dir * target_speed, accel * delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, decel * delta)
	return Vector3(horizontal.x, velocity.y, horizontal.z)


static func apply_gravity(velocity: Vector3, gravity: float, delta: float) -> Vector3:
	return Vector3(velocity.x, velocity.y - gravity * delta, velocity.z)


## World-space horizontal direction for a 2D move input (x = right, y = back, as from
## Input.get_vector) relative to [param basis]. Unit length, or zero inside the deadzone.
static func wish_direction(move: Vector2, basis: Basis) -> Vector3:
	if not has_move(move):
		return Vector3.ZERO
	var dir := basis * Vector3(move.x, 0.0, move.y)
	dir.y = 0.0
	return dir.normalized()


static func has_move(move: Vector2) -> bool:
	return move.length() >= INPUT_DEADZONE


## True if [param move] points within [param max_angle_deg] of forward (-y).
static func is_sprint_direction(move: Vector2, max_angle_deg: float) -> bool:
	if not has_move(move):
		return false
	var angle := rad_to_deg(move.normalized().angle_to(Vector2.UP))
	return absf(angle) <= max_angle_deg + 0.001


static func horizontal_speed(velocity: Vector3) -> float:
	return Vector2(velocity.x, velocity.z).length()
