class_name EnemyState
extends State
## Base for cultist brain states (docs/adr/0008-enemy-ai.md). The owner is the EnemyBase.

var enemy: EnemyBase:
	get:
		return owner as EnemyBase


func data() -> EnemyData:
	return enemy.data
