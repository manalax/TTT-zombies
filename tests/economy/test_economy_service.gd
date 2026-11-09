extends GdUnitTestSuite
## F016: the Economy service credits players for real hits through Combat.apply().

const World := preload("res://tests/enemies/enemy_test_world.gd")
const DUMMY_SCENE := preload("res://src/world/dev/training_dummy.tscn")

var _world: Node3D
var _player: Player
var _enemy: EnemyBase


func before_test() -> void:
	_world = auto_free(World.world(30.0))
	add_child(_world)
	_player = World.player(_world, Vector3.ZERO)
	_player.set_physics_process(false)
	_enemy = World.acolyte(_world, Vector3(0, 0, -3), PI, _tough())
	_enemy.set_physics_process(false)
	_player.points.reset(0)


func _tough() -> EnemyData:
	var data := World.acolyte_data()
	data.max_health = 500.0
	return data


func _hit(
	source: HealthComponent,
	target: HealthComponent,
	amount: float,
	hurtbox: Hurtbox = null,
	type: CombatTypes.DamageType = CombatTypes.DamageType.MELEE
) -> DamageResult:
	return Combat.apply(DamageEvent.from_source(source, target, amount, type, hurtbox))


func test_player_starts_with_starting_points() -> void:
	var fresh := World.player(_world, Vector3(5, 0, 0))
	assert_int(fresh.points.balance).is_equal(Settings.match_settings.starting_points)


func test_hit_on_acolyte_pays_the_attacker() -> void:
	_hit(_player.health, _enemy.health, 35.0)
	assert_int(_player.points.balance).is_equal(40)
	assert_str(_player.points.last_award.describe()).contains("+40")


func test_weakpoint_hit_pays_more() -> void:
	var head: Hurtbox = _enemy.get_node("HeadHurtbox")
	var result := _hit(_player.health, _enemy.health, 20.0, head, CombatTypes.DamageType.BULLET)
	# 20 × firearm weak-point mult 1 (event default) = 20 applied, × 1.5 points = 30.
	assert_float(result.applied).is_equal_approx(20.0, 0.001)
	assert_int(_player.points.balance).is_equal(30)


func test_riposte_pays_bonus() -> void:
	_enemy.health.stun(1.0, _player.health)
	var event := DamageEvent.from_source(
		_player.health, _enemy.health, 35.0, CombatTypes.DamageType.MELEE
	)
	event.riposte_mult = 2.5
	var result := Combat.apply(event)
	assert_bool(result.riposte).is_true()
	assert_int(_player.points.balance).is_equal(140)  # 87.5 → 90, +50


func test_special_category_pays_more() -> void:
	var data := _tough()
	data.category = EnemyData.Category.SPECIAL
	var special := World.acolyte(_world, Vector3(4, 0, -3), PI, data)
	special.set_physics_process(false)
	_hit(_player.health, special.health, 40.0)
	assert_int(_player.points.balance).is_equal(60)


func test_training_dummy_pays() -> void:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector3(-4, 0, -3)
	_world.add_child(dummy)
	_hit(_player.health, dummy.health, 25.0)
	assert_int(_player.points.balance).is_equal(30)


func test_friendly_fire_and_enemy_hits_pay_nobody() -> void:
	var other := World.player(_world, Vector3(3, 0, 0))
	other.set_physics_process(false)
	other.points.reset(0)
	_hit(_player.health, other.health, 10.0)
	assert_int(_player.points.balance).is_equal(0)
	_hit(_enemy.health, _player.health, 15.0)
	assert_int(_player.points.balance).is_equal(0)
	assert_int(other.points.balance).is_equal(0)


func test_overkill_and_dead_targets() -> void:
	var data := World.acolyte_data()
	data.max_health = 10.0
	var frail := World.acolyte(_world, Vector3(-3, 0, -3), PI, data)
	frail.set_physics_process(false)
	_hit(_player.health, frail.health, 70.0)
	assert_int(_player.points.balance).is_equal(10)
	_hit(_player.health, frail.health, 70.0)  # already dead: rejected
	assert_int(_player.points.balance).is_equal(10)


func test_wallet_lookup_helpers() -> void:
	assert_object(Economy.wallet_for(_player.health.peer_id)).is_same(_player.points)
	assert_object(Economy.wallet_for(999)).is_null()
	assert_object(Economy.wallet_of(_enemy.health)).is_null()
	assert_int(Economy.category_of(_enemy.health)).is_equal(EnemyData.Category.COMMON)
