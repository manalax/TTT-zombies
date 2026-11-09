extends Node
## Points service (DESIGN §12.3, docs/adr/0009-points-economy.md), autoload "Economy".
##
## On the authority it turns every committed hit (Combat.damage_applied) into points for the
## attacking player's PointsComponent. The rules themselves are in PointRules.


func _ready() -> void:
	Combat.damage_applied.connect(_on_damage_applied)


## The wallet of the player with [param peer_id], or null.
func wallet_for(peer_id: int) -> PointsComponent:
	for node in get_tree().get_nodes_in_group(AITargeting.GROUP):
		var player := node as Player
		if player != null and player.health.peer_id == peer_id:
			return player.points
	return null


## The wallet on the body that owns [param health], or null (AI, dummies, world).
static func wallet_of(health: HealthComponent) -> PointsComponent:
	if health == null:
		return null
	var body := health.get_body()
	if body == null:
		return null
	return body.get_node_or_null(^"PointsComponent") as PointsComponent


## Points category of the combatant owning [param health]: its EnemyData.category, or COMMON.
static func category_of(health: HealthComponent) -> EnemyData.Category:
	if health == null:
		return EnemyData.Category.COMMON
	var enemy := health.get_body() as EnemyBase
	if enemy != null and enemy.data != null:
		return enemy.data.category
	return EnemyData.Category.COMMON


func _on_damage_applied(result: DamageResult) -> void:
	if not Net.is_authority() or not PointRules.is_eligible(result):
		return
	var wallet := wallet_of(result.event.source)
	if wallet == null:
		return
	wallet.award_points(PointRules.for_hit(result, category_of(result.event.target)))
