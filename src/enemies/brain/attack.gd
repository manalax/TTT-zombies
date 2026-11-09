extends EnemyState
## Parent of the swing phases. Leaving it for any reason (stagger, stun, death) clears the
## telegraph and the pose.


func _exit() -> void:
	enemy.set_telegraph(false)
	enemy.set_pose(&"idle")
