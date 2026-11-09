class_name MovementState
extends State
## Base for the player's movement states (docs/adr/0003-player-controller.md).
##
## States read the current intent, set the motor parameters and posture on the [Player], and
## request transitions. They never move the body themselves: the player runs the motor after
## the machine has ticked.

var player: Player:
	get:
		return owner as Player


func intent() -> MoveIntent:
	return player.intent


func defaults() -> PlayerDefaults:
	return player.defaults


func wants_sprint() -> bool:
	var i := intent()
	return (
		i.sprint
		and not player.sprint_locked
		and PlayerMotor.is_sprint_direction(i.move, defaults().sprint_max_angle_deg)
		and player.stamina.can_sprint()
	)


## The grounded leaf the current intent asks for. Crouch wins while crouch is wanted or there is
## no room to stand.
func choose_ground_leaf() -> StringName:
	if intent().crouch or (player.is_crouched() and not player.has_headroom()):
		return &"Crouch"
	if not PlayerMotor.has_move(intent().move):
		return &"Idle"
	if wants_sprint():
		return &"Sprint"
	return &"Walk"


## Transitions to [method choose_ground_leaf] if it differs from this state. Returns true if a
## transition was requested (the caller should stop its update).
func follow_ground_leaf() -> bool:
	var next := choose_ground_leaf()
	if next == name:
		return false
	return transition_to(next)
