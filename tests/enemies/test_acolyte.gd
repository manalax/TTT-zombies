# gdlint:disable=max-public-methods
extends GdUnitTestSuite
## F015: acolyte chase, telegraphed lunge swing, player counterplay, reactions and death.
## The brain is stepped manually (avoidance off) so timings are tick-exact.

const World := preload("res://tests/enemies/enemy_test_world.gd")
const ScriptedInputSource := preload("res://tests/player/fixtures/scripted_input_source.gd")
const DT := 1.0 / 60.0
const NAV_SYNC_FRAMES := 6

var _world: Node3D
var _player: Player
var _input: ScriptedInputSource
var _enemies: Array[EnemyBase] = []
var _killed: Array[Array] = []


func before_test() -> void:
	_enemies.clear()
	_killed.clear()
	Events.enemy_killed.connect(_on_enemy_killed)


func after_test() -> void:
	Events.enemy_killed.disconnect(_on_enemy_killed)


func _on_enemy_killed(net_id: int, killer_id: int) -> void:
	_killed.append([net_id, killer_id])


func _build(boxes: Array[AABB] = [], with_player: bool = true) -> void:
	_world = auto_free(World.world(40.0, boxes))
	add_child(_world)
	if with_player:
		_player = World.player(_world, Vector3.ZERO)
		_player.set_physics_process(false)
		_input = _player.get_meta(&"input")


## An acolyte at [param at] facing the player (+Z from the -Z side).
func _spawn(at: Vector3, data: EnemyData = null) -> EnemyBase:
	var enemy := World.acolyte(_world, at, PI, data)
	enemy.set_physics_process(false)
	enemy.agent.avoidance_enabled = false
	_enemies.append(enemy)
	return enemy


## Lets the navigation map pick up the freshly baked region (regions sync asynchronously).
func _settle() -> void:
	for i in NAV_SYNC_FRAMES:
		await get_tree().physics_frame
	for enemy in _enemies:
		enemy.update_target()


func _steps(count: int) -> void:
	for i in count:
		if _player != null:
			_player.step(DT)
		for enemy in _enemies:
			if is_instance_valid(enemy):
				enemy.step(DT)


## Steps until [param enemy] reaches [param path] (or [param limit] ticks). Returns ticks taken.
func _until(enemy: EnemyBase, path: String, limit: int = 120) -> int:
	for i in limit:
		if enemy.get_state_path() == path:
			return i
		_steps(1)
	return -1


func _player_hit(amount: float, stagger: float, enemy: EnemyBase) -> DamageResult:
	var event := DamageEvent.from_source(
		_player.health, enemy.health, amount, CombatTypes.DamageType.MELEE
	)
	event.stagger = stagger
	return Combat.apply(event)


func _tough() -> EnemyData:
	var data := World.acolyte_data()
	data.max_health = 500.0
	return data


# --- Targeting and movement ---------------------------------------------------------------


func test_idles_without_a_target() -> void:
	_build([], false)
	var enemy := _spawn(Vector3(0, 0, -5))
	await _settle()
	_steps(30)
	assert_str(enemy.get_state_path()).is_equal("Alive/Idle")
	assert_object(enemy.target).is_null()


func test_chases_and_closes_distance() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -12))
	await _settle()
	_steps(90)
	assert_str(enemy.get_state_path()).is_equal("Alive/Chase")
	assert_float(enemy.horizontal_distance_to(_player.global_position)).is_less(9.0)
	assert_object(enemy.target).is_same(_player)


func test_paths_around_a_wall() -> void:
	_build([AABB(Vector3(-4, 0, -6.5), Vector3(8, 3, 1))])
	var enemy := _spawn(Vector3(0, 0, -12))
	await _settle()
	var max_side := 0.0
	for i in 360:
		_steps(1)
		max_side = maxf(max_side, absf(enemy.global_position.x))
		if enemy.get_state_path().begins_with("Alive/Attack"):
			break
	assert_float(max_side).is_greater(3.5)
	assert_float(enemy.horizontal_distance_to(_player.global_position)).is_less(2.5)


func test_target_is_never_a_dead_or_cult_body() -> void:
	_build()
	var other := World.acolyte(_world, Vector3(3, 0, 0))
	var candidates: Array[Node3D] = [other, _player]
	assert_object(AITargeting.pick(Vector3(4, 0, 0), candidates, null, 2.0)).is_same(_player)
	_player.health.setup(1.0)
	Combat.apply(DamageEvent.world(_player.health, 5.0, CombatTypes.DamageType.DEBUG))
	assert_object(AITargeting.pick(Vector3(4, 0, 0), candidates, null, 2.0)).is_null()


# --- Telegraph and lunge ------------------------------------------------------------------


func test_windup_telegraphs_for_exactly_the_windup_time() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -2.0))
	await _settle()
	assert_int(_until(enemy, "Alive/Attack/Windup")).is_greater_equal(0)
	assert_bool(enemy.is_telegraphing()).is_true()
	var ticks := roundi(enemy.data.attack_windup_s / DT)  # 0.6 s = 36 ticks
	_steps(ticks - 1)
	assert_str(enemy.get_state_path()).is_equal("Alive/Attack/Windup")
	_steps(1)
	assert_str(enemy.get_state_path()).is_equal("Alive/Attack/Lunge")
	assert_bool(enemy.is_telegraphing()).is_false()


func test_lunge_moves_forward_and_hits_the_player() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -2.2))
	await _settle()
	_until(enemy, "Alive/Attack/Lunge")
	var start := enemy.global_position
	var hits: Array[DamageResult] = []
	enemy.attack_hit.connect(func(results: Array[DamageResult]) -> void: hits.append_array(results))
	_until(enemy, "Alive/Attack/Recovery", 30)
	var moved := enemy.global_position - start
	moved.y = 0.0
	assert_float(moved.length()).is_between(0.9, 1.3)
	assert_float(moved.z).is_greater(0.0)  # toward the player
	assert_int(hits.size()).is_equal(1)
	assert_float(_player.health.current_health).is_equal_approx(100.0 - 15.0, 0.01)


func test_recovery_then_cooldown_before_next_swing() -> void:
	_build()
	_player.health.invulnerable = true
	var enemy := _spawn(Vector3(0, 0, -2.2))
	await _settle()
	_until(enemy, "Alive/Attack/Recovery")
	var recovery := roundi(enemy.data.attack_recovery_s / DT)
	_steps(recovery - 1)
	assert_str(enemy.get_state_path()).is_equal("Alive/Attack/Recovery")
	_steps(1)
	assert_str(enemy.get_state_path()).is_equal("Alive/Chase")
	assert_float(enemy.cooldown_left).is_greater(0.0)
	var wait := _until(enemy, "Alive/Attack/Windup", 120)
	assert_float(wait * DT).is_greater_equal(enemy.data.attack_cooldown_s - DT)


func test_stepping_back_during_windup_makes_it_whiff() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -2.2))
	await _settle()
	_until(enemy, "Alive/Attack/Windup")
	_player.global_position.z += 2.5
	# Let the physics space see the teleport (queries use the last synced broadphase).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_until(enemy, "Alive/Attack/Recovery", 60)
	assert_float(_player.health.current_health).is_equal(100.0)


# --- Player counterplay -------------------------------------------------------------------


func test_parry_stuns_and_opens_riposte() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -2.2), _tough())
	await _settle()
	_until(enemy, "Alive/Attack/Lunge")
	_input.block_held = true  # fresh press as the lunge starts: inside the 0.2 s window
	_steps(15)
	assert_float(_player.health.current_health).is_equal(100.0)
	assert_bool(enemy.health.is_stunned()).is_true()
	assert_str(enemy.get_state_path()).is_equal("Alive/Stunned")
	assert_object(enemy.health.riposte_by).is_same(_player.health)
	_input.block_held = false
	_steps(2)
	# Let the physics space see where the lunge left the acolyte before swinging at it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var before := enemy.health.current_health
	_input.attack_held = true
	_steps(1)
	_input.attack_held = false
	_steps(40)
	# Sword light 35 × riposte 2.5 (more on the head).
	assert_float(before - enemy.health.current_health).is_greater_equal(87.0)


func test_block_reduces_the_hit() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -2.2))
	_input.block_held = true
	await _settle()
	_steps(50)  # past the parry window: a plain block
	_until(enemy, "Alive/Attack/Recovery", 120)
	var lost := 100.0 - _player.health.current_health
	assert_float(lost).is_greater(0.0)
	assert_float(lost).is_less(15.0)


func test_dodge_iframes_avoid_the_hit() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -2.2))
	await _settle()
	var hits: Array[DamageResult] = []
	enemy.attack_hit.connect(func(results: Array[DamageResult]) -> void: hits.append_array(results))
	_until(enemy, "Alive/Attack/Lunge")
	_player.health.grant_iframes(0.5)
	_until(enemy, "Alive/Attack/Recovery", 30)
	assert_int(hits.size()).is_equal(1)
	assert_str(hits[0].reject_reason).is_equal("dodged")
	assert_float(_player.health.current_health).is_equal(100.0)


func test_unparryable_data_maps_to_unparryable_swing() -> void:
	_build()
	var data := World.acolyte_data()
	data.parryable = false
	var enemy := _spawn(Vector3(0, 0, -2.2), data)
	assert_bool(enemy.build_swing().unparryable).is_true()
	assert_bool(World.acolyte_data().parryable).is_true()


# --- Reactions ----------------------------------------------------------------------------


func test_heavy_stagger_interrupts_windup() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -2.2), _tough())
	await _settle()
	_until(enemy, "Alive/Attack/Windup")
	_player_hit(35.0, 10.0, enemy)  # light: below stagger_resist 30
	assert_str(enemy.get_state_path()).is_equal("Alive/Attack/Windup")
	_player_hit(70.0, 35.0, enemy)  # heavy
	assert_str(enemy.get_state_path()).is_equal("Alive/Staggered")
	assert_bool(enemy.is_telegraphing()).is_false()
	_steps(roundi(enemy.data.stagger_duration_s / DT))
	assert_str(enemy.get_state_path()).is_equal("Alive/Chase")


func test_damage_aggro_switches_target() -> void:
	_build()
	var other := World.player(_world, Vector3(6, 0, -8))
	other.set_physics_process(false)
	var enemy := _spawn(Vector3(0, 0, -5))
	await _settle()
	assert_object(enemy.target).is_same(_player)
	var event := DamageEvent.from_source(
		other.health, enemy.health, 5.0, CombatTypes.DamageType.BULLET
	)
	Combat.apply(event)
	assert_object(enemy.target).is_same(other)
	enemy.update_target()
	assert_object(enemy.target).is_same(other)  # aggro memory holds it
	_steps(roundi(enemy.data.aggro_memory_s / DT) + 1)
	# It chased the aggressor meanwhile; put it back next to the first player.
	enemy.global_position = Vector3(0, 0, -1.5)
	enemy.update_target()
	assert_object(enemy.target).is_same(_player)


# --- Death --------------------------------------------------------------------------------


func test_death_disables_collision_emits_and_despawns() -> void:
	_build()
	var enemy := _spawn(Vector3(0, 0, -6))
	await _settle()
	var net_id := enemy.net_id
	var result := _player_hit(500.0, 0.0, enemy)
	assert_bool(result.killed).is_true()
	assert_str(enemy.get_state_path()).is_equal("Dead")
	assert_array(_killed).contains([[net_id, _player.health.peer_id]])
	await get_tree().physics_frame
	assert_int(enemy.collision_layer).is_equal(0)
	assert_int((enemy.get_node("BodyHurtbox") as Area3D).collision_layer).is_equal(0)
	_steps(roundi(enemy.data.corpse_s / DT) - 2)
	assert_bool(enemy.is_queued_for_deletion()).is_false()
	_steps(3)
	assert_bool(enemy.is_queued_for_deletion()).is_true()


func test_cult_melee_never_hurts_another_acolyte() -> void:
	_build([], false)
	var a := _spawn(Vector3(0, 0, -2))
	var b := _spawn(Vector3(0, 0, -3))
	var swing := DamageEvent.from_source(a.health, b.health, 15.0, CombatTypes.DamageType.MELEE)
	assert_bool(Combat.apply(swing).accepted).is_false()
	assert_float(b.health.current_health).is_equal(b.health.max_health)
