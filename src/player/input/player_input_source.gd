class_name PlayerInputSource
extends Node
## Base class for anything that drives a [Player]: local devices, tests, and later the network.


## Called once per physics step by the player.
func get_intent() -> MoveIntent:
	return MoveIntent.new()


## Look rotation accumulated since the last call, in degrees (x = yaw right, y = pitch down).
## Called once per render frame by the player.
func consume_look() -> Vector2:
	return Vector2.ZERO


## Called when movement cancels a crouch (sprinting out of a toggled crouch). Sources that
## resolve toggle-crouch reset their toggle here.
func cancel_crouch() -> void:
	pass
