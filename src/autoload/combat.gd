extends Node
## Damage service (DESIGN §12.3, docs/adr/0004-damage-pipeline.md).
##
## All damage goes through apply(): never subtract health directly. On the authority it resolves
## the event with DamagePipeline using the active MatchSettings, commits it (stamina, health),
## then announces it. Clients get no result (F032 sends them the outcome).

## Every committed hit, authority only. Node refs are fine here: this is a server-side service
## signal, not part of the Events bus. Consumers: points (F016), exposure (F042), death (F044).
signal damage_applied(result: DamageResult)


func apply(event: DamageEvent) -> DamageResult:
	if not Net.is_authority():
		return DamageResult.rejected(event, &"not_authority")
	var result := DamagePipeline.resolve(event, get_rules())
	if not result.accepted:
		return result
	_commit(result)
	return result


## Rules from the active MatchSettings (built-in defaults if none is set).
func get_rules() -> DamageRules:
	return DamageRules.from_settings(Settings.match_settings)


func _commit(result: DamageResult) -> void:
	var event := result.event
	var target := event.target
	if result.stamina_spent > 0.0 and target.block != null and target.block.stamina != null:
		target.block.stamina.drain(result.stamina_spent)
	if not is_nan(result.parry_timing_ms) and target.block != null:
		target.block.last_timing_ms = result.parry_timing_ms
	if result.parried:
		target.block.notify_parried()
		if event.source != null:
			event.source.stun(target.block.parry_stun_s, target)
	if result.riposte:
		target.clear_riposte()
	target.apply_result(result)
	if target.poise != null and result.stagger > 0.0 and not target.is_dead():
		target.poise.add(result.stagger)
	damage_applied.emit(result)
	if target.peer_id > 0:
		Events.player_damaged.emit(target.peer_id, event.source_peer_id, result.applied)
		if target.is_dead():
			Events.player_died.emit(
				target.peer_id, event.source_peer_id, CombatTypes.type_name(event.type)
			)
