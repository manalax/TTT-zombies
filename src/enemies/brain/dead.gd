extends EnemyState
## Terminal. EnemyBase handles the corpse (collision off, tip-over, removal after corpse_s).


func _enter(_data: Dictionary) -> void:
	enemy.stop()
