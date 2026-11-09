extends EnemyState
## Parent of every living state. Poise staggers and parry stuns interrupt whatever is running.


func _handle_event(event: StringName, event_data: Dictionary) -> bool:
	match event:
		&"staggered":
			transition_to(&"Staggered", event_data)
			return true
		&"stunned":
			transition_to(&"Stunned", event_data)
			return true
	return false
