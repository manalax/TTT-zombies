class_name MoveIntent
extends RefCounted
## What the player wants to do this physics step (movement and combat buttons), independent of
## where it came from (local devices now, network packets in F021). Look is delivered
## separately, per render frame, via [method PlayerInputSource.consume_look].

## x = right, y = back (same convention as Input.get_vector). Length <= 1.
var move: Vector2 = Vector2.ZERO
var sprint: bool = false
## True only on the step the jump was pressed.
var jump_pressed: bool = false
## Desired posture, with hold/toggle already resolved by the source.
var crouch: bool = false
## True only on the step the dodge was pressed.
var dodge_pressed: bool = false
## Attack button state (held). Melee derives press/release edges itself (fire on release).
var attack_held: bool = false
var block_held: bool = false
## RMB doubles as aim with a firearm out; each weapon reads only its own field.
var aim_held: bool = false
## Loadout slot requested this step (0/1 firearms, 2 melee); -1 = none.
var slot_pressed: int = -1
## Mouse-wheel weapon cycling this step: -1, 0 or +1.
var cycle: int = 0
var reload_pressed: bool = false
var interact_pressed: bool = false


static func make(
	p_move: Vector2 = Vector2.ZERO,
	p_sprint: bool = false,
	p_jump_pressed: bool = false,
	p_crouch: bool = false
) -> MoveIntent:
	var intent := MoveIntent.new()
	intent.move = p_move.limit_length(1.0)
	intent.sprint = p_sprint
	intent.jump_pressed = p_jump_pressed
	intent.crouch = p_crouch
	return intent
