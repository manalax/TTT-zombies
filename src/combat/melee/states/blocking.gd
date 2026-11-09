extends WeaponState
## Guard up while block is held. Only melee in the frontal arc is reduced (DamagePipeline).
## A fresh press opens the parry window (docs/adr/0006-parry-dodge.md); a block still held from
## before (e.g. through a stagger or recovery) does not.


func _enter(_data: Dictionary) -> void:
	weapon.set_blocking(true)
	if weapon.block_pressed:
		weapon.player.health.block.open_parry_window()


func _physics_update(_delta: float) -> void:
	if not intent().block_held:
		transition_to(&"Idle")
		return
	modifiers(defaults().block_move_mult, true)


func _exit() -> void:
	weapon.player.health.block.close_parry_window()
	weapon.set_blocking(false)
