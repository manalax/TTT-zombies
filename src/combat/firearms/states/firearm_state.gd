class_name FirearmState
extends State
## Base for firearm states. The owner of these nodes is the Firearm.

var gun: Firearm:
	get:
		return owner as Firearm


func intent() -> MoveIntent:
	return gun.player.intent


func defaults() -> PlayerDefaults:
	return gun.player.defaults
