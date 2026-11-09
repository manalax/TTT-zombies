class_name WeaponState
extends State
## Base for melee weapon states. The owner of these nodes is the MeleeWeapon.

var weapon: MeleeWeapon:
	get:
		return owner as MeleeWeapon


func intent() -> MoveIntent:
	return weapon.player.intent


func defaults() -> PlayerDefaults:
	return weapon.player.defaults


func modifiers(speed_mult: float, sprint_locked: bool) -> void:
	weapon.player.set_combat_modifiers(speed_mult, sprint_locked)
