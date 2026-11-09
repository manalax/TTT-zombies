extends GdUnitTestSuite
## F012: PoiseComponent build-up, decay, stagger, and blocked hits carrying less stagger.


func _poise() -> PoiseComponent:
	var poise: PoiseComponent = auto_free(PoiseComponent.new())
	poise.stagger_resist = 30.0
	poise.decay_per_s = 10.0
	poise.stagger_duration_s = 0.5
	return poise


func test_accumulates_until_threshold() -> void:
	var poise := _poise()
	var count := [0]
	poise.staggered.connect(func(_d: float) -> void: count[0] += 1)
	poise.add(10)
	poise.add(15)
	assert_bool(poise.is_staggered()).is_false()
	poise.add(10)
	assert_bool(poise.is_staggered()).is_true()
	assert_int(count[0]).is_equal(1)
	# No extra stagger while already staggered.
	poise.add(100)
	assert_int(count[0]).is_equal(1)


func test_decay() -> void:
	var poise := _poise()
	poise.add(25)
	poise.tick(1.0)
	assert_float(poise.accumulated).is_equal(15.0)
	poise.add(10)
	assert_bool(poise.is_staggered()).is_false()


func test_recovers_after_duration() -> void:
	var poise := _poise()
	var recovered := [false]
	poise.recovered.connect(func() -> void: recovered[0] = true)
	poise.add(40)
	poise.tick(0.25)
	assert_bool(poise.is_staggered()).is_true()
	poise.tick(0.3)
	assert_bool(poise.is_staggered()).is_false()
	assert_bool(recovered[0]).is_true()


func test_combat_applies_stagger_reduced_by_block() -> void:
	var body: Node3D = auto_free(Node3D.new())
	var target := HealthComponent.new()
	target.faction = CombatTypes.Faction.HUNTER
	body.add_child(target)
	add_child(body)
	target.setup(1000)
	target.poise = _poise()
	var attacker_body: Node3D = auto_free(Node3D.new())
	var attacker := HealthComponent.new()
	attacker_body.add_child(attacker)
	add_child(attacker_body)
	attacker_body.global_position = Vector3(0, 0, -2)

	var hit := DamageEvent.from_source(attacker, target, 10, CombatTypes.DamageType.MELEE)
	hit.stagger = 20.0
	assert_float(Combat.apply(hit).stagger).is_equal(20.0)
	assert_float(target.poise.accumulated).is_equal(20.0)

	var stamina: StaminaComponent = auto_free(StaminaComponent.new())
	stamina.configure(PlayerDefaults.new())
	var block := BlockState.new()
	block.active = true
	block.reduction = 0.75
	block.stamina = stamina
	target.block = block
	var blocked := DamageEvent.from_source(attacker, target, 10, CombatTypes.DamageType.MELEE)
	blocked.stagger = 20.0
	var result := Combat.apply(blocked)
	assert_bool(result.blocked).is_true()
	assert_float(result.stagger).is_equal(5.0)
	assert_float(target.poise.accumulated).is_equal(25.0)
