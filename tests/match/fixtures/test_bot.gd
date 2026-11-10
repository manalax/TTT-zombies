extends RefCounted
## F019 test bot: kills every enemy the registry receives, [member kill_delay_s] after it
## appears, through Combat.apply as [member attacker] (a real hit, so points, enemy_killed and
## the director's bookkeeping all run). Drive it with [method step].

var attacker: HealthComponent
var kill_delay_s: float = 0.5
var kills: int = 0

var _pending: Dictionary[EnemyBase, float] = {}


func _init(registry: EnemyRegistry, p_attacker: HealthComponent) -> void:
	attacker = p_attacker
	registry.child_entered_tree.connect(_on_child)


func _on_child(node: Node) -> void:
	var enemy := node as EnemyBase
	if enemy != null:
		_pending[enemy] = kill_delay_s


func step(delta: float) -> void:
	for enemy: EnemyBase in _pending.keys():
		if not is_instance_valid(enemy):
			_pending.erase(enemy)
			continue
		_pending[enemy] -= delta
		if _pending[enemy] > 0.0 or not enemy.is_node_ready():
			continue
		_pending.erase(enemy)
		if enemy.is_dead():
			continue
		var event := DamageEvent.from_source(
			attacker, enemy.health, 100000.0, CombatTypes.DamageType.MELEE
		)
		if Combat.apply(event).killed:
			kills += 1
