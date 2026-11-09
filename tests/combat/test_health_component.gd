extends GdUnitTestSuite
## F011: HealthComponent bookkeeping.


func _health(max_health: float = 100.0) -> HealthComponent:
	var health: HealthComponent = auto_free(HealthComponent.new())
	health.setup(max_health)
	return health


func _hit(health: HealthComponent, amount: float) -> DamageResult:
	var result := DamagePipeline.resolve(DamageEvent.world(health, amount), DamageRules.new())
	health.apply_result(result)
	return result


func test_setup_fills() -> void:
	var health := _health(150)
	assert_float(health.current_health).is_equal(150.0)
	assert_float(health.get_ratio()).is_equal(1.0)


func test_damage_and_clamp() -> void:
	var health := _health()
	_hit(health, 30)
	assert_float(health.current_health).is_equal(70.0)
	_hit(health, 500)
	assert_float(health.current_health).is_equal(0.0)
	assert_bool(health.is_dead()).is_true()


func test_died_emitted_once() -> void:
	var health := _health()
	var deaths: Array[DamageResult] = []
	health.died.connect(func(result: DamageResult) -> void: deaths.append(result))
	_hit(health, 100)
	health.apply_result(DamageResult.rejected(null, &"x"))
	_hit(health, 50)
	assert_int(deaths.size()).is_equal(1)
	assert_bool(deaths[0].killed).is_true()


func test_signals() -> void:
	var health := _health()
	var changes: Array[float] = []
	var hits: Array[float] = []
	health.health_changed.connect(
		func(current: float, _max: float) -> void: changes.append(current)
	)
	health.damaged.connect(func(result: DamageResult) -> void: hits.append(result.applied))
	_hit(health, 25)
	health.heal(10)
	assert_array(changes).contains_exactly([75.0, 85.0])
	assert_array(hits).contains_exactly([25.0])


func test_heal_capped_and_not_when_dead() -> void:
	var health := _health()
	_hit(health, 10)
	health.heal(50)
	assert_float(health.current_health).is_equal(100.0)
	_hit(health, 100)
	health.heal(50)
	assert_float(health.current_health).is_equal(0.0)


func test_reset_revives() -> void:
	var health := _health()
	_hit(health, 100)
	health.reset()
	assert_bool(health.is_dead()).is_false()
	assert_float(health.current_health).is_equal(100.0)


func test_forward_and_position_without_body() -> void:
	var health := _health()
	assert_vector(health.forward()).is_equal(Vector3.FORWARD)
	assert_vector(health.get_world_position()).is_equal(Vector3.ZERO)
